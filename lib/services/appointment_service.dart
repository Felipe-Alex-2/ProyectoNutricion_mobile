import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart';
import '../modo_offline/cola_sincronizacion_service.dart';
import '../modo_offline/conectividad_service.dart';
import '../modo_offline/elemento_cola.dart';
import 'api_service.dart';

class AppointmentService extends ChangeNotifier {
  final ApiService _apiService;
  ColaSincronizacionService? colaService;
  ConectividadService? conectividadService;
  String? currentUserId;

  List<AppointmentModel> _appointments = [];
  List<NutritionistItem> _nutritionists = [];
  bool _isLoading = false;
  String? _errorMessage;

  AppointmentService(
    this._apiService, {
    this.colaService,
    this.conectividadService,
  });

  List<AppointmentModel> get appointments => _appointments;
  List<NutritionistItem> get nutritionists => _nutritionists;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchAppointments({String? status}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String endpoint = '/appointments';
      if (status != null && status.isNotEmpty && status != 'ALL') {
        endpoint += '?status=$status';
      }

      final response = await _apiService.get(endpoint);
      if (response is List) {
        _appointments = response
            .map((item) => AppointmentModel.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        _appointments = [];
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
    } finally {
      // Incorporar citas pendientes o con conflicto encoladas localmente
      _incorporarCitasEnCola();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _incorporarCitasEnCola() {
    if (colaService == null) return;
    final citasEnCola = colaService!.elementos.where((e) => e.esCita).toList();
    for (final item in citasEnCola) {
      final index = _appointments.indexWhere((a) => a.id == item.id);
      final scheduledIso = item.cuerpo?['scheduled_at'] as String? ?? DateTime.now().toIso8601String();
      final localAppt = AppointmentModel(
        id: item.id,
        patientId: item.userId,
        nutritionistId: item.cuerpo?['nutritionist_id'] as String? ?? '',
        nutritionistName: item.metadata?['nutritionist_name'] as String? ?? 'Especialista Nutricional',
        scheduledAt: DateTime.parse(scheduledIso),
        reason: item.cuerpo?['reason'] as String?,
        status: item.tieneErrorConflicto ? 'ERROR_CONFLICTO' : 'PENDIENTE_OFFLINE',
        cancellationReason: item.mensajeError,
        createdAt: item.fechaCreacion,
        updatedAt: item.fechaCreacion,
      );

      if (index != -1) {
        _appointments[index] = localAppt;
      } else {
        _appointments.insert(0, localAppt);
      }
    }
  }

  Future<void> fetchNutritionists({String? tenantId}) async {
    try {
      String endpoint = '/appointments/nutritionists';
      if (tenantId != null && tenantId.isNotEmpty) {
        endpoint += '?tenant_id=$tenantId';
      }

      final response = await _apiService.get(endpoint);
      if (response is List) {
        _nutritionists = response
            .map((item) => NutritionistItem.fromJson(item as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching nutritionists: $e');
    }
  }

  Future<bool> bookAppointment({
    required String nutritionistId,
    required DateTime scheduledAt,
    String? reason,
    String? tenantId,
    String? nutritionistName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final body = {
      'nutritionist_id': nutritionistId,
      'scheduled_at': scheduledAt.toIso8601String(),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
    };

    final bool estaOffline = conectividadService != null && !conectividadService!.estaConectado;

    if (estaOffline) {
      return await _encolarCitaOffline(
        nutritionistId: nutritionistId,
        nutritionistName: nutritionistName,
        scheduledAt: scheduledAt,
        body: body,
      );
    }

    try {
      final response = await _apiService.post('/appointments', body: body);
      if (response != null && response is Map<String, dynamic>) {
        final newAppt = AppointmentModel.fromJson(response);
        _appointments.insert(0, newAppt);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      throw Exception('Respuesta inesperada del servidor');
    } catch (e) {
      final errorStr = e.toString().toLowerCase();

      // Si el servidor indica conflicto (horario ocupado)
      if (errorStr.contains('ya tiene una cita') ||
          errorStr.contains('conflicto') ||
          errorStr.contains('solapamiento') ||
          (e is ApiException && e.statusCode == 400)) {
        _errorMessage = 'El especialista ya tiene una cita agendada en ese horario. Por favor selecciona otro horario.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Si es error de conectividad de red, guardar en cola offline
      if (colaService != null &&
          (errorStr.contains('conexión') ||
           errorStr.contains('socket') ||
           errorStr.contains('failed host lookup') ||
           errorStr.contains('timeout'))) {
        conectividadService?.marcarDesconectadoPorErrorHttp();
        return await _encolarCitaOffline(
          nutritionistId: nutritionistId,
          nutritionistName: nutritionistName,
          scheduledAt: scheduledAt,
          body: body,
        );
      }

      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _encolarCitaOffline({
    required String nutritionistId,
    String? nutritionistName,
    required DateTime scheduledAt,
    required Map<String, dynamic> body,
  }) async {
    final offlineId = 'offline_appt_${DateTime.now().millisecondsSinceEpoch}';
    final nombreEspecialista = nutritionistName ?? 'Especialista Nutricional';

    final elemento = ElementoCola(
      id: offlineId,
      userId: currentUserId ?? '',
      metodo: 'POST',
      endpoint: '/appointments',
      tipoAccion: 'CREAR_CITA',
      descripcionHumana: 'Cita con $nombreEspecialista el ${scheduledAt.day}/${scheduledAt.month} ${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}',
      cuerpo: body,
      fechaCreacion: DateTime.now(),
      metadata: {
        'nutritionist_name': nombreEspecialista,
      },
    );

    if (colaService != null) {
      await colaService!.encolar(elemento);
    }

    final localAppt = AppointmentModel(
      id: offlineId,
      patientId: currentUserId ?? '',
      nutritionistId: nutritionistId,
      nutritionistName: nombreEspecialista,
      scheduledAt: scheduledAt,
      reason: body['reason'] as String?,
      status: 'PENDIENTE_OFFLINE',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _appointments.insert(0, localAppt);
    _isLoading = false;
    notifyListeners();
    return true;
  }
}
