import 'package:flutter/foundation.dart';
import '../models/patient_link.dart';
import 'api_service.dart';

class PatientService extends ChangeNotifier {
  final ApiService _apiService;

  PatientNutritionistLink? _linkedNutritionist;
  bool _isLoading = false;
  String? _errorMessage;

  PatientService(this._apiService);

  PatientNutritionistLink? get linkedNutritionist => _linkedNutritionist;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasNutritionist => _linkedNutritionist != null;

  Future<void> fetchMyNutritionist() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/patient-links/my-nutritionist');
      if (response != null && response is Map<String, dynamic>) {
        _linkedNutritionist = PatientNutritionistLink.fromJson(response);
      } else {
        _linkedNutritionist = null;
      }
    } catch (e) {
      // If 404 or empty, not linked
      _linkedNutritionist = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> claimLink(String pairingCode) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        '/patient-links/claim',
        body: {'pairing_code': pairingCode.trim().toUpperCase()},
      );

      if (response != null && response is Map<String, dynamic>) {
        _linkedNutritionist = PatientNutritionistLink.fromJson(response);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      throw Exception('Respuesta inválida del servidor');
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
