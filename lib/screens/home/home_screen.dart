import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/activity_log.dart';
import '../../services/activity_log_service.dart';
import '../../services/auth_service.dart';
import '../../services/patient_service.dart';
import '../../services/theme_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  final TextEditingController _codeController = TextEditingController();
  bool _isClaiming = false;
  String? _claimError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PatientService>().fetchMyNutritionist();
      context.read<ActivityLogService>().fetchLogs();
      context.read<ActivityLogService>().recordLog(
        action: 'INICIO_SESION',
        description: 'Inicio de sesión en aplicación móvil',
      );
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleClaimCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _claimError = 'Por favor ingresa el código';
      });
      return;
    }

    setState(() {
      _isClaiming = true;
      _claimError = null;
    });

    final patientService = context.read<PatientService>();
    final success = await patientService.claimLink(code);

    if (mounted) {
      setState(() {
        _isClaiming = false;
        if (success) {
          _codeController.clear();
          _claimError = null;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Vinculación exitosa con tu especialista!'),
              backgroundColor: AppTheme.primaryGreen,
            ),
          );
        } else {
          _claimError = patientService.errorMessage ?? 'Código inválido o ya utilizado';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final themeService = context.watch<ThemeService>();
    final patientService = context.watch<PatientService>();
    final isDark = themeService.isDarkMode;

    final primaryGreen = isDark ? AppTheme.primaryGreenDark : AppTheme.primaryGreen;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: _buildSelectedTab(
          authService: authService,
          themeService: themeService,
          patientService: patientService,
          isDark: isDark,
          primaryGreen: primaryGreen,
          cardBg: cardBg,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSidebar : AppTheme.lightSidebar,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white10 : const Color(0x0A000000),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentNavIndex,
          onDestinationSelected: (idx) {
            setState(() {
              _currentNavIndex = idx;
            });
            if (idx == 2) {
              context.read<ActivityLogService>().fetchLogs();
            }
          },
          backgroundColor: Colors.transparent,
          indicatorColor: isDark ? AppTheme.darkPillActive : AppTheme.lightPillActive,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: textSecondary),
              selectedIcon: Icon(Icons.home_rounded, color: primaryGreen),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.medical_services_outlined, color: textSecondary),
              selectedIcon: Icon(Icons.medical_services_rounded, color: primaryGreen),
              label: 'Nutri',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined, color: textSecondary),
              selectedIcon: Icon(Icons.auto_stories_rounded, color: primaryGreen),
              label: 'Bitácora',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined, color: textSecondary),
              selectedIcon: Icon(Icons.calendar_month_rounded, color: primaryGreen),
              label: 'Plan',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, color: textSecondary),
              selectedIcon: Icon(Icons.person_rounded, color: primaryGreen),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTab({
    required AuthService authService,
    required ThemeService themeService,
    required PatientService patientService,
    required bool isDark,
    required Color primaryGreen,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    switch (_currentNavIndex) {
      case 0:
        return _buildHomeView(
          authService: authService,
          themeService: themeService,
          patientService: patientService,
          isDark: isDark,
          primaryGreen: primaryGreen,
          cardBg: cardBg,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );
      case 1:
        return _buildNutritionistView(
          patientService: patientService,
          isDark: isDark,
          primaryGreen: primaryGreen,
          cardBg: cardBg,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );
      case 2:
        return _buildJournalView(
          isDark: isDark,
          primaryGreen: primaryGreen,
          cardBg: cardBg,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );
      case 3:
        return _buildPlanView(
          patientService: patientService,
          isDark: isDark,
          primaryGreen: primaryGreen,
          cardBg: cardBg,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );
      case 4:
        return _buildProfileView(
          authService: authService,
          patientService: patientService,
          themeService: themeService,
          isDark: isDark,
          primaryGreen: primaryGreen,
          cardBg: cardBg,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // 1. MENÚ PRINCIPAL (Home View - Bienvenida y Detalles de Cuenta)
  Widget _buildHomeView({
    required AuthService authService,
    required ThemeService themeService,
    required PatientService patientService,
    required bool isDark,
    required Color primaryGreen,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final user = authService.currentUser;
    final nutri = patientService.linkedNutritionist;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header: Avatar, App Title, Theme Toggle
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: primaryGreen.withValues(alpha: 0.18),
                child: Text(
                  (user != null && user.fullName.isNotEmpty)
                      ? user.fullName[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NutriSalud SaaS',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      'Menú Principal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0x0F000000),
                  ),
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
            ],
          ),
          const SizedBox(height: 20),

          // Welcome Banner Card (Matched exactly to Web screenshot)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0x0A000000),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "Sesión Activa" Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? primaryGreen.withValues(alpha: 0.25)
                        : AppTheme.primaryGreenLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: isDark ? const Color(0xFF5DB386) : AppTheme.primaryGreen,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Sesión Activa',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF5DB386) : AppTheme.primaryGreen,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Greeting Title
                Text(
                  '¡Bienvenido/a, ${user?.fullName ?? 'prueba'}!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                RichText(
                  text: TextSpan(
                    text: 'Has ingresado al sistema como ',
                    style: TextStyle(
                      fontSize: 14,
                      color: textSecondary,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: user?.roleId == 'ADMIN_SAAS'
                            ? 'Administrador SaaS'
                            : (user?.roleId == 'ADMIN_CLINICA'
                                ? 'Administrador Clínica'
                                : (user?.roleId == 'NUTRICIONISTA'
                                    ? 'Nutricionista'
                                    : 'Cliente')),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const TextSpan(
                        text: '. Aquí puedes consultar la información y estado actual de tu cuenta.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Account Details Card ("Detalles de la Cuenta")
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0x0A000000),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header of Card
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detalles de la Cuenta',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Parámetros registrados de tu perfil en NutriSalud',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Cuenta Activa',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(color: isDark ? Colors.white10 : const Color(0x0A000000)),
                const SizedBox(height: 14),

                // Details Items
                _buildAccountInfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Nombre Completo',
                  value: user?.fullName ?? 'No especificado',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  iconColor: primaryGreen,
                ),
                const SizedBox(height: 16),

                _buildAccountInfoRow(
                  icon: Icons.email_outlined,
                  label: 'Correo Electrónico',
                  value: user?.email ?? 'No especificado',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  iconColor: primaryGreen,
                ),
                const SizedBox(height: 16),

                _buildAccountInfoRow(
                  icon: Icons.shield_outlined,
                  label: 'Rol del Sistema',
                  valueWidget: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Cliente',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                  ),
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  iconColor: primaryGreen,
                ),
                const SizedBox(height: 16),

                _buildAccountInfoRow(
                  icon: Icons.business_rounded,
                  label: 'Organización / Especialista',
                  value: nutri?.nutritionistName != null
                      ? '${nutri!.nutritionistName} (${nutri.tenantName ?? "NutriSalud"})'
                      : 'NutriSalud Central',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  iconColor: primaryGreen,
                ),
                const SizedBox(height: 16),

                _buildAccountInfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Teléfono de Contacto',
                  value: '+591 73683564',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  iconColor: primaryGreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAccountInfoRow({
    required IconData icon,
    required String label,
    String? value,
    Widget? valueWidget,
    required Color textPrimary,
    required Color textSecondary,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              if (valueWidget != null)
                valueWidget
              else
                Text(
                  value ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // 2. NUTRICIONISTA / VINCULAR VIEW
  Widget _buildNutritionistView({
    required PatientService patientService,
    required bool isDark,
    required Color primaryGreen,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final nutri = patientService.linkedNutritionist;

    return RefreshIndicator(
      onRefresh: () => patientService.fetchMyNutritionist(),
      color: primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mi Nutricionista',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Especialista a cargo de tu plan nutricional',
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            if (patientService.isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: CircularProgressIndicator(color: primaryGreen),
                ),
              )
            else if (nutri != null)
              // READ-ONLY NUTRICIONISTA CARD
              _buildNutritionistDetailsCard(
                nutri: nutri,
                isDark: isDark,
                cardBg: cardBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                primaryGreen: primaryGreen,
              )
            else
              // CLAIM PAIRING CODE CARD
              _buildClaimCodeCard(
                isDark: isDark,
                cardBg: cardBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                primaryGreen: primaryGreen,
              ),
          ],
        ),
      ),
    );
  }

  // Read-only Details of the Linked Nutritionist
  Widget _buildNutritionistDetailsCard({
    required dynamic nutri,
    required bool isDark,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryGreen,
  }) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22.0),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: primaryGreen.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: primaryGreen, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'ACTIVO / VINCULADO',
                          style: TextStyle(
                            color: primaryGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Solo Lectura',
                    style: TextStyle(
                      fontSize: 11,
                      color: textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Specialist Avatar & Name
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: primaryGreen.withValues(alpha: 0.15),
                    child: Icon(
                      Icons.medical_services_rounded,
                      color: primaryGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nutri.nutritionistName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          nutri.tenantName ?? 'Centro Nutricional Especializado',
                          style: TextStyle(
                            fontSize: 13,
                            color: primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: isDark ? Colors.white10 : const Color(0x0A000000)),
              const SizedBox(height: 14),

              // Details List
              if (nutri.nutritionistEmail != null && (nutri.nutritionistEmail as String).isNotEmpty)
                _buildReadOnlyDetailRow(
                  icon: Icons.email_outlined,
                  label: 'Correo de Contacto',
                  value: nutri.nutritionistEmail,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  iconColor: primaryGreen,
                ),
              const SizedBox(height: 12),
              _buildReadOnlyDetailRow(
                icon: Icons.phone_android_rounded,
                label: 'WhatsApp de Vinculación',
                value: nutri.whatsappNumber,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                iconColor: AppTheme.accentOrange,
              ),
              const SizedBox(height: 12),
              _buildReadOnlyDetailRow(
                icon: Icons.vpn_key_outlined,
                label: 'Código Canjeado',
                value: nutri.pairingCode,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                iconColor: primaryGreen,
              ),
              if (nutri.linkedAt != null) ...[
                const SizedBox(height: 12),
                _buildReadOnlyDetailRow(
                  icon: Icons.event_available_rounded,
                  label: 'Fecha de Vinculación',
                  value: '${nutri.linkedAt!.day}/${nutri.linkedAt!.month}/${nutri.linkedAt!.year}',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  iconColor: textSecondary,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Read-only Notice Card
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: primaryGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primaryGreen.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: primaryGreen, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tu cuenta está conectada de forma segura con tu nutricionista. Los planes alimenticios y recomendaciones son actualizados directamente por el especialista.',
                  style: TextStyle(
                    fontSize: 12,
                    color: textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color textPrimary,
    required Color textSecondary,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Form to Enter WhatsApp Link Code
  Widget _buildClaimCodeCard({
    required bool isDark,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryGreen,
  }) {
    return Container(
      padding: const EdgeInsets.all(22.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0x0A000000),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.link_rounded,
                  color: primaryGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vincular con tu Nutricionista',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'Ingresa el código que recibiste por WhatsApp',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Code Input Field
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Ej: NUTRI-12345',
              hintStyle: TextStyle(
                color: textSecondary.withValues(alpha: 0.6),
                letterSpacing: 1.0,
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: Icon(Icons.key_rounded, color: primaryGreen),
              filled: true,
              fillColor: isDark ? const Color(0xFF141C18) : const Color(0xFFF3F7F4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),

          if (_claimError != null) ...[
            const SizedBox(height: 8),
            Text(
              _claimError!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 18),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isClaiming ? null : _handleClaimCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isClaiming
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Vincular Especialista',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Instructions Callout
          Container(
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121915) : const Color(0xFFF7FBF8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryGreen.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.chat_outlined, color: primaryGreen, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¿Aún no tienes un código? Tu nutricionista te enviará un enlace con el código a través de WhatsApp para conectar tu plan.',
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. BITÁCORA DEL SISTEMA
  Widget _buildJournalView({
    required bool isDark,
    required Color primaryGreen,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final activityLogService = context.watch<ActivityLogService>();

    return RefreshIndicator(
      onRefresh: () => activityLogService.fetchLogs(),
      color: primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title, Subtitle, and Refresh Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bitácora del Sistema',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Registro cronológico de actividades y eventos',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: activityLogService.isLoading
                      ? null
                      : () => activityLogService.fetchLogs(),
                  icon: activityLogService.isLoading
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryGreen,
                          ),
                        )
                      : Icon(Icons.refresh_rounded, size: 16, color: primaryGreen),
                  label: Text(
                    'Actualizar',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    side: BorderSide(color: primaryGreen.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Logs Content
            if (activityLogService.isLoading && activityLogService.logs.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60.0),
                  child: CircularProgressIndicator(color: primaryGreen),
                ),
              )
            else if (activityLogService.logs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0x0A000000),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: primaryGreen.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        color: primaryGreen,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No hay eventos registrados',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No se encontraron registros de eventos en la bitácora.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activityLogService.logs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final log = activityLogService.logs[index];
                  return _buildLogItemCard(
                    log: log,
                    isDark: isDark,
                    cardBg: cardBg,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    primaryGreen: primaryGreen,
                  );
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLogItemCard({
    required ActivityLog log,
    required bool isDark,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryGreen,
  }) {
    Color badgeBg;
    Color badgeFg;
    final actionUpper = log.action.toUpperCase();

    if (actionUpper.contains('SESION') || actionUpper.contains('LOGIN')) {
      badgeBg = const Color(0xFF10B981).withValues(alpha: 0.15);
      badgeFg = const Color(0xFF10B981);
    } else if (actionUpper.contains('VINCUL') || actionUpper.contains('EMPAREJ')) {
      badgeBg = const Color(0xFF8B5CF6).withValues(alpha: 0.15);
      badgeFg = const Color(0xFF8B5CF6);
    } else if (actionUpper.contains('CONSULTA') || actionUpper.contains('BUSQUEDA')) {
      badgeBg = const Color(0xFF3B82F6).withValues(alpha: 0.15);
      badgeFg = const Color(0xFF3B82F6);
    } else if (actionUpper.contains('LOGOUT') || actionUpper.contains('SALIR')) {
      badgeBg = const Color(0xFFEF4444).withValues(alpha: 0.15);
      badgeFg = const Color(0xFFEF4444);
    } else {
      badgeBg = primaryGreen.withValues(alpha: 0.15);
      badgeFg = primaryGreen;
    }

    final hour = log.createdAt.hour.toString().padLeft(2, '0');
    final minute = log.createdAt.minute.toString().padLeft(2, '0');
    final second = log.createdAt.second.toString().padLeft(2, '0');
    final day = log.createdAt.day.toString().padLeft(2, '0');
    final month = log.createdAt.month.toString().padLeft(2, '0');
    final year = log.createdAt.year.toString();

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0x0A000000),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Time, Date and Action Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 14, color: textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '$hour:$minute:$second',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$day/$month/$year',
                    style: TextStyle(
                      fontSize: 11,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  log.action,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeFg,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Event Description
          Text(
            log.description,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),

          // Row 3: Origin / IP
          Row(
            children: [
              Icon(Icons.phone_android_rounded, size: 13, color: textSecondary),
              const SizedBox(width: 4),
              Text(
                'Móvil App • ${log.ipAddress ?? "127.0.0.1"}',
                style: TextStyle(
                  fontSize: 11,
                  color: textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 4. PLAN VIEW ("Próximamente" as requested)
  Widget _buildPlanView({
    required PatientService patientService,
    required bool isDark,
    required Color primaryGreen,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final nutri = patientService.linkedNutritionist;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plan Alimenticio',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Menús, porciones y guías nutricionales',
            style: TextStyle(
              fontSize: 13,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 40),

          // "Próximamente" Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0x0A000000),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.restaurant_menu_rounded,
                    color: AppTheme.accentOrange,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PROXIMAMENTE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Plan Personalizado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  nutri != null
                      ? 'Tu nutricionista (${nutri.nutritionistName}) está preparando tu pauta personalizada. Muy pronto podrás consultar tus recetas y equivalencias aquí.'
                      : 'Vincula a tu nutricionista en la sección "Nutri" para recibir tu plan alimenticio personalizado en cuanto esté listo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 5. PERFIL VIEW (Account details + Logout button as requested)
  Widget _buildProfileView({
    required AuthService authService,
    required PatientService patientService,
    required ThemeService themeService,
    required bool isDark,
    required Color primaryGreen,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final user = authService.currentUser;
    final nutri = patientService.linkedNutritionist;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mi Perfil',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Detalles de tu cuenta de paciente',
            style: TextStyle(
              fontSize: 13,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // User Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0x0A000000),
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: primaryGreen.withValues(alpha: 0.15),
                  child: Text(
                    (user != null && user.fullName.isNotEmpty)
                        ? user.fullName[0].toUpperCase()
                        : 'P',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  user?.fullName ?? 'Paciente',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Rol: ${user?.roleId ?? "CLIENTE"}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Details List Card
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0x0A000000),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Información General',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildProfileItem(
                  icon: Icons.badge_outlined,
                  title: 'Nombre',
                  value: user?.fullName ?? 'Sin registrar',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  primaryGreen: primaryGreen,
                ),
                const SizedBox(height: 14),
                _buildProfileItem(
                  icon: Icons.email_outlined,
                  title: 'Correo',
                  value: user?.email ?? 'Sin registrar',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  primaryGreen: primaryGreen,
                ),
                const SizedBox(height: 14),
                _buildProfileItem(
                  icon: Icons.medical_services_outlined,
                  title: 'Especialista Asignado',
                  value: nutri != null ? nutri.nutritionistName : 'Sin vincular aún',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  primaryGreen: primaryGreen,
                ),
                const SizedBox(height: 14),
                _buildProfileItem(
                  icon: Icons.verified_user_outlined,
                  title: 'Estado de Cuenta',
                  value: user?.isActive == true ? 'Activa' : 'Inactiva',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  primaryGreen: primaryGreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dark Mode Switch Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0x0A000000),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: primaryGreen,
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Modo Oscuro',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: isDark,
                  activeThumbColor: primaryGreen,
                  onChanged: (val) => themeService.toggleTheme(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _showLogoutDialog(context, authService),
              icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
              label: const Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCoral,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required String value,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryGreen,
  }) {
    return Row(
      children: [
        Icon(icon, color: primaryGreen, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCoral,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final logService = context.read<ActivityLogService>();
              logService.clearLogs();
              await logService.clearLogsOnServer();
              await authService.logout();
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }
}
