import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../conectividad_service.dart';
import '../cola_sincronizacion_service.dart';
import '../sincronizador_service.dart';

class BannerSinConexion extends StatelessWidget {
  const BannerSinConexion({super.key});

  @override
  Widget build(BuildContext context) {
    final conectividad = context.watch<ConectividadService>();
    final cola = context.watch<ColaSincronizacionService>();
    final sinc = context.watch<SincronizadorService>();

    // 1. Mostrar banner de conflicto si ocurrió error al reservar cita
    if (sinc.ultimoErrorConflicto != null || cola.conflictos.isNotEmpty) {
      final errorMsg = sinc.ultimoErrorConflicto ?? cola.conflictos.first.mensajeError ?? 'Conflicto en la cita';
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEF4444)),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Conflicto de Cita',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                  Text(
                    errorMsg,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF991B1B), size: 18),
              onPressed: () {
                sinc.limpiarMensajes();
                if (cola.conflictos.isNotEmpty) {
                  cola.descartarConflicto(cola.conflictos.first.id);
                }
              },
            ),
          ],
        ),
      );
    }

    // 2. Mostrar banner de sincronización activa
    if (sinc.estaSincronizando) {
      return Container(
        width: double.infinity,
        color: const Color(0xFF2563EB),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 10),
            Text(
              'Sincronizando acciones con el servidor...',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    // 3. Mostrar banner de éxito temporal
    if (sinc.ultimoMensajeExito != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF10B981)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                sinc.ultimoMensajeExito!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.w500),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF065F46), size: 18),
              onPressed: () => sinc.limpiarMensajes(),
            ),
          ],
        ),
      );
    }

    // 4. Mostrar banner sin conexión
    if (!conectividad.estaConectado) {
      final pendientes = cola.cantidadPendientes;
      return Container(
        width: double.infinity,
        color: const Color(0xFFD97706),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              pendientes > 0
                  ? 'Modo sin conexión • $pendientes ${pendientes == 1 ? "acción pendiente" : "acciones pendientes"}'
                  : 'Modo sin conexión',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
