# Reportes dinámicos en mobile

La entrada de Reportes conserva su ubicación. Incluye las siete entidades de web, consultas por texto y dictado, resumen leído en español, columnas, filtros, fechas, agrupaciones, métricas, gráficos, orden y límite. Permite guardar reportes y exportar a PDF o Excel, incluso una copia guardada.

Todos los roles, incluido CLIENTE, pueden consultar reportes generales de su empresa. Esta ampliación fue solicitada expresamente: incluye datos de otros clientes de esa empresa. SUPERADMIN conserva el alcance global; el personal conserva las restricciones de su espacio de trabajo. Los reportes guardados de clientes solo los gestiona su creador. Los endpoints personales /reports/mine continúan disponibles en Mis registros.

Desplegar backend y web, e instalar el APK actualizado. No hay migraciones ni variables nuevas. Se reutiliza la configuración Gemini existente para interpretación y resumen; el dictado usa el reconocimiento del teléfono y solicita permiso de micrófono. La lectura usa el motor de voz del teléfono. Revisar dictado y sonido en un dispositivo físico.

La evaluación nutricional web muestra el historial de alimentación registrado en mobile, con los permisos clínicos existentes. El panel completo de copia offline se encuentra en Perfil; el aviso de desconexión y cantidad de pendientes sigue visible al perder internet.

Un cliente vinculado a SUPERADMIN puede solicitarle cita dentro de la empresa de su vinculación. El código se genera desde el espacio de empresa/sucursal correspondiente.
