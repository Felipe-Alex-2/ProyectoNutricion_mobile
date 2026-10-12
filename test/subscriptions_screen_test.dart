import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:mobile/services/subscription_service.dart';
import 'package:mobile/services/theme_service.dart';
import 'package:mobile/screens/subscriptions/subscriptions_screen.dart';
import 'package:mobile/screens/subscriptions/subscription_receipts_section.dart';

import 'subscription_service_test.dart' show premium;

class BuyerAuth extends AuthService {
  BuyerAuth(super.apiService, super.storageService);
  @override
  User get currentUser => User(
    id: 'buyer',
    email: 'buyer@example.com',
    fullName: 'Buyer',
    roleId: 'CLIENTE',
    isActive: true,
    isVerified: true,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'Unknown subscription shows checking, then Premium stays visible during refresh',
    (tester) async {
      final storage = StorageService();
      var gate = Completer<http.Response>();
      final api = ApiService(
        storage,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/current')) return gate.future;
          return http.Response('[]', 200);
        }),
      )..currentUserId = 'buyer';
      final service = SubscriptionService(api, storage);
      final auth = BuyerAuth(api, storage);
      final theme = ThemeService();
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SubscriptionService>.value(value: service),
            ChangeNotifierProvider<AuthService>.value(value: auth),
            ChangeNotifierProvider<ThemeService>.value(value: theme),
          ],
          child: const MaterialApp(home: Scaffold(body: SubscriptionsScreen())),
        ),
      );
      await tester.pump();
      expect(find.text('Comprobando suscripción…'), findsOneWidget);
      expect(find.text('Bloqueado (Requiere Premium)'), findsNothing);
      gate.complete(http.Response(jsonEncode(premium()), 200));
      await tester.pumpAndSettle();
      expect(find.text('Suscripción Premium Activa'), findsOneWidget);
      gate = Completer<http.Response>();
      final refresh = service.fetchCurrentSubscription(userId: 'buyer');
      await tester.pump();
      expect(find.text('Suscripción Premium Activa'), findsOneWidget);
      expect(find.text('Bloqueado (Requiere Premium)'), findsNothing);
      gate.complete(http.Response(jsonEncode(premium()), 200));
      await refresh;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      auth.dispose();
      theme.dispose();
    },
  );

  test('Android PDF saving passes the bytes and filename to the system save dialog', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_file_dialog'), (
          call,
        ) async {
          received = call;
          return 'content://downloads/receipt.pdf';
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter_file_dialog'),
            null,
          ),
    );
    final bytes = Uint8List.fromList(utf8.encode('%PDF-1.4 example'));
    expect(await saveReceiptPdf(bytes, 'receipt.pdf'), isTrue);
    expect(received!.method, 'saveFile');
    expect(received!.arguments['fileName'], 'receipt.pdf');
    expect(received!.arguments['data'], bytes);
  });
}
