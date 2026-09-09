class RecipeModel {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final num calories;
  final num protein;
  final num carbohydrates;
  final num fats;
  final num fiber;
  final num? sodium;
  final int servings;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final String difficulty;
  final String category;
  final String ingredients;
  final String instructions;

  RecipeModel({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fats,
    required this.fiber,
    this.sodium,
    required this.servings,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.difficulty,
    required this.category,
    required this.ingredients,
    required this.instructions,
  });

  factory RecipeModel.fromJson(Map<String, dynamic> json) {
    return RecipeModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      imageUrl: json['image_url']?.toString(),
      calories: json['calories'] ?? 0,
      protein: json['protein'] ?? 0,
      carbohydrates: json['carbohydrates'] ?? 0,
      fats: json['fats'] ?? 0,
      fiber: json['fiber'] ?? 0,
      sodium: json['sodium'],
      servings: json['servings'] ?? 1,
      prepTimeMinutes: json['prep_time_minutes'] ?? 0,
      cookTimeMinutes: json['cook_time_minutes'] ?? 0,
      difficulty: json['difficulty']?.toString() ?? 'Fácil',
      category: json['category']?.toString() ?? 'Plato',
      ingredients: json['ingredients']?.toString() ?? '',
      instructions: json['instructions']?.toString() ?? '',
    );
  }
}
