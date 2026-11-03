# Activar notificaciones push de NutriSalud (Android)

La app muestra el total de mensajes no leídos en la campana. El backend guarda primero la notificación y, después del commit, envía un mensaje FCM a los dispositivos registrados del destinatario. Incluye título, texto, referencia y cantidad no leída. La app registra/renueva su token al iniciar sesión y lo retira al cerrar sesión. Sin Firebase configurado, la app sigue funcionando con el centro de notificaciones y las consultas periódicas; no habrá push con la app cerrada.

## 1. Crear Firebase y registrar Android

1. Abre https://console.firebase.google.com/ y crea un proyecto para NutriSalud. Google Analytics es opcional.
2. En Configuración del proyecto > General, añade una app Android con el identificador exacto **com.nutrisalud.app.mobile**. No es el nombre visible de la app.
3. Descarga **google-services.json** y guárdalo en **mobile/android/app/google-services.json**.
4. El plugin Gradle de Google Services ya está declarado y se activa cuando existe ese archivo. Las dependencias Firebase Core, Messaging y notificaciones locales ya están añadidas. No necesitas Firestore ni Realtime Database para este flujo.
5. Recompila e instala el APK. Inicia sesión y permite las notificaciones cuando Android lo solicite (Android 13 o posterior).

No inventes los valores de google-services.json ni uses los de otro proyecto. El proyecto Android y la cuenta de servicio del backend deben ser el mismo proyecto Firebase.

## 2. Configurar el envío desde Railway

1. En Firebase > Configuración del proyecto > Cuentas de servicio, genera una clave privada de la cuenta de servicio. Guarda el JSON en un lugar privado, fuera de Git y fuera del cliente móvil/web.
2. En Railway, abre el servicio **backend** > Variables y agrega los valores del JSON:

| Variable de Railway | Campo del JSON de cuenta de servicio |
|---|---|
| FIREBASE_PROJECT_ID | project_id |
| FIREBASE_CLIENT_EMAIL | client_email |
| FIREBASE_PRIVATE_KEY | private_key completo, incluidos BEGIN/END PRIVATE KEY |

La clave privada puede contener saltos de línea reales o el texto literal \n; el backend normaliza ese formato. No pegues el JSON entero como valor de una variable individual.

3. Verifica en Google Cloud que la API Firebase Cloud Messaging HTTP v1 esté habilitada para ese proyecto y que la cuenta tenga permiso de envío (Firebase Cloud Messaging API Admin).
4. Despliega esta versión del backend con **firebase-admin** de requirements.txt. Los errores de FCM se registran con el logger push; una falla de envío no revierte un pago confirmado.

Para probar localmente puedes añadir las tres variables a backend/.env.local y arrancar run_local.py. Mobile debe usar ese backend de prueba. No pegues claves privadas en código fuente, capturas, recibos o el repositorio.

## 3. Prueba completa con teléfono

1. Usa un Android con Google Play Services y esta versión de la app instalada. También sirve un emulador con Google APIs/Play Services.
2. Inicia sesión. La app obtiene el token y llama al endpoint autenticado POST /api/v1/automation/device-tokens.
3. Envía al usuario una notificación desde la web o confirma una cita. Con la app abierta debe actualizarse el centro de mensajes y aparecer el aviso del sistema.
4. Pon la app en segundo plano o retírala de aplicaciones recientes; envía otra notificación. Debe aparecer en la bandeja del teléfono. Al tocarla se abre el centro de notificaciones, conservando la validación de la cuenta.
5. Prueba una recarga de wallet confirmada y un pago de cita: se guarda el aviso y su comprobante. Repetir la verificación del pago no vuelve a crear el aviso ni el movimiento.
6. Cierra sesión y comprueba que ese teléfono deja de recibir avisos de esa cuenta.

El punto o número sobre el icono de Android depende del launcher del teléfono. Se envía notification_count con el total no leído; Pixel Launcher suele mostrar un punto, mientras otros launchers muestran números. La campana dentro de NutriSalud muestra el contador exacto. Forzar detención desde Ajustes bloquea la recepción hasta abrir de nuevo la app; también influyen permisos, conexión y restricciones del fabricante.

Los envíos se ejecutan en segundo plano después del commit, con registro de fallos. No hay una cola persistente de reintentos; el centro de notificaciones conserva los mensajes aunque FCM no entregue un aviso.

## iPhone

El código incluye permisos y badge de iOS, pero activar push allí requiere registrar la app iOS en el mismo proyecto, añadir GoogleService-Info.plist al target Runner desde Xcode, activar Push Notifications y Background Modes > Remote notifications y cargar la clave APNs en Firebase. Estos pasos requieren el proyecto y firma Apple; no se han configurado ni probado en esta entrega.

## Referencias oficiales

- https://firebase.google.com/docs/cloud-messaging/flutter/get-started
- https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages
- https://firebase.google.com/docs/cloud-messaging/send/admin-sdk
- https://developer.android.com/develop/ui/views/notifications/badges
