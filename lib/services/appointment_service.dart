import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart';
import 'api_service.dart';

class AppointmentService extends ChangeNotifier {
  final ApiService _apiService;

  List<AppointmentModel> _appointments = [];
  List<NutritionistItem> _nutritionists = [];
  bool _isLoading = false;
  String? _errorMessage;

  AppointmentService(this._apiService);

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
      _isLoading = false;
      notifyListeners();
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
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = {
        'nutritionist_id': nutritionistId,
        'scheduled_at': scheduledAt.toIso8601String(),
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
      };

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
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
