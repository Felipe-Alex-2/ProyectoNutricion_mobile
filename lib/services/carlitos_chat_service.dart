import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'storage_service.dart';
import 'offline_carlitos_service.dart';

class ChatMessageItem {
  final String id, role, content, source;
  final DateTime createdAt;
  ChatMessageItem({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.source = 'ONLINE',
  });
  factory ChatMessageItem.fromJson(Map<String, dynamic> json) =>
      ChatMessageItem(
        id: json['id'] as String? ?? UniqueKey().toString(),
        role: json['role'] as String? ?? 'assistant',
        content: json['content'] as String? ?? '',
        source: json['source'] as String? ?? 'ONLINE',
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'content': content,
    'source': source,
    'created_at': createdAt.toIso8601String(),
  };
}

class CarlitosChatService extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storage;
  final bool Function() _canUseOffline;
  final OfflineCarlitosService offline;
  List<ChatMessageItem> _messages = [];
  bool _isLoading = false, _pendingClear = false, _disposed = false;
  String? _errorMessage, _owner;
  int _generation = 0;
  Future<void>? _ownerLoad;
  CarlitosChatService(
    this._apiService, {
    StorageService? storage,
    OfflineCarlitosService? offline,
    bool Function()? canUseOffline,
  }) : _storage = storage ?? StorageService(),
       offline = offline ?? OfflineCarlitosService(),
       _canUseOffline = canUseOffline ?? (() => false) {
    this.offline.addListener(_notify);
  }
  List<ChatMessageItem> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get _connected =>
      _apiService.conectividadService?.estaConectado != false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _current(String owner, int generation) =>
      !_disposed &&
      generation == _generation &&
      owner == _apiService.currentUserId &&
      owner == _owner;
  Future<void> _ensureOwner() async {
    final user = _apiService.currentUserId;
    if (user == _owner) {
      await _ownerLoad;
      return;
    }
    reset();
    _owner = user;
    if (user == null) return;
    final generation = _generation;
    final pending = () async {
      try {
        final raw = await _storage.readCarlitosHistory(user);
        if (!_current(user, generation) || raw == null) return;
        final data = jsonDecode(raw) as Map;
        _messages = (data['messages'] as List? ?? [])
            .map(
              (m) =>
                  ChatMessageItem.fromJson(Map<String, dynamic>.from(m as Map)),
            )
            .toList();
        _pendingClear = data['clear_remote'] == true;
      } catch (_) {
        /* Invalid local data is ignored. */
      }
    }();
    _ownerLoad = pending;
    await pending;
    if (identical(_ownerLoad, pending)) _ownerLoad = null;
  }

  Future<void> _persist(String owner, int generation) async {
    if (!_current(owner, generation)) return;
    final rows = _messages
        .skip(_messages.length > 80 ? _messages.length - 80 : 0)
        .map((m) => m.toJson())
        .toList();
    try {
      await _storage.writeCarlitosHistory(
        owner,
        jsonEncode({'messages': rows, 'clear_remote': _pendingClear}),
      );
    } catch (_) {
      debugPrint('No se pudo guardar el historial local de Carlitos.');
    }
  }

  Future<void> fetchHistory() async {
    if (_isLoading) return;
    await _ensureOwner();
    final owner = _owner;
    if (owner == null) return;
    final generation = _generation;
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      await offline.initialize();
    } catch (_) {
      /* Download setup remains optional. */
    }
    try {
      if (!_connected) return;
      if (_pendingClear) {
        await _apiService.delete('/chat/history');
        if (!_current(owner, generation)) return;
        _pendingClear = false;
      }
      final response = await _apiService.get('/chat/history', usarCache: false);
      if (!_current(owner, generation)) return;
      if (response is Map) {
        final remote = (response['messages'] as List? ?? []).map(
          (m) => ChatMessageItem.fromJson(Map<String, dynamic>.from(m as Map)),
        );
        _messages = [...remote, ..._messages.where((m) => m.source == 'LOCAL')]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        await _persist(owner, generation);
      }
    } on ApiException catch (error) {
      if (_current(owner, generation) && error.statusCode != 0) {
        _errorMessage = error.message;
      }
    } catch (_) {
      if (_current(owner, generation)) {
        _errorMessage = 'No se pudo actualizar el historial.';
      }
    } finally {
      if (_current(owner, generation)) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<bool> sendMessage(String text) async {
    if (_isLoading || text.trim().isEmpty) return false;
    await _ensureOwner();
    if (_isLoading) return false;
    final owner = _owner;
    if (owner == null) {
      _errorMessage = 'Inicia sesión para conversar con Carlitos.';
      _notify();
      return false;
    }
    final generation = _generation;
    final question = ChatMessageItem(
      id: UniqueKey().toString(),
      role: 'user',
      content: text.trim(),
      createdAt: DateTime.now(),
    );
    _messages.add(question);
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      if (_connected) {
        try {
          if (_pendingClear) {
            await _apiService.delete('/chat/history');
            if (!_current(owner, generation)) return false;
            _pendingClear = false;
          }
          final response = await _apiService.post(
            '/chat',
            body: {'message': text.trim()},
          );
          if (!_current(owner, generation)) return false;
          if (response is! Map<String, dynamic>) {
            throw const FormatException('Respuesta inválida.');
          }
          _messages.add(ChatMessageItem.fromJson(response));
          await _persist(owner, generation);
          return true;
        } on ApiException catch (error) {
          // Authentication, entitlement and server failures must remain errors.
          if (error.statusCode != 0) rethrow;
        }
      }
      if (!_current(owner, generation)) return false;
      if (!_canUseOffline()) {
        throw StateError(
          'Carlitos necesita una suscripción Premium vigente verificada en esta cuenta.',
        );
      }
      final cachedProfile = await _apiService.cacheService?.obtener(
        '/clinical/anamnesis/me',
        userId: owner,
        duracionValidez: const Duration(days: 30),
      );
      final cachedPlan = await _apiService.cacheService?.obtener(
        '/plans/my-plan',
        userId: owner,
        duracionValidez: const Duration(days: 30),
      );
      if (!_current(owner, generation)) return false;
      Map<String, dynamic>? owned(dynamic data) {
        if (data is! Map ||
            (data['patient_id'] != null && data['patient_id'] != owner))
          return null;
        return Map<String, dynamic>.from(data);
      }

      final answer = await offline.generate(
        _messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
        anamnesis: owned(cachedProfile),
        approvedPlan: owned(cachedPlan),
      );
      if (!_current(owner, generation)) return false;
      final index = _messages.indexWhere((m) => m.id == question.id);
      if (index >= 0) {
        _messages[index] = ChatMessageItem(
          id: question.id,
          role: 'user',
          content: question.content,
          createdAt: question.createdAt,
          source: 'LOCAL',
        );
      }
      _messages.add(
        ChatMessageItem(
          id: UniqueKey().toString(),
          role: 'assistant',
          content: answer,
          createdAt: DateTime.now(),
          source: 'LOCAL',
        ),
      );
      await _persist(owner, generation);
      return true;
    } catch (error) {
      if (_current(owner, generation)) {
        _messages.removeWhere((m) => m.id == question.id);
        _errorMessage = error is ApiException
            ? error.message
            : !offline.isReady
            ? 'Primero descarga el modelo con «Preparar modo sin internet» mientras tengas conexión.'
            : !_canUseOffline()
            ? 'Carlitos requiere Premium vigente en esta cuenta.'
            : 'No se pudo generar la respuesta local. Cierra otras apps y vuelve a intentar.';
      }
      return false;
    } finally {
      if (_current(owner, generation)) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<void> clearHistory() async {
    if (_isLoading) return;
    await _ensureOwner();
    final owner = _owner;
    if (owner == null) return;
    final generation = _generation;
    _messages.clear();
    _pendingClear = true;
    _errorMessage = null;
    await _persist(owner, generation);
    _notify();
    if (_connected) {
      try {
        await _apiService.delete('/chat/history');
        if (_current(owner, generation)) {
          _pendingClear = false;
          await _persist(owner, generation);
        }
      } catch (_) {
        if (_current(owner, generation)) _errorMessage = 'Historial local borrado. El del servidor se borrará al recuperar conexión.';
      }
    }
  }

  void reset() {
    ++_generation;
    _owner = null;
    _ownerLoad = null;
    _messages = [];
    _isLoading = false;
    _pendingClear = false;
    _errorMessage = null;
    unawaited(offline.release());
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    offline.removeListener(_notify);
    offline.dispose();
    super.dispose();
  }
}
