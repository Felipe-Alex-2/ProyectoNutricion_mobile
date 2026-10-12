import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:mobile/config/theme.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/modo_offline/cola_sincronizacion_service.dart';
import 'package:mobile/modo_offline/conectividad_service.dart';
import 'package:mobile/modo_offline/sincronizador_service.dart';
import 'package:mobile/screens/auth/login_screen.dart';
import 'package:mobile/screens/auth/register_screen.dart';
import 'package:mobile/screens/auth/forgot_password_screen.dart';
import 'package:mobile/screens/chat/carlitos_chat_screen.dart';
import 'package:mobile/screens/food/food_vision_screen.dart';
import 'package:mobile/screens/home/home_screen.dart';
import 'package:mobile/screens/subscriptions/ai_module_screen.dart';
import 'package:mobile/services/activity_log_service.dart';
import 'package:mobile/services/anamnesis_service.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/appointment_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/carlitos_chat_service.dart';
import 'package:mobile/services/food_vision_service.dart';
import 'package:mobile/services/notification_service.dart';
import 'package:mobile/services/patient_service.dart';
import 'package:mobile/services/recipe_service.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:mobile/services/subscription_service.dart';
import 'package:mobile/services/theme_service.dart';

// Local fixtures only: no calls to Railway, PayPal, or real patient data.
class _PreviewAuth extends AuthService {
  _PreviewAuth(super.apiService, super.storageService);
  @override
  User get currentUser => User(
    id: 'preview-patient',
    email: 'felipe@ejemplo.com',
    fullName: 'Felipe',
    roleId: 'CLIENTE',
    isActive: true,
    isVerified: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _Connectivity extends ChangeNotifier implements ConectividadService {
  @override
  bool get estaConectado => true;
  @override
  bool get estaVerificando => false;
  @override
  bool get estaEnPrimerPlano => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sync extends ChangeNotifier implements SincronizadorService {
  @override
  String? get ultimoErrorConflicto => null;
  @override
  String? get ultimoMensajeExito => null;
  @override
  bool get estaSincronizando => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session {
  final storage = StorageService();
  final theme = ThemeService();
  final connectivity = _Connectivity();
  final sync = _Sync();
  final queue = ColaSincronizacionService();
  late final ApiService api;
  late final _PreviewAuth auth;
  late final PatientService patients;
  late final RecipeService recipes;
  late final AppointmentService appointments;
  late final NotificationService notifications;
  late final SubscriptionService subscriptions;
  late final AnamnesisService health;
  late final CarlitosChatService chat;
  late final FoodVisionService food;
  late final ActivityLogService activity;
  final List<String> requests = [];
  final bool linked;
  final bool premium;
  _Session({this.linked = true, this.premium = true}) {
    api = ApiService(
      storage,
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        final now = DateTime.now();
        final path = request.url.path;
        Object? data = <Object>[];
        if (path.endsWith('/current') && path.contains('subscriptions')) {
          data = premium
              ? {
                  'id': 'subscription-demo',
                  'user_id': 'preview-patient',
                  'plan_name': 'CLIENTE_PREMIUM',
                  'status': 'ACTIVE',
                  'amount': 5,
                  'currency': 'USD',
                  'expires_at': now
                      .add(const Duration(days: 30))
                      .toUtc()
                      .toIso8601String(),
                }
              : null;
        } else if (path.endsWith('/my-nutritionist')) {
          data = linked
              ? {
                  'id': 'link-demo',
                  'nutritionist_id': 'nutri-demo',
                  'nutritionist_name': 'Lic. Ana López',
                  'nutritionist_email': 'ana@ejemplo.com',
                  'tenant_name': 'Nutrición y bienestar',
                  'pairing_code': 'DEMO123',
                  'whatsapp_number': '+59170000000',
                  'created_at': now.toIso8601String(),
                }
              : null;
        } else if (path.endsWith('/appointments')) {
          data = [
            {
              'id': 'appointment-demo',
              'patient_id': 'preview-patient',
              'nutritionist_id': 'nutri-demo',
              'nutritionist_name': 'Lic. Ana López',
              'scheduled_at': now
                  .add(const Duration(days: 2))
                  .toIso8601String(),
              'reason': 'Consulta de seguimiento',
              'status': 'CONFIRMED',
              'created_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
            },
          ];
        } else if (path.endsWith('/nutritionists')) {
          data = [
            {
              'id': 'nutri-demo',
              'full_name': 'Lic. Ana López',
              'email': 'ana@ejemplo.com',
            },
          ];
        } else if (path.endsWith('/my-plan') && path.contains('recipes')) {
          data = [
            {
              'id': 'recipe-demo',
              'title': 'Ensalada de quinoa',
              'description': 'Una opción balanceada para tu día.',
              'category': 'Almuerzo',
              'calories': 420,
              'protein': 18,
              'carbohydrates': 45,
              'fats': 14,
              'prep_time_minutes': 15,
              'cook_time_minutes': 5,
              'servings': 1,
              'ingredients': 'Quinoa, tomate, aguacate',
              'instructions': 'Cocina la quinoa y mezcla con las verduras.',
            },
          ];
        } else if (path.endsWith('/unread-count')) {
          data = {'unread_count': 2};
        } else if (path.endsWith('/notifications')) {
          data = [
            {
              'id': 'notification-cita',
              'user_id': 'preview-patient',
              'title': 'Tu cita está confirmada',
              'message': 'Revisa los detalles con tu nutricionista.',
              'type': 'CITA_CONFIRMADA',
              'is_read': false,
              'created_at': now.toIso8601String(),
            },
            {
              'id': 'notification-plan',
              'user_id': 'preview-patient',
              'title': 'Tu plan está listo',
              'message': 'Tu nutricionista actualizó tus recetas.',
              'type': 'PLAN',
              'is_read': false,
              'created_at': now
                  .subtract(const Duration(days: 1))
                  .toIso8601String(),
            },
          ];
        } else if (path.endsWith('/receipts')) {
          data = [
            {
              'id': 'receipt-demo',
              'buyer_name': 'Felipe',
              'buyer_email': 'felipe@ejemplo.com',
              'plan_name': 'CLIENTE_PREMIUM',
              'currency': 'USD',
              'paypal_order_id': 'demo-order',
              'paypal_capture_id': 'demo-capture',
              'amount': 5,
              'paid_at': now.toUtc().toIso8601String(),
              'is_sandbox': true,
            },
          ];
        } else if (path.endsWith('/history')) {
          data = {
            'messages': [
              {
                'id': 'chat-demo',
                'role': 'assistant',
                'content': '¡Hola, Felipe! ¿Qué te gustaría consultar sobre tu alimentación?',
                'created_at': now.toIso8601String(),
              },
            ],
          };
        } else if (path.endsWith('/me') && path.contains('anamnesis')) {
          data = null;
        }
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    )..currentUserId = 'preview-patient';
    auth = _PreviewAuth(api, storage);
    patients = PatientService(api);
    recipes = RecipeService(api);
    appointments = AppointmentService(api);
    notifications = NotificationService(api);
    subscriptions = SubscriptionService(api, storage);
    health = AnamnesisService(api);
    chat = CarlitosChatService(api);
    food = FoodVisionService(api);
    activity = ActivityLogService(api);
  }

  Widget app(
    Widget screen,
    GlobalKey capture, {
    double scale = 1,
  }) => MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>.value(value: auth),
      ChangeNotifierProvider<ThemeService>.value(value: theme),
      ChangeNotifierProvider<PatientService>.value(value: patients),
      ChangeNotifierProvider<RecipeService>.value(value: recipes),
      ChangeNotifierProvider<AppointmentService>.value(value: appointments),
      ChangeNotifierProvider<NotificationService>.value(value: notifications),
      ChangeNotifierProvider<SubscriptionService>.value(value: subscriptions),
      ChangeNotifierProvider<AnamnesisService>.value(value: health),
      ChangeNotifierProvider<CarlitosChatService>.value(value: chat),
      ChangeNotifierProvider<FoodVisionService>.value(value: food),
      ChangeNotifierProvider<ActivityLogService>.value(value: activity),
      ChangeNotifierProvider<ConectividadService>.value(value: connectivity),
      ChangeNotifierProvider<ColaSincronizacionService>.value(value: queue),
      ChangeNotifierProvider<SincronizadorService>.value(value: sync),
    ],
    child: Builder(
      builder: (context) => RepaintBoundary(
        key: capture,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: context.watch<ThemeService>().themeMode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    ),
  );

  void dispose() {
    for (final service in [
      auth,
      theme,
      patients,
      recipes,
      appointments,
      notifications,
      subscriptions,
      health,
      chat,
      food,
      activity,
      connectivity,
      sync,
      queue,
    ]) {
      service.dispose();
    }
    api.dispose();
  }
}

const captureDirectory = String.fromEnvironment('UI_CAPTURE_DIR');

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (captureDirectory.isEmpty) return;
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => precacheImage(
      const ResizeImage(
        AssetImage('assets/images/welcome_nutrition.png'),
        width: 1000,
      ),
      key.currentContext!,
    ),
  );
  await tester.pumpAndSettle();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$captureDirectory/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  setUpAll(() async {
    // Use the font shipped with Flutter; no font download or new dependency.
    final loader = FontLoader('NutriSans');
    for (final weight in ['regular', 'medium', 'bold']) {
      loader.addFont(rootBundle.load('assets/fonts/nutri-sans-$weight.ttf'));
    }
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final config in [
    (390.0, false, 1.0),
    (320.0, false, 1.3),
    (390.0, true, 1.0),
  ]) {
    testWidgets(
      'Navigation, notification links and health fields at width ${config.$1}, dark ${config.$2}, scale ${config.$3}',
      (tester) async {
        tester.view.physicalSize = Size(config.$1, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = _Session();
        final capture = GlobalKey();
        session.theme.setThemeMode(
          config.$2 ? ThemeMode.dark : ThemeMode.light,
        );
        await tester.pumpWidget(
          session.app(const HomeScreen(), capture, scale: config.$3),
        );
        await tester.pumpAndSettle();
        expect(find.text('Hola, Felipe'), findsOneWidget);
        final prefix = config.$2 ? 'oscuro' : 'claro';
        if (config.$1 == 390) {
          await _capture(tester, capture, '$prefix-04-inicio');
        }
        await tester.tap(find.byTooltip('Notificaciones'));
        await tester.pumpAndSettle();
        expect(find.text('Hoy'), findsOneWidget);
        expect(find.text('Ayer'), findsOneWidget);
        if (config.$1 == 390) {
          await _capture(tester, capture, '$prefix-09-notificaciones');
        }
        await tester.tap(find.text('Sin leer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Marcar leídas'));
        await tester.pumpAndSettle();
        expect(find.text('Todo al día'), findsOneWidget);
        await tester.tap(find.text('Todas'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Ver plan'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ver plan'));
        await tester.pumpAndSettle();
        expect(find.text('Mi plan nutricional'), findsOneWidget);
        if (config.$1 == 390) {
          await _capture(tester, capture, '$prefix-06-plan');
        }
        await tester.tap(find.text('Ensalada de quinoa'));
        await tester.pumpAndSettle();
        expect(find.text('Quinoa, tomate, aguacate'), findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(NavigationDestination).at(1));
        await tester.pumpAndSettle();
        expect(find.text('Solicitar cita'), findsOneWidget);
        if (config.$1 == 390) {
          await _capture(tester, capture, '$prefix-05-nutricionista');
        }
        await tester.tap(find.byType(NavigationDestination).at(2));
        await tester.pumpAndSettle();
        expect(find.text('Suscripción Premium Activa'), findsOneWidget);
        if (config.$1 == 390) {
          await _capture(tester, capture, '$prefix-10-suscripciones');
        }
        await tester.tap(find.byType(NavigationDestination).at(4));
        await tester.pumpAndSettle();
        if (config.$1 == 390) {
          await _capture(tester, capture, '$prefix-08-perfil');
        }
        await tester.tap(find.text('Mis comprobantes'));
        await tester.pumpAndSettle();
        expect(find.text('Ver recibo'), findsOneWidget);
        expect(find.text('Descargar PDF'), findsOneWidget);
        if (config.$1 == 390) {
          await _capture(tester, capture, '$prefix-11-comprobantes');
        }
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mi ficha de salud'));
        await tester.pumpAndSettle();
        expect(find.text('Datos personales'), findsOneWidget);
        if (config.$1 == 390) {
          await _capture(tester, capture, '$prefix-07-ficha');
        }
        final weight = find.widgetWithText(TextField, 'Peso actual (kg)');
        await tester.ensureVisible(weight);
        await tester.pumpAndSettle();
        await tester.enterText(weight, '72.5');
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        final section = find.text('Datos personales');
        await tester.ensureVisible(section);
        await tester.pumpAndSettle();
        await tester.tap(section);
        await tester.pumpAndSettle();
        await tester.tap(section);
        await tester.pumpAndSettle();
        expect((tester.widget<TextField>(weight)).controller!.text, '72.5');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        session.dispose();
      },
    );
  }

  testWidgets(
    'Unlinked free patient can request appointments and inspect Premium without activating payments',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = _Session(linked: false, premium: false);
      final capture = GlobalKey();
      await tester.pumpWidget(session.app(const HomeScreen(), capture));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Solicitar cita'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solicitar cita'));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      await _capture(tester, capture, 'claro-solicitar-cita');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(2));
      await tester.pumpAndSettle();
      expect(find.text('Tu plan gratuito'), findsOneWidget);
      await _capture(tester, capture, 'claro-premium-gratuito');
      expect(
        session.requests.where(
          (r) => r.contains('create-order') || r.contains('capture'),
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );

  for (final screen in <(String, Widget)>[
    ('01-acceso', const LoginScreen()),
    ('02-registro', const RegisterScreen()),
    ('03-recuperar', const ForgotPasswordScreen()),
    ('13-carlitos', const CarlitosChatScreen()),
    (
      '14-recomendaciones',
      const AiModuleScreen(
        title: 'Recomendaciones IA',
        subtitle: 'Ideas para tu alimentación.',
        icon: Icons.restaurant_menu_outlined,
        accentColor: AppTheme.primaryGreen,
        upcomingFeatures: [
          'Ideas para tus comidas',
          'Alternativas según tus preferencias',
        ],
      ),
    ),
    ('15-alimentos', const FoodVisionScreen()),
  ]) {
    testWidgets('${screen.$1} renders on a phone in both themes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = _Session();
      final capture = GlobalKey();
      await session.subscriptions.fetchCurrentSubscription(
        userId: 'preview-patient',
      );
      await tester.pumpWidget(session.app(screen.$2, capture));
      await tester.pumpAndSettle();
      await _capture(tester, capture, 'claro-${screen.$1}');
      session.theme.toggleTheme();
      await tester.pumpAndSettle();
      await _capture(tester, capture, 'oscuro-${screen.$1}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    });
  }
}
