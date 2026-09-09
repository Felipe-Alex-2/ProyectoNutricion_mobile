import 'package:flutter/foundation.dart';
import '../models/recipe_model.dart';
import 'api_service.dart';

class RecipeService extends ChangeNotifier {
  final ApiService _apiService;

  List<RecipeModel> _myPlanRecipes = [];
  bool _isLoading = false;
  String? _errorMessage;

  RecipeService(this._apiService);

  List<RecipeModel> get myPlanRecipes => _myPlanRecipes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchMyPlanRecipes() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/recipes/my-plan');
      if (response != null && response is List) {
        _myPlanRecipes = response
            .map((item) => RecipeModel.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        _myPlanRecipes = [];
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      _myPlanRecipes = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
