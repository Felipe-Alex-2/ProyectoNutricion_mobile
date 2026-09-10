import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _formKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor, rellene todos los campos para iniciar sesión'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final authService = context.read<AuthService>();
    final success = await authService.login(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    if (!success && authService.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authService.errorMessage!),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final themeService = context.watch<ThemeService>();
    final isDark = themeService.isDarkMode;
    final isAuthenticating = authService.status == AuthStatus.authenticating;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Theme Mode Toggle in Top Right Corner
            Positioned(
              top: 8,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0x0F000000),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    color: isDark ? const Color(0xFFFBBF24) : AppTheme.primaryGreen,
                    size: 20,
                  ),
                  tooltip: isDark ? 'Modo Claro' : 'Modo Oscuro',
                  onPressed: () => themeService.toggleTheme(),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Icon
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      'NutriSalud',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Accede a tu plan de nutrición y bienestar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF687B70),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico',
                        hintText: 'ejemplo@correo.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, rellene este campo';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Correo inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, rellene este campo';
                        }
                        if (value.length < 8) {
                          return 'Mínimo 8 caracteres';
                        }
                        if (!RegExp(r'[A-Z]').hasMatch(value)) {
                          return 'Debe incluir al menos una letra mayúscula';
                        }
                        if (!RegExp(r'[a-z]').hasMatch(value)) {
                          return 'Debe incluir al menos una letra minúscula';
                        }
                        if (!RegExp(r'[0-9]').hasMatch(value)) {
                          return 'Debe incluir al menos un número';
                        }
                        if (!RegExp(r'[^a-zA-Z0-9]').hasMatch(value)) {
                          return 'Debe incluir al menos un carácter especial';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Forgot Password Link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ForgotPasswordScreen(
                                initialEmail: _emailController.text.trim().isNotEmpty
                                    ? _emailController.text.trim()
                                    : null,
                              ),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    ElevatedButton(
                      onPressed: isAuthenticating ? null : _submit,
                      child: isAuthenticating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Ingresar'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                    ),
                    const SizedBox(height: 24),

                    // Register Link
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          '¿No tienes cuenta? ',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Regístrate gratis',
                            style: TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  ),
);
  }
}
