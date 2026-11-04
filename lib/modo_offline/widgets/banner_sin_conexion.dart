import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../conectividad_service.dart';
import '../cola_sincronizacion_service.dart';
import '../sincronizador_service.dart';

class BannerSinConexion extends StatelessWidget {
  const BannerSinConexion({super.key});
  @override
  Widget build(BuildContext context) {
    final connected = context.watch<ConectividadService>().estaConectado;
    final cola = context.watch<ColaSincronizacionService>();
    final sync = context.watch<SincronizadorService>();
    final count = cola.elementos.length;
    if (connected && count == 0 && !sync.estaSincronizando) {
      return const SizedBox.shrink();
    }
    return ColoredBox(
      color: connected ? const Color(0xFFE4F0EA) : const Color(0xFFFFE9C4),
      child: ExpansionTile(
        dense: true,
        textColor: const Color(0xFF19392B),
        collapsedTextColor: const Color(0xFF19392B),
        iconColor: const Color(0xFF19392B),
        collapsedIconColor: const Color(0xFF19392B),
        leading: Icon(
          connected ? Icons.sync : Icons.wifi_off,
          color: const Color(0xFF19392B),
        ),
        title: Text(
          '${connected ? (sync.estaSincronizando ? "Sincronizando" : "Pendiente de sincronización") : "Modo sin conexión"} · $count pendientes',
          style: const TextStyle(fontSize: 13, color: Color(0xFF19392B)),
        ),
        children: [
          if (count == 0)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Puedes consultar tu copia y guardar citas o fotos pendientes.',
              ),
            ),
          if (count > 0)
            SizedBox(
              height: count < 3 ? count * 72.0 : 180,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: count,
                itemBuilder: (context, index) {
                  final item = cola.elementos[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      '${index + 1}. ${item.descripcionHumana}',
                      style: const TextStyle(color: Color(0xFF19392B)),
                    ),
                    subtitle: Text(
                      item.mensajeError ?? item.estado,
                      style: const TextStyle(color: Color(0xFF19392B)),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
