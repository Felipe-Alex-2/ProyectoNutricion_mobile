import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/config/theme.dart';
import 'package:mobile/screens/auth/login_screen.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:mobile/services/theme_service.dart';

void main() {
  testWidgets('LoginScreen renders email, password, and login button', (WidgetTester tester) async {
    final storageService = StorageService();
    final apiService = ApiService(storageService);
    final authService = AuthService(apiService, storageService);
    final themeService = ThemeService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storageService),
          Provider<ApiService>.value(value: apiService),
          ChangeNotifierProvider<AuthService>.value(value: authService),
          ChangeNotifierProvider<ThemeService>.value(value: themeService),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const LoginScreen(),
        ),
      ),
    );

    // Verify brand, input fields and login button
    expect(find.text('NutriSalud'), findsOneWidget);
    expect(find.text('Correo Electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('LoginScreen shows validation errors when fields are empty on submit', (WidgetTester tester) async {
    final storageService = StorageService();
    final apiService = ApiService(storageService);
    final authService = AuthService(apiService, storageService);
    final themeService = ThemeService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storageService),
          Provider<ApiService>.value(value: apiService),
          ChangeNotifierProvider<AuthService>.value(value: authService),
          ChangeNotifierProvider<ThemeService>.value(value: themeService),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const LoginScreen(),
        ),
      ),
    );

    // Tap submit without entering data
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    // Verify empty field validation indicators
    expect(find.text('Por favor, rellene este campo'), findsNWidgets(2));
    expect(find.text('Por favor, rellene todos los campos para iniciar sesión'), findsOneWidget);
  });

  testWidgets('LoginScreen validates password complexity rules', (WidgetTester tester) async {
    final storageService = StorageService();
    final apiService = ApiService(storageService);
    final authService = AuthService(apiService, storageService);
    final themeService = ThemeService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storageService),
          Provider<ApiService>.value(value: apiService),
          ChangeNotifierProvider<AuthService>.value(value: authService),
          ChangeNotifierProvider<ThemeService>.value(value: themeService),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const LoginScreen(),
        ),
      ),
    );

    // Enter valid email and short/weak password
    await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'pass');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.text('Mínimo 8 caracteres'), findsOneWidget);

    // Enter 8 characters without uppercase
    await tester.enterText(find.byType(TextFormField).last, 'password123!');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
    expect(find.text('Debe incluir al menos una letra mayúscula'), findsOneWidget);

    // Enter without number
    await tester.enterText(find.byType(TextFormField).last, 'Password!@#');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
    expect(find.text('Debe incluir al menos un número'), findsOneWidget);

    // Enter without special character
    await tester.enterText(find.byType(TextFormField).last, 'Password123');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
    expect(find.text('Debe incluir al menos un carácter especial'), findsOneWidget);
  });
}
