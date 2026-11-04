import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:mobile/services/food_vision_service.dart';
import 'package:mobile/modo_offline/cache_local_service.dart';
import 'package:mobile/modo_offline/copia_offline_service.dart';
import 'package:mobile/modo_offline/cola_sincronizacion_service.dart';
import 'package:mobile/modo_offline/conectividad_service.dart';
import 'package:mobile/modo_offline/sincronizador_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'Login copy downloads plan and doctors; failed copy preserves timestamp',
    () async {
      var offline = false;
      final requested = <String>[];
      final api = ApiService(
        StorageService(),
        cacheService: CacheLocalService(),
        client: MockClient((request) async {
          requested.add(request.url.path);
          if (offline) throw http.ClientException('offline');
          if (request.url.path.endsWith('/clinical/anamnesis/me')) {
            return http.Response('{}', 404);
          }
          return http.Response(
            request.url.path.endsWith('/plans/my-plan')
                ? '{"title":"Plan profesional"}'
                : '[]',
            200,
          );
        }),
      )..currentUserId = 'a';
      addTearDown(api.dispose);
      final copy = CopiaOfflineService(api);
      addTearDown(copy.dispose);
      await copy.bindUser('a');
      expect(copy.ultimaCopia, isNotNull);
      expect(
        requested.any((p) => p.endsWith('/appointments/nutritionists')),
        isTrue,
      );
      final last = copy.ultimaCopia;
      offline = true;
      await copy.copiar();
      expect(copy.error, isNotNull);
      expect(copy.ultimaCopia, last);
      expect(await api.get('/plans/my-plan'), {'title': 'Plan profesional'});
      api.currentUserId = 'b';
      await copy.bindUser('b');
      expect(copy.ultimaCopia, isNull);
      await expectLater(
        api.get('/plans/my-plan'),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test('Photo survives restart, is isolated, and replays multipart with original key', () async {
    final dir = await Directory.systemTemp.createTemp('nutri-offline-photo-');
    addTearDown(() async {
      final resolved = dir.absolute.path;
      if (!resolved.startsWith(Directory.systemTemp.absolute.path) ||
          !dir.uri.pathSegments
              .where((s) => s.isNotEmpty)
              .last
              .startsWith('nutri-offline-photo-')) {
        throw StateError('Unexpected test directory');
      }
      await dir.delete(recursive: true);
    });
    var offline = true;
    final keys = <String?>[];
    final api = ApiService(
      StorageService(),
      client: MockClient((request) async {
        keys.add(request.headers['Idempotency-Key']);
        expect(
          request.headers['content-type'],
          contains('multipart/form-data'),
        );
        if (offline) throw http.ClientException('offline');
        expect(latin1.decode(request.bodyBytes), contains('food.jpg'));
        return http.Response(
          '{"record_id":"saved","alimentos":[],"total":{}}',
          200,
        );
      }),
    )..currentUserId = 'a';
    addTearDown(api.dispose);
    final queue = ColaSincronizacionService(documentsDirectory: dir);
    addTearDown(queue.dispose);
    final vision = FoodVisionService(api, colaService: queue);
    addTearDown(vision.dispose);
    final bytes = Uint8List.fromList([255, 216, 255, 65]);
    expect(await vision.analyzeImage(bytes, 'food.jpg'), isNull);
    expect(vision.wasQueued, isTrue);
    expect(base64Decode(queue.elementos.single.cuerpo!['image_base64']), bytes);
    final id = queue.elementos.single.id;
    final restarted = ColaSincronizacionService(documentsDirectory: dir);
    addTearDown(restarted.dispose);
    await restarted.cargarCola(userId: 'b');
    expect(restarted.elementos, isEmpty);
    await restarted.cargarCola(userId: 'a');
    expect(restarted.elementos.single.id, id);
    offline = false;
    final connectivity = ConectividadService(iniciarMonitoreo: false);
    addTearDown(connectivity.dispose);
    final sync = SincronizadorService(
      conectividadService: connectivity,
      colaService: restarted,
      apiService: api,
    );
    addTearDown(sync.dispose);
    await sync.sincronizarCola(userId: 'a');
    expect(restarted.elementos, isEmpty);
    expect(keys.toSet(), {id});
  });
}
