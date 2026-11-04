import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../copia_offline_service.dart';
import '../cola_sincronizacion_service.dart';
import '../../services/api_service.dart';

class CopiaOfflineCard extends StatelessWidget {
  const CopiaOfflineCard({super.key});
  @override
  Widget build(BuildContext context) {
    final copia = context.watch<CopiaOfflineService>();
    final cola = context.watch<ColaSincronizacionService>();
    final date = copia.ultimaCopia?.toLocal().toString().split('.').first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Copia para usar sin conexión',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              date == null
                  ? 'Todavía no hay una copia completa.'
                  : 'Última copia: $date',
            ),
            const Text(
              'Citas, plan nutricional, recetas e historial. Se actualiza al iniciar sesión. Los datos descargados se conservan hasta 30 días.',
            ),
            if (copia.error != null) Text(copia.error!),
            TextButton.icon(
              onPressed: copia.copiando ? null : copia.copiar,
              icon: const Icon(Icons.cloud_download_outlined),
              label: Text(copia.copiando ? 'Copiando…' : 'Copiar ahora'),
            ),
            Text('Operaciones pendientes: ${cola.elementos.length}'),
            for (final (index, item) in cola.elementos.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${index + 1}. ${item.descripcionHumana}'),
                subtitle: Text(
                  item.mensajeError ??
                      (item.estado == 'SINCRONIZANDO'
                          ? 'Enviando…'
                          : 'Pendiente de enviar'),
                ),
                trailing:
                    item.estado.startsWith('ERROR') || item.reintentos >= 5
                    ? IconButton(
                        tooltip: 'Reintentar',
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          final user = context.read<ApiService>().currentUserId;
                          if (user != null) {
                            cola.reintentar(item.id, userId: user);
                          }
                        },
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
