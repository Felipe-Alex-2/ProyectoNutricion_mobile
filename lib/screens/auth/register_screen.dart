import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/branch_model.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  List<Branch> _branches = [];
  Branch? _selectedBranch;
  bool _isLoadingBranches = true;
  bool _isBranchAccordionOpen = false;
  String? _branchError;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final branches = await context.read<AuthService>().fetchPublicBranches();
    if (mounted) {
      setState(() {
        _branches = branches;
        _isLoadingBranches = false;
        if (branches.length == 1) {
          _selectedBranch = branches.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBranch == null && _branches.isNotEmpty) {
      setState(() {
        _branchError = 'Por favor selecciona la sucursal de tu atención';
        _isBranchAccordionOpen = true;
      });
      return;
    }

    setState(() {
      _branchError = null;
    });

    final authService = context.read<AuthService>();
    final success = await authService.register(
      _emailController.text,
      _passwordController.text,
      _nameController.text,
      tenantId: _selectedBranch?.id,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(); // Go back or auth status will navigate
    } else if (authService.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authService.errorMessage!),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildBranchAccordion(bool isDark) {
    final primaryColor = AppTheme.primaryGreen;
    final borderColor = _branchError != null
        ? Colors.redAccent
        : (_isBranchAccordionOpen ? primaryColor : Colors.grey.withValues(alpha: 0.3));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2922) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: _isBranchAccordionOpen || _branchError != null ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado de acordeon
              InkWell(
                onTap: () {
                  setState(() {
                    _isBranchAccordionOpen = !_isBranchAccordionOpen;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.storefront_rounded,
                          color: primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sucursal / Clínica de Atención',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF687B70),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedBranch != null
                                  ? _selectedBranch!.name
                                  : 'Toca para elegir tu sucursal...',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: _selectedBranch != null ? FontWeight.bold : FontWeight.w500,
                                color: _selectedBranch != null
                                    ? (isDark ? Colors.white : const Color(0xFF1B2E24))
                                    : Colors.grey[500],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isBranchAccordionOpen
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: primaryColor,
                        size: 26,
                      ),
                    ],
                  ),
                ),
              ),

              // Contenido desplegable de sucursales
              if (_isBranchAccordionOpen) ...[
                const Divider(height: 1, thickness: 1),
                if (_isLoadingBranches)
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Cargando sucursales...',
                            style: TextStyle(fontSize: 13, color: Color(0xFF687B70)),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_branches.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'No hay sucursales disponibles en este momento.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    itemCount: _branches.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final branch = _branches[index];
                      final isSelected = _selectedBranch?.id == branch.id;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedBranch = branch;
                            _branchError = null;
                            _isBranchAccordionOpen = false;
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor.withValues(alpha: 0.12)
                                : (isDark ? const Color(0xFF28362D) : const Color(0xFFF7FAF8)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? primaryColor : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: isSelected ? primaryColor : Colors.grey[400],
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            branch.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight:
                                                  isSelected ? FontWeight.bold : FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF1B2E24),
                                            ),
                                          ),
                                        ),
                                        if (branch.code.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              branch.code,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: primaryColor,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (branch.address != null &&
                                        branch.address!.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on_outlined,
                                              size: 13, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              branch.address!,
                                              style: TextStyle(
                                                  fontSize: 11.5, color: Colors.grey[600]),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
        if (_branchError != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              _branchError!,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isAuthenticating = authService.status == AuthStatus.authenticating;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
                      'Crear Cuenta',
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
                      'Únete a NutriSalud y comienza hoy',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF687B70),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Full Name Field
                    TextFormField(
                      controller: _nameController,
                      maxLength: 250,
                      decoration: const InputDecoration(
                        labelText: 'Nombre Completo',
                        hintText: 'Alex Felipe',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa tu nombre';
                        }
                        if (value.trim().length < 2) {
                          return 'Mínimo 2 caracteres';
                        }
                        if (value.trim().length > 250) {
                          return 'Máximo 250 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

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
                          return 'Ingresa tu correo';
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
                        hintText: 'Mínimo 8 caracteres',
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
                    const SizedBox(height: 16),

                    // Confirm Password Field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscurePassword,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar Contraseña',
                        hintText: 'Repite tu contraseña',
                        prefixIcon: Icon(Icons.lock_reset_rounded),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Selector de Sucursal en lista acordeón
                    _buildBranchAccordion(isDark),
                    const SizedBox(height: 28),

                    // Submit Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                      ),
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
                          : const Text('Crear Cuenta'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
