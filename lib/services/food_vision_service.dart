import 'package:flutter/foundation.dart';
import 'api_service.dart';

class DetectedFoodItem {
  final String nombre;
  final double porcionG;
  final double calorias;
  final double carbohidratosG;
  final double proteinasG;
  final double grasasG;

  DetectedFoodItem({
    required this.nombre,
    required this.porcionG,
    required this.calorias,
    required this.carbohidratosG,
    required this.proteinasG,
    required this.grasasG,
  });

  factory DetectedFoodItem.fromJson(Map<String, dynamic> json) {
    return DetectedFoodItem(
      nombre: json['nombre'] as String? ?? 'Alimento',
      porcionG: (json['porcion_aprox_g'] as num?)?.toDouble() ?? 0.0,
      calorias: (json['calorias'] as num?)?.toDouble() ?? 0.0,
      carbohidratosG: (json['carbohidratos_g'] as num?)?.toDouble() ?? 0.0,
      proteinasG: (json['proteinas_g'] as num?)?.toDouble() ?? 0.0,
      grasasG: (json['grasas_g'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FoodAnalysisResult {
  final String? recordId;
  final List<DetectedFoodItem> alimentos;
  final double totalCalorias;
  final double totalCarbs;
  final double totalProteinas;
  final double totalGrasas;
  final String confianza;
  final String observaciones;
  final String? evalStatus;
  final String? evalMessage;
  final double? targetDailyKcal;
  final double? mealTargetKcal;

  FoodAnalysisResult({
    this.recordId,
    required this.alimentos,
    required this.totalCalorias,
    required this.totalCarbs,
    required this.totalProteinas,
    required this.totalGrasas,
    required this.confianza,
    required this.observaciones,
    this.evalStatus,
    this.evalMessage,
    this.targetDailyKcal,
    this.mealTargetKcal,
  });

  factory FoodAnalysisResult.fromJson(Map<String, dynamic> json) {
    final list = json['alimentos'] as List<dynamic>? ?? [];
    final total = json['total'] as Map<String, dynamic>? ?? {};
    final eval = json['evaluacion'] as Map<String, dynamic>?;

    return FoodAnalysisResult(
      recordId: json['record_id'] as String?,
      alimentos: list.map((a) => DetectedFoodItem.fromJson(a as Map<String, dynamic>)).toList(),
      totalCalorias: (total['calorias'] as num?)?.toDouble() ?? 0.0,
      totalCarbs: (total['carbohidratos_g'] as num?)?.toDouble() ?? 0.0,
      totalProteinas: (total['proteinas_g'] as num?)?.toDouble() ?? 0.0,
      totalGrasas: (total['grasas_g'] as num?)?.toDouble() ?? 0.0,
      confianza: json['confianza'] as String? ?? 'media',
      observaciones: json['observaciones'] as String? ?? '',
      evalStatus: eval?['status'] as String?,
      evalMessage: eval?['comparison_message'] as String?,
      targetDailyKcal: (eval?['daily_target_calories'] as num?)?.toDouble(),
      mealTargetKcal: (eval?['meal_recommended_calories'] as num?)?.toDouble(),
    );
  }
}

class FoodVisionService extends ChangeNotifier {
  final ApiService _apiService;

  bool _isAnalyzing = false;
  String? _errorMessage;
  FoodAnalysisResult? _lastAnalysis;
  final List<FoodAnalysisResult> _history = [];

  FoodVisionService(this._apiService);

  bool get isAnalyzing => _isAnalyzing;
  String? get errorMessage => _errorMessage;
  FoodAnalysisResult? get lastAnalysis => _lastAnalysis;
  List<FoodAnalysisResult> get history => _history;

  Future<FoodAnalysisResult?> analyzeImage(Uint8List imageBytes, String filename) async {
    _isAnalyzing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.postMultipart(
        '/food/analyze',
        fileBytes: imageBytes,
        filename: filename,
      );

      if (response != null && response is Map<String, dynamic>) {
        _lastAnalysis = FoodAnalysisResult.fromJson(response);
        _isAnalyzing = false;
        notifyListeners();
        return _lastAnalysis;
      }
      throw Exception('Formato de respuesta inválido del servidor');
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      _isAnalyzing = false;
      notifyListeners();
      return null;
    }
  }

  void clearLastAnalysis() {
    _lastAnalysis = null;
    _errorMessage = null;
    notifyListeners();
  }
}
