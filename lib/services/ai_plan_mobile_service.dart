import 'package:flutter/foundation.dart';
import 'api_service.dart';

class WeeklyDayMeal {
  final String mealName;
  final String? timeSuggestion;
  final double totalCalories;
  final List<String> foods;

  WeeklyDayMeal({
    required this.mealName,
    this.timeSuggestion,
    required this.totalCalories,
    required this.foods,
  });

  factory WeeklyDayMeal.fromJson(Map<String, dynamic> json) {
    final foodList = json['foods'] as List<dynamic>? ?? [];
    return WeeklyDayMeal(
      mealName: json['meal_name'] as String? ?? 'Comida',
      timeSuggestion: json['time_suggestion'] as String?,
      totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0.0,
      foods: foodList.map((f) => '${f['name'] ?? ''} (${f['portion'] ?? ''})').toList(),
    );
  }
}

class WeeklyDayMenu {
  final String day;
  final double dailyCalories;
  final List<WeeklyDayMeal> meals;

  WeeklyDayMenu({
    required this.day,
    required this.dailyCalories,
    required this.meals,
  });

  factory WeeklyDayMenu.fromJson(Map<String, dynamic> json) {
    final mealList = json['meals'] as List<dynamic>? ?? [];
    return WeeklyDayMenu(
      day: json['day'] as String? ?? 'Día',
      dailyCalories: (json['daily_calories'] as num?)?.toDouble() ?? 0.0,
      meals: mealList.map((m) => WeeklyDayMeal.fromJson(m as Map<String, dynamic>)).toList(),
    );
  }
}

class AIPlanMobileService extends ChangeNotifier {
  final ApiService _apiService;

  Map<String, dynamic>? _activePlan;
  List<WeeklyDayMenu> _weeklyMenu = [];
  bool _isLoading = false;
  String? _errorMessage;

  AIPlanMobileService(this._apiService);

  Map<String, dynamic>? get activePlan => _activePlan;
  List<WeeklyDayMenu> get weeklyMenu => _weeklyMenu;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchMyPlan() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/plans/my-plan');
      if (response != null && response is Map<String, dynamic>) {
        _activePlan = response;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> generateWeeklyMenu(String patientId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        '/menu-semanal/generate',
        body: {'patient_id': patientId},
      );

      if (response != null && response is Map<String, dynamic>) {
        final days = response['days'] as List<dynamic>? ?? [];
        _weeklyMenu = days.map((d) => WeeklyDayMenu.fromJson(d as Map<String, dynamic>)).toList();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      throw Exception('Respuesta inesperada al generar menú');
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchCurrentWeeklyMenu() async {
    try {
      final response = await _apiService.get('/menu-semanal/current');
      if (response != null && response is Map<String, dynamic>) {
        final days = response['days'] as List<dynamic>? ?? [];
        _weeklyMenu = days.map((d) => WeeklyDayMenu.fromJson(d as Map<String, dynamic>)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }
}
