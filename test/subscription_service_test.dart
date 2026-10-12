import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:mobile/services/subscription_service.dart';
import 'package:mobile/models/subscription_receipt.dart';

Map<String, dynamic> premium([String user = 'buyer']) => {
  'id': 'subscription-123',
  'user_id': user,
  'plan_name': 'CLIENTE_PREMIUM',
  'status': 'ACTIVE',
  'amount': 5,
  'currency': 'USD',
  'paypal_order_id': 'ORDER-123',
  'started_at': DateTime.now().toUtc().toIso8601String(),
  'expires_at': DateTime.now()
      .toUtc()
      .add(const Duration(days: 30))
      .toIso8601String(),
};
Map<String, dynamic> receipt() => {
  'id': 'subscription-123',
  'buyer_name': 'Buyer',
  'buyer_email': 'buyer@example.com',
  'plan_name': 'CLIENTE_PREMIUM',
  'amount': 5,
  'currency': 'USD',
  'paypal_order_id': 'ORDER-123',
  'paypal_capture_id': 'CAPTURE-123',
  'is_sandbox': true,
  'paid_at': DateTime.now().toUtc().toIso8601String(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'First load is unknown; refresh preserves Premium and shares the request',
    () async {
      final storage = StorageService();
      var response = Completer<http.Response>();
      var requests = 0;
      final api = ApiService(
        storage,
        client: MockClient((_) {
          requests++;
          return response.future;
        }),
      )..currentUserId = 'buyer';
      addTearDown(api.dispose);
      final service = SubscriptionService(api, storage);
      final first = service.fetchCurrentSubscription(userId: 'buyer');
      expect(service.hasResolvedSubscription, isFalse);
      expect(service.isRefreshing, isTrue);
      response.complete(http.Response(jsonEncode(premium()), 200));
      await first;
      expect(service.isPremium, isTrue);
      expect(service.hasResolvedSubscription, isTrue);
      response = Completer<http.Response>();
      final refresh = service.fetchCurrentSubscription(userId: 'buyer');
      final duplicate = service.fetchCurrentSubscription(userId: 'buyer');
      expect(service.isPremium, isTrue);
      expect(service.isRefreshing, isTrue);
      response.complete(http.Response(jsonEncode(premium()), 200));
      await Future.wait([refresh, duplicate]);
      expect(requests, 2);
      expect(service.isPremium, isTrue);
    },
  );

  test('Only a confirmed absence removes Premium; temporary server error preserves it', () async {
    final storage = StorageService();
    var next = http.Response(jsonEncode(premium()), 200);
    final api = ApiService(storage, client: MockClient((_) async => next))
      ..currentUserId = 'buyer';
    addTearDown(api.dispose);
    final service = SubscriptionService(api, storage);
    await service.fetchCurrentSubscription(userId: 'buyer');
    next = http.Response('{}', 503);
    await service.fetchCurrentSubscription(userId: 'buyer');
    expect(service.isPremium, isTrue);
    expect(service.hasResolvedSubscription, isTrue);
    next = http.Response('null', 200);
    await service.fetchCurrentSubscription(userId: 'buyer');
    expect(service.isPremium, isFalse);
    expect(service.hasResolvedSubscription, isTrue);
    expect(
      (await storage.getLocalSubscription(userId: 'buyer'))['status'],
      isNull,
    );
  });

  test(
    'New account does not inherit Premium or a late refresh result',
    () async {
      final storage = StorageService();
      final gate = Completer<http.Response>();
      final api = ApiService(storage, client: MockClient((_) => gate.future))
        ..currentUserId = 'buyer';
      addTearDown(api.dispose);
      final service = SubscriptionService(api, storage);
      final pending = service.fetchCurrentSubscription(userId: 'buyer');
      service.reset();
      api.currentUserId = 'other';
      gate.complete(http.Response(jsonEncode(premium()), 200));
      await pending;
      expect(service.isPremium, isFalse);
      expect(service.hasResolvedSubscription, isFalse);
    },
  );

  test(
    'Confirmed checkout immediately enables Premium and fetches its receipt',
    () async {
      final storage = StorageService();
      final api = ApiService(
        storage,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/verify-order')) {
            return http.Response(
              jsonEncode({
                'paid': true,
                'status': 'COMPLETED',
                'subscription': premium(),
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/receipts')) {
            return http.Response(jsonEncode([receipt()]), 200);
          }
          return http.Response('null', 200);
        }),
      )..currentUserId = 'buyer';
      addTearDown(api.dispose);
      final service = SubscriptionService(api, storage);
      final result = await service.verifyAndActivateSubscription(
        'ORDER-123',
        userId: 'buyer',
      );
      expect(result.isPaid, isTrue);
      expect(service.isPremium, isTrue);
      expect(service.hasResolvedSubscription, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(service.receipts.single.captureId, 'CAPTURE-123');
      expect(service.receipts.single.isSandbox, isTrue);
    },
  );

  test(
    'Receipt failure never turns a confirmed payment into a failed checkout',
    () async {
      final storage = StorageService();
      final api = ApiService(
        storage,
        client: MockClient(
          (request) async => request.url.path.endsWith('/verify-order')
              ? http.Response(
                  jsonEncode({'paid': true, 'subscription': premium()}),
                  200,
                )
              : http.Response('{}', 503),
        ),
      )..currentUserId = 'buyer';
      addTearDown(api.dispose);
      final service = SubscriptionService(api, storage);
      expect(
        (await service.verifyAndActivateSubscription(
          'ORDER-123',
          userId: 'buyer',
        )).isPaid,
        isTrue,
      );
      expect(service.isPremium, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(service.receiptsError, isNotNull);
    },
  );

  test(
    'Receipt PDF uses authenticated binary download and token refresh',
    () async {
      final storage = StorageService();
      await storage.saveTokens(accessToken: 'old', refreshToken: 'refresh');
      final api = ApiService(
        storage,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            return http.Response(
              '{"access_token":"new","refresh_token":"rotated"}',
              200,
            );
          }
          if (request.headers['Authorization'] != 'Bearer new') {
            return http.Response('{}', 401);
          }
          return http.Response(
            '%PDF-1.4 receipt',
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }),
      )..currentUserId = 'buyer';
      addTearDown(api.dispose);
      final service = SubscriptionService(api, storage);
      final bytes = await service.downloadReceipt(
        SubscriptionReceipt.fromJson(receipt()),
      );
      expect(utf8.decode(bytes), startsWith('%PDF-'));
      expect(await storage.getAccessToken(), 'new');
    },
  );
  test(
    'Confirmed payment returns while receipt history is still loading',
    () async {
      final storage = StorageService();
      final receiptGate = Completer<http.Response>();
      final api = ApiService(
        storage,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/verify-order')) {
            return http.Response(
              jsonEncode({'paid': true, 'subscription': premium()}),
              200,
            );
          }
          return receiptGate.future;
        }),
      )..currentUserId = 'buyer';
      addTearDown(api.dispose);
      final service = SubscriptionService(api, storage);
      final result = await service.verifyAndActivateSubscription(
        'ORDER-123',
        userId: 'buyer',
      );
      expect(result.isPaid, isTrue);
      expect(service.isPremium, isTrue);
      expect(service.receiptsLoading, isTrue);
      receiptGate.complete(http.Response(jsonEncode([receipt()]), 200));
      await Future<void>.delayed(Duration.zero);
      expect(service.receipts.single.orderId, 'ORDER-123');
    },
  );
}
