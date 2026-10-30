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
import 'package:mobile/screens/food/nutrition_diary_screen.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:mobile/modo_offline/cola_sincronizacion_service.dart';
import 'package:mobile/modo_offline/conectividad_service.dart';
import 'package:mobile/modo_offline/sincronizador_service.dart';

class OfflineConnectivity extends ChangeNotifier
    implements ConectividadService {
  @override
  bool get estaConectado => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
  for (final dark in [false, true]) {
    testWidgets(
      'Patient can save an offline meal on a narrow phone, dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final directory = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('nutrition-screen-'),
        ))!;
        addTearDown(() => directory.delete(recursive: true));
        final api = ApiService(
          StorageService(),
          client: MockClient(
            (r) async => http.Response(
              r.url.path.endsWith('/my-plan')
                  ? jsonEncode({
                      'id': 'plan',
                      'title': 'Plan de demostración',
                      'daily_calories': 2000,
                      'protein_g': 100,
                      'carbs_g': 250,
                      'fats_g': 65,
                      'meals': [],
                    })
                  : '[]',
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        )..currentUserId = 'patient';
        final queue = ColaSincronizacionService(documentsDirectory: directory);
        await tester.runAsync(() => queue.cargarCola(userId: 'patient'));
        final connectivity = OfflineConnectivity();
        final sync = SincronizadorService(
          conectividadService: connectivity,
          colaService: queue,
          apiService: api,
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<ApiService>.value(value: api),
              ChangeNotifierProvider<ColaSincronizacionService>.value(
                value: queue,
              ),
              ChangeNotifierProvider<ConectividadService>.value(
                value: connectivity,
              ),
              ChangeNotifierProvider<SincronizadorService>.value(value: sync),
            ],
            child: MaterialApp(
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: RepaintBoundary(
                key: key,
                child: const NutritionDiaryScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Estás sin conexión'), findsOneWidget);
        expect(find.text('Plan de demostración'), findsOneWidget);
        expect(tester.takeException(), isNull);
        const captureDirectory = String.fromEnvironment('UI_CAPTURE_DIR');
        if (captureDirectory.isNotEmpty) {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              '$captureDirectory/mobile-nutricion-${dark ? "oscuro" : "claro"}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.enterText(
          find.byType(TextFormField).first,
          'Manzana y yogur',
        );
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        final save = find.widgetWithText(FilledButton, 'Guardar comida');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(queue.elementos, hasLength(1));
        expect(
          queue.elementos.single.cuerpo!['description'],
          'Manzana y yogur',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        sync.dispose();
        queue.dispose();
        connectivity.dispose();
        api.dispose();
      },
    );
  }
}
