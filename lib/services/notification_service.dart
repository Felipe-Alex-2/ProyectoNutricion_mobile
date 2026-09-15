import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import 'api_service.dart';

class NotificationService extends ChangeNotifier {
  final ApiService _apiService;

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  NotificationService(this._apiService);

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  Future<void> fetchNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.get('/notifications?limit=50');
      if (response is List) {
        _notifications = response
            .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
            .toList();
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
        _unreadCount = response['unread_count'] as int;
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
}
