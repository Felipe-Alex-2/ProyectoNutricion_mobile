import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:mobile/services/offline_wallet_service.dart';
import 'package:mobile/modo_offline/cache_local_service.dart';
import 'package:mobile/modo_offline/cola_sincronizacion_service.dart';
import 'package:mobile/modo_offline/conectividad_service.dart';
import 'package:mobile/modo_offline/sincronizador_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late CacheLocalService cache;
  late ColaSincronizacionService queue;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('nutri-offline-wallet-');
    cache = CacheLocalService();
    queue = ColaSincronizacionService(documentsDirectory: dir);
    await cache.guardar('/wallet', {
      'balance': 5,
      'movements': [],
    }, userId: 'a');
    await cache.guardar('/my-payments', [
      for (final id in ['one', 'two'])
        {
          'id': 'payment-$id',
          'appointment_id': id,
          'status': 'PENDING',
          'amount': 5,
          'payment_method': 'PENDING',
        },
    ], userId: 'a');
  });
  tearDown(() async {
    queue.dispose();
    if (!dir.absolute.path.startsWith(Directory.systemTemp.absolute.path) ||
        !dir.uri.pathSegments
            .where((s) => s.isNotEmpty)
            .last
            .startsWith('nutri-offline-wallet-')) {
      throw StateError('Unexpected test directory');
    }
    await dir.delete(recursive: true);
  });

  test('Offline wallet reserves funds, prevents double spending and survives restart', () async {
    final api = ApiService(
      StorageService(),
      cacheService: cache,
      client: MockClient((_) async => throw http.ClientException('offline')),
    )..currentUserId = 'a';
    addTearDown(api.dispose);
    final service = OfflineWalletService(api, queue);
    expect((await service.pay('one'))['status'], 'PENDING_SYNC');
    expect(service.available({'balance': 5, 'movements': []}), 0);
    await expectLater(service.pay('one'), throwsStateError);
    await expectLater(service.pay('two'), throwsStateError);
    expect(queue.elementos, hasLength(1));
    final id = queue.elementos.single.id;
    final restarted = ColaSincronizacionService(documentsDirectory: dir);
    addTearDown(restarted.dispose);
    await restarted.asegurarCuenta('a');
    expect(restarted.elementos.single.id, id);
    api.currentUserId = 'b';
    await restarted.asegurarCuenta('b');
    expect(restarted.elementos, isEmpty);
    await expectLater(
      OfflineWalletService(api, restarted).pay('one'),
      throwsA(isA<ApiException>()),
    );
  });

  test('Lost response reuses the operation key and never subtracts a settled movement twice', () async {
    var offline = true;
    final keys = <String>[];
    final api = ApiService(
      StorageService(),
      cacheService: cache,
      client: MockClient((request) async {
        if (request.method == 'POST') {
          keys.add(request.headers['Idempotency-Key']!);
        }
        if (offline) throw http.ClientException('lost response');
        if (request.url.path.endsWith('/wallet')) {
          return http.Response(
            jsonEncode({
              'balance': 0,
              'movements': [
                {'amount': -5, 'payment_id': 'payment-one'},
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/my-payments')) {
          return http.Response(
            '[{"id":"payment-one","appointment_id":"one","status":"COMPLETED"}]',
            200,
          );
        }
        expect(jsonDecode(request.body)['method'], 'WALLET');
        return http.Response(
          '{"status":"COMPLETED","payment_id":"payment-one"}',
          200,
        );
      }),
    )..currentUserId = 'a';
    addTearDown(api.dispose);
    final service = OfflineWalletService(api, queue);
    await service.pay('one');
    final id = queue.elementos.single.id;
    // The server may have settled the original request before its response was lost.
    expect(
      service.reserved({
        'balance': 0,
        'movements': [
          {'amount': -5, 'payment_id': 'payment-one'},
        ],
      }),
      0,
    );
    offline = false;
    final connection = ConectividadService(iniciarMonitoreo: false);
    addTearDown(connection.dispose);
    final sync = SincronizadorService(
      conectividadService: connection,
      colaService: queue,
      apiService: api,
    );
    addTearDown(sync.dispose);
    await sync.sincronizarCola(userId: 'a');
    expect(queue.elementos, isEmpty);
    expect(keys.toSet(), {id});
    expect((await cache.obtener('/wallet', userId: 'a'))['balance'], 0);
  });

  test('Pending wallet reservations are released only after a server rejection, never marked paid', () async {
    var offline = true;
    final api = ApiService(
      StorageService(),
      cacheService: cache,
      client: MockClient((_) async {
        if (offline) throw http.ClientException('offline');
        return http.Response('{"detail":"Saldo insuficiente"}', 400);
      }),
    )..currentUserId = 'a';
    addTearDown(api.dispose);
    final service = OfflineWalletService(api, queue);
    await service.pay('one');
    offline = false;
    final connection = ConectividadService(iniciarMonitoreo: false);
    addTearDown(connection.dispose);
    final sync = SincronizadorService(
      conectividadService: connection,
      colaService: queue,
      apiService: api,
    );
    addTearDown(sync.dispose);
    await sync.sincronizarCola(userId: 'a');
    expect(queue.elementos.single.estado, 'ERROR_PERMANENTE');
    expect(service.reserved({'balance': 5, 'movements': []}), 0);
    expect(queue.elementos.single.mensajeError, 'Saldo insuficiente');
  });
}
