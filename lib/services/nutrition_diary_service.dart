import 'dart:math';

import '../modo_offline/cola_sincronizacion_service.dart';
import '../modo_offline/elemento_cola.dart';
import 'api_service.dart';

/// Meals are persisted before upload. The same UUID survives every retry.
class NutritionDiaryService {
  final ApiService api;
  final ColaSincronizacionService queue;
  NutritionDiaryService(this.api, this.queue);

  static String newId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> save({
    required String description,
    required String mealType,
    required DateTime consumedAt,
    double calories = 0,
    double protein = 0,
    double carbs = 0,
    double fats = 0,
  }) async {
    final user = api.currentUserId;
    if (user == null) {
      throw StateError('Inicia sesión para registrar tu alimentación.');
    }
    if (description.trim().isEmpty || description.trim().length > 500) {
      throw ArgumentError(
        'Describe tu comida usando entre 1 y 500 caracteres.',
      );
    }
    if (![
      'Desayuno',
      'Almuerzo',
      'Merienda',
      'Cena',
      'Snack',
    ].contains(mealType)) {
      throw ArgumentError('Selecciona un tipo de comida válido.');
    }
    for (final value in [calories, protein, carbs, fats]) {
      if (!value.isFinite || value < 0) {
        throw ArgumentError('Los valores nutricionales deben ser positivos.');
      }
    }
    if (calories > 10000 || [protein, carbs, fats].any((v) => v > 1000)) {
      throw ArgumentError('Revisa las cantidades nutricionales.');
    }
    final id = newId();
    await queue.encolar(
      ElementoCola(
        id: id,
        userId: user,
        metodo: 'POST',
        endpoint: '/food/records',
        tipoAccion: 'REGISTRAR_ALIMENTACION',
        descripcionHumana: '$mealType: ${description.trim()}',
        fechaCreacion: DateTime.now(),
        cuerpo: {
          'client_record_id': id,
          'description': description.trim(),
          'meal_type': mealType,
          'consumed_at': consumedAt.toUtc().toIso8601String(),
          'calories': calories,
          'protein_g': protein,
          'carbs_g': carbs,
          'fats_g': fats,
        },
      ),
    );
  }
}
