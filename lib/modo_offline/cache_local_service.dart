import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class CacheLocalService {
  final FlutterSecureStorage _storage;
  CacheLocalService({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();
  String _prefix(String? userId) => 'nutri_cache_v2_${base64Url.encode(utf8.encode(userId ?? 'public'))}_';
  String _key(String key, String? userId) => '${_prefix(userId)}${base64Url.encode(utf8.encode(key))}';
  Future<void> guardar(String clave, dynamic datos, {String? userId}) async {
    await _storage.write(key: _key(clave, userId), value: jsonEncode({
      'guardado_en': DateTime.now().toIso8601String(), 'usuario_id': userId, 'datos': datos}));
  }
  Future<dynamic> obtener(String clave, {String? userId, Duration? duracionValidez}) async {
    final raw = await _storage.read(key: _key(clave, userId));
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final age = DateTime.now().difference(DateTime.parse(data['guardado_en']));
      if (data['usuario_id'] != userId || age > (duracionValidez ?? const Duration(hours: 24))) {
        await _storage.delete(key: _key(clave, userId)); return null;
      }
      return data['datos'];
    } catch (_) { return null; }
  }
  Future<void> limpiarCacheUsuario(String userId) async {
    for (final key in (await _storage.readAll()).keys.where((k) => k.startsWith(_prefix(userId))).toList()) {
      await _storage.delete(key: key);
    }
  }
  Future<void> limpiarTodo() async {
    for (final key in (await _storage.readAll()).keys.where((k) => k.startsWith('nutri_cache_v2_')).toList()) {
      await _storage.delete(key: key);
    }
  }
  Future<void> eliminarCacheLegacy() async {
    final dir = await getApplicationDocumentsDirectory();
    await for (final entry in dir.list()) {
      if (entry is File && entry.uri.pathSegments.last.startsWith('nutri_cache_')) await entry.delete();
    }
  }
}
