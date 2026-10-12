import '../../widgets/nutrition_ui.dart';
import 'subscription_receipts_section.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../models/subscription_model.dart';
import '../../services/auth_service.dart';
import '../../services/subscription_service.dart';
import '../../services/theme_service.dart';
import 'ai_module_screen.dart';
import '../chat/carlitos_chat_screen.dart';
import '../food/food_vision_screen.dart';
import '../../modo_offline/conectividad_service.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  bool _isProcessingPayment = false;
  CreateOrderResponse? _activeOrder;
  bool _browserOpened = false;
  bool _paymentFailedOrNotPaid = false;
  String? _verificationMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthService>().currentUser;
      context.read<SubscriptionService>().fetchCurrentSubscription(
        userId: user?.id,
      );
      context.read<SubscriptionService>().fetchPlans();
      context.read<SubscriptionService>().fetchReceipts();
    });
  }

  void _showPayPalCheckoutModal({bool autoLaunch = true}) {
    setState(() {
      _activeOrder = null;
      _browserOpened = false;
      _isProcessingPayment = false;
      _paymentFailedOrNotPaid = false;
      _verificationMessage = null;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildPayPalModalContent(autoLaunch: autoLaunch),
    );
  }

  Future<void> _launchPayPalUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (e) {
        debugPrint('Error abriendo URL de PayPal: $e');
      }
    }
  }

  Future<void> _startPayPalFlow(StateSetter setModalState) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final conectividad = context.read<ConectividadService>();

    if (!conectividad.estaConectado) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Error: estás sin conexión a internet'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setModalState(() => _isProcessingPayment = true);

    final subService = context.read<SubscriptionService>();

    // El backend crea y verifica la orden PayPal.
    final order = await subService.createPayPalOrder('CLIENTE_PREMIUM');

    if (!mounted) return;

    if (order != null && order.approvalUrl.isNotEmpty) {
      await _launchPayPalUrl(order.approvalUrl);

      setModalState(() {
        _isProcessingPayment = false;
        _activeOrder = order;
        _browserOpened = true;
      });
    } else {
      setModalState(() => _isProcessingPayment = false);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            subService.errorMessage ?? 'Error al conectar con PayPal.',
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildPayPalModalContent({bool autoLaunch = true}) {
    final isDark = context.read<ThemeService>().isDarkMode;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textSecondary = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;

    bool autoLaunched = false;

    return StatefulBuilder(
      builder: (context, setModalState) {
        if (autoLaunch &&
            !autoLaunched &&
            !_browserOpened &&
            !_isProcessingPayment) {
          autoLaunched = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startPayPalFlow(setModalState);
          });
        }

        final bottomBarPadding = MediaQuery.of(context).viewPadding.bottom;
        return SafeArea(
          top: false,
          bottom: true,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + (bottomBarPadding > 0 ? bottomBarPadding : 8),
            ),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header with PayPal Logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF003087)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.payment_rounded,
                            color: Color(0xFF003087),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PayPal Sandbox Checkout',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF003087),
                              ),
                            ),
                            Text(
                              'Pago Seguro de 1 Mes (\$5.00 USD)',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Summary Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Plan Seleccionado:',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const Text(
                            'Plan Premium IA',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Periodo de vigencia:',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const Text(
                            '1 Mes (30 días)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Módulos IA incluidos:',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const Text(
                            'Recomendación & Estimación',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total a Pagar:',
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const Text(
                            '\$5.00 USD',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF003087),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (!_browserOpened) ...[
                  // PASO 1: Iniciar sesión en PayPal Sandbox
                  if (_isProcessingPayment)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF003087).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF003087),
                            ),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Conectando con PayPal Sandbox y abriendo navegador...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF003087),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => _startPayPalFlow(setModalState),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFFFFC439,
                          ), // Color oficial PayPal Gold
                          foregroundColor: const Color(
                            0xFF003087,
                          ), // Azul oficial PayPal
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 1,
                        ),
                        icon: const Text(
                          'P',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF003087),
                          ),
                        ),
                        label: const Text(
                          'Abrir PayPal Sandbox (\$5.00 USD)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF003087),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Se abrirá tu navegador (Google / Chrome) para ingresar con tu cuenta personal Sandbox',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ),
                ] else ...[
                  // PASO 2: Confirmación tras pagar en el navegador
                  if (_paymentFailedOrNotPaid) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF87171)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFDC2626),
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'No se pudo confirmar el pago',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: Color(0xFF991B1B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _verificationMessage ?? 'No se detectó el pago completado en PayPal Sandbox. Por favor completa el cobro en el navegador y vuelve a presionar "Verificar otra vez".',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF7F1D1D),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white12
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.open_in_browser_rounded,
                            color: Color(0xFF003087),
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Se abrió PayPal Sandbox en tu navegador. Una vez completes el cobro simulado, presiona el botón para verificar.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: textPrimary,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessingPayment
                          ? null
                          : () async {
                              setModalState(() => _isProcessingPayment = true);

                              final subService = context
                                  .read<SubscriptionService>();
                              final authService = context.read<AuthService>();
                              final scaffoldMessenger = ScaffoldMessenger.of(
                                context,
                              );
                              final navigator = Navigator.of(context);

                              final orderId = _activeOrder!.orderId;
                              final result = await subService
                                  .verifyAndActivateSubscription(
                                    orderId,
                                    userId: authService.currentUser?.id,
                                  );

                              if (!mounted) return;

                              if (result.isPaid) {
                                setModalState(() {
                                  _isProcessingPayment = false;
                                  _paymentFailedOrNotPaid = false;
                                  _verificationMessage = null;
                                });

                                if (!mounted) return;
                                setState(() {});

                                navigator.pop(); // Cerrar modal

                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Pago verificado exitosamente. Plan Premium activo por 1 mes y módulos de IA habilitados.',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: Color(0xFF15803D),
                                    duration: Duration(seconds: 4),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } else {
                                setModalState(() {
                                  _isProcessingPayment = false;
                                  _paymentFailedOrNotPaid = true;
                                  _verificationMessage = result.message;
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _paymentFailedOrNotPaid
                            ? const Color(
                                0xFFD97706,
                              ) // Color ámbar cuando debe reintentar
                            : const Color(
                                0xFF15803D,
                              ), // Color verde oficial verificación
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 1,
                      ),
                      icon: _isProcessingPayment
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _paymentFailedOrNotPaid
                                  ? Icons.refresh_rounded
                                  : Icons.verified_outlined,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isProcessingPayment
                            ? 'Verificando pago con PayPal...'
                            : (_paymentFailedOrNotPaid
                                  ? 'Verificar otra vez'
                                  : 'Verificar Pago'),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        if (_activeOrder != null) {
                          await _launchPayPalUrl(_activeOrder!.approvalUrl);
                        }
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text(
                        'Volver a abrir PayPal Sandbox en el navegador',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SubscriptionService>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final premium = service.isPremium;
    final plans = service.plans.where((p) => p.name == 'CLIENTE_PREMIUM');
    final price = plans.isEmpty
        ? r'$5.00 USD'
        : '${plans.first.price.toStringAsFixed(2)} ${plans.first.currency}';
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          service.fetchCurrentSubscription(
            userId: context.read<AuthService>().currentUser?.id,
          ),
          service.fetchPlans(),
          service.fetchReceipts(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NutritionHeading(
              'Suscripciones',
              subtitle: 'Tu bienestar, con más herramientas.',
            ),
            const SizedBox(height: 24),
            if (service.isRefreshing) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            if (!service.hasResolvedSubscription) ...[
              NutritionCard(
                child: Column(
                  children: [
                    if (service.errorMessage == null)
                      const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      service.errorMessage == null
                          ? 'Comprobando suscripción…'
                          : 'No se pudo comprobar tu suscripción.',
                    ),
                    if (service.errorMessage != null)
                      TextButton(
                        onPressed: () => service.fetchCurrentSubscription(
                          userId: context.read<AuthService>().currentUser?.id,
                        ),
                        child: const Text('Reintentar'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              NutritionCard(
                color: dark
                    ? AppTheme.darkCardAccent
                    : AppTheme.primaryGreenLight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NutritionIcon(
                      premium
                          ? Icons.workspace_premium_outlined
                          : Icons.eco_outlined,
                      color: premium
                          ? (dark
                                ? AppTheme.premiumGold
                                : const Color(0xFF9B671E))
                          : primary,
                      size: 56,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            premium
                                ? 'Suscripción Premium Activa'
                                : 'Tu plan gratuito',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            premium
                                ? 'Acceso habilitado'
                                : 'Lo esencial para empezar a cuidarte',
                          ),
                          if (premium) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Vigente hasta el ${service.currentSubscription!.formattedExpiresAt}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                premium ? 'Tus herramientas Premium' : 'Descubre Premium',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _module(
                Icons.eco_outlined,
                'Carlitos IA',
                'Tu asistente para dudas sobre alimentación.',
                premium,
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CarlitosChatScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _module(
                Icons.menu_book_outlined,
                'Recomendaciones personalizadas',
                'Un espacio para tus ideas de comidas. En desarrollo.',
                premium,
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AiModuleScreen(
                      title: 'Recomendaciones IA',
                      subtitle: 'Ideas para tu alimentación, adaptadas a ti.',
                      icon: Icons.restaurant_menu_outlined,
                      accentColor: AppTheme.primaryGreen,
                      upcomingFeatures: [
                        'Ideas para desayunos, almuerzos y cenas',
                        'Alternativas según tus preferencias y alergias',
                        'Recetas con instrucciones paso a paso',
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _module(
                Icons.photo_camera_outlined,
                'Análisis de alimentos',
                'Estima nutrientes a partir de una fotografía.',
                premium,
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FoodVisionScreen()),
                ),
              ),
              const SizedBox(height: 24),
              if (!premium) ...[
                NutritionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const NutritionStatus(
                        'Premium',
                        icon: Icons.workspace_premium_outlined,
                        gold: true,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        price,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '30 días de acceso · Pago con PayPal',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Incluye Carlitos y análisis de alimentos. El generador de menús está en desarrollo.',
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showPayPalCheckoutModal,
                          icon: const Icon(Icons.payment_outlined),
                          label: const Text('Continuar con PayPal'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (!premium)
                NutritionCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 16),
                    title: const Text('Incluido en tu plan gratuito'),
                    children: [
                      for (final feature in [
                        'Mi ficha de salud',
                        'Vinculación con tu nutricionista',
                        'Solicitud de citas',
                        'Plan nutricional asignado',
                      ])
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.check_circle_outline_rounded,
                            color: primary,
                          ),
                          title: Text(feature),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
            ],
            const SubscriptionReceiptsSection(showLatestOnly: true),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _module(
    IconData icon,
    String title,
    String subtitle,
    bool unlocked,
    VoidCallback action,
  ) => NutritionCard(
    padding: const EdgeInsets.all(18),
    onTap: unlocked ? action : _showUpgradeNoticeSnackBar,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NutritionIcon(icon),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          unlocked ? Icons.chevron_right_rounded : Icons.lock_outline_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ],
    ),
  );

  void _showUpgradeNoticeSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Módulo exclusivo del Plan Premium. Adquiere el plan por \$5 USD para desbloquearlo.',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFB45309),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Ver Planes',
          textColor: Colors.white,
          onPressed: _showPayPalCheckoutModal,
        ),
      ),
    );
  }
}
