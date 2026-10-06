import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import 'conectividad_service.dart';
import 'cola_sincronizacion_service.dart';

class SincronizadorService extends ChangeNotifier {
  final ConectividadService conectividadService;
  final ColaSincronizacionService colaService;
  final ApiService apiService;

  bool _estaSincronizando = false;
  String? _ultimoMensajeExito;
  String? _ultimoErrorConflicto;
  DateTime? _ultimaSincronizacion;
  Timer? _timerReintento;

  bool get estaSincronizando => _estaSincronizando;
  String? get ultimoMensajeExito => _ultimoMensajeExito;
  String? get ultimoErrorConflicto => _ultimoErrorConflicto;
  DateTime? get ultimaSincronizacion => _ultimaSincronizacion;

  VoidCallback? onCitasActualizadas;
  VoidCallback? onFichaActualizada;

  SincronizadorService({
    required this.conectividadService,
    required this.colaService,
    required this.apiService,
  }) {
    // 1. Escuchar cambios de conectividad para auto-sincronizar al volver internet
    conectividadService.addListener(_alCambiarConectividad);

    // 2. Escuchar adiciones en la cola offline para procesar de inmediato si hay conexion
    colaService.addListener(_alCambiarCola);

    // 3. Temporizador periodico de auto-reintento cada 10 segundos si hay pendientes y conexion
    _timerReintento = Timer.periodic(const Duration(seconds: 10), (_) {
      if (conectividadService.estaConectado && colaService.tienePendientes && !_estaSincronizando) {
        sincronizarCola(userId: apiService.currentUserId);
      }
    });
  }

  void _alCambiarConectividad() {
    if (conectividadService.estaConectado && !_estaSincronizando) {
      sincronizarCola(userId: apiService.currentUserId);
    }
  }

  void _alCambiarCola() {
    if (conectividadService.estaConectado && colaService.tienePendientes && !_estaSincronizando) {
      Future.microtask(() => sincronizarCola(userId: apiService.currentUserId));
    }
  }

  /// Procesa la cola FIFO de acciones pendientes
  Future<void> sincronizarCola({String? userId}) async {
    if (_estaSincronizando || !conectividadService.estaConectado) return;

    final targetUserId = (userId != null && userId.isNotEmpty) ? userId : apiService.currentUserId;
    if (colaService.elementos.isEmpty && targetUserId != null && targetUserId.isNotEmpty) {
      await colaService.cargarCola(userId: targetUserId);
    }

    final pendientes = colaService.elementos
        .where((e) => e.esSincronizable)
        .toList();

    if (pendientes.isEmpty) return;

    _estaSincronizando = true;
    _ultimoMensajeExito = null;
    _ultimoErrorConflicto = null;
    notifyListeners();

    try {
      pendientes.sort((a, b) => a.fechaCreacion.compareTo(b.fechaCreacion)); // Orden FIFO estricto

      bool huboCambiosEnCitas = false;
      bool huboCambiosEnFicha = false;

      for (final elemento in pendientes) {
        if (!conectividadService.estaConectado) break;

        final elUserId = (targetUserId != null && targetUserId.isNotEmpty) ? targetUserId : elemento.userId;
        await colaService.actualizarEstado(elemento.id, 'SINCRONIZANDO', userId: elUserId);

        try {
          if (elemento.metodo == 'POST') {
            await apiService.post(
              elemento.endpoint,
              body: elemento.cuerpo,
            );

            if (elemento.esCita) {
              huboCambiosEnCitas = true;
              _ultimoMensajeExito = 'Cita medica sincronizada exitosamente con tu especialista.';
            } else if (elemento.esFichaMedica || elemento.tipoAccion == 'ACTUALIZAR_FICHA_MEDICA') {
              huboCambiosEnFicha = true;
              _ultimoMensajeExito = 'Ficha de salud sincronizada exitosamente con el servidor.';
            }

            // Removido con exito de la cola
            await colaService.remover(elemento.id, userId: elUserId);
          } else if (elemento.metodo == 'PUT') {
            await apiService.put(
              elemento.endpoint,
              body: elemento.cuerpo,
            );
            await colaService.remover(elemento.id, userId: elUserId);
          } else if (elemento.metodo == 'PATCH') {
            await apiService.patch(
              elemento.endpoint,
              body: elemento.cuerpo,
            );
            await colaService.remover(elemento.id, userId: elUserId);
          } else if (elemento.metodo == 'DELETE') {
            await apiService.delete(
              elemento.endpoint,
              body: elemento.cuerpo,
            );
            await colaService.remover(elemento.id, userId: elUserId);
          }
        } catch (e) {
          final errorStr = e.toString().toLowerCase();

          // 1. Conflicto o solapamiento de horario confirmado por backend
          if (errorStr.contains('ya tiene una cita') ||
              errorStr.contains('conflicto') ||
              errorStr.contains('solapamiento') ||
              (e is ApiException && (e.statusCode == 400 || e.statusCode == 409))) {
            String mensajeAmigable = 'No se pudo reservar la cita: El especialista ya tiene una cita agendada en ese horario. Por favor selecciona otro horario.';
            if (e is ApiException && e.message.isNotEmpty) {
              mensajeAmigable = e.message;
            }

            await colaService.actualizarEstado(
              elemento.id,
              'ERROR_CONFLICTO',
              error: mensajeAmigable,
              userId: elUserId,
            );
            _ultimoErrorConflicto = mensajeAmigable;
            if (elemento.esCita) {
              huboCambiosEnCitas = true;
            }
          } else if (errorStr.contains('conexión') ||
              errorStr.contains('conexion') ||
              errorStr.contains('socket') ||
              errorStr.contains('failed host lookup') ||
              errorStr.contains('timeout') ||
              (e is ApiException && e.statusCode == 0)) {
            // Error de red transitorio: restaurar a PENDIENTE para que reintente en el proximo ciclo
            await colaService.actualizarEstado(elemento.id, 'PENDIENTE', userId: elUserId);
            break;
          } else {
            // Error general: restaurar a PENDIENTE para continuar intentando
            await colaService.actualizarEstado(
              elemento.id,
              'PENDIENTE',
              error: e.toString().replaceAll('Exception:', '').trim(),
              userId: elUserId,
            );
          }
        }
      }

      _ultimaSincronizacion = DateTime.now();

      if (huboCambiosEnCitas) {
        onCitasActualizadas?.call();
      }
      if (huboCambiosEnFicha) {
        onFichaActualizada?.call();
      }
    } finally {
      _estaSincronizando = false;
      notifyListeners();
    }
  }

  void limpiarMensajes() {
    _ultimoMensajeExito = null;
    _ultimoErrorConflicto = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timerReintento?.cancel();
    colaService.removeListener(_alCambiarCola);
    conectividadService.removeListener(_alCambiarConectividad);
    super.dispose();
  }
}
