import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../models/subscription_model.dart';
import '../../services/subscription_service.dart';
import '../../services/theme_service.dart';
import 'ai_module_screen.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  bool _isProcessingPayment = false;
  CreateOrderResponse? _activeOrder;
  bool _browserOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionService>().fetchCurrentSubscription();
      context.read<SubscriptionService>().fetchPlans();
    });
  }

  void _showPayPalCheckoutModal({bool autoLaunch = true}) {
    setState(() {
      _activeOrder = null;
      _browserOpened = false;
      _isProcessingPayment = false;
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
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    setModalState(() => _isProcessingPayment = true);

    final subService = context.read<SubscriptionService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // 1. Generar orden oficial de PayPal Sandbox (vía backend o fallback directo a PayPal API)
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
          content: Text(subService.errorMessage ?? 'Error al conectar con PayPal.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildPayPalModalContent({bool autoLaunch = true}) {
    final isDark = context.read<ThemeService>().isDarkMode;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    bool autoLaunched = false;

    return StatefulBuilder(
      builder: (context, setModalState) {
        if (autoLaunch && !autoLaunched && !_browserOpened && !_isProcessingPayment) {
          autoLaunched = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startPayPalFlow(setModalState);
          });
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                          color: const Color(0xFF003087).withValues(alpha: 0.1),
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
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
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
                        Text('Plan Seleccionado:', style: TextStyle(color: textSecondary, fontSize: 13)),
                        const Text('Plan Premium IA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Periodo de vigencia:', style: TextStyle(color: textSecondary, fontSize: 13)),
                        const Text('1 Mes (30 días)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Módulos IA incluidos:', style: TextStyle(color: textSecondary, fontSize: 13)),
                        const Text('Recomendación & Estimación', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF16A34A))),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total a Pagar:', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF003087).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF003087)),
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
                        backgroundColor: const Color(0xFFFFC439), // Color oficial PayPal Gold
                        foregroundColor: const Color(0xFF003087), // Azul oficial PayPal
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: Color(0xFF15803D), size: 24),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Se abrió PayPal Sandbox en tu navegador. Completa el cobro simulado y pulsa el botón abajo.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF14532D),
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessingPayment
                        ? null
                        : () async {
                            setModalState(() => _isProcessingPayment = true);

                            final subService = context.read<SubscriptionService>();
                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(context);

                            final orderId = _activeOrder?.orderId ?? 'PAYPAL_ORDER';
                            final success = await subService.captureOrActivateSubscription(orderId);

                            if (!mounted) return;
                            setModalState(() => _isProcessingPayment = false);

                            navigator.pop(); // Cerrar modal
                            if (success) {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '¡Pago con PayPal completado! Plan Premium activo por 1 mes y módulos de IA habilitados.',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Color(0xFF15803D),
                                  duration: Duration(seconds: 4),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      elevation: 1,
                    ),
                    icon: _isProcessingPayment
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.verified_rounded, color: Colors.white),
                    label: Text(
                      _isProcessingPayment ? 'Activando Plan Premium...' : 'Confirmar Pago y Activar Plan Premium',
                      style: const TextStyle(
                        fontSize: 14,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final subService = context.watch<SubscriptionService>();
    final themeService = context.watch<ThemeService>();
    final isDark = themeService.isDarkMode;

    final primaryGreen = isDark ? AppTheme.primaryGreenDark : AppTheme.primaryGreen;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final sub = subService.currentSubscription;
    final isPremium = subService.isPremium;

    return RefreshIndicator(
      onRefresh: () async {
        await subService.fetchCurrentSubscription();
        await subService.fetchPlans();
      },
      color: primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Header
            Text(
              'Suscripciones & Módulos IA',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gestiona tu membresía y desbloquea módulos avanzados',
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // =========================================================
            // 1. BANNER DE ESTADO SUPERIOR
            // El usuario pidió: "y que el primero este en amarillo y te
            // detalle que estas en el plan premium ya no en el free
            // que todos empiezan por default en el free"
            // =========================================================
            _buildStatusHeaderCard(
              isPremium: isPremium,
              sub: sub,
              isDark: isDark,
              cardBg: cardBg,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 28),

            // =========================================================
            // 2. MÓDULOS CON INTELIGENCIA ARTIFICIAL (Estilo Imagen 3)
            // =========================================================
            Text(
              'Módulos con Inteligencia Artificial',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isPremium
                  ? 'Módulos habilitados por tu suscripción Premium'
                  : 'Desbloquea estos módulos adquiriendo el Plan Premium (\$5 USD/mes)',
              style: TextStyle(
                fontSize: 12.5,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // MÓDULO 1: RECOMENDACIÓN DE COMIDAS CON IA (Color Ámbar / Dorado Mostaza #D9A441)
            _buildAiModuleCard(
              title: 'Recomendación de Comidas con IA',
              subtitle: 'Sugerencias y menús inteligentes adaptados a tus objetivos nutricionales y gustos.',
              buttonLabel: isPremium ? 'Acceder a Recomendación IA' : 'Bloqueado (Requiere Premium)',
              buttonIcon: isPremium ? Icons.auto_awesome_rounded : Icons.lock_outline_rounded,
              bgColor: isDark ? const Color(0xFF2C1E0A) : const Color(0xFFFFFBEB),
              borderColor: isDark ? const Color(0xFF6B4B10) : const Color(0xFFFDE68A),
              badgeColor: const Color(0xFFD9A441),
              iconData: Icons.restaurant_menu_rounded,
              buttonBgColor: const Color(0xFFD9A441),
              isUnlocked: isPremium,
              isDark: isDark,
              onPressed: () {
                if (isPremium) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AiModuleScreen(
                        title: 'Recomendación de Comidas con IA',
                        subtitle: 'Generador de menús diarios personalizados con modelos generativos de IA.',
                        icon: Icons.restaurant_menu_rounded,
                        accentColor: Color(0xFFD9A441),
                        upcomingFeatures: [
                          'Sugerencia de desayunos, almuerzos y cenas ajustados a tu meta calórica',
                          'Sustitución inteligente de ingredientes según tus alergias o preferencias',
                          'Recetas detalladas con instrucciones paso a paso optimizadas por IA',
                        ],
                      ),
                    ),
                  );
                } else {
                  _showUpgradeNoticeSnackBar();
                }
              },
            ),
            const SizedBox(height: 16),

            // MÓDULO 2: ESTIMACIÓN NUTRICIONAL DE ALIMENTOS CON IA (Color Ámbar / Dorado Mostaza #D9A441 + Cámara)
            _buildAiModuleCard(
              title: 'Estimación Nutricional de Alimentos con IA',
              subtitle: 'Calcula calorías, macronutrientes y porciones de tus alimentos con IA.',
              buttonLabel: isPremium ? 'Acceder a Estimación Nutricional IA' : 'Bloqueado (Requiere Premium)',
              buttonIcon: isPremium ? Icons.photo_camera_rounded : Icons.lock_outline_rounded,
              bgColor: isDark ? const Color(0xFF2C1E0A) : const Color(0xFFFFFBEB),
              borderColor: isDark ? const Color(0xFF6B4B10) : const Color(0xFFFDE68A),
              badgeColor: const Color(0xFFD9A441),
              iconData: Icons.photo_camera_rounded,
              buttonBgColor: const Color(0xFFD9A441),
              isUnlocked: isPremium,
              isDark: isDark,
              onPressed: () {
                if (isPremium) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AiModuleScreen(
                        title: 'Estimación Nutricional de Alimentos con IA',
                        subtitle: 'Análisis automatizado de macronutrientes y aporte energético.',
                        icon: Icons.photo_camera_rounded,
                        accentColor: Color(0xFFD9A441),
                        upcomingFeatures: [
                          'Estimación de calorías (kcal), proteínas, carbohidratos y grasas con reconocimiento fotográfico',
                          'Cálculo de equivalentes nutricionales y densidad calórica',
                          'Integración con tu registro de hábitos y anamnesis',
                        ],
                      ),
                    ),
                  );
                } else {
                  _showUpgradeNoticeSnackBar();
                }
              },
            ),
            const SizedBox(height: 32),

            // =========================================================
            // 3. COMPARATIVA Y GESTIÓN DE PLANES
            // Plan Free (lo que se tiene actualmente)
            // Plan Premium ($5 USD con PayPal y módulos IA)
            // =========================================================
            Text(
              'Planes Disponibles',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Revisa las diferencias entre el plan Gratuito y el Plan Premium',
              style: TextStyle(
                fontSize: 12.5,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // TARJETA PLAN FREE ($0 USD)
            _buildPlanCard(
              title: 'Plan Gratuito',
              price: '\$0.00 USD',
              period: 'por defecto',
              isCurrentPlan: !isPremium,
              badgeText: 'INCLUIDO POR DEFECTO',
              badgeColor: const Color(0xFF64748B),
              features: [
                'Mi Ficha de Salud (Llenar / Actualizar Anamnesis)',
                'Generar Cita con Nutricionista',
                'Vincularse con Nutricionista (WhatsApp)',
                'Ver Plan Nutricional asignado',
              ],
              disabledFeatures: [
                'Recomendación de comidas con IA',
                'Estimación nutricional de Alimentos con IA',
              ],
              isDark: isDark,
              cardBg: cardBg,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              actionWidget: OutlinedButton(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(
                  !isPremium ? 'Tu Plan Actual' : 'Plan Base (Superado)',
                  style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // TARJETA PLAN PREMIUM ($5.00 USD / mes con PayPal)
            _buildPlanCard(
              title: 'Plan Premium IA',
              price: '\$5.00 USD',
              period: 'por 1 mes de vigencia',
              isCurrentPlan: isPremium,
              badgeText: '⭐ PLAN PREMIUM',
              badgeColor: const Color(0xFFF59E0B),
              features: [
                'Mi Ficha de Salud (Llenar / Actualizar Anamnesis)',
                'Generar Cita con Nutricionista',
                'Vincularse con Nutricionista (WhatsApp)',
                'Ver Plan Nutricional asignado',
                'Recomendación de comidas con IA (Habilitado)',
                'Estimación nutricional de Alimentos con IA (Habilitado)',
                'Soporte prioritario y actualizaciones continuas',
              ],
              disabledFeatures: [],
              isDark: isDark,
              cardBg: cardBg,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              actionWidget: isPremium
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF15803D).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: const Color(0xFF16A34A)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Suscripción Premium Activa',
                            style: TextStyle(
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _showPayPalCheckoutModal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC439),
                          foregroundColor: const Color(0xFF003087),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 1,
                        ),
                        icon: const Icon(Icons.payment_rounded, color: Color(0xFF003087), size: 20),
                        label: const Text(
                          'Pagar con PayPal (\$5.00 USD / mes)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF003087),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // BANNER DE ESTADO SUPERIOR (Resalta en AMARILLO si está en Premium)
  Widget _buildStatusHeaderCard({
    required bool isPremium,
    required dynamic sub,
    required bool isDark,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    if (isPremium) {
      // AMARILLO / ORO DESTACADO PARA PREMIUM
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFF59E0B), // Borde Amarillo Oro
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.stars_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '⭐ PLAN PREMIUM ACTIVO',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '¡Ya no estás en el plan Free!',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Cuentas con acceso ilimitado a todos los módulos y funciones avanzadas de Inteligencia Artificial.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFFFDE68A).withValues(alpha: 0.9) : const Color(0xFF78350F),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_available_rounded, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Text(
                        'Vigencia: 1 Mes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Hasta: ${sub?.formattedExpiresAt ?? "30 días"}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // TARJETA DE ESTADO PLAN FREE (Default para todos)
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0x0A000000),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: textSecondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'PLAN ACTUAL: FREE (GRATUITO)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Nivel Estándar por Defecto',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Tu cuenta cuenta con los servicios básicos incluidos. Para desbloquear las recomendaciones y estimación con IA, actualiza al Plan Premium por \$5 USD.',
            style: TextStyle(
              fontSize: 12.5,
              color: textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // MÓDULOS CON EL ESTILO LIMPIO DE LA FOTO (ÁMBAR / DORADO MOSTAZA)
  Widget _buildAiModuleCard({
    required String title,
    required String subtitle,
    required String buttonLabel,
    required IconData buttonIcon,
    required Color bgColor,
    required Color borderColor,
    required Color badgeColor,
    required IconData iconData,
    required Color buttonBgColor,
    required bool isUnlocked,
    required bool isDark,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular icon badge
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Action Pill Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isUnlocked ? buttonBgColor : const Color(0xFF64748B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
              icon: Icon(buttonIcon, size: 18, color: Colors.white),
              label: Text(
                buttonLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // TARJETA DE PLAN (FREE / PREMIUM)
  Widget _buildPlanCard({
    required String title,
    required String price,
    required String period,
    required bool isCurrentPlan,
    required String badgeText,
    required Color badgeColor,
    required List<String> features,
    required List<String> disabledFeatures,
    required bool isDark,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required Widget actionWidget,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrentPlan
              ? badgeColor.withValues(alpha: 0.6)
              : (isDark ? Colors.white12 : const Color(0x0A000000)),
          width: isCurrentPlan ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (isCurrentPlan)
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                    SizedBox(width: 4),
                    Text(
                      'Activo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '• $period',
                style: TextStyle(
                  fontSize: 13,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Features List
          ...features.map(
            (feat) => Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 17, color: Color(0xFF16A34A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feat,
                      style: TextStyle(
                        fontSize: 13,
                        color: textPrimary,
                        fontWeight: feat.contains('IA') ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Disabled Features
          ...disabledFeatures.map(
            (feat) => Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Row(
                children: [
                  Icon(Icons.cancel_rounded, size: 17, color: textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feat,
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary.withValues(alpha: 0.6),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),
          actionWidget,
        ],
      ),
    );
  }

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
