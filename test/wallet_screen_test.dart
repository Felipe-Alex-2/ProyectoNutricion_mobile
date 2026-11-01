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
                        'payment_method': paid ? 'WALLET' : 'PENDING',
                        'paypal_order_id': null,
                      },
                    ]
                  : [];
            }
            if (r.url.path.endsWith('/appointments/a/pay')) {
              paid = true;
              body = {'payment_id': 'p', 'status': 'COMPLETED'};
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
          final pay = find.text('Pagar USD 5 con wallet');
          await tester.ensureVisible(pay);
          await tester.tap(pay);
          await tester.pumpAndSettle();
          expect(paid, isTrue);
          expect(
            requests
                .where((r) => r.url.path.endsWith('/appointments/a/pay'))
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
}
