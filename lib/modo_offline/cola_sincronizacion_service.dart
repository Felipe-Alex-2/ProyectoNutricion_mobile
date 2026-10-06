import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'elemento_cola.dart';

class ColaSincronizacionService extends ChangeNotifier {
  Directory? _documentsDir;
  final List<ElementoCola> _colaMemoria = [];

  List<ElementoCola> get elementos => List.unmodifiable(_colaMemoria);
  int get cantidadPendientes => _colaMemoria.where((e) => e.esSincronizable).length;
  bool get tienePendientes => cantidadPendientes > 0;
  List<ElementoCola> get conflictos => _colaMemoria.where((e) => e.tieneErrorConflicto).toList();

  Future<Directory> _getDir() async {
    _documentsDir ??= await getApplicationDocumentsDirectory();
    return _documentsDir!;
  }

  String _sanitizeKey(String key) {
    return key.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  Future<File> _getFile(String? userId) async {
    final dir = await _getDir();
    final safeUser = (userId != null && userId.isNotEmpty) ? _sanitizeKey(userId) : 'default';
    return File('${dir.path}/nutri_cola_u_$safeUser.json');
  }

  /// Carga la cola desde el almacenamiento persistente
  Future<void> cargarCola({String? userId}) async {
    try {
      final file = await _getFile(userId);
      final List<ElementoCola> cargados = [];

      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> list = jsonDecode(content);
          cargados.addAll(list.map((item) => ElementoCola.fromJson(item as Map<String, dynamic>)));
        }
      }

      // Si se especificó un usuario, recuperar y fusionar elementos huérfanos de la cola por defecto
      if (userId != null && userId.isNotEmpty) {
        final defaultFile = await _getFile(null);
        if (await defaultFile.exists()) {
          try {
            final defContent = await defaultFile.readAsString();
            if (defContent.isNotEmpty) {
              final List<dynamic> defList = jsonDecode(defContent);
              for (final item in defList) {
                final elem = ElementoCola.fromJson(item as Map<String, dynamic>);
                if (!cargados.any((existing) => existing.id == elem.id)) {
                  cargados.add(ElementoCola(
                    id: elem.id,
                    userId: userId,
                    metodo: elem.metodo,
                    endpoint: elem.endpoint,
                    cuerpo: elem.cuerpo,
                    tipoAccion: elem.tipoAccion,
                    descripcionHumana: elem.descripcionHumana,
                    fechaCreacion: elem.fechaCreacion,
                    reintentos: elem.reintentos,
                    estado: elem.estado,
                    mensajeError: elem.mensajeError,
                    metadata: elem.metadata,
                  ));
                }
              }
            }
            await defaultFile.delete();
          } catch (e) {
            debugPrint('[ColaSincronizacionService] Advertencia al migrar cola default: $e');
          }
        }
      }

      _colaMemoria.clear();
      _colaMemoria.addAll(cargados);
      if (userId != null && userId.isNotEmpty && cargados.isNotEmpty) {
        await _guardarDisco(userId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[ColaSincronizacionService] Error al cargar cola: $e');
    }
  }

  /// Guarda la cola en disco
  Future<void> _guardarDisco(String? userId) async {
    try {
      final file = await _getFile(userId);
      final jsonList = _colaMemoria.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList), flush: true);
    } catch (e) {
      debugPrint('[ColaSincronizacionService] Error al persistir cola: $e');
    }
  }

  /// Encola una acción offline
  Future<void> encolar(ElementoCola elemento) async {
    _colaMemoria.add(elemento);
    await _guardarDisco(elemento.userId);
    notifyListeners();
  }

  /// Actualiza el estado de un elemento en la cola
  Future<void> actualizarEstado(
    String id,
    String nuevoEstado, {
    String? error,
    String? userId,
  }) async {
    final index = _colaMemoria.indexWhere((e) => e.id == id);
    if (index != -1) {
      final el = _colaMemoria[index];
      el.estado = nuevoEstado;
      if (error != null) {
        el.mensajeError = error;
      }
      el.reintentos += 1;
      await _guardarDisco(userId ?? el.userId);
      notifyListeners();
    }
  }

  /// Remueve un elemento de la cola (cuando finalizó exitosamente o se descartó)
  Future<void> remover(String id, {String? userId}) async {
    final index = _colaMemoria.indexWhere((e) => e.id == id);
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

  /// Limpia la cola del usuario actual al cerrar sesión
  Future<void> limpiarColaUsuario(String userId) async {
    try {
      _colaMemoria.clear();
      final file = await _getFile(userId);
      if (await file.exists()) {
        await file.delete();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[ColaSincronizacionService] Error al limpiar cola de usuario: $e');
    }
  }
}
