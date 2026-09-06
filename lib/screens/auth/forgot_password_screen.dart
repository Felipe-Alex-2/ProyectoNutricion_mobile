import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Step 0: request token, Step 1: enter token & new password
  int _currentStep = 0;

  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  late final TextEditingController _emailController;
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestToken() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _successMessage = null;
    });

    final authService = context.read<AuthService>();
    final success = await authService.forgotPassword(_emailController.text);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      setState(() {
        _currentStep = 1;
        _successMessage =
            'Enviamos un token a ${_emailController.text}. Es válido por 10 minutos.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_successMessage!),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authService.errorMessage ?? 'Error al solicitar el token'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleResetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final authService = context.read<AuthService>();
    final success = await authService.resetPassword(
      _tokenController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 28),
              SizedBox(width: 8),
              Text('Contraseña Restablecida'),
            ],
          ),
          content: const Text(
            'Tu contraseña ha sido actualizada con éxito. Ya puedes iniciar sesión con tu nueva credencial.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // Close dialog
                Navigator.of(context).pop(); // Back to login
              },
              child: const Text('Ir al Inicio de Sesión'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authService.errorMessage ?? 'El token no es válido o ha expirado (10 min).'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar Contraseña'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header icon
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: AppTheme.primaryGreen,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    _currentStep == 0
                        ? '¿Olvidaste tu contraseña?'
                        : 'Ingresa tu Token de 10 min',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    _currentStep == 0
                        ? 'Ingresa tu correo electrónico registrado. Te enviaremos un token temporal con 10 minutos de validez.'
                        : 'Copia el token que enviamos a tu correo e ingresa tu nueva contraseña antes de que expire el tiempo.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF687B70),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 10 Min Alert Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7).withValues(alpha: 0.6),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.timer_outlined, color: Color(0xFFB45309), size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Por seguridad, cada token tiene una validez estricta de 10 minutos.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_currentStep == 0) _buildRequestTokenForm() else _buildResetPasswordForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestTokenForm() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                return 'Ingresa tu correo';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Correo inválido';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading ? null : _handleRequestToken,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Enviar Token (10 min)'),
                      SizedBox(width: 8),
                      Icon(Icons.send_rounded, size: 18),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: () {
              setState(() {
                _currentStep = 1;
              });
            },
            child: const Text('¿Ya tienes un token? Ingrésalo aquí'),
          ),
        ],
      ),
    );
  }

  Widget _buildResetPasswordForm() {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _tokenController,
            decoration: const InputDecoration(
              labelText: 'Token de Restablecimiento',
              hintText: 'Pega aquí el token recibido',
              prefixIcon: Icon(Icons.vpn_key_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa el token';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Nueva Contraseña',
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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
                return 'Ingresa la nueva contraseña';
              }
              if (value.length < 8) {
                return 'Mínimo 8 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirmar Contraseña',
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_clock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirma tu contraseña';
              }
              if (value != _passwordController.text) {
                return 'Las contraseñas no coinciden';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading ? null : _handleResetPassword,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Actualizar Contraseña'),
                      SizedBox(width: 8),
                      Icon(Icons.check_rounded, size: 18),
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          TextButton(
            onPressed: () {
              setState(() {
                _currentStep = 0;
              });
            },
            child: const Text('Volver a solicitar token'),
          ),
        ],
      ),
    );
  }
}
