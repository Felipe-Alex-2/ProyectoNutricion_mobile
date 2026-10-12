import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../widgets/nutrition_ui.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _unreadOnly = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationService>().fetchNotifications();
    });
  }

  String _group(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final day = DateTime(local.year, local.month, local.day);
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'Hoy';
    if (day == DateTime(now.year, now.month, now.day - 1)) return 'Ayer';
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  (IconData, String?, int?) _category(String value) {
    final type = value.toUpperCase();
    if (type.contains('CITA') || type.contains('APPOINTMENT')) {
      return (Icons.calendar_today_outlined, 'Ver citas', 1);
    }
    if (type.contains('RECETA') ||
        type.contains('RECIPE') ||
        type.contains('PLAN')) {
      return (Icons.menu_book_outlined, 'Ver plan', 3);
    }
    if (type.contains('PAGO') ||
        type.contains('PAYMENT') ||
        type.contains('SUSCRIP')) {
      return (Icons.receipt_long_outlined, 'Ver suscripción', 2);
    }
    if (type.contains('VINCUL')) {
      return (Icons.person_add_outlined, 'Ver nutricionista', 1);
    }
    return (Icons.notifications_none_rounded, null, null);
  }

  Widget _notification(
    NotificationModel notification,
    NotificationService service,
  ) {
    final category = _category(notification.type);
    final color = category.$3 == 3
        ? AppTheme.accentOrange
        : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NutritionCard(
        onTap: notification.isRead
            ? null
            : () => service.markAsRead(notification.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NutritionIcon(category.$1, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (!notification.isRead) ...[
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Semantics(
                                label: 'Sin leer',
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        notification.timeAgo,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (category.$2 != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    if (!notification.isRead) {
                      service.markAsRead(notification.id);
                    }
                    Navigator.of(context).pop(category.$3);
                  },
                  child: Row(
                    children: [
                      Expanded(child: Text(category.$2!)),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ] else if (!notification.isRead)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => service.markAsRead(notification.id),
                  child: const Text('Marcar leída'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<NotificationService>();
    final notifications =
        service.notifications.where((n) => !_unreadOnly || !n.isRead).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final children = <Widget>[
      Row(
        children: [
          Expanded(
            child: ChoiceChip(
              label: const Center(child: Text('Todas')),
              selected: !_unreadOnly,
              labelStyle: TextStyle(
                color: !_unreadOnly
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
              showCheckmark: false,
              onSelected: (_) => setState(() => _unreadOnly = false),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ChoiceChip(
              label: const Center(child: Text('Sin leer')),
              selected: _unreadOnly,
              labelStyle: TextStyle(
                color: _unreadOnly
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
              showCheckmark: false,
              onSelected: (_) => setState(() => _unreadOnly = true),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
    ];
    String? previousGroup;
    for (final notification in notifications) {
      final group = _group(notification.createdAt);
      if (group != previousGroup) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Text(group, style: Theme.of(context).textTheme.titleLarge),
          ),
        );
        previousGroup = group;
      }
      children.add(_notification(notification, service));
    }
    if (notifications.isEmpty) {
      children.add(
        service.isLoading
            ? const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            : NutritionEmptyState(
                icon: Icons.notifications_none_rounded,
                title: _unreadOnly
                    ? 'Todo al día'
                    : 'Aún no hay notificaciones',
                message: _unreadOnly
                    ? 'Ya leíste tus avisos. Puedes revisar el historial en Todas.'
                    : 'Aquí encontrarás las novedades de tus citas y tu plan nutricional.',
              ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (service.unreadCount > 0)
            TextButton(
              onPressed: service.markAllAsRead,
              child: const Text('Marcar leídas'),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await service.fetchNotifications();
            await service.fetchUnreadCount();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: children,
          ),
        ),
      ),
    );
  }
}
