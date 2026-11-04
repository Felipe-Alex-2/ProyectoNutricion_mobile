import 'services/offline_wallet_service.dart';
import 'modo_offline/copia_offline_service.dart';
import 'modo_offline/widgets/banner_sin_conexion.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/theme_service.dart';

import 'services/activity_log_service.dart';
import 'services/patient_service.dart';
import 'services/anamnesis_service.dart';
import 'services/recipe_service.dart';
import 'services/appointment_service.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';
import 'services/subscription_service.dart';
import 'services/carlitos_chat_service.dart';
import 'services/food_vision_service.dart';
import 'services/ai_plan_mobile_service.dart';

import 'modo_offline/conectividad_service.dart';
import 'modo_offline/cache_local_service.dart';
import 'modo_offline/cola_sincronizacion_service.dart';
import 'modo_offline/sincronizador_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  final conectividadService = ConectividadService();
  final cacheLocalService = CacheLocalService();
  final colaService = ColaSincronizacionService();
  await cacheLocalService.eliminarCacheLegacy();

  final apiService = ApiService(
    storageService,
    cacheService: cacheLocalService,
    conectividadService: conectividadService,
  );

  final copiaOffline = CopiaOfflineService(apiService);

  final authService = AuthService(
    apiService,
    storageService,
    cacheService: cacheLocalService,
    colaService: colaService,
  );

  final appointmentService = AppointmentService(
    apiService,
    colaService: colaService,
    conectividadService: conectividadService,
  );

  final anamnesisService = AnamnesisService(
    apiService,
    colaService: colaService,
    conectividadService: conectividadService,
    cacheService: cacheLocalService,
  );

  final sincronizadorService = SincronizadorService(
    conectividadService: conectividadService,
    colaService: colaService,
    apiService: apiService,
  );

  // Auto-actualizar citas si el sincronizador termina de enviar citas encoladas
  sincronizadorService.onCitasActualizadas = () {
    appointmentService.fetchAppointments();
  };

  // Auto-actualizar ficha medica si el sincronizador termina de enviar la ficha encolada
  sincronizadorService.onFichaActualizada = () {
    anamnesisService.fetchMyAnamnesis();
  };

  final themeService = ThemeService();
  final patientService = PatientService(apiService);
  final activityLogService = ActivityLogService(apiService);
  final recipeService = RecipeService(apiService);
  final notificationService = NotificationService(apiService);
  final pushService = PushNotificationService(apiService, notificationService);
  await pushService.initialize();
  authService.beforeLogout = pushService.unlink;
  final subscriptionService = SubscriptionService(apiService, storageService);
  final carlitosChatService = CarlitosChatService(
    apiService,
    storage: storageService,
    canUseOffline: () => subscriptionService.isPremium,
  );
  final foodVisionService = FoodVisionService(
    apiService,
    colaService: colaService,
  );
  final aiPlanMobileService = AIPlanMobileService(apiService);

  // Sincronizar identificador de usuario con almacenamiento local
  String? loadedUserId;
  authService.addListener(() {
    final userId = authService.currentUser?.id.toString();
    apiService.currentUserId = userId;
    appointmentService.currentUserId = userId;
    anamnesisService.currentUserId = userId;
    if (loadedUserId == userId) return;
    loadedUserId = userId;
    copiaOffline.bindUser(userId);
    pushService.bindUser(userId);
    patientService.reset();
    recipeService.reset();
    appointmentService.reset();
    anamnesisService.reset();
    notificationService.reset();
    carlitosChatService.reset();
    subscriptionService.reset();
    aiPlanMobileService.reset();
    foodVisionService.clearLastAnalysis();
    if (userId != null) {
      colaService.cargarCola(userId: userId).then((_) {
        if (apiService.currentUserId != userId) return;
        appointmentService.fetchAppointments();
        anamnesisService.fetchMyAnamnesis();
        appointmentService.fetchNutritionists();
      });
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CopiaOfflineService>.value(value: copiaOffline),
        Provider<StorageService>.value(value: storageService),
        ChangeNotifierProvider<ConectividadService>.value(
          value: conectividadService,
        ),
        Provider<CacheLocalService>.value(value: cacheLocalService),
        ChangeNotifierProvider<ColaSincronizacionService>.value(
          value: colaService,
        ),
        ChangeNotifierProvider<SincronizadorService>.value(
          value: sincronizadorService,
        ),
        Provider<ApiService>.value(value: apiService),
        Provider<OfflineWalletService>(
          create: (_) => OfflineWalletService(apiService, colaService),
        ),
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<ThemeService>.value(value: themeService),
        ChangeNotifierProvider<PatientService>.value(value: patientService),
        ChangeNotifierProvider<ActivityLogService>.value(
          value: activityLogService,
        ),
        ChangeNotifierProvider<AnamnesisService>.value(value: anamnesisService),
        ChangeNotifierProvider<RecipeService>.value(value: recipeService),
        ChangeNotifierProvider<AppointmentService>.value(
          value: appointmentService,
        ),
        ChangeNotifierProvider<NotificationService>.value(
          value: notificationService,
        ),
        ChangeNotifierProvider<SubscriptionService>.value(
          value: subscriptionService,
        ),
        ChangeNotifierProvider<CarlitosChatService>.value(
          value: carlitosChatService,
        ),
        ChangeNotifierProvider<FoodVisionService>.value(
          value: foodVisionService,
        ),
        ChangeNotifierProvider<AIPlanMobileService>.value(
          value: aiPlanMobileService,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();

    return MaterialApp(
      navigatorKey: PushNotificationService.navigatorKey,
      title: 'NutriSalud',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeService.themeMode,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final showBanner =
            context.watch<AuthService>().status == AuthStatus.authenticated &&
            (!context.watch<ConectividadService>().estaConectado ||
                context
                    .watch<ColaSincronizacionService>()
                    .elementos
                    .isNotEmpty ||
                context.watch<SincronizadorService>().estaSincronizando);
        return Column(
          children: [
            if (showBanner)
              const SafeArea(
                bottom: false,
                child: Material(child: BannerSinConexion()),
              ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: showBanner,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    switch (authService.status) {
      case AuthStatus.uninitialized:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.authenticated:
        return const HomeScreen();
      case AuthStatus.unauthenticated:
      case AuthStatus.authenticating:
        return const LoginScreen();
    }
  }
}
