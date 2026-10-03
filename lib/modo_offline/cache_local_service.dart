import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CacheLocalService {
  Directory? _documentsDir;

  Future<Directory> _getDir() async {
    _documentsDir ??= await getApplicationDocumentsDirectory();
    return _documentsDir!;
  }

  String _sanitizeKey(String key) {
    return key.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  Future<File> _getFile(String clave, String? userId) async {
    final dir = await _getDir();
    final userPrefix = (userId != null && userId.isNotEmpty) ? 'u_${_sanitizeKey(userId)}_' : 'global_';
    final safeKey = _sanitizeKey(clave);
    return File('${dir.path}/nutri_cache_$userPrefix$safeKey.json');
  }

  /// Guarda una respuesta en caché local con marca de tiempo
  Future<void> guardar(String clave, dynamic datos, {String? userId}) async {
    try {
      final file = await _getFile(clave, userId);
      final cacheEnvelope = {
        'guardado_en': DateTime.now().toIso8601String(),
        'clave': clave,
        'usuario_id': userId,
        'datos': datos,
      };
      await file.writeAsString(jsonEncode(cacheEnvelope), flush: true);
    } catch (e) {
      debugPrint('[CacheLocalService] Error al guardar caché ($clave): $e');
    }
  }

  /// Obtiene los datos en caché si existen y no han expirado
  Future<dynamic> obtener(String clave, {String? userId, Duration? duracionValidez}) async {
    try {
      final file = await _getFile(clave, userId);
      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString();
      if (content.isEmpty) return null;

      final Map<String, dynamic> envelope = jsonDecode(content);
      if (duracionValidez != null && envelope.containsKey('guardado_en')) {
        final guardadoEn = DateTime.parse(envelope['guardado_en'] as String);
        if (DateTime.now().difference(guardadoEn) > duracionValidez) {
          // Ha expirado la validez
          return null;
        }
      }

      return envelope['datos'];
    } catch (e) {
      debugPrint('[CacheLocalService] Error al leer caché ($clave): $e');
      return null;
    }
  }

  /// Elimina los archivos de caché correspondientes a un usuario (usado en Logout)
  Future<void> limpiarCacheUsuario(String userId) async {
    try {
      final dir = await _getDir();
      final prefix = 'nutri_cache_u_${_sanitizeKey(userId)}_';
      final files = dir.listSync();
      for (final entity in files) {
        if (entity is File && entity.path.contains(prefix)) {
          await entity.delete();
        }
      }
    } catch (e) {
      debugPrint('[CacheLocalService] Error al limpiar caché de usuario: $e');
    }
  }

  /// Limpia todo el caché de la aplicación
  Future<void> limpiarTodo() async {
    try {
      final dir = await _getDir();
      final files = dir.listSync();
      for (final entity in files) {
        if (entity is File && entity.path.contains('nutri_cache_')) {
          await entity.delete();
        }
      }
    } catch (e) {
      debugPrint('[CacheLocalService] Error al limpiar todo el caché: $e');
    }
  }
}
