# Diario nutricional móvil (CU-14 a CU-18)

Entradas: botón **Mi nutrición** en Inicio y **Ver plan asignado y diario de alimentación** en la sección Plan.

La pantalla permite consultar el plan aprobado, registrar una comida con fecha/hora, analizar una foto con conexión, consultar el historial y ver/reintentar registros pendientes. Los nutrientes manuales son opcionales. La guía sin conexión es una consulta local, no un modelo generativo.

El plan y el historial se descargan al iniciar una sesión y al abrir el diario. Se guardan durante 30 días por cuenta en `flutter_secure_storage`. Una respuesta del servidor que retire el plan elimina la copia anterior. Sin conexión se avisa que la copia puede estar desactualizada.

Las comidas se guardan en una cola segura antes de enviarse; el UUID no cambia al reintentar. El backend deduplica por cuenta y UUID. La cola se conserva al cerrar sesión y solo se vuelve a cargar para su propietario. Las otras cachés clínicas se limpian al salir.

La sincronización necesita una sesión activa y conectividad. Funciona mientras el sistema operativo permite ejecutar la app; no se garantiza con la app cerrada. Tras cinco intentos automáticos, el usuario puede reintentar explícitamente. Los errores permanentes permanecen visibles para revisión.

Para compilar contra producción, configurar `API_BASE_URL` en GitHub → repositorio → Settings → Secrets and variables → Actions → Variables. Usar el dominio HTTPS del backend más `/api/v1`. La clave Gemini solo pertenece a Railway; nunca debe incluirse en `--dart-define`.

La URL predeterminada ya corresponde al backend público del proyecto. Para desarrollo local en un emulador Android se puede reemplazar con `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1`.

`flutter build apk --debug --dart-define=API_BASE_URL=https://DOMINIO_BACKEND/api/v1` genera la APK de QA. La publicación de tienda o una APK release requiere la clave de firma del propietario. El workflow existente conserva el APK de QA como artefacto.
