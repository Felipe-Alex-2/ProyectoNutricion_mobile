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
import 'services/subscription_service.dart';
import 'services/carlitos_chat_service.dart';
import 'services/food_vision_service.dart';
import 'services/ai_plan_mobile_service.dart';

import 'modo_offline/conectividad_service.dart';
import 'modo_offline/cache_local_service.dart';
import 'modo_offline/cola_sincronizacion_service.dart';
import 'modo_offline/sincronizador_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  final conectividadService = ConectividadService();
  final cacheLocalService = CacheLocalService();
  final colaService = ColaSincronizacionService();

  final apiService = ApiService(
    storageService,
    cacheService: cacheLocalService,
    conectividadService: conectividadService,
  );

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

  final sincronizadorService = SincronizadorService(
    conectividadService: conectividadService,
    colaService: colaService,
    apiService: apiService,
  );

  // Auto-actualizar citas si el sincronizador termina de enviar citas encoladas
  sincronizadorService.onCitasActualizadas = () {
    appointmentService.fetchAppointments();
  };

  // Sincronizar identificador de usuario con almacenamiento local
  authService.addListener(() {
    final userId = authService.currentUser?.id.toString();
    apiService.currentUserId = userId;
    appointmentService.currentUserId = userId;
    if (userId != null) {
      colaService.cargarCola(userId: userId).then((_) {
        appointmentService.fetchAppointments();
      });
    }
  });

  final themeService = ThemeService();
  final patientService = PatientService(apiService);
  final activityLogService = ActivityLogService(apiService);
  final anamnesisService = AnamnesisService(apiService);
  final recipeService = RecipeService(apiService);
  final notificationService = NotificationService(apiService);
  final subscriptionService = SubscriptionService(apiService, storageService);
  final carlitosChatService = CarlitosChatService(apiService);
  final foodVisionService = FoodVisionService(apiService);
  final aiPlanMobileService = AIPlanMobileService(apiService);

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        ChangeNotifierProvider<ConectividadService>.value(value: conectividadService),
        Provider<CacheLocalService>.value(value: cacheLocalService),
        ChangeNotifierProvider<ColaSincronizacionService>.value(value: colaService),
        ChangeNotifierProvider<SincronizadorService>.value(value: sincronizadorService),
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<ThemeService>.value(value: themeService),
        ChangeNotifierProvider<PatientService>.value(value: patientService),
        ChangeNotifierProvider<ActivityLogService>.value(value: activityLogService),
        ChangeNotifierProvider<AnamnesisService>.value(value: anamnesisService),
        ChangeNotifierProvider<RecipeService>.value(value: recipeService),
        ChangeNotifierProvider<AppointmentService>.value(value: appointmentService),
        ChangeNotifierProvider<NotificationService>.value(value: notificationService),
        ChangeNotifierProvider<SubscriptionService>.value(value: subscriptionService),
        ChangeNotifierProvider<CarlitosChatService>.value(value: carlitosChatService),
        ChangeNotifierProvider<FoodVisionService>.value(value: foodVisionService),
        ChangeNotifierProvider<AIPlanMobileService>.value(value: aiPlanMobileService),
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
      title: 'NutriSalud',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeService.themeMode,
      debugShowCheckedModeBanner: false,
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
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      case AuthStatus.authenticated:
        return const HomeScreen();
      case AuthStatus.unauthenticated:
      case AuthStatus.authenticating:
        return const LoginScreen();
    }
  }
}
