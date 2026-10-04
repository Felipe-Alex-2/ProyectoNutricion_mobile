import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'storage_service.dart';

import '../modo_offline/cache_local_service.dart';
import '../modo_offline/conectividad_service.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, {this.statusCode = 500});

  @override
  String toString() => message;
}

class ApiService {
  final StorageService _storageService;
  CacheLocalService? cacheService;
  ConectividadService? conectividadService;
  String? currentUserId;

  ApiService(
    this._storageService, {
    this.cacheService,
    this.conectividadService,
  });

  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await _storageService.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<dynamic> get(String endpoint, {bool includeAuth = true, bool usarCache = true}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders(includeAuth: includeAuth);

    // Si no hay conexión y el caché está disponible, consultar primero el caché local
    if (conectividadService != null && !conectividadService!.estaConectado && usarCache && cacheService != null) {
      final cached = await cacheService!.obtener(endpoint, userId: currentUserId);
      if (cached != null) {
        debugPrint('[ApiService] Sin conexión: Sirviendo desde caché para $endpoint');
        return cached;
      }
    }

    try {
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 12));
      final data = _processResponse(response);

      // Guardar en caché local si la respuesta fue exitosa
      if (usarCache && cacheService != null && data != null) {
        await cacheService!.guardar(endpoint, data, userId: currentUserId);
      }
      return data;
    } catch (e) {
      if (e is ApiException) rethrow;

      // Error de red/conectividad
      conectividadService?.marcarDesconectadoPorErrorHttp();

      // Fallback a caché local
      if (usarCache && cacheService != null) {
        final cached = await cacheService!.obtener(endpoint, userId: currentUserId);
        if (cached != null) {
          debugPrint('[ApiService] Fallback exitoso a caché offline para $endpoint');
          return cached;
        }
      }

      throw ApiException('Error de conexión con el servidor ($e)');
    }
  }

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    if (conectividadService != null && !conectividadService!.estaConectado) {
      throw ApiException('Error: estás sin conexión a internet', statusCode: 0);
    }

    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders(includeAuth: includeAuth);

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      conectividadService?.marcarDesconectadoPorErrorHttp();
      throw ApiException('Error: estás sin conexión a internet', statusCode: 0);
    }
  }

  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    if (conectividadService != null && !conectividadService!.estaConectado) {
      throw ApiException('Error: estás sin conexión a internet', statusCode: 0);
    }

    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders(includeAuth: includeAuth);

    try {
      final response = await http.put(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      conectividadService?.marcarDesconectadoPorErrorHttp();
      throw ApiException('Error: estás sin conexión a internet', statusCode: 0);
    }
  }

  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    if (conectividadService != null && !conectividadService!.estaConectado) {
      throw ApiException('Error: estás sin conexión a internet', statusCode: 0);
    }

    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders(includeAuth: includeAuth);

    try {
      final response = await http.patch(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      conectividadService?.marcarDesconectadoPorErrorHttp();
      throw ApiException('Error: estás sin conexión a internet', statusCode: 0);
    }
  }

  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    if (conectividadService != null && !conectividadService!.estaConectado) {
      throw ApiException('Error: estás sin conexión a internet', statusCode: 0);
    }

    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders(includeAuth: includeAuth);

    try {
      final response = await http.delete(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      conectividadService?.marcarDesconectadoPorErrorHttp();
      throw ApiException('Error: estás sin conexión a internet', statusCode: 0);
    }
  }

  Future<dynamic> postMultipart(
    String endpoint, {
    required List<int> fileBytes,
    required String filename,
    String fieldName = 'file',
    bool includeAuth = true,
  }) async {
    if (conectividadService != null && !conectividadService!.estaConectado) {
      throw ApiException('Error: estás sin conexión a internet', statusCode: 0);
    }

    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final request = http.MultipartRequest('POST', url);

    if (includeAuth) {
      final token = await _storageService.getAccessToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }
    request.headers['Accept'] = 'application/json';

    request.files.add(
      http.MultipartFile.fromBytes(
        fieldName,
        fileBytes,
        filename: filename,
      ),
    );

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      conectividadService?.marcarDesconectadoPorErrorHttp();
      throw ApiException('Error: estás sin conexión a internet', statusCode: 0);
    }
  }

  dynamic _processResponse(http.Response response) {
    dynamic decodedBody;
    try {
      decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decodedBody = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    }

    String errorMessage = 'Ocurrió un error inesperado';
    if (decodedBody is Map) {
      if (decodedBody.containsKey('detail')) {
        final detail = decodedBody['detail'];
        if (detail is String) {
          errorMessage = detail;
        } else if (detail is List && detail.isNotEmpty) {
          errorMessage = detail[0]['msg'] ?? 'Error de validación';
        }
      } else if (decodedBody.containsKey('message')) {
        errorMessage = decodedBody['message'];
      }
    }

    if (response.statusCode == 401 && errorMessage.toLowerCase().contains('invalid or expired token')) {
      errorMessage = 'Error: sesión expirada. Inicia sesión nuevamente.';
    }

    throw ApiException(errorMessage, statusCode: response.statusCode);
  }
}
