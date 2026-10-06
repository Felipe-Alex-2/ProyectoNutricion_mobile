import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/branch_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

import '../modo_offline/cache_local_service.dart';
import '../modo_offline/cola_sincronizacion_service.dart';
import '../modo_offline/elemento_cola.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, authenticating }

class AuthService extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storageService;
  final CacheLocalService? cacheService;
  final ColaSincronizacionService? colaService;

  User? _currentUser;
  AuthStatus _status = AuthStatus.uninitialized;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get errorMessage => _errorMessage;

  AuthService(
    this._apiService,
    this._storageService, {
    this.cacheService,
    this.colaService,
  }) {
    _initialize();
  }

  Future<void> _initialize() async {
    final hasToken = await _storageService.hasToken();
    if (!hasToken) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      final data = await _apiService.get('/users/me');
      _currentUser = User.fromJson(data);
      _apiService.currentUserId = _currentUser?.id;
      await cacheService?.guardar('/users/me', data, userId: _currentUser?.id);
      _status = AuthStatus.authenticated;
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) {
        await _storageService.clearTokens();
        _currentUser = null;
        _status = AuthStatus.unauthenticated;
      } else {
        // Modo offline: leer el perfil desde el almacenamiento local
        final cached = await cacheService?.obtener('/users/me');
        if (cached != null) {
          _currentUser = User.fromJson(cached);
          _apiService.currentUserId = _currentUser?.id;
          _status = AuthStatus.authenticated;
        } else {
          _status = AuthStatus.unauthenticated;
        }
      }
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        '/auth/login',
        body: {'email': email.trim(), 'password': password},
        includeAuth: false,
      );

      final accessToken = response['access_token'] as String;
      final refreshToken = response['refresh_token'] as String;
      _currentUser = User.fromJson(response['user']);
      _apiService.currentUserId = _currentUser?.id;

      await _storageService.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      await cacheService?.guardar('/users/me', response['user'], userId: _currentUser?.id);

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<List<Branch>> fetchPublicBranches() async {
    try {
      final res = await _apiService.get('/tenants/public', includeAuth: false);
      if (res is List) {
        return res
            .map((item) => Branch.fromJson(item as Map<String, dynamic>))
            .where((b) => b.isActive)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> register(
    String email,
    String password,
    String fullName, {
    String? tenantId,
  }) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'full_name': fullName.trim(),
        'client_platform': 'mobile',
      };
      if (tenantId != null && tenantId.isNotEmpty) {
        body['tenant_id'] = tenantId;
      }

      await _apiService.post(
        '/auth/register',
        body: body,
        includeAuth: false,
      );

      // Auto login after registration
      return await login(email, password);
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({String? fullName, String? email}) async {
    try {
      final body = <String, dynamic>{};
      if (fullName != null) body['full_name'] = fullName;
      if (email != null) body['email'] = email;

      final uid = _currentUser?.id ?? '';

      // Si no hay conexión o falla la red, guardar en cola offline y actualizar local
      try {
        final response = await _apiService.put('/users/me', body: body);
        _currentUser = User.fromJson(response);
        await cacheService?.guardar('/users/me', response, userId: uid);
      } catch (e) {
        final cola = colaService;
        final user = _currentUser;
        if (cola != null && user != null) {
          final elemento = ElementoCola(
            id: 'offline_profile_${DateTime.now().millisecondsSinceEpoch}',
            userId: uid,
            metodo: 'PUT',
            endpoint: '/users/me',
            tipoAccion: 'ACTUALIZAR_PERFIL',
            descripcionHumana: 'Actualizar perfil de usuario',
            cuerpo: body,
            fechaCreacion: DateTime.now(),
          );
          await cola.encolar(elemento);

          // Actualizar modelo en memoria
          final updatedJson = user.toJson();
          if (fullName != null) updatedJson['full_name'] = fullName;
          if (email != null) updatedJson['email'] = email;
          _currentUser = User.fromJson(updatedJson);
          await cacheService?.guardar('/users/me', updatedJson, userId: uid);
        } else {
          rethrow;
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.post(
        '/auth/forgot-password',
        body: {'email': email.trim()},
        includeAuth: false,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.post(
        '/auth/reset-password',
        body: {
          'token': token.trim(),
          'new_password': newPassword,
        },
        includeAuth: false,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final uid = _currentUser?.id;
    try {
      await _apiService.delete('/activity-logs');
      await _apiService.post('/auth/logout?client_platform=mobile&clear_logs=true');
    } catch (_) {}

    if (uid != null) {
      await cacheService?.limpiarCacheUsuario(uid);
      await colaService?.limpiarColaUsuario(uid);
      await _storageService.clearLocalSubscription(userId: uid);
    }
    await _storageService.clearTokens();
    _currentUser = null;
    _apiService.currentUserId = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
