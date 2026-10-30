import 'package:url_launcher/url_launcher.dart';

import '../subscriptions/subscription_receipts_section.dart';
import '../../widgets/nutrition_ui.dart';
import 'widgets/nutrition_recipe_card.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../services/activity_log_service.dart';
import '../../services/auth_service.dart';
import '../../services/patient_service.dart';
import '../../services/theme_service.dart';
import '../../services/recipe_service.dart';
import '../../models/recipe_model.dart';
import '../../services/appointment_service.dart';
import '../../services/notification_service.dart';
import '../../services/subscription_service.dart';
import '../anamnesis/anamnesis_screen.dart';
import '../notifications/notifications_screen.dart';
import '../subscriptions/subscriptions_screen.dart';
import '../chat/carlitos_chat_screen.dart';
import '../../modo_offline/widgets/banner_sin_conexion.dart';
import '../../modo_offline/conectividad_service.dart';
import '../food/nutrition_diary_screen.dart';

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
  String _selectedPlanCategory = 'Todas';
  bool _showPastAppointments = false;
  NotificationService? _notificationService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notificationService = context.read<NotificationService>();
      context.read<PatientService>().fetchMyNutritionist();
      context.read<NotificationService>().fetchNotifications();
      context.read<NotificationService>().fetchUnreadCount();
      context.read<NotificationService>().startPolling();
      context.read<AppointmentService>().fetchAppointments();
      context.read<RecipeService>().fetchMyPlanRecipes();
      final currentUserId = context.read<AuthService>().currentUser?.id;
      context.read<SubscriptionService>().fetchCurrentSubscription(
        userId: currentUserId,
      );
    });
  }

  @override
  void dispose() {
    _notificationService?.stopPolling();
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
          _claimError =
              patientService.errorMessage ?? 'Código inválido o ya utilizado';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final themeService = context.watch<ThemeService>();
    final patientService = context.watch<PatientService>();
    final notifService = context.watch<NotificationService>();
    final unreadCount = notifService.unreadCount;
    final isDark = themeService.isDarkMode;

    final primaryGreen = isDark
        ? AppTheme.primaryGreenDark
        : AppTheme.primaryGreen;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textSecondary = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;

    // Si llegó una nueva alerta en vivo, mostrar notificación emergente flotante
    final alert = notifService.latestAlert;
    if (alert != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifService.clearLatestAlert();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.notifications_active,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        alert.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primaryGreen,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => const NutritionDiaryScreen())),
        icon: const Icon(Icons.restaurant_menu), label: const Text('Mi nutrición')),
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const BannerSinConexion(),
                Expanded(
                  child: _buildSelectedTab(
                    authService: authService,
                    themeService: themeService,
                    patientService: patientService,
                    unreadCount: unreadCount,
                    isDark: isDark,
                    primaryGreen: primaryGreen,
                    cardBg: cardBg,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white10 : const Color(0x0A000000),
            ),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
              states,
            ) {
              final isSelected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 11.0,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? primaryGreen : textSecondary,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _currentNavIndex,
            onDestinationSelected: _selectTab,
            backgroundColor: Colors.transparent,
            indicatorColor: isDark
                ? AppTheme.darkPillActive
                : AppTheme.lightPillActive,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, color: textSecondary),
                selectedIcon: Icon(Icons.home_rounded, color: primaryGreen),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.eco_outlined, color: textSecondary),
                selectedIcon: Icon(Icons.eco_rounded, color: primaryGreen),
                label: 'Nutri',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.workspace_premium_outlined,
                  color: textSecondary,
                ),
                selectedIcon: Icon(
                  Icons.workspace_premium_rounded,
                  color: primaryGreen,
                ),
                label: 'Premium',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined, color: textSecondary),
                selectedIcon: Icon(
                  Icons.menu_book_rounded,
                  color: primaryGreen,
                ),
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
      ),
    );
  }

  void _selectTab(int index) {
    setState(() => _currentNavIndex = index);
    if (index == 1) {
      context.read<PatientService>().fetchMyNutritionist();
      context.read<AppointmentService>().fetchAppointments();
    }
    if (index == 3) context.read<RecipeService>().fetchMyPlanRecipes();
  }

  Future<void> _openNotifications() async {
    final destination = await Navigator.of(
      context,
    ).push<int>(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    if (mounted && destination != null) _selectTab(destination);
  }

  Widget _buildSelectedTab({
    required AuthService authService,
    required ThemeService themeService,
    required PatientService patientService,
    required int unreadCount,
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
          unreadCount: unreadCount,
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
        return const SubscriptionsScreen();
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
    required int unreadCount,
    required bool isDark,
    required Color primaryGreen,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final user = authService.currentUser;
    final subscription = context.watch<SubscriptionService>();
    final appointments = context.watch<AppointmentService>();
    final recipes = context.watch<RecipeService>();
    final upcoming =
        appointments.appointments
            .where(
              (a) =>
                  a.status != 'CANCELLED' && a.status != 'COMPLETED' &&
                  !a.isConflictError &&
                  a.scheduledAt.isAfter(DateTime.now()),
            )
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final next = upcoming.isEmpty ? null : upcoming.first;
    final recipe = recipes.myPlanRecipes.isEmpty
        ? null
        : recipes.myPlanRecipes.first;
    final name =
        user?.fullName.trim().split(RegExp(r'\s+')).first ?? 'bienvenido';
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          patientService.fetchMyNutritionist(),
          appointments.fetchAppointments(),
          recipes.fetchMyPlanRecipes(),
          context.read<NotificationService>().fetchNotifications(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: NutritionBrand()),
                Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
                  backgroundColor: AppTheme.accentOrange,
                  child: IconButton(
                    tooltip: 'Notificaciones',
                    onPressed: _openNotifications,
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            NutritionHeading(
              'Hola, $name',
              subtitle: 'Un paso a la vez hacia tu bienestar.',
            ),
            const SizedBox(height: 20),
            NutritionCard(
              color: isDark
                  ? AppTheme.darkCardAccent
                  : AppTheme.primaryGreenLight,
              padding: const EdgeInsets.all(16),
              onTap: () => _selectTab(2),
              child: Row(
                children: [
                  Icon(
                    subscription.isPremium
                        ? Icons.workspace_premium_outlined
                        : Icons.eco_outlined,
                    color: primaryGreen,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      subscription.isPremium
                          ? 'Premium activo'
                          : subscription.hasResolvedSubscription
                          ? 'Tu plan gratuito'
                          : 'Comprobando tu plan…',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SizedBox(height: 20),
            NutritionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, color: primaryGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tu próxima cita',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (next != null) ...[
                    Text(
                      '${_shortDate(next.scheduledAt)} · ${_time(next.scheduledAt)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      next.nutritionistName ?? 'Tu nutricionista',
                      style: TextStyle(color: textSecondary),
                    ),
                    const SizedBox(height: 12),
                    NutritionStatus(
                      next.isOfflinePending
                          ? 'Pendiente de sincronizar'
                          : next.status == 'CONFIRMED'
                          ? 'Confirmada'
                          : 'Pendiente de confirmación',
                      icon: Icons.schedule_outlined,
                    ),
                  ] else
                    Text(
                      appointments.isLoading ? 'Cargando tus citas…' : 'Aún no tienes una próxima cita. Encuentra un espacio para cuidar de ti.',
                      style: TextStyle(color: textSecondary, height: 1.5),
                    ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _selectTab(1),
                      child: Text(
                        next == null ? 'Ir a mi nutricionista' : 'Ver cita',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (recipe != null)
              NutritionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.restaurant_menu_outlined,
                          color: primaryGreen,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tu plan nutricional',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (recipe.imageUrl?.isNotEmpty == true) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          recipe.imageUrl!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          cacheWidth: 1000,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      recipe.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${recipe.calories} kcal · ${recipe.prepTimeMinutes + recipe.cookTimeMinutes} min',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _selectTab(3),
                        child: const Text('Ver mi plan'),
                      ),
                    ),
                  ],
                ),
              )
            else
              NutritionEmptyState(
                icon: Icons.restaurant_menu_outlined,
                title: 'Tu plan nutricional',
                message: recipes.isLoading ? 'Estamos buscando tu plan…' : 'Las recetas que te asigne tu nutricionista aparecerán aquí.',
                action: OutlinedButton(
                  onPressed: () => _selectTab(3),
                  child: const Text('Ver mi plan'),
                ),
              ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final actions = [
                  _quickAction(
                    Icons.favorite_border_rounded,
                    'Ficha de salud',
                    'Tu información',
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AnamnesisScreen(),
                      ),
                    ),
                  ),
                  _quickAction(
                    Icons.eco_outlined,
                    'Carlitos IA',
                    'Resuelve tus dudas',
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CarlitosChatScreen(),
                      ),
                    ),
                  ),
                ];
                return constraints.maxWidth < 340 ||
                        MediaQuery.textScalerOf(context).scale(14) > 18
                    ? Column(
                        children: [
                          actions[0],
                          const SizedBox(height: 12),
                          actions[1],
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: actions[0]),
                          const SizedBox(width: 12),
                          Expanded(child: actions[1]),
                        ],
                      );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback action,
  ) => NutritionCard(
    padding: const EdgeInsets.all(14),
    onTap: action,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NutritionIcon(icon, size: 36),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );

  String _shortDate(DateTime value) {
    final date = value.toLocal();
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _time(DateTime value) {
    final date = value.toLocal();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

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
              'Mi nutricionista',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Especialista a cargo de tu plan nutricional',
              style: TextStyle(fontSize: 13, color: textSecondary),
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
              Column(
                children: [
                  _buildClaimCodeCard(
                    isDark: isDark,
                    cardBg: cardBg,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    primaryGreen: primaryGreen,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showScheduleAppointmentBottomSheet(context),
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: const Text('Solicitar cita'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            _buildAppointmentsListSection(
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
    final email = nutri.nutritionistEmail as String?;
    final phone = nutri.whatsappNumber as String?;
    return NutritionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const NutritionIcon(Icons.person_outline_rounded, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nutri.nutritionistName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nutri.tenantName ?? 'Nutricionista',
                      style: TextStyle(color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const NutritionStatus(
            'Vinculada',
            icon: Icons.check_circle_outline_rounded,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (email != null && email.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () =>
                      _openContact(Uri(scheme: 'mailto', path: email)),
                  icon: const Icon(Icons.mail_outline_rounded, size: 20),
                  label: const Text('Correo'),
                ),
              if (phone != null &&
                  phone.replaceAll(RegExp(r'\D'), '').isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _openContact(
                    Uri.https(
                      'wa.me',
                      '/${phone.replaceAll(RegExp(r'\D'), '')}',
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                  label: const Text('WhatsApp'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            title: const Text('Detalles de vinculación'),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Código canjeado'),
                subtitle: Text(nutri.pairingCode),
              ),
              if (nutri.linkedAt != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha de vinculación'),
                  subtitle: Text(_shortDate(nutri.linkedAt)),
                ),
              if (email != null && email.isNotEmpty) SelectableText(email),
              if (phone != null && phone.isNotEmpty) SelectableText(phone),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showScheduleAppointmentBottomSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Solicitar cita'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openContact(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir la aplicación de contacto.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir la aplicación de contacto.'),
          ),
        );
      }
    }
  }

  Widget _buildAppointmentsListSection({
    required bool isDark,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryGreen,
  }) {
    final service = context.watch<AppointmentService>();
    final now = DateTime.now();
    final appointments =
        service.appointments.where((a) {
          final past = a.scheduledAt.isBefore(now) || a.status == 'CANCELLED' || a.status == 'COMPLETED';
          return _showPastAppointments ? past : !past;
        }).toList()..sort(
          (a, b) => _showPastAppointments
              ? b.scheduledAt.compareTo(a.scheduledAt)
              : a.scheduledAt.compareTo(b.scheduledAt),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mis citas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Actualizar citas',
              onPressed: service.fetchAppointments,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: [
            ChoiceChip(
              label: const Text('Próximas'),
              selected: !_showPastAppointments,
              showCheckmark: false,
              labelStyle: TextStyle(
                color: !_showPastAppointments
                    ? Theme.of(context).colorScheme.onPrimary
                    : textPrimary,
              ),
              onSelected: (_) => setState(() => _showPastAppointments = false),
            ),
            ChoiceChip(
              label: const Text('Anteriores'),
              selected: _showPastAppointments,
              showCheckmark: false,
              labelStyle: TextStyle(
                color: _showPastAppointments
                    ? Theme.of(context).colorScheme.onPrimary
                    : textPrimary,
              ),
              onSelected: (_) => setState(() => _showPastAppointments = true),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (service.isLoading) const LinearProgressIndicator(),
        if (appointments.isEmpty && !service.isLoading)
          NutritionEmptyState(
            icon: Icons.calendar_today_outlined,
            title: _showPastAppointments
                ? 'Sin citas anteriores'
                : 'Un espacio para tu bienestar',
            message: _showPastAppointments
                ? 'Aquí aparecerá tu historial de citas.'
                : 'Solicita una cita con tu nutricionista para continuar tu seguimiento.',
          ),
        for (final appointment in appointments) ...[
          NutritionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.reason?.isNotEmpty == true
                      ? appointment.reason!
                      : 'Consulta nutricional',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${_shortDate(appointment.scheduledAt)} · ${_time(appointment.scheduledAt)}',
                      style: TextStyle(color: textSecondary),
                    ),
                    NutritionStatus(
                      appointment.isConflictError
                          ? 'Horario ocupado'
                          : appointment.isOfflinePending
                          ? 'Pendiente · sin conexión'
                          : appointment.status == 'CONFIRMED'
                          ? 'Confirmada'
                          : appointment.status == 'COMPLETED'
                          ? 'Atendida'
                          : appointment.status == 'CANCELLED'
                          ? 'Cancelada'
                          : 'Pendiente de confirmación',
                      icon: Icons.event_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  appointment.nutritionistName ?? 'Tu nutricionista',
                  style: TextStyle(color: textSecondary),
                ),
                if (appointment.isOfflinePending) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Guardada en tu dispositivo. Se enviará cuando vuelvas a conectarte.',
                  ),
                ],
                if (appointment.cancellationReason?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    appointment.cancellationReason!,
                    style: const TextStyle(color: AppTheme.accentCoral),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

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
        borderRadius: BorderRadius.circular(20),
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
                child: Icon(Icons.link_rounded, color: primaryGreen, size: 24),
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
                      style: TextStyle(fontSize: 12, color: textSecondary),
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
              fillColor: isDark
                  ? const Color(0xFF141C18)
                  : const Color(0xFFF3F7F4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
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
              border: Border.all(color: primaryGreen.withValues(alpha: 0.12)),
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

  // 3. CENTRO DE NOTIFICACIONES (Conservado por compatibilidad)
  // ignore: unused_element

  Future<void> _showScheduleAppointmentBottomSheet(BuildContext context) async {
    final owner = context.read<AuthService>().currentUser?.id;
    await context.read<AppointmentService>().fetchNutritionists();
    if (!context.mounted ||
        context.read<AuthService>().currentUser?.id != owner) {
      return;
    }
    final patientService = context.read<PatientService>();
    final apptService = context.read<AppointmentService>();
    final themeService = context.read<ThemeService>();
    final isDark = themeService.isDarkMode;

    final primaryGreen = isDark
        ? AppTheme.primaryGreenDark
        : AppTheme.primaryGreen;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textSecondary = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;

    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    final TextEditingController reasonController = TextEditingController();

    // Map deduplicado de nutricionistas disponibles
    final Map<String, String> nutriMap = {};
    for (final n in apptService.nutritionists) {
      if (n.id.isNotEmpty) {
        nutriMap[n.id] = n.fullName;
      }
    }
    if (patientService.linkedNutritionist != null) {
      final ln = patientService.linkedNutritionist!;
      if (ln.nutritionistId.isNotEmpty) {
        nutriMap[ln.nutritionistId] = ln.nutritionistName;
      }
    }

    String? selectedNutritionistId =
        patientService.linkedNutritionist?.nutritionistId;
    String? selectedNutritionistName =
        patientService.linkedNutritionist?.nutritionistName;

    // Si aún no hay selección válida y hay nutricionistas disponibles
    if (selectedNutritionistId == null ||
        !nutriMap.containsKey(selectedNutritionistId)) {
      if (nutriMap.isNotEmpty) {
        selectedNutritionistId = nutriMap.keys.first;
        selectedNutritionistName = nutriMap[selectedNutritionistId];
      } else {
        selectedNutritionistId = null;
        selectedNutritionistName = null;
      }
    }

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final navBarPadding = MediaQuery.of(context).viewPadding.bottom;
            final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
            final bottomPadding =
                keyboardPadding +
                (navBarPadding > 0 ? navBarPadding + 16 : 28.0);

            return SafeArea(
              top: false,
              bottom: true,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: bottomPadding,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB)
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.calendar_month_rounded,
                                  color: Color(0xFF2563EB),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Agendar Cita',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: textSecondary),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Selector de Nutricionista
                      Text(
                        'Nutricionista *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (nutriMap.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue:
                              nutriMap.containsKey(selectedNutritionistId)
                              ? selectedNutritionistId
                              : (nutriMap.isNotEmpty
                                    ? nutriMap.keys.first
                                    : null),
                          dropdownColor: cardBg,
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.person_rounded,
                              color: primaryGreen,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF141C18)
                                : const Color(0xFFF3F7F4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          items: nutriMap.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setModalState(() {
                              selectedNutritionistId = val;
                              if (val != null && nutriMap.containsKey(val)) {
                                selectedNutritionistName = nutriMap[val];
                              }
                            });
                          },
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF141C18)
                                : const Color(0xFFF3F7F4),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_rounded,
                                color: primaryGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                selectedNutritionistName ??
                                    'Especialista de la clínica',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Selector de Fecha y Hora
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fecha *',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: selectedDate,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 90),
                                      ),
                                    );
                                    if (picked != null) {
                                      setModalState(() {
                                        selectedDate = picked;
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF141C18)
                                          : const Color(0xFFF3F7F4),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          size: 16,
                                          color: primaryGreen,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hora *',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: selectedTime,
                                    );
                                    if (picked != null) {
                                      setModalState(() {
                                        selectedTime = picked;
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF141C18)
                                          : const Color(0xFFF3F7F4),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 16,
                                          color: primaryGreen,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          selectedTime.format(context),
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Motivo de consulta (Opcional)
                      Text(
                        'Motivo de la consulta (Opcional)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: reasonController,
                        maxLines: 2,
                        style: TextStyle(color: textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Ej: Control mensual, revisión de plan alimenticio...',
                          hintStyle: TextStyle(
                            color: textSecondary.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF141C18)
                              : const Color(0xFFF3F7F4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Botón de Enviar
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (selectedNutritionistId == null &&
                                      apptService.nutritionists.isNotEmpty) {
                                    selectedNutritionistId =
                                        apptService.nutritionists.first.id;
                                  }

                                  if (selectedNutritionistId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Por favor selecciona un nutricionista disponible',
                                        ),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }

                                  setModalState(() {
                                    isSubmitting = true;
                                  });

                                  final scheduledDateTime = DateTime(
                                    selectedDate.year,
                                    selectedDate.month,
                                    selectedDate.day,
                                    selectedTime.hour,
                                    selectedTime.minute,
                                  );

                                  final conectividad = context
                                      .read<ConectividadService>();
                                  final bool estaOffline =
                                      !conectividad.estaConectado;

                                  final success = await apptService
                                      .bookAppointment(
                                        nutritionistId: selectedNutritionistId!,
                                        scheduledAt: scheduledDateTime,
                                        reason: reasonController.text.trim(),
                                        nutritionistName:
                                            selectedNutritionistName,
                                      );

                                  if (context.mounted) {
                                    if (!success) {
                                      setModalState(() {
                                        isSubmitting = false;
                                      });
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            apptService.errorMessage ??
                                                'Error al agendar la cita',
                                          ),
                                          backgroundColor: Colors.redAccent,
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                      return;
                                    }

                                    Navigator.pop(context);
                                    final esPendienteOffline =
                                        estaOffline ||
                                        (apptService.appointments.isNotEmpty &&
                                            apptService
                                                .appointments
                                                .first
                                                .isOfflinePending);

                                    if (esPendienteOffline) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Cita guardada como pendiente (sin conexion). Se enviara automaticamente a tu especialista cuando te conectes a internet.',
                                          ),
                                          backgroundColor: Color(0xFFD97706),
                                          duration: Duration(seconds: 4),
                                        ),
                                      );
                                    } else {
                                      context
                                          .read<NotificationService>()
                                          .fetchNotifications();
                                      context
                                          .read<NotificationService>()
                                          .fetchUnreadCount();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Cita solicitada con exito. Queda pendiente de confirmacion por tu especialista.',
                                          ),
                                          backgroundColor: Color(0xFF059669),
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Confirmar y Agendar Cita',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 4. PLAN VIEW (Recetas asignadas por el Nutricionista con macros y fotos)
  Widget _buildPlanView({
    required PatientService patientService,
    required bool isDark,
    required Color primaryGreen,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final nutri = patientService.linkedNutritionist;
    final recipeService = context.watch<RecipeService>();
    final allRecipes = recipeService.myPlanRecipes;

    final categories = ['Todas', 'Desayuno', 'Almuerzo', 'Cena', 'Snack'];
    final filteredRecipes = _selectedPlanCategory == 'Todas'
        ? allRecipes
        : allRecipes
              .where(
                (r) =>
                    r.category.toLowerCase() ==
                    _selectedPlanCategory.toLowerCase(),
              )
              .toList();

    return RefreshIndicator(
      color: primaryGreen,
      onRefresh: () => context.read<RecipeService>().fetchMyPlanRecipes(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mi plan nutricional',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Preparado para ti por tu nutricionista',
                        style: TextStyle(fontSize: 13, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: primaryGreen),
                  tooltip: 'Actualizar recetas',
                  onPressed: () =>
                      context.read<RecipeService>().fetchMyPlanRecipes(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
                builder: (_) => const NutritionDiaryScreen())),
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Ver plan asignado y diario de alimentación')),
            const SizedBox(height: 14),

            // Filtros de Categoría
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSel = _selectedPlanCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSel,
                      selectedColor: primaryGreen,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : textPrimary,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedPlanCategory = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            if (recipeService.isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: CircularProgressIndicator(color: primaryGreen),
                ),
              )
            else if (allRecipes.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 36.0,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
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
                    Text(
                      'Sin Recetas Asignadas Aún',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      nutri != null
                          ? 'Tu especialista (${nutri.nutritionistName}) aún no ha asignado recetas a tu plan. En cuanto te asigne una receta desde la plataforma web, aparecerá aquí con sus ingredientes e instrucciones.'
                          : 'Vincula a tu especialista en la sección "Nutri" para que pueda programar y asignarte tus recetas personalizadas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              )
            else if (filteredRecipes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: Text(
                    'No tienes recetas en la categoría "$_selectedPlanCategory".',
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredRecipes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final recipe = filteredRecipes[index];
                  return NutritionRecipeCard(
                    onDetails: () => _showRecipeDetailsSheet(
                      recipe,
                      isDark,
                      cardBg,
                      textPrimary,
                      textSecondary,
                      primaryGreen,
                    ),
                    recipe: recipe,
                    isDark: isDark,
                    cardBg: cardBg,
                    primaryGreen: primaryGreen,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  );
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showRecipeDetailsSheet(
    RecipeModel recipe,
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color primaryGreen,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return SafeArea(
              top: false,
              bottom: true,
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  24.0,
                  24.0,
                  24.0,
                  28.0 + MediaQuery.of(context).viewPadding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            recipe.title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          label: Text(recipe.category),
                          backgroundColor: primaryGreen.withValues(alpha: 0.15),
                        ),
                        Chip(
                          label: Text('${recipe.calories} kcal'),
                          backgroundColor: AppTheme.accentOrange.withValues(
                            alpha: 0.15,
                          ),
                        ),
                        Chip(
                          label: Text(
                            '${recipe.prepTimeMinutes + recipe.cookTimeMinutes} min',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Ingredientes
                    Row(
                      children: [
                        Icon(
                          Icons.format_list_bulleted_rounded,
                          color: primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ingredientes y Porciones',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0x08000000),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        recipe.ingredients,
                        style: TextStyle(
                          fontSize: 14,
                          color: textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Instrucciones
                    Row(
                      children: [
                        Icon(
                          Icons.kitchen_rounded,
                          color: primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Modo de Preparación',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0x08000000),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        recipe.instructions,
                        style: TextStyle(
                          fontSize: 14,
                          color: textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            );
          },
        );
      },
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
    final sub = context.watch<SubscriptionService>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NutritionHeading('Perfil'),
          const SizedBox(height: 28),
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: primaryGreen.withValues(alpha: .12),
                child: Text(
                  user?.fullName.isNotEmpty == true
                      ? user!.fullName[0].toUpperCase()
                      : 'P',
                  style: TextStyle(fontSize: 28, color: primaryGreen),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'Paciente',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(color: textSecondary),
                    ),
                    const SizedBox(height: 10),
                    NutritionStatus(
                      sub.isPremium
                          ? 'Premium activo'
                          : sub.hasResolvedSubscription
                          ? 'Plan gratuito'
                          : 'Comprobando plan…',
                      icon: sub.isPremium
                          ? Icons.workspace_premium_outlined
                          : Icons.eco_outlined,
                      gold: sub.isPremium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          NutritionCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text('Datos personales'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showModalBottomSheet(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    builder: (context) => SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const NutritionHeading('Datos personales'),
                            const SizedBox(height: 16),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Nombre'),
                              subtitle: Text(user?.fullName ?? 'Sin registrar'),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Correo'),
                              subtitle: SelectableText(
                                user?.email ?? 'Sin registrar',
                              ),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Especialista'),
                              subtitle: Text(
                                patientService
                                        .linkedNutritionist
                                        ?.nutritionistName ??
                                    'Sin vincular',
                              ),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Cuenta'),
                              subtitle: Text(
                                user?.isActive == true ? 'Activa' : 'Inactiva',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const Divider(indent: 56, endIndent: 12),
                ListTile(
                  leading: const Icon(Icons.favorite_border_rounded),
                  title: const Text('Mi ficha de salud'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AnamnesisScreen()),
                  ),
                ),
                const Divider(indent: 56, endIndent: 12),
                SwitchListTile(
                  secondary: const Icon(Icons.palette_outlined),
                  title: const Text('Apariencia'),
                  subtitle: Text(isDark ? 'Modo oscuro' : 'Modo claro'),
                  value: isDark,
                  onChanged: (_) => themeService.toggleTheme(),
                ),
                const Divider(indent: 56, endIndent: 12),
                ListTile(
                  leading: const Icon(Icons.notifications_none_rounded),
                  title: const Text('Notificaciones'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openNotifications,
                ),
                const Divider(indent: 56, endIndent: 12),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Mis comprobantes'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionReceiptsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          NutritionCard(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: AppTheme.accentCoral,
              ),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(color: AppTheme.accentCoral),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.accentCoral,
              ),
              onTap: () => _showLogoutDialog(context, authService),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
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
              final subService = context.read<SubscriptionService>();
              logService.clearLogs();
              await logService.clearLogsOnServer();
              subService.reset();
              await authService.logout();
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }
}
