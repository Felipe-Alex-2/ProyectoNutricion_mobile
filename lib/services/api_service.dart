import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';

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
  final http.Client _client;
  CacheLocalService? cacheService;
  ConectividadService? conectividadService;
  String? currentUserId;
  Future<bool>? _refreshing;
  static const _timeout = Duration(seconds: 70);
  ApiService(
    this._storageService, {
    this.cacheService,
    this.conectividadService,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri _url(String endpoint) => Uri.parse('${ApiConfig.baseUrl}$endpoint');
  Future<Map<String, String>> _headers(bool auth) async {
    final token = auth ? await _storageService.getAccessToken() : null;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<bool> _refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  Future<bool> _doRefresh() async {
    final refreshToken = await _storageService.getRefreshToken();
    if (refreshToken == null) return false;
    final response = await _client
        .post(
          _url('/auth/refresh'),
          headers: await _headers(false),
          body: jsonEncode({'refresh_token': refreshToken}),
        )
        .timeout(_timeout);
    if (await _storageService.getRefreshToken() != refreshToken) return false;
    if (response.statusCode == 401) {
      await _storageService.clearTokens();
      return false;
    }
    final data = _processResponse(response) as Map<String, dynamic>;
    await _storageService.saveTokens(
      accessToken: data['access_token'],
      refreshToken: data['refresh_token'],
    );
    return true;
  }

  Future<dynamic> _send(
    Future<http.Response> Function(Map<String, String>) send,
    bool auth, {
    bool binary = false,
  }) async {
    final owner = currentUserId;
    try {
      final headers = await _headers(auth);
      var response = await send(headers).timeout(_timeout);
      if (auth && owner != currentUserId) {
        throw ApiException(
          "La cuenta cambió durante la solicitud.",
          statusCode: 401,
        );
      }
      if (auth && response.statusCode == 401) {
        final latest = await _storageService.getAccessToken();
        final changed =
            latest != null && headers['Authorization'] != 'Bearer $latest';
        if (changed || await _refresh()) {
          if (owner != currentUserId) {
            throw ApiException(
              "La cuenta cambió durante la solicitud.",
              statusCode: 401,
            );
          }
          response = await send(await _headers(auth)).timeout(_timeout);
        }
      }
      if (auth && owner != currentUserId) {
        throw ApiException(
          "La cuenta cambió durante la solicitud.",
          statusCode: 401,
        );
      }
      if (binary && response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      return _processResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'El servidor tardó demasiado en responder.',
        statusCode: 0,
      );
    } on http.ClientException {
      conectividadService?.marcarDesconectadoPorErrorHttp();
      throw ApiException('Error de conexión con el servidor.', statusCode: 0);
    }
  }

  Future<Uint8List> getBytes(String endpoint) async {
    return await _send(
      (headers) => _client.get(_url(endpoint), headers: headers),
      true,
      binary: true,
    ) as Uint8List;
  }

  Future<dynamic> get(
    String endpoint, {
    bool includeAuth = true,
    bool usarCache = true,
  }) async {
    final owner = currentUserId;
    final cacheAllowed =
        usarCache &&
        (!includeAuth || owner != null) &&
        !endpoint.startsWith('/subscriptions/');
    try {
      if (conectividadService?.estaConectado == false && cacheAllowed) {
        final cached = await cacheService?.obtener(
          endpoint,
          userId: owner,
          duracionValidez: _nutritionCacheAge(endpoint),
        );
        if (owner != currentUserId) {
          throw ApiException(
            'La cuenta cambió durante la consulta.',
            statusCode: 401,
          );
        }
        if (cached != null) return cached;
        throw ApiException(
          'Sin conexión. Abre esta sección con internet para descargar su información.',
          statusCode: 0,
        );
      }
      final result = await _send(
        (headers) => _client.get(_url(endpoint), headers: headers),
        includeAuth,
      );
      if (cacheAllowed && owner == currentUserId) {
        await cacheService?.guardar(endpoint, result, userId: owner);
      }
      return result;
    } on ApiException catch (error) {
      if (error.statusCode == 0 && cacheAllowed) {
        final cached = await cacheService?.obtener(
          endpoint,
          userId: owner,
          duracionValidez: _nutritionCacheAge(endpoint),
        );
        if (cached != null && owner == currentUserId) return cached;
      }
      rethrow;
    }
  }

  Duration? _nutritionCacheAge(String endpoint) =>
      endpoint == '/plans/my-plan' || endpoint == '/food/history'
      ? const Duration(days: 30)
      : null;

  Future<dynamic> _write(
    String method,
    String endpoint,
    Map<String, dynamic>? body,
    bool auth, {
    String? idempotencyKey,
  }) {
    return _send((headers) {
      final data = body == null ? null : jsonEncode(body);
      if (idempotencyKey != null) headers['Idempotency-Key'] = idempotencyKey;
      final url = _url(endpoint);
      return switch (method) {
        'POST' => _client.post(url, headers: headers, body: data),
        'PUT' => _client.put(url, headers: headers, body: data),
        'PATCH' => _client.patch(url, headers: headers, body: data),
        _ => _client.delete(url, headers: headers, body: data),
      };
    }, auth);
  }

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
    String? idempotencyKey,
  }) => _write(
    'POST',
    endpoint,
    body,
    includeAuth,
    idempotencyKey: idempotencyKey,
  );
  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) => _write('PUT', endpoint, body, includeAuth);
  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) => _write('PATCH', endpoint, body, includeAuth);
  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) => _write('DELETE', endpoint, body, includeAuth);

  Future<dynamic> postMultipart(
    String endpoint, {
    required List<int> fileBytes,
    required String filename,
    String fieldName = 'file',
    bool includeAuth = true,
  }) {
    return _send((headers) async {
      final request = http.MultipartRequest('POST', _url(endpoint));
      request.headers.addAll(headers..remove('Content-Type'));
      request.files.add(
        http.MultipartFile.fromBytes(fieldName, fileBytes, filename: filename),
      );
      final response = await _client.send(request).timeout(_timeout);
      return http.Response.fromStream(response).timeout(_timeout);
    }, includeAuth);
  }

  dynamic _processResponse(http.Response response) {
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    String message = 'No se pudo completar la solicitud.';
    if (data is Map) {
      final detail = data['detail'] ?? data['message'];
      if (detail is String) message = detail;
      if (detail is List && detail.isNotEmpty) {
        message = detail.first['msg']?.toString() ?? message;
      }
    }
    if (response.statusCode == 401) {
      message = 'Sesión expirada. Inicia sesión nuevamente.';
    }
    throw ApiException(message, statusCode: response.statusCode);
  }

  void dispose() => _client.close();
}
