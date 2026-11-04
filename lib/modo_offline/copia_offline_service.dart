import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

/// A successful timestamp means every required resource was downloaded online.
class CopiaOfflineService extends ChangeNotifier {
  final ApiService api;
  String? _owner;
  int _generation = 0;
  bool copiando = false;
  DateTime? ultimaCopia;
  String? error;
  CopiaOfflineService(this.api);

  Future<void> bindUser(String? userId) async {
    final generation = ++_generation;
    _owner = userId;
    ultimaCopia = null;
    copiando = false;
    error = null;
    notifyListeners();
    if (userId == null) return;
    final saved = await api.cacheService?.obtener(
      'offline_copy',
      userId: userId,
      duracionValidez: const Duration(days: 3650),
    );
    if (generation != _generation) return;
    ultimaCopia = DateTime.tryParse(saved?.toString() ?? '');
    notifyListeners();
    if (api.conectividadService?.estaConectado != false) await copiar();
  }

  Future<void> copiar() async {
    final owner = _owner;
    final generation = _generation;
    if (owner == null || owner != api.currentUserId || copiando) return;
    if (api.conectividadService?.estaConectado == false) {
      error = 'Conéctate a internet para actualizar la copia.';
      notifyListeners();
      return;
    }
    copiando = true;
    error = null;
    notifyListeners();
    try {
      for (final endpoint in const [
        '/users/me',
        '/appointments',
        '/appointments/nutritionists',
        '/clinical/anamnesis/me',
        '/plans/my-plan',
        '/recipes/my-plan',
        '/food/history',
      ]) {
        if (generation != _generation || owner != api.currentUserId) return;
        try {
          await api.get(endpoint, forceRefresh: true);
        } on ApiException catch (e) {
          if (e.statusCode != 404 || endpoint != '/clinical/anamnesis/me') {
            rethrow;
          }
          await api.cacheService?.guardar(endpoint, null, userId: owner);
        }
      }
      if (generation != _generation || owner != api.currentUserId) return;
      final now = DateTime.now();
      await api.cacheService?.guardar(
        'offline_copy',
        now.toIso8601String(),
        userId: owner,
      );
      ultimaCopia = now;
    } catch (_) {
      if (generation == _generation) error = 'Copia incompleta. Se conserva lo descargado; vuelve a intentarlo con internet.';
    } finally {
      if (generation == _generation) {
        copiando = false;
        notifyListeners();
      }
    }
  }
}
