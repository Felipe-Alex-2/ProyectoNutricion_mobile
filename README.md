# NutriSalud móvil

Aplicación Flutter para Android. Ejecuta los comandos desde esta carpeta.

## Ejecutar

```powershell
flutter pub get
flutter run
```

Usa por defecto el mismo backend que la web en producción:
https://proyectonutricionbackend-production-8308.up.railway.app/api/v1
No es necesario iniciar el backend local ni pasar una IP del equipo.

Para conectar un backend local en el emulador Android:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

## Validar y generar APK de prueba

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

APK: `build/app/outputs/flutter-apk/app-debug.apk`.
El APK debug también apunta a Railway por defecto. Los APK release necesitan
la firma privada descrita en `DEVELOPMENT.md`.

## Registro

Selecciona una empresa. Si tiene sucursales, debes elegir una; si la consulta
confirma que no tiene ninguna, puedes crear la cuenta sin sucursal. Una falla
de conexión no se considera una lista vacía: aparece un mensaje con Reintentar.
El nombre admite hasta 100 caracteres, como el endpoint de registro.
