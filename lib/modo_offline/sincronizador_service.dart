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
    // Escuchar cambios de conectividad para auto-sincronizar
    conectividadService.addListener(_alCambiarConectividad);
  }

  void _alCambiarConectividad() {
    if (conectividadService.estaConectado && !_estaSincronizando) {
      sincronizarCola(userId: apiService.currentUserId);
    }
  }

  /// Procesa la cola FIFO de acciones pendientes
  Future<void> sincronizarCola({String? userId}) async {
    if (_estaSincronizando || !conectividadService.estaConectado) return;

    final targetUserId = (userId != null && userId.isNotEmpty) ? userId : apiService.currentUserId;
    if (colaService.elementos.isEmpty && targetUserId != null && targetUserId.isNotEmpty) {
      await colaService.cargarCola(userId: targetUserId);
    }

    if (!colaService.tienePendientes) return;

    _estaSincronizando = true;
    _ultimoMensajeExito = null;
    _ultimoErrorConflicto = null;
    notifyListeners();

    try {
      final pendientes = colaService.elementos.where((e) => e.estaPendiente).toList();
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

            // Removido con exito
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

          // Si el servidor indica conflicto o que ya esta agendada
          if (errorStr.contains('ya tiene una cita') ||
              errorStr.contains('conflicto') ||
              errorStr.contains('solapamiento') ||
              errorStr.contains('bad request') ||
              (e is ApiException && e.statusCode == 400)) {
            final mensajeAmigable = 'No se pudo reservar la cita: El especialista ya tiene una cita agendada en ese horario. Por favor selecciona otro horario.';
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
              errorStr.contains('timeout')) {
            // Error de red temporal: volver a dejarlo pendiente y pausar la sincronizacion
            await colaService.actualizarEstado(elemento.id, 'PENDIENTE', userId: elUserId);
            conectividadService.marcarDesconectadoPorErrorHttp();
            break;
          } else {
            // Otro error
            await colaService.actualizarEstado(
              elemento.id,
              'ERROR',
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
    conectividadService.removeListener(_alCambiarConectividad);
    super.dispose();
  }
}
