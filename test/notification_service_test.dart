import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/notification_service.dart';
import 'package:mobile/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'Unread badge uses the server total beyond the notification page size',
    () async {
      final api = ApiService(
        StorageService(),
        client: MockClient((r) async {
          final dynamic data = r.url.path.endsWith('/unread-count')
              ? {'unread_count': 128}
              : [
                  {
                    'id': 'n',
                    'user_id': 'patient',
                    'title': 'Mensaje',
                    'message': 'Texto',
                    'type': 'SISTEMA',
                    'is_read': false,
                    'created_at': '2026-11-03T12:00:00Z',
                  },
                ];
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      )..currentUserId = 'patient';
      final service = NotificationService(api);
      await service.fetchNotifications();
      expect(service.notifications.length, 1);
      expect(service.unreadCount, 128);
      await service.checkForNewNotifications();
      expect(service.unreadCount, 128);
      service.reset();
      expect(service.unreadCount, 0);
      service.dispose();
      api.dispose();
    },
  );
}
