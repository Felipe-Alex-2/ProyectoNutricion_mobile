import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/notification_model.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/patient_service.dart';
import '../../services/theme_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  void _showSurveyModal(BuildContext context, NotificationModel notif) {
    String question = 'Evaluación Semanal de Hábitos';
    List<String> options = ['Sí, completamente', 'A veces / Parcialmente', 'No, me costó esta semana'];

    if (notif.referenceId != null && notif.referenceId!.isNotEmpty) {
      try {
        final data = jsonDecode(notif.referenceId!);
        if (data is Map<String, dynamic>) {
          if (data['question'] != null) question = data['question'].toString();
          if (data['options'] is List && (data['options'] as List).isNotEmpty) {
            options = (data['options'] as List).map((e) => e.toString()).toList();
          }
        }
      } catch (_) {}
    } else if (notif.message.contains('"')) {
      final parts = notif.message.split('"');
      if (parts.length >= 2) question = parts[1];
    }

    String? selectedOption = options.isNotEmpty ? options.first : null;
    bool isSubmitting = false;

    final themeService = context.read<ThemeService>();
    final isDark = themeService.isDarkMode;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final primaryGreen = isDark ? AppTheme.primaryGreenDark : AppTheme.primaryGreen;

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
            final bottomPadding = MediaQuery.of(context).viewInsets.bottom + 28.0;

            return SafeArea(
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
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.poll_rounded, color: Color(0xFF2563EB), size: 22),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Encuesta de Hábitos',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: textSecondary),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tu especialista nutricional ha programado la siguiente pregunta para evaluar tu progreso semanal:',
                        style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.35),
                      ),
                      const SizedBox(height: 16),

                      // Card con la Pregunta tipo WhatsApp
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141C18) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: primaryGreen.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          question,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      Text(
                        'Selecciona una opción:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary),
                      ),
                      const SizedBox(height: 10),

                      // Opciones tipo encuesta WhatsApp
                      ...options.map((opt) {
                        final isSelected = selectedOption == opt;
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              selectedOption = opt;
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? primaryGreen.withValues(alpha: 0.2) : const Color(0xFFE8F5E9))
                                  : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? primaryGreen : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  color: isSelected ? primaryGreen : textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    opt,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? primaryGreen : textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: isSubmitting || selectedOption == null
                              ? null
                              : () async {
                                  setModalState(() => isSubmitting = true);

                                  final auth = context.read<AuthService>();
                                  final patientService = context.read<PatientService>();
                                  final notifService = context.read<NotificationService>();
                                  final nutritionistId = patientService.linkedNutritionist?.nutritionistId;
                                  final patientName = auth.currentUser?.fullName ?? 'Paciente';
                                  final myId = auth.currentUser?.id;

                                  // 1. Enviar respuesta al nutricionista
                                  if (nutritionistId != null) {
                                    await notifService.sendNotification(
                                      userId: nutritionistId,
                                      title: '📋 Respuesta de Encuesta de Hábitos',
                                      message: '$patientName respondió: "$selectedOption" a la pregunta "$question"',
                                      type: 'RESPUESTA_ENCUESTA',
                                    );
                                  }

                                  // 2. Notificación local para el paciente confirmando la encuesta
                                  if (myId != null) {
                                    await notifService.sendNotification(
                                      userId: myId,
                                      title: '✅ Encuesta Completada',
                                      message: 'Has respondido a la encuesta: "$question" con "$selectedOption". Tu especialista ha recibido tu respuesta.',
                                      type: 'ENCUESTA_COMPLETADA',
                                    );
                                  }

                                  // 3. Marcar notificación actual como leída
                                  await notifService.markAsRead(notif.id);

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    notifService.fetchNotifications();
                                    notifService.fetchUnreadCount();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('¡Encuesta completada con éxito! Tu nutricionista ha recibido tu respuesta.'),
                                        backgroundColor: Color(0xFF059669),
                                      ),
                                    );
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Enviar Respuesta a Especialista',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final notifService = context.watch<NotificationService>();
    final isDark = themeService.isDarkMode;

    final primaryGreen = isDark ? AppTheme.primaryGreenDark : AppTheme.primaryGreen;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final notifications = notifService.notifications;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSidebar : AppTheme.lightSidebar,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notificaciones',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (notifService.unreadCount > 0)
            TextButton.icon(
              onPressed: () => notifService.markAllAsRead(),
              icon: Icon(Icons.done_all_rounded, color: primaryGreen, size: 18),
              label: Text(
                'Marcar leídas',
                style: TextStyle(
                  color: primaryGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifService.fetchNotifications(),
        color: primaryGreen,
        child: notifications.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: primaryGreen.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications_none_rounded,
                            size: 44,
                            color: primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Sin notificaciones pendientes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Aquí recibirás alertas cuando tu nutricionista actualice tu plan o asigne nuevas recetas y encuestas.',
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
                ),
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                itemCount: notifications.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  final isUnread = !notif.isRead;
                  final isSurvey = notif.type == 'ENCUESTA_HABITOS';

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (isSurvey) {
                        _showSurveyModal(context, notif);
                      } else if (isUnread) {
                        notifService.markAsRead(notif.id);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: isSurvey && isUnread
                            ? (isDark ? const Color(0xFF1E2838) : const Color(0xFFEFF6FF))
                            : cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSurvey && isUnread
                              ? const Color(0xFF3B82F6)
                              : (isUnread
                                  ? primaryGreen.withValues(alpha: 0.4)
                                  : (isDark ? Colors.white12 : const Color(0x0A000000))),
                          width: isUnread ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isSurvey
                                  ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                                  : (isUnread
                                      ? primaryGreen.withValues(alpha: 0.15)
                                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getNotifIcon(notif.type),
                              color: isSurvey
                                  ? const Color(0xFF2563EB)
                                  : (isUnread ? primaryGreen : textSecondary),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notif.title,
                                        style: TextStyle(
                                          fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 14,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (isUnread)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: isSurvey ? const Color(0xFF2563EB) : const Color(0xFFDC2626),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notif.message,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: textSecondary,
                                    height: 1.3,
                                  ),
                                ),
                                if (isSurvey) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                      onPressed: () => _showSurveyModal(context, notif),
                                      icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
                                      label: const Text(
                                        'Hacer Encuesta',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  notif.timeAgo,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: textSecondary.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  IconData _getNotifIcon(String type) {
    switch (type.toUpperCase()) {
      case 'ENCUESTA_HABITOS':
      case 'HABITOS':
        return Icons.poll_rounded;
      case 'RESPUESTA_ENCUESTA':
      case 'ENCUESTA_COMPLETADA':
        return Icons.task_alt_rounded;
      case 'CITA':
      case 'APPOINTMENT':
      case 'CITA_CREADA':
      case 'CITA_CONFIRMADA':
      case 'CITA_CANCELADA':
        return Icons.calendar_month_rounded;
      case 'RECETA':
      case 'RECIPE':
      case 'PLAN':
        return Icons.restaurant_menu_rounded;
      case 'ANAMNESIS':
        return Icons.assignment_turned_in_rounded;
      case 'VINCULACION':
        return Icons.person_add_rounded;
      case 'SISTEMA':
        return Icons.notifications_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }
}
