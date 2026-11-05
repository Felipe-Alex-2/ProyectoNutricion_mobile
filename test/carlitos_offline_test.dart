import 'dart:async';

import 'package:mobile/modo_offline/cache_local_service.dart';

import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/services/subscription_service.dart';
import 'package:mobile/services/theme_service.dart';
import 'package:mobile/screens/chat/carlitos_chat_screen.dart';
import 'package:mobile/config/theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/modo_offline/conectividad_service.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:mobile/services/carlitos_chat_service.dart';
import 'package:mobile/services/offline_carlitos_service.dart';

class Connection extends ConectividadService {
  bool online;
  Connection(this.online) : super(iniciarMonitoreo: false);
  @override
  bool get estaConectado => online;
}

class LocalRuntime implements CarlitosLocalRuntime {
  int calls = 0;
  List<Map<String, String>> received = [];
  final Completer<void> started = Completer<void>();
  Completer<String>? pending;
  @override
  Future<String> reply(String path, List<Map<String, String>> messages) async {
    calls++;
    received = messages;
    expect(File(path).readAsBytesSync(), [71, 71, 85, 70]);
    expect(messages.first['role'], 'system');
    if (!started.isCompleted) started.complete();
    return pending != null
        ? pending!.future
        : 'Respuesta generada en el teléfono.';
  }

  @override
  void cancel() {}
  @override
  Future<void> dispose() async {}
}

class PremiumAccess extends SubscriptionService {
  PremiumAccess(super.api, super.storage);
  @override
  bool get isPremium => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  late CarlitosModelSpec spec;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    folder = await Directory.systemTemp.createTemp('carlitos-tests-');
    spec = CarlitosModelSpec(
      url: 'https://example.test/model.gguf',
      filename: 'test.gguf',
      bytes: 4,
      sha256Hex: sha256.convert([71, 71, 85, 70]).toString(),
    );
  });
  tearDown(() async {
    final root = Directory.systemTemp.absolute.path;
    expect(folder.absolute.parent.path, root);
    expect(
      folder.path.split(Platform.pathSeparator).last,
      startsWith('carlitos-tests-'),
    );
    await folder.delete(recursive: true);
  });
  OfflineCarlitosService local(LocalRuntime runtime, {bool corrupt = false}) =>
      OfflineCarlitosService(
        model: spec,
        directoryProvider: () async => folder,
        runtimeFactory: () => runtime,
        clientFactory: () => MockClient(
          (_) async => http.Response.bytes(
            corrupt ? [1, 2, 3, 4] : [71, 71, 85, 70],
            200,
          ),
        ),
      );

  test(
    'Model download verifies integrity before being available offline',
    () async {
      final runtime = LocalRuntime();
      final offline = local(runtime);
      expect(await offline.download(), isTrue);
      expect(offline.isReady, isTrue);
      expect(
        await offline.generate([
          {'role': 'user', 'content': 'Hola'},
        ]),
        contains('teléfono'),
      );
      expect(runtime.calls, 1);
      await offline.release();
      offline.dispose();
      final restored = local(LocalRuntime());
      await restored.initialize();
      expect(restored.isReady, isTrue);
      restored.dispose();
    },
  );
  test(
    'Corrupted download is not accepted and partial file is removed',
    () async {
      final offline = local(LocalRuntime(), corrupt: true);
      expect(await offline.download(), isFalse);
      expect(offline.isReady, isFalse);
      expect(
        await File('${folder.path}/carlitos_models/test.gguf.part').exists(),
        isFalse,
      );
      expect(
        await File('${folder.path}/carlitos_models/test.gguf').exists(),
        isFalse,
      );
      offline.dispose();
    },
  );
  test(
    'Offline chat bypasses HTTP and persists account-scoped conversation',
    () async {
      final runtime = LocalRuntime();
      final offline = local(runtime);
      await offline.download();
      var httpCalls = 0;
      final connection = Connection(false);
      final api = ApiService(
        StorageService(),
        conectividadService: connection,
        client: MockClient((_) async {
          httpCalls++;
          throw http.ClientException('offline');
        }),
      )..currentUserId = 'owner';
      final chat = CarlitosChatService(
        api,
        offline: offline,
        canUseOffline: () => true,
      );
      expect(await chat.sendMessage('Hola'), isTrue);
      expect(httpCalls, 0);
      expect(chat.messages.last.source, 'LOCAL');
      expect(chat.messages.last.content, 'Respuesta generada en el teléfono.');
      chat.dispose();
      final restored = CarlitosChatService(
        api,
        offline: local(LocalRuntime()),
        canUseOffline: () => true,
      );
      await restored.fetchHistory();
      expect(restored.messages.length, 2);
      api.currentUserId = 'other';
      await restored.fetchHistory();
      expect(restored.messages, isEmpty);
      api.currentUserId = 'owner';
      await restored.fetchHistory();
      expect(restored.messages.length, 2);
      await restored.clearHistory();
      expect(restored.messages, isEmpty);
      restored.dispose();
      api.dispose();
      connection.dispose();
    },
  );
  test('Offline context follows the current account and prevents sugary soda advice for fat loss', () async {
    final runtime = LocalRuntime();
    final offline = local(runtime);
    await offline.download();
    final cache = CacheLocalService();
    await cache.guardar('/clinical/anamnesis/me', {
      'patient_id': 'owner',
      'goal': 'Pérdida de grasa',
      'allergies': 'Maní',
      'pathologies': 'Hipertensión',
    }, userId: 'owner');
    await cache.guardar('/plans/my-plan', {
      'patient_id': 'owner',
      'status': 'APPROVED',
      'title': 'Mi plan aprobado',
    }, userId: 'owner');
    final connection = Connection(false);
    final api = ApiService(
      StorageService(),
      cacheService: cache,
      conectividadService: connection,
    )..currentUserId = 'owner';
    final chat = CarlitosChatService(
      api,
      offline: offline,
      canUseOffline: () => true,
    );
    expect(await chat.sendMessage('¿Me recomiendas tomar soda?'), isTrue);
    expect(runtime.received.first['content'], contains('Maní'));
    expect(runtime.received.first['content'], contains('Hipertensión'));
    expect(runtime.received.first['content'], contains('Mi plan aprobado'));
    expect(
      chat.messages.last.content,
      contains('agua en lugar de gaseosas azucaradas'),
    );
    await cache.guardar('/clinical/anamnesis/me', {
      'patient_id': 'owner',
      'goal': 'Ganancia muscular',
    }, userId: 'owner');
    expect(await chat.sendMessage('Dame una idea'), isTrue);
    expect(runtime.received.first['content'], contains('Ganancia muscular'));
    expect(runtime.received.first['content'], isNot(contains('Hipertensión')));
    api.currentUserId = 'other';
    expect(await chat.sendMessage('Dame una idea'), isTrue);
    expect(
      runtime.received.first['content'],
      isNot(contains('Ganancia muscular')),
    );
    expect(
      runtime.received.first['content'],
      isNot(contains('Mi plan aprobado')),
    );
    chat.dispose();
    api.dispose();
    connection.dispose();
  });
  test('Missing model does not invent an offline response', () async {
    final connection = Connection(false);
    final runtime = LocalRuntime();
    final api = ApiService(StorageService(), conectividadService: connection)
      ..currentUserId = 'owner';
    final chat = CarlitosChatService(
      api,
      offline: local(runtime),
      canUseOffline: () => true,
    );
    expect(await chat.sendMessage('Hola'), isFalse);
    expect(chat.messages, isEmpty);
    expect(runtime.calls, 0);
    expect(chat.errorMessage, contains('descarga'));
    chat.dispose();
    api.dispose();
    connection.dispose();
  });
  for (final code in [401, 403, 500]) {
    test(
      'HTTP $code remains an error and never bypasses access through local inference',
      () async {
        final runtime = LocalRuntime();
        final offline = local(runtime);
        await offline.download();
        final api = ApiService(
          StorageService(),
          client: MockClient(
            (_) async =>
                http.Response(jsonEncode({'detail': 'No disponible'}), code),
          ),
        )..currentUserId = 'owner';
        final chat = CarlitosChatService(
          api,
          offline: offline,
          canUseOffline: () => true,
        );
        expect(await chat.sendMessage('Hola'), isFalse);
        expect(runtime.calls, 0);
        expect(chat.messages, isEmpty);
        chat.dispose();
        api.dispose();
      },
    );
  }
  test(
    'Connection loss while sending switches to the downloaded model',
    () async {
      final runtime = LocalRuntime();
      final offline = local(runtime);
      await offline.download();
      final api = ApiService(
        StorageService(),
        client: MockClient((_) async => throw http.ClientException('offline')),
      )..currentUserId = 'owner';
      final chat = CarlitosChatService(
        api,
        offline: offline,
        canUseOffline: () => true,
      );
      expect(await chat.sendMessage('Hola'), isTrue);
      expect(runtime.calls, 1);
      chat.dispose();
      api.dispose();
    },
  );
  test('Late local generation cannot leak into the next account', () async {
    final runtime = LocalRuntime()..pending = Completer<String>();
    final offline = local(runtime);
    await offline.download();
    final connection = Connection(false);
    final api = ApiService(StorageService(), conectividadService: connection)
      ..currentUserId = 'owner';
    final chat = CarlitosChatService(
      api,
      offline: offline,
      canUseOffline: () => true,
    );
    final reply = chat.sendMessage('Mensaje privado');
    await runtime.started.future.timeout(const Duration(seconds: 10));
    api.currentUserId = 'other';
    chat.reset();
    await chat.fetchHistory();
    runtime.pending!.complete('Respuesta privada');
    expect(await reply, isFalse);
    expect(chat.messages, isEmpty);
    chat.dispose();
    api.dispose();
    connection.dispose();
  });
  test('Expired offline entitlement is respected even when the model is downloaded', () async {
    final runtime = LocalRuntime();
    final offline = local(runtime);
    await offline.download();
    final connection = Connection(false);
    final api = ApiService(StorageService(), conectividadService: connection)
      ..currentUserId = 'owner';
    final chat = CarlitosChatService(
      api,
      offline: offline,
      canUseOffline: () => false,
    );
    expect(await chat.sendMessage('Hola'), isFalse);
    expect(runtime.calls, 0);
    chat.dispose();
    api.dispose();
    connection.dispose();
  });
  testWidgets(
    'Downloaded Carlitos responds from the offline chat UI on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = LocalRuntime();
      final offline = local(runtime);
      await tester.runAsync(offline.download);
      final connection = Connection(false);
      final storage = StorageService();
      var requests = 0;
      final api = ApiService(
        storage,
        conectividadService: connection,
        client: MockClient((_) async {
          requests++;
          throw http.ClientException('offline');
        }),
      )..currentUserId = 'owner';
      final chat = CarlitosChatService(
        api,
        offline: offline,
        canUseOffline: () => true,
      );
      final premium = PremiumAccess(api, storage);
      final theme = ThemeService();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CarlitosChatService>.value(value: chat),
            ChangeNotifierProvider<SubscriptionService>.value(value: premium),
            ChangeNotifierProvider<ThemeService>.value(value: theme),
            ChangeNotifierProvider<ConectividadService>.value(
              value: connection,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const CarlitosChatScreen(),
          ),
        ),
      );
      await tester.runAsync(chat.fetchHistory);
      await tester.pumpAndSettle();
      expect(
        find.text('Modo sin internet preparado en este teléfono.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Hola');
      await tester.tap(find.byTooltip('Enviar mensaje'));
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
        for (var i = 0; i < 100 && chat.isLoading; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('Respuesta generada en el teléfono.'), findsOneWidget);
      expect(find.text('Carlitos · En tu teléfono'), findsOneWidget);
      expect(requests, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      chat.dispose();
      premium.dispose();
      theme.dispose();
      api.dispose();
      connection.dispose();
    },
  );
}
