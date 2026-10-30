import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'elemento_cola.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ColaSincronizacionService extends ChangeNotifier {
  Directory? _documentsDir;
  final FlutterSecureStorage _storage;
  ColaSincronizacionService({
    FlutterSecureStorage? storage,
    Directory? documentsDirectory,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _documentsDir = documentsDirectory;
  String _secureKey(String userId) =>
      'nutri_queue_v2_${base64Url.encode(utf8.encode(userId))}';
  final List<ElementoCola> _colaMemoria = [];
  String? _loadedUserId;
  int _loadVersion = 0;
  Future<void>? _loading;

  List<ElementoCola> get elementos => List.unmodifiable(_colaMemoria);
  int get cantidadPendientes => _colaMemoria
      .where((e) => e.estado == 'PENDIENTE' || e.estado == 'SINCRONIZANDO')
      .length;
  bool get tienePendientes => cantidadPendientes > 0;
  List<ElementoCola> get conflictos =>
      _colaMemoria.where((e) => e.tieneErrorConflicto).toList();

  Future<Directory> _getDir() async {
    _documentsDir ??= await getApplicationDocumentsDirectory();
    return _documentsDir!;
  }

  String _sanitizeKey(String key) {
    return key.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  Future<File> _getFile(String? userId) async {
    final dir = await _getDir();
    final safeUser = (userId != null && userId.isNotEmpty)
        ? _sanitizeKey(userId)
        : 'default';
    return File('${dir.path}/nutri_cola_u_$safeUser.json');
  }

  /// Carga la cola desde el almacenamiento persistente
  Future<void> cargarCola({String? userId}) {
    final pending = _cargarCola(userId: userId);
    _loading = pending;
    return pending.whenComplete(() {
      if (identical(_loading, pending)) _loading = null;
    });
  }

  Future<void> _cargarCola({String? userId}) async {
    final version = ++_loadVersion;
    _loadedUserId = userId;
    _colaMemoria.clear();
    if (userId == null || userId.isEmpty) {
      notifyListeners();
      return;
    }
    var content = await _storage.read(key: _secureKey(userId));
    final legacy = await _getFile(userId);
    if (content == null && await legacy.exists()) {
      content = await legacy.readAsString();
    }
    if (version != _loadVersion) return;
    if (content != null) {
      final rows = jsonDecode(content) as List;
      _colaMemoria.addAll(
        rows
            .map((row) => ElementoCola.fromJson(row as Map<String, dynamic>))
            .where((e) => e.userId == userId),
      );
      await _guardarDisco(userId);
    }
    if (await legacy.exists()) await legacy.delete();
    notifyListeners();
  }

  Future<void> _guardarDisco(String? userId) async {
    if (userId == null || userId.isEmpty) {
      throw StateError('La cola requiere un usuario.');
    }
    final rows = _colaMemoria
        .where((e) => e.userId == userId)
        .map((e) => e.toJson())
        .toList();
    await _storage.write(key: _secureKey(userId), value: jsonEncode(rows));
  }

  /// Encola una acción offline
  Future<void> encolar(ElementoCola elemento) async {
    if (elemento.userId.isEmpty) {
      throw StateError('La operación requiere un usuario.');
    }
    if (_loading != null) await _loading;
    if (_loadedUserId != elemento.userId) {
      await cargarCola(userId: elemento.userId);
    }
    if (_loadedUserId != elemento.userId) {
      throw StateError("La cuenta cambió durante la operación.");
    }
    if (_colaMemoria.length >= 200) {
      throw StateError(
        'Hay demasiadas operaciones pendientes. Sincroniza primero.',
      );
    }
    _colaMemoria.add(elemento);
    try {
      await _guardarDisco(elemento.userId);
    } catch (_) {
      _colaMemoria.remove(elemento);
      rethrow;
    }
    notifyListeners();
  }

  /// Actualiza el estado de un elemento en la cola
  Future<void> actualizarEstado(
    String id,
    String nuevoEstado, {
    String? error,
    String? userId,
  }) async {
    final index = _colaMemoria.indexWhere(
      (e) => e.id == id && (userId == null || e.userId == userId),
    );
    if (index != -1) {
      final el = _colaMemoria[index];
      el.estado = nuevoEstado;
      if (error != null) {
        el.mensajeError = error;
      }
      if (nuevoEstado == 'SINCRONIZANDO') el.reintentos += 1;
      if (nuevoEstado == 'PENDIENTE' && el.reintentos > 0) {
        el.proximoIntento = DateTime.now().add(
          Duration(seconds: 5 * (1 << el.reintentos.clamp(0, 6))),
        );
      }
      await _guardarDisco(userId ?? el.userId);
      notifyListeners();
    }
  }

  /// Remueve un elemento de la cola (cuando finalizó exitosamente o se descartó)
  Future<void> remover(String id, {String? userId}) async {
    final index = _colaMemoria.indexWhere(
      (e) => e.id == id && (userId == null || e.userId == userId),
    );
    if (index != -1) {
      final el = _colaMemoria.removeAt(index);
      await _guardarDisco(userId ?? el.userId);
      notifyListeners();
    }
  }

  /// Descarta un conflicto específico
  Future<void> descartarConflicto(String id, {String? userId}) async {
    await remover(id, userId: userId);
  }

  Future<void> reintentar(String id, {required String userId}) async {
    for (final item in _colaMemoria.where(
      (e) => e.id == id && e.userId == userId && e.estado != 'SINCRONIZANDO',
    )) {
      item.reintentos = 0;
      item.estado = 'PENDIENTE';
      item.mensajeError = null;
      item.proximoIntento = null;
    }
    await _guardarDisco(userId);
    notifyListeners();
  }

  /// Keep encrypted pending meals for the next login of their owner.
  void soltarCuenta() {
    _loadVersion++;
    _loadedUserId = null;
    _colaMemoria.clear();
    notifyListeners();
  }

  /// Limpia la cola del usuario actual al cerrar sesión
  Future<void> limpiarColaUsuario(String userId) async {
    try {
      if (_loadedUserId == userId) {
        _loadVersion++;
        _loadedUserId = null;
      }
      _colaMemoria.removeWhere((e) => e.userId == userId);
      await _storage.delete(key: _secureKey(userId));
      final file = await _getFile(userId);
      if (await file.exists()) {
        await file.delete();
      }
      notifyListeners();
    } catch (e) {
      debugPrint(
        '[ColaSincronizacionService] Error al limpiar cola de usuario: $e',
      );
    }
  }
}
