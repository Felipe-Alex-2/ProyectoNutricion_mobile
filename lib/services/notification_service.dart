import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/notification_model.dart';
import 'api_service.dart';

class NotificationService extends ChangeNotifier {
  final ApiService _apiService;

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  Timer? _pollingTimer;
  NotificationModel? _latestAlert;

  NotificationService(this._apiService);

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  NotificationModel? get latestAlert => _latestAlert;

  void clearLatestAlert() {
    _latestAlert = null;
  }

  void startPolling({Duration interval = const Duration(seconds: 10)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) => checkForNewNotifications());
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> playAlertSoundAndVibrate() async {
    try {
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 140));
      await HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      debugPrint('Error triggering vibration/sound: $e');
    }
  }

  Future<void> checkForNewNotifications() async {
    try {
      final response = await _apiService.get('/notifications?limit=25');
      if (response is List) {
        final freshList = response
            .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
            .toList();
        final freshUnread = freshList.where((n) => !n.isRead).length;

        // Detectar si llegaron nuevas notificaciones no leídas
        final newUnreadItems = freshList.where(
          (f) => !f.isRead && !_notifications.any((old) => old.id == f.id && !old.isRead),
        ).toList();

        if (newUnreadItems.isNotEmpty && _notifications.isNotEmpty) {
          // Hacer sonar y vibrar el teléfono
          await playAlertSoundAndVibrate();
          _latestAlert = newUnreadItems.first;
        }

        _notifications = freshList;
        _unreadCount = freshUnread;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error polling notifications: $e');
    }
  }

  Future<void> fetchNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.get('/notifications?limit=50');
      if (response is List) {
        final freshList = response
            .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _notifications = freshList;
      } else {
        _notifications = [];
      }
      _unreadCount = _notifications.where((n) => !n.isRead).length;
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final response = await _apiService.get('/notifications/unread-count');
      if (response is Map<String, dynamic> && response.containsKey('unread_count')) {
        final newCount = response['unread_count'] as int;
        if (newCount > _unreadCount && _unreadCount >= 0) {
          await playAlertSoundAndVibrate();
        }
        _unreadCount = newCount;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching unread count: $e');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _apiService.patch('/notifications/$notificationId/read');
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index].isRead = true;
        _unreadCount = (_unreadCount > 0) ? _unreadCount - 1 : 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiService.patch('/notifications/read-all');
      for (final n in _notifications) {
        n.isRead = true;
      }
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
