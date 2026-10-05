import 'package:flutter/foundation.dart';
import '../models/anamnesis_model.dart';
import 'api_service.dart';
import '../modo_offline/cache_local_service.dart';
import '../modo_offline/cola_sincronizacion_service.dart';
import '../modo_offline/conectividad_service.dart';
import '../modo_offline/elemento_cola.dart';

class AnamnesisService extends ChangeNotifier {
  final ApiService _apiService;
  final ColaSincronizacionService? colaService;
  final ConectividadService? conectividadService;
  final CacheLocalService? cacheService;
  String? currentUserId;

  PatientAnamnesisModel? _anamnesis;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;
  bool _isSavedOffline = false;

  AnamnesisService(
    this._apiService, {
    this.colaService,
    this.conectividadService,
    this.cacheService,
    this.currentUserId,
  });

  String? get effectiveUserId => currentUserId ?? _apiService.currentUserId;

  PatientAnamnesisModel? get anamnesis => _anamnesis;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSuccess => _isSuccess;
  bool get isSavedOffline => _isSavedOffline;
  bool get hasCompletedAnamnesis => _anamnesis != null;

  Future<void> fetchMyAnamnesis() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final userId = effectiveUserId;

    // 1. Si estamos offline o para disponibilidad inmediata, leer de cache local
    if (cacheService != null) {
      final cached = await cacheService!.obtener('/clinical/anamnesis/me', userId: userId);
      if (cached != null && cached is Map<String, dynamic>) {
        _anamnesis = PatientAnamnesisModel.fromJson(cached);
        if (conectividadService != null && !conectividadService!.estaConectado) {
          _isLoading = false;
          notifyListeners();
          return;
        }
      }
    }

    try {
      final response = await _apiService.get('/clinical/anamnesis/me');
      if (response != null && response is Map<String, dynamic>) {
        _anamnesis = PatientAnamnesisModel.fromJson(response);
        if (cacheService != null) {
          await cacheService!.guardar('/clinical/anamnesis/me', response, userId: userId);
        }
      } else {
        _anamnesis = null;
      }
    } catch (e) {
      // Fallback a cache local si la red falla
      if (_anamnesis == null && cacheService != null) {
        final cached = await cacheService!.obtener('/clinical/anamnesis/me', userId: userId);
        if (cached != null && cached is Map<String, dynamic>) {
          _anamnesis = PatientAnamnesisModel.fromJson(cached);
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveMyAnamnesis(PatientAnamnesisModel model) async {
    _isLoading = true;
    _errorMessage = null;
    _isSuccess = false;
    _isSavedOffline = false;
    notifyListeners();

    final userId = effectiveUserId;
    final bool estaOffline = conectividadService != null && !conectividadService!.estaConectado;

    if (estaOffline) {
      return await _guardarAnamnesisOffline(model);
    }

    try {
      final response = await _apiService.post(
        '/clinical/anamnesis/me',
        body: model.toJson(),
      );

      if (response != null && response is Map<String, dynamic>) {
        _anamnesis = PatientAnamnesisModel.fromJson(response);
        _isSuccess = true;
        _isSavedOffline = false;
        _isLoading = false;

        // Guardar en cache local
        if (cacheService != null) {
          await cacheService!.guardar('/clinical/anamnesis/me', response, userId: userId);
        }

        // Si habia un elemento pendiente en cola, descartarlo porque ya se guardo online
        if (colaService != null) {
          final pendientesPrevios = colaService!.elementos
              .where((e) => e.tipoAccion == 'ACTUALIZAR_FICHA_MEDICA' && e.estaPendiente)
              .toList();
          for (final prev in pendientesPrevios) {
            await colaService!.remover(prev.id, userId: userId);
          }
        }

        notifyListeners();
        return true;
      }
      throw Exception('Respuesta inesperada al guardar la ficha de salud');
    } catch (e) {
      final errorStr = e.toString().toLowerCase();

      // Si fue error de red/conexion, encolar offline automaticamente en vez de fallar
      if (errorStr.contains('conexión') ||
          errorStr.contains('conexion') ||
          errorStr.contains('socket') ||
          errorStr.contains('failed host lookup') ||
          errorStr.contains('sin conexión') ||
          errorStr.contains('sin conexion') ||
          errorStr.contains('timeout')) {
        return await _guardarAnamnesisOffline(model);
      }

      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _guardarAnamnesisOffline(PatientAnamnesisModel model) async {
    _anamnesis = model;
    final userId = effectiveUserId;

    // 1. Guardar en cache local para persistencia instantanea en el telefono
    if (cacheService != null) {
      await cacheService!.guardar('/clinical/anamnesis/me', model.toJson(), userId: userId);
    }

    // 2. Encolar en la cola de sincronizacion offline FIFO
    if (colaService != null) {
      // Si ya existia un elemento previo de ficha en la cola, removerlo para no duplicar peticiones
      final pendientesPrevios = colaService!.elementos
          .where((e) => e.tipoAccion == 'ACTUALIZAR_FICHA_MEDICA' && e.estaPendiente)
          .toList();
      for (final prev in pendientesPrevios) {
        await colaService!.remover(prev.id, userId: userId);
      }

      final elemento = ElementoCola(
        id: 'anamnesis_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId ?? '',
        metodo: 'POST',
        endpoint: '/clinical/anamnesis/me',
        cuerpo: model.toJson(),
        tipoAccion: 'ACTUALIZAR_FICHA_MEDICA',
        descripcionHumana: 'Actualizacion de Ficha de Salud Medica',
        fechaCreacion: DateTime.now(),
      );

      await colaService!.encolar(elemento);
    }

    _isSuccess = true;
    _isSavedOffline = true;
    _isLoading = false;
    notifyListeners();
    return true;
  }
}

