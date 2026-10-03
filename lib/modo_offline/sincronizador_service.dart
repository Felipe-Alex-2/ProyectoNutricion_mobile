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

  SincronizadorService({
    required this.conectividadService,
    required this.colaService,
    required this.apiService,
  }) {
    // Escuchar cambios de conectividad para auto-sincronizar
    conectividadService.addListener(_alCambiarConectividad);
  }

  void _alCambiarConectividad() {
    if (conectividadService.estaConectado && colaService.tienePendientes && !_estaSincronizando) {
      sincronizarCola();
    }
  }

  /// Procesa la cola FIFO de acciones pendientes
  Future<void> sincronizarCola({String? userId}) async {
    if (_estaSincronizando || !conectividadService.estaConectado) return;

    _estaSincronizando = true;
    _ultimoMensajeExito = null;
    _ultimoErrorConflicto = null;
    notifyListeners();

    try {
      final pendientes = colaService.elementos.where((e) => e.estaPendiente).toList();
      pendientes.sort((a, b) => a.fechaCreacion.compareTo(b.fechaCreacion)); // Orden FIFO estricto

      bool huboCambiosEnCitas = false;

      for (final elemento in pendientes) {
        if (!conectividadService.estaConectado) break;

        await colaService.actualizarEstado(elemento.id, 'SINCRONIZANDO', userId: userId);

        try {
          if (elemento.metodo == 'POST') {
            await apiService.post(
              elemento.endpoint,
              body: elemento.cuerpo,
            );

            if (elemento.esCita) {
              huboCambiosEnCitas = true;
              _ultimoMensajeExito = 'Cita médica sincronizada exitosamente con tu especialista.';
            }

            // Removido con éxito
            await colaService.remover(elemento.id, userId: userId);
          } else if (elemento.metodo == 'PUT') {
            await apiService.put(
              elemento.endpoint,
              body: elemento.cuerpo,
            );
            await colaService.remover(elemento.id, userId: userId);
          } else if (elemento.metodo == 'PATCH') {
            await apiService.patch(
              elemento.endpoint,
              body: elemento.cuerpo,
            );
            await colaService.remover(elemento.id, userId: userId);
          } else if (elemento.metodo == 'DELETE') {
            await apiService.delete(
              elemento.endpoint,
              body: elemento.cuerpo,
            );
            await colaService.remover(elemento.id, userId: userId);
          }
        } catch (e) {
          final errorStr = e.toString().toLowerCase();

          // Si el servidor indica conflicto o que ya está agendada
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
              userId: userId,
            );
            _ultimoErrorConflicto = mensajeAmigable;
            if (elemento.esCita) {
              huboCambiosEnCitas = true;
            }
          } else if (errorStr.contains('conexión') ||
              errorStr.contains('socket') ||
              errorStr.contains('failed host lookup') ||
              errorStr.contains('timeout')) {
            // Error de red temporal: volver a dejarlo pendiente y pausar la sincronización
            await colaService.actualizarEstado(elemento.id, 'PENDIENTE', userId: userId);
            conectividadService.marcarDesconectadoPorErrorHttp();
            break;
          } else {
            // Otro error
            await colaService.actualizarEstado(
              elemento.id,
              'ERROR',
              error: e.toString().replaceAll('Exception:', '').trim(),
              userId: userId,
            );
          }
        }
      }

      _ultimaSincronizacion = DateTime.now();

      if (huboCambiosEnCitas) {
        onCitasActualizadas?.call();
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
