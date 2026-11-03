import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/notifications/notifications_screen.dart';
import 'api_service.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // The OS displays notification payloads while the app is closed.
}

class PushNotificationService {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static const channel = AndroidNotificationChannel(
    'nutrisalud_messages',
    'Mensajes de NutriSalud',
    description: 'Citas, pagos y mensajes de tu clínica',
    importance: Importance.high,
  );
  final ApiService api;
  final NotificationService notifications;
  final _local = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _refresh;
  StreamSubscription<RemoteMessage>? _messages, _opens;
  String? _token;
  String? _userId;
  RemoteMessage? _initial;
  bool _enabled = false;
  int _generation = 0;
  PushNotificationService(this.api, this.notifications);

  Future<void> initialize() async {
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return;
    }
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessage);
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          if (response.payload == api.currentUserId) _openInbox();
        },
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: false,
            sound: false,
          );
      _messages = FirebaseMessaging.onMessage.listen((message) async {
        if (message.data['user_id'] != api.currentUserId || _userId == null) {
          return;
        }
        await notifications.fetchNotifications();
        if (message.data['user_id'] != api.currentUserId) return;
        await _local.show(
          id: 1,
          title: message.notification?.title,
          body: message.notification?.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: Importance.high,
              priority: Priority.high,
              number: notifications.unreadCount,
              icon: 'ic_stat_notification',
            ),
            iOS: DarwinNotificationDetails(
              badgeNumber: notifications.unreadCount,
            ),
          ),
          payload: _userId,
        );
      });
      _opens = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        if (message.data['user_id'] == api.currentUserId) _openInbox();
      });
      _refresh = FirebaseMessaging.instance.onTokenRefresh.listen((
        token,
      ) async {
        _token = token;
        if (_userId != null) await _register(token, _userId!, _generation);
      });
      _initial = await FirebaseMessaging.instance.getInitialMessage();
      _enabled = true;
      notifications.addListener(_updateReadBadge);
    } catch (error) {
      debugPrint(
        'Push sin configurar. Añade google-services.json y sigue docs/NOTIFICACIONES_PUSH.md.',
      );
    }
  }

  void _updateReadBadge() {
    if (_enabled && notifications.unreadCount == 0) {
      unawaited(_local.cancelAll().catchError((Object _) {}));
    }
  }

  void _openInbox() {
    if (api.currentUserId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (api.currentUserId != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
        );
      }
    });
  }

  Future<void> bindUser(String? userId) async {
    _userId = userId;
    final generation = ++_generation;
    if (!_enabled || userId == null) return;
    try {
      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied ||
          generation != _generation) {
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        _token = token;
        await _register(token, userId, generation);
      }
      if (_initial?.data['user_id'] == userId) {
        _initial = null;
        _openInbox();
      }
    } catch (_) {
      debugPrint('No se pudo registrar el dispositivo para push.');
    }
  }

  Future<void> _register(String token, String userId, int generation) async {
    if (api.currentUserId != userId || generation != _generation) return;
    try {
      await api.post(
        '/automation/device-tokens',
        body: {
          'token': token,
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        },
      );
    } catch (_) {
      debugPrint('No se pudo registrar el token push.');
    }
  }

  Future<void> unlink() async {
    ++_generation;
    _userId = null;
    if (!_enabled) return;
    try {
      if (_token != null) {
        await api.post(
          '/automation/device-tokens/unregister',
          body: {'token': _token!, 'platform': 'android'},
        );
      }
    } catch (_) {
      debugPrint('No se pudo retirar el token push del servidor.');
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    await _local.cancelAll();
    _token = null;
  }

  Future<void> dispose() async {
    notifications.removeListener(_updateReadBadge);
    await _refresh?.cancel();
    await _messages?.cancel();
    await _opens?.cancel();
  }
}
