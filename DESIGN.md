# Interfaz de NutriSalud

Rediseño implementado a partir de las láminas aprobadas: verde bosque, salvia, fondo claro, tarjetas blancas, iconos de línea y controles uniformes. El nombre real de la aplicación sigue siendo NutriSalud. Los nombres, precios y fotos de personas de las láminas eran ejemplos; la aplicación muestra los datos que devuelve el backend.

## Sistema visual

- Principal: `#206443`; fondo claro: `#F7F9F4`; salvia: `#E6F0EB`; texto: `#172920`; secundario: `#65756B`.
- Naranja `#E0873E` para pequeños acentos y dorado `#EFC66C` para Premium.
- Tema oscuro con superficies verdes profundas, texto claro y acentos salvia. Botones con contraste definido en el tema.
- Tarjetas de 20 px, botones de 16 px, acción principal de al menos 52 px. Separación habitual de 20–24 px.
- Roboto se incluye localmente como `NutriSans`, con pesos 400/500/700, para mantener la tipografía sin descargar fuentes. Licencia Apache 2.0 en `assets/fonts/LICENSE-Roboto.txt`.
- Componentes compartidos en `lib/widgets/nutrition_ui.dart`; configuración en `lib/config/theme.dart`.

## Pantallas y comportamiento

Acceso, registro y recuperación tienen el nuevo estilo. Se conservan la selección de sucursal y el código temporal real de recuperación; el backend no utiliza el enlace ilustrado en el concepto.

Inicio muestra próximas citas, estado de suscripción, resumen del plan y accesos a ficha de salud y Carlitos. Se retiró el acceso flotante morado que tapaba contenido. El plan utiliza las imágenes reales de las recetas; si no existen, muestra un estado gráfico neutro.

Mi nutricionista incluye contacto por correo y WhatsApp, detalles de vinculación, solicitud de cita e historial separado entre próximas y anteriores. Los estados de citas pendientes, canceladas, sin conexión y con conflicto siguen disponibles.

La ficha de salud conserva sus campos y su consentimiento en secciones plegables. Cerrar una sección no borra lo escrito. Perfil reúne información de cuenta, apariencia, notificaciones, ficha y comprobantes.

Notificaciones ofrece Todas/Sin leer, grupos Hoy/Ayer/fecha, indicadores verdes, marcar leídas y enlaces a las secciones de citas, plan y suscripción. Los tipos sin destino conocido permiten marcar leída. El sondeo y las notificaciones recibidas siguen dependiendo de los servicios existentes; este cambio no añade notificaciones push del sistema con la aplicación cerrada.

Suscripciones conserva la comprobación neutral inicial y el Premium vigente durante una actualización. Presenta las herramientas en tarjetas, el comprobante reciente y un historial completo accesible también desde Perfil. El PDF conserva su guardado mediante el selector nativo y añade una acción inferior visible. El checkout y la verificación de PayPal siguen usando el backend; no se realizaron pagos reales.

El generador de menús en `AiModuleScreen` continúa en desarrollo, como en la aplicación anterior. Se presenta claramente y ofrece acceso al chat existente de Carlitos. No se añadieron resultados de IA simulados. El análisis de alimentos comienza solicitando una fotografía; ya no precarga automáticamente la antigua imagen con un teléfono y valores impresos.

## Validación

`flutter analyze --no-pub`, `flutter test --no-pub` y `flutter build apk --debug --no-pub`.

Las pruebas de rediseño navegan por las cinco secciones, enlaces de notificaciones, historial, recetas, ficha y solicitud de cita. Comprueban 320 px con texto al 130 %, 390 px, temas claro/oscuro y persistencia de campos al plegar. Usan un cliente HTTP simulado, sin acceder a pacientes, Railway o PayPal reales.

Para capturas locales, ejecutar `flutter test --no-pub test/mobile_redesign_test.dart --dart-define=UI_CAPTURE_DIR=RUTA_ABSOLUTA`. Sin esta opción las pruebas no guardan imágenes. Las capturas muestran datos ficticios y el render de Flutter en pruebas, no una sesión en un dispositivo físico.

El APK debug utiliza por defecto `http://10.0.2.2:8000/api/v1` (backend local del emulador). Para otro entorno: `flutter build apk --debug --dart-define=API_BASE_URL=https://TU_BACKEND/api/v1`. No se cambió la URL de producción ni se desplegó esta entrega. La distribución release y las migraciones del backend siguen los pasos de `DEVELOPMENT.md`.

## Imagen de bienvenida

Archivo utilizado: `assets/images/welcome_nutrition.png`. Se generó con la herramienta integrada `image_gen`, se inspeccionó y se copió al proyecto. Se usa como fotografía ilustrativa de bienvenida y en el módulo de recomendaciones; no reemplaza imágenes de recetas reales.

Prompt utilizado:

> Create a photorealistic editorial food photograph for the welcome screen of a Spanish nutrition and wellbeing mobile app. Landscape 3:2 composition. Close-up overhead three-quarter view of a beautiful balanced quinoa salad bowl with cherry tomatoes, cucumber, avocado, leafy greens and chickpeas on a warm pale natural stone table. Soft morning daylight, fresh natural appetizing colors, premium understated food photography, deep leafy green hues, off-white neutral surroundings, realistic portion, crisp focus on salad with gentle depth of field. Bowl and ingredients fill frame; aesthetically balanced crop usable in a wide banner. No people, no hands, no phones, no lettering, no labels, no logos, no watermarks, no UI, no nutrition measurements. This is a real food asset, not a screenshot.
