import 'package:flutter/foundation.dart';
import '../models/anamnesis_model.dart';
import 'api_service.dart';

class AnamnesisService extends ChangeNotifier {
  final ApiService _apiService;

  PatientAnamnesisModel? _anamnesis;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  AnamnesisService(this._apiService);

  PatientAnamnesisModel? get anamnesis => _anamnesis;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSuccess => _isSuccess;
  bool get hasCompletedAnamnesis => _anamnesis != null;

  Future<void> fetchMyAnamnesis() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/clinical/anamnesis/me');
      if (response != null && response is Map<String, dynamic>) {
        _anamnesis = PatientAnamnesisModel.fromJson(response);
      } else {
        _anamnesis = null;
      }
    } catch (e) {
      _anamnesis = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveMyAnamnesis(PatientAnamnesisModel model) async {
    _isLoading = true;
    _errorMessage = null;
    _isSuccess = false;
    notifyListeners();

    try {
      final response = await _apiService.post(
        '/clinical/anamnesis/me',
        body: model.toJson(),
      );

      if (response != null && response is Map<String, dynamic>) {
        _anamnesis = PatientAnamnesisModel.fromJson(response);
        _isSuccess = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      throw Exception('Respuesta inesperada al guardar la anamnesis');
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
