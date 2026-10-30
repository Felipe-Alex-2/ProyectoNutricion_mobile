# Desarrollo y distribución

Flutter 3.47.2, `flutter pub get`, `flutter analyze`, `flutter test`.

`flutter run` utiliza por defecto https://proyectonutricionbackend-production-8308.up.railway.app/api/v1, tanto en emulador como en dispositivo físico. Para desarrollo local en emulador Android: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1`. Dispositivo físico con backend local: `flutter run --dart-define=API_BASE_URL=http://IP_LOCAL:8000/api/v1`.

Producción: `flutter build apk --release` utiliza el backend de Railway por defecto. Se puede cambiar con `--dart-define=API_BASE_URL=https://TU_BACKEND/api/v1`. Release bloquea HTTP sin cifrar y ya no se firma con la llave debug. Completa android/key.properties desde android/key.properties.example y utiliza tu keystore privado. No subirlo a Git.

CI ejecuta análisis y pruebas y produce APK debug para QA usando Railway por defecto. La variable de repositorio API_BASE_URL permite elegir otra URL HTTPS si está configurada. No es un APK firmado para publicar en una tienda.

PayPal se gestiona exclusivamente mediante backend. Rota la credencial Sandbox expuesta en versiones anteriores: retirarla del archivo actual no la elimina de APKs ni del historial Git. Se requieren las nuevas rutas del backend antes de distribuir este cliente.

Caché y cola nuevas se guardan con flutter_secure_storage, separadas por cuenta. La caché clínica caduca en 24 horas; los JSON antiguos de caché se eliminan al actualizar y la cola identificada por usuario se migra. Operaciones sin dueño no se adoptan por otra cuenta. Los errores permanentes no se reintentan y las operaciones tienen un máximo de cinco intentos. Al reintentar citas se envía Idempotency-Key al backend.

La pantalla de inicio todavía requiere una división mayor por módulos; se extrajo la tarjeta de receta y se redujeron cargas iniciales. La firma release y los proveedores reales se validan en el entorno de distribución.


## Suscripción y comprobantes

La pantalla conserva el Premium vigente mientras actualiza su estado. En primera carga muestra comprobación neutral y permite reintentar; una respuesta confirmada sin suscripción revoca el estado local. Solicitudes simultáneas comparten la consulta y respuestas anteriores al pago/cambio de cuenta se descartan.

Mis comprobantes lista los pagos nuevos confirmados, con Ver recibo y Descargar PDF. Android/iOS abren un selector de destino para guardar el PDF; no se solicitan permisos generales de almacenamiento. Dependencias: https://pub.dev/packages/printing (visor) y https://pub.dev/documentation/flutter_file_dialog/latest/flutter_file_dialog/SaveFileDialogParams-class.html (guardado). El backend debe actualizarse con la migración de comprobantes antes de distribuir la app.

En Windows, agregar plugins nuevos puede requerir activar Modo de desarrollador para crear symlinks si `flutter pub get` lo solicita. No se cambió esa configuración del equipo durante esta entrega. Dependencias resueltas y APK Android verificado con `flutter build apk --debug --no-pub`.
