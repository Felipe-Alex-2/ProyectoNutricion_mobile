import '../../widgets/nutrition_ui.dart';

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
  List<Branch> _companyBranches = [];
  Branch? _selectedCompanyBranch;
  bool _loadingCompanyBranches = false;
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
      if (branches.length == 1) await _loadCompanyBranches(branches.first);
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

    if (_selectedBranch == null || _selectedCompanyBranch == null) {
      setState(() {
        _branchError = 'Selecciona tu empresa y sucursal de atención';
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
      branchId: _selectedCompanyBranch?.id,
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

  Future<void> _loadCompanyBranches(Branch company) async {
    setState(() {
      _selectedBranch = company;
      _selectedCompanyBranch = null;
      _companyBranches = [];
      _loadingCompanyBranches = true;
      _branchError = null;
    });
    try {
      final rows = await context.read<AuthService>().fetchCompanyBranches(
        company.id,
      );
      if (!mounted || _selectedBranch?.id != company.id) return;
      setState(() {
        _companyBranches = rows;
        _loadingCompanyBranches = false;
        if (rows.length == 1) _selectedCompanyBranch = rows.first;
      });
    } catch (_) {
      if (mounted && _selectedBranch?.id == company.id) {
        setState(() {
          _loadingCompanyBranches = false;
          _branchError = 'No se pudieron cargar las sucursales. Selecciona la empresa de nuevo.';
        });
      }
    }
  }

  Widget _buildBranchAccordion(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isLoadingBranches) const LinearProgressIndicator(),
        DropdownButtonFormField<String>(
          initialValue: _selectedBranch?.id,
          decoration: const InputDecoration(labelText: 'Empresa'),
          isExpanded: true,
          items: _branches
              .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
              .toList(),
          onChanged: (id) {
            final company = _branches.where((b) => b.id == id).firstOrNull;
            if (company != null) _loadCompanyBranches(company);
          },
          validator: (v) => v == null ? 'Selecciona una empresa' : null,
        ),
        const SizedBox(height: 16),
        if (_loadingCompanyBranches) const LinearProgressIndicator(),
        DropdownButtonFormField<String>(
          key: ValueKey('${_selectedBranch?.id}-${_selectedCompanyBranch?.id}'),
          initialValue: _selectedCompanyBranch?.id,
          decoration: const InputDecoration(labelText: 'Sucursal'),
          isExpanded: true,
          items: _companyBranches
              .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
              .toList(),
          onChanged: (id) => setState(
            () => _selectedCompanyBranch = _companyBranches
                .where((b) => b.id == id)
                .firstOrNull,
          ),
          validator: (v) => v == null ? 'Selecciona una sucursal' : null,
        ),
        if (_branchError != null)
          Text(
            _branchError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authenticating =
        context.watch<AuthService>().status == AuthStatus.authenticating;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const NutritionBrand(), const SizedBox(height: 24),
                    const NutritionHeading(
                      'Empecemos contigo',
                      subtitle: 'Crea tu cuenta y da el primer paso.',
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

                    NutritionCard(
                      color: isDark
                          ? AppTheme.darkCardAccent
                          : AppTheme.primaryGreenLight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Tu información nos ayuda a personalizar tu experiencia en NutriSalud.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: authenticating ? null : _submit,
                      child: authenticating
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Crear cuenta'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Ya tengo cuenta · Iniciar sesión'),
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
