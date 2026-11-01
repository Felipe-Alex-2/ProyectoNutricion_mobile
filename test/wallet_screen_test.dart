import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:mobile/config/theme.dart';
import 'package:mobile/screens/payments/wallet_screen.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/appointment_service.dart';
import 'package:mobile/services/storage_service.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  setUpAll(() async {
    final loader = FontLoader('NutriSans');
    for (final weight in ['regular', 'medium', 'bold']) {
      loader.addFont(rootBundle.load('assets/fonts/nutri-sans-$weight.ttf'));
    }
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final accepted in [false, true]) {
    testWidgets(
      'Wallet narrow phone: payment enabled only after acceptance=$accepted',
      (tester) async {
        tester.view.physicalSize = const Size(320, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var paid = false;
        var preference = 'PENDING';
        final requests = <http.Request>[];
        final api = ApiService(
          StorageService(),
          client: MockClient((r) async {
            requests.add(r);
            dynamic body = [];
            if (r.url.path.endsWith('/wallet')) {
              body = {
                'balance': paid ? 5 : 10,
                'movements': [],
                'currency': 'USD',
              };
            }
            if (r.url.path.endsWith('/my-payments')) {
              body = accepted
                  ? [
                      {
                        'id': 'p',
                        'appointment_id': 'a',
                        'status': paid ? 'COMPLETED' : 'PENDING',
                        'concept': 'Consulta general',
                        'amount': 5,
                        'currency': 'USD',
                        'payment_method': paid ? 'WALLET' : preference,
                        'paypal_order_id': null,
                      },
                    ]
                  : [];
            }
            if (r.url.path.endsWith('/appointments/a/pay')) {
              final method = jsonDecode(r.body)['method'];
              if (method == 'ONLINE' || method == 'PRESENCIAL') {
                preference = method;
                body = {'payment_id': 'p', 'status': 'PENDING'};
              } else {
                paid = true;
                body = {'payment_id': 'p', 'status': 'COMPLETED'};
              }
            }
            return http.Response(
              jsonEncode(body),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );
        api.currentUserId = 'patient';
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<ApiService>.value(value: api),
              ChangeNotifierProvider(create: (_) => AppointmentService(api)),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: RepaintBoundary(
                key: boundary,
                child: const WalletScreen(appointmentId: 'a'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (!accepted) {
          expect(
            find.text(
              'El especialista debe aceptar la cita para habilitar el pago.',
            ),
            findsOneWidget,
          );
          expect(find.text('Pagar USD 5 con wallet'), findsNothing);
        } else {
          final presencial = find.text('Presencial · USD 5');
          await tester.ensureVisible(presencial);
          await tester.tap(presencial);
          await tester.pumpAndSettle();
          expect(paid, isFalse);
          expect(preference, 'PRESENCIAL');
          expect(find.text('Pagar USD 5 con wallet'), findsNothing);
          final online = find.text('Online · USD 5');
          await tester.ensureVisible(online);
          await tester.tap(online);
          await tester.pumpAndSettle();
          expect(paid, isFalse);
          final pay = find.text('Pagar USD 5 con wallet');
          await tester.ensureVisible(pay);
          await tester.tap(pay);
          await tester.pumpAndSettle();
          expect(paid, isTrue);
          expect(
            requests
                .where(
                  (r) =>
                      r.url.path.endsWith('/appointments/a/pay') &&
                      jsonDecode(r.body)['method'] == 'WALLET',
                )
                .single
                .body,
            contains('WALLET'),
          );
          expect(find.text('Confirmada · pagada'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        if (accepted) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final directory = Directory('build/wallet-preview')
              ..createSync(recursive: true);
            File('${directory.path}/wallet.png')
                .writeAsBytesSync(data!.buffer.asUint8List());
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'Reopening wallet automatically verifies the latest approved topup',
    (tester) async {
      var credited = false;
      var captures = 0;
      final api = ApiService(
        StorageService(),
        client: MockClient((r) async {
          dynamic body = [];
          if (r.url.path.endsWith('/wallet')) {
            body = {
              'balance': credited ? 20 : 0,
              'movements': [],
              'currency': 'USD',
            };
          }
          if (r.url.path.endsWith('/my-payments')) {
            body = [
              {
                'id': 'topup',
                'purpose': 'WALLET_TOPUP',
                'status': credited ? 'COMPLETED' : 'PENDING',
                'concept': 'Recarga wallet USD 20',
                'amount': 20,
                'payment_method': 'PAYPAL',
                'paypal_order_id': 'ORDER',
              },
            ];
          }
          if (r.url.path.endsWith('/payments/capture')) {
            captures++;
            credited = true;
            body = {'status': 'COMPLETED'};
          }
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      api.currentUserId = 'patient';
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiService>.value(value: api),
            ChangeNotifierProvider(create: (_) => AppointmentService(api)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const WalletScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(captures, 1);
      expect(credited, isTrue);
      expect(
        find.text('Recarga confirmada. Tu saldo ya está disponible.'),
        findsOneWidget,
      );
      expect(find.text(r'$20.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Wallet failure does not block choosing in-person payment for an accepted appointment',
    (tester) async {
      String? selected;
      final api = ApiService(
        StorageService(),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/wallet')) {
            return http.Response('{"detail":"Not Found"}', 404);
          }
          dynamic body = [];
          if (r.url.path.endsWith('/my-payments')) {
            body = [
              {
                'id': 'p',
                'appointment_id': 'a',
                'status': 'PENDING',
                'concept': 'Consulta general',
                'amount': 5,
                'payment_method': selected ?? 'PENDING',
                'paypal_order_id': null,
              },
            ];
          }
          if (r.url.path.endsWith('/appointments/a/pay')) {
            selected = jsonDecode(r.body)['method'];
            body = {'status': 'PENDING', 'payment_id': 'p'};
          }
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      api.currentUserId = 'patient';
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiService>.value(value: api),
            ChangeNotifierProvider(create: (_) => AppointmentService(api)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const WalletScreen(appointmentId: 'a'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Not Found'), findsNothing);
      final option = find.text('Presencial · USD 5');
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(selected, 'PRESENCIAL');
      expect(find.text('Confirmada · pagada'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
