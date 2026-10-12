import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:mobile/modo_offline/cache_local_service.dart';
import 'package:mobile/modo_offline/elemento_cola.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'Concurrent unauthorized requests share one refresh and retry',
    () async {
      final storage = StorageService();
      await storage.saveTokens(accessToken: 'old', refreshToken: 'refresh');
      var refreshes = 0;
      final gate = Completer<void>();
      final api = ApiService(
        storage,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            refreshes++;
            await gate.future;
            return http.Response(
              jsonEncode({'access_token': 'new', 'refresh_token': 'rotated'}),
              200,
            );
          }
          return request.headers['Authorization'] == 'Bearer new'
              ? http.Response('{"ok":true}', 200)
              : http.Response('{}', 401);
        }),
      );
      addTearDown(api.dispose);
      final pending = Future.wait([
        api.get('/users/me'),
        api.get('/appointments'),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gate.complete();
      expect(await pending, [
        {'ok': true},
        {'ok': true},
      ]);
      expect(refreshes, 1);
      expect(await storage.getRefreshToken(), 'rotated');
    },
  );

  test(
    'An old account request cannot retry using a new account token',
    () async {
      final storage = StorageService();
      await storage.saveTokens(
        accessToken: 'account-a',
        refreshToken: 'refresh-a',
      );
      final response = Completer<http.Response>();
      var requests = 0;
      final api = ApiService(
        storage,
        client: MockClient((_) {
          requests++;
          return response.future;
        }),
      )..currentUserId = 'a';
      addTearDown(api.dispose);
      final pending = api.get('/users/me');
      final assertion = expectLater(
        pending,
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      api.currentUserId = 'b';
      await storage.saveTokens(
        accessToken: 'account-b',
        refreshToken: 'refresh-b',
      );
      response.complete(http.Response('{}', 401));
      await assertion;
      expect(requests, 1);
      expect(await storage.getAccessToken(), 'account-b');
    },
  );

  test('Forbidden is not replaced by offline cached clinical data', () async {
    final cache = CacheLocalService();
    await cache.guardar('/anamnesis/me', {'sensitive': true}, userId: 'a');
    final api = ApiService(
      StorageService(),
      cacheService: cache,
      client: MockClient(
        (_) async => http.Response('{"detail":"Forbidden"}', 403),
      ),
    )..currentUserId = 'a';
    addTearDown(api.dispose);
    await expectLater(
      api.get('/anamnesis/me'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
    );
  });

  test('Network outage uses only the current account cache', () async {
    final cache = CacheLocalService();
    await cache.guardar('/users/me', {'id': 'a'}, userId: 'a');
    final api = ApiService(
      StorageService(),
      cacheService: cache,
      client: MockClient((_) async => throw http.ClientException('offline')),
    )..currentUserId = 'a';
    addTearDown(api.dispose);
    expect(await api.get('/users/me'), {'id': 'a'});
    api.currentUserId = 'b';
    await expectLater(
      api.get('/users/me'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 0)),
    );
  });

  test('Clinical cache is isolated, expires and clears per account', () async {
    final cache = CacheLocalService();
    await cache.guardar('/profile', {'id': 'a'}, userId: 'a');
    await cache.guardar('/profile', {'id': 'b'}, userId: 'b');
    expect(await cache.obtener('/profile'), isNull);
    await cache.limpiarCacheUsuario('a');
    expect(await cache.obtener('/profile', userId: 'a'), isNull);
    expect(await cache.obtener('/profile', userId: 'b'), {'id': 'b'});
    expect(
      await cache.obtener(
        '/profile',
        userId: 'b',
        duracionValidez: const Duration(seconds: -1),
      ),
      isNull,
    );
  });

  test('Offline retry ceiling and permanent failures stop resubmission', () {
    final item = ElementoCola(
      id: 'id',
      userId: 'a',
      metodo: 'POST',
      endpoint: '/appointments',
      tipoAccion: 'CREAR_CITA',
      descripcionHumana: 'Cita',
      fechaCreacion: DateTime.now(),
    );
    expect(item.esSincronizable, isTrue);
    item.reintentos = 5;
    expect(item.esSincronizable, isFalse);
    item.reintentos = 0;
    item.estado = 'ERROR_PERMANENTE';
    expect(item.esSincronizable, isFalse);
  });
}
