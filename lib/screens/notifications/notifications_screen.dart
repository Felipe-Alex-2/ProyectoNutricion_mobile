import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/notification_service.dart';
import '../../services/theme_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

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
                          'Aquí recibirás alertas cuando tu nutricionista actualice tu plan o asigne nuevas recetas.',
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

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (isUnread) {
                        notifService.markAsRead(notif.id);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isUnread
                              ? primaryGreen.withValues(alpha: 0.4)
                              : (isDark ? Colors.white12 : const Color(0x0A000000)),
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
                              color: isUnread
                                  ? primaryGreen.withValues(alpha: 0.15)
                                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getNotifIcon(notif.type),
                              color: isUnread ? primaryGreen : textSecondary,
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
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFDC2626),
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
      case 'CITA':
      case 'APPOINTMENT':
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
