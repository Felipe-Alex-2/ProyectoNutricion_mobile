import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:mobile/services/nutrition_diary_service.dart';
import 'package:mobile/modo_offline/cache_local_service.dart';
import 'package:mobile/modo_offline/cola_sincronizacion_service.dart';
import 'package:mobile/modo_offline/conectividad_service.dart';
import 'package:mobile/modo_offline/sincronizador_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('nutri-diary-test-');
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'Offline meals persist across restart and stay isolated after logout',
    () async {
      final api = ApiService(StorageService())..currentUserId = 'patient-a';
      addTearDown(api.dispose);
      final queue = ColaSincronizacionService(documentsDirectory: directory);
      addTearDown(queue.dispose);
      final service = NutritionDiaryService(api, queue);
      await service.save(
        description: 'Pollo y arroz',
        mealType: 'Almuerzo',
        consumedAt: DateTime.utc(2026, 10, 29, 12),
        calories: 450,
      );
      final id = queue.elementos.single.id;
      expect(
        queue.elementos.single.cuerpo!['consumed_at'],
        '2026-10-29T12:00:00.000Z',
      );
      queue.soltarCuenta();
      expect(queue.elementos, isEmpty);
      await queue.cargarCola(userId: 'patient-b');
      expect(queue.elementos, isEmpty);
      final restarted = ColaSincronizacionService(
        documentsDirectory: directory,
      );
      addTearDown(restarted.dispose);
      await restarted.cargarCola(userId: 'patient-a');
      expect(restarted.elementos.single.id, id);
      expect(
        restarted.elementos.single.cuerpo!['description'],
        'Pollo y arroz',
      );
    },
  );

  test(
    'Lost response retries use the same meal UUID and preserve the queue',
    () async {
      var fail = true;
      final ids = <String>[];
      final api = ApiService(
        StorageService(),
        client: MockClient((request) async {
          ids.add(
            (jsonDecode(request.body) as Map)['client_record_id'] as String,
          );
          if (fail) throw http.ClientException('offline');
          return http.Response('{"id":"saved"}', 201);
        }),
      )..currentUserId = 'patient-a';
      addTearDown(api.dispose);
      final queue = ColaSincronizacionService(documentsDirectory: directory);
      addTearDown(queue.dispose);
      await NutritionDiaryService(api, queue).save(
        description: 'Manzana',
        mealType: 'Snack',
        consumedAt: DateTime.now(),
      );
      final connectivity = ConectividadService(iniciarMonitoreo: false);
      addTearDown(connectivity.dispose);
      final sync = SincronizadorService(
        conectividadService: connectivity,
        colaService: queue,
        apiService: api,
      );
      addTearDown(sync.dispose);
      await sync.sincronizarCola(userId: 'patient-a');
      expect(queue.elementos, hasLength(1));
      expect(queue.elementos.single.proximoIntento, isNotNull);
      fail = false;
      await queue.reintentar(queue.elementos.single.id, userId: 'patient-a');
      await sync.sincronizarCola(userId: 'patient-a');
      // The queue listener may have started synchronization in a microtask.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(queue.elementos, isEmpty);
      expect(ids.toSet(), hasLength(1));
    },
  );

  test('Invalid manual nutrition never reaches persistent storage', () async {
    final api = ApiService(StorageService())..currentUserId = 'a';
    addTearDown(api.dispose);
    final queue = ColaSincronizacionService(documentsDirectory: directory);
    addTearDown(queue.dispose);
    final diary = NutritionDiaryService(api, queue);
    await expectLater(
      diary.save(
        description: 'Comida',
        mealType: 'Cena',
        consumedAt: DateTime.now(),
        calories: -1,
      ),
      throwsArgumentError,
    );
    await expectLater(
      diary.save(
        description: ' ',
        mealType: 'Cena',
        consumedAt: DateTime.now(),
      ),
      throwsArgumentError,
    );
    expect(queue.elementos, isEmpty);
  });

  test(
    'Downloaded plan is available offline and cleared when server revokes it',
    () async {
      final cache = CacheLocalService();
      await cache.guardar('/plans/my-plan', {'id': 'approved'}, userId: 'a');
      var offline = true;
      final api = ApiService(
        StorageService(),
        cacheService: cache,
        client: MockClient((_) async {
          if (offline) throw http.ClientException('offline');
          return http.Response('null', 200);
        }),
      )..currentUserId = 'a';
      addTearDown(api.dispose);
      expect(await api.get('/plans/my-plan'), {'id': 'approved'});
      offline = false;
      expect(await api.get('/plans/my-plan'), isNull);
      offline = true;
      await expectLater(
        api.get('/plans/my-plan'),
        throwsA(isA<ApiException>()),
      );
      api.currentUserId = 'b';
      await expectLater(
        api.get('/plans/my-plan'),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
