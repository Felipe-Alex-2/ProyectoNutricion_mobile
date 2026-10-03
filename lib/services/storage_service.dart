import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<bool> hasToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> saveLocalSubscription({
    required String status,
    required String expiresAt,
    required String orderId,
    String? userId,
  }) async {
    // Limpiar claves legacy globales para evitar contaminación
    await _storage.delete(key: 'sub_status');
    await _storage.delete(key: 'sub_expires');
    await _storage.delete(key: 'sub_order');

    if (userId != null && userId.isNotEmpty) {
      await _storage.write(key: 'sub_${userId}_status', value: status);
      await _storage.write(key: 'sub_${userId}_expires', value: expiresAt);
      await _storage.write(key: 'sub_${userId}_order', value: orderId);
    }
  }

  Future<Map<String, String?>> getLocalSubscription({String? userId}) async {
    // Limpiar claves legacy globales
    await _storage.delete(key: 'sub_status');
    await _storage.delete(key: 'sub_expires');
    await _storage.delete(key: 'sub_order');

    if (userId == null || userId.isEmpty) {
      return {};
    }
    final status = await _storage.read(key: 'sub_${userId}_status');
    final expires = await _storage.read(key: 'sub_${userId}_expires');
    final order = await _storage.read(key: 'sub_${userId}_order');
    return {
      'status': status,
      'expires': expires,
      'order': order,
    };
  }

  Future<void> clearLocalSubscription({String? userId}) async {
    await _storage.delete(key: 'sub_status');
    await _storage.delete(key: 'sub_expires');
    await _storage.delete(key: 'sub_order');
    if (userId != null && userId.isNotEmpty) {
      await _storage.delete(key: 'sub_${userId}_status');
      await _storage.delete(key: 'sub_${userId}_expires');
      await _storage.delete(key: 'sub_${userId}_order');
    }
  }
}
