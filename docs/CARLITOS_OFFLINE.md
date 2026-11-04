# Carlitos generativo sin internet (Android)

## Uso

1. Instala la nueva compilación de mobile, inicia sesión y comprueba tu suscripción Premium vigente.
2. Con internet abre Carlitos y pulsa **Preparar modo sin internet** > **Descargar modelo**. La descarga es opcional y ocupa 491.400.032 bytes (aproximadamente 492 MB). Conviene usar Wi-Fi y disponer de espacio adicional para el archivo temporal.
3. Espera al mensaje **Modo sin internet preparado en este teléfono**. Solo se acepta una descarga completa cuyo SHA-256 coincide con el archivo publicado del modelo. Una descarga cancelada o incompleta no se activa y puede reintentarse.
4. Al perder internet, Carlitos genera las respuestas en el dispositivo y las identifica como **Carlitos · En tu teléfono**. Sin modelo descargado se explica cómo prepararlo; no se presentan textos fijos como si fueran generación local.
5. Al recuperar conexión, los mensajes nuevos vuelven al backend/Gemini. Las conversaciones locales se conservan en el dispositivo, separadas por cuenta; no se suben automáticamente como contexto al servidor.

## Motor y modelo

- Runtime: llamadart 0.17.5 con llama.cpp, únicamente el runtime de texto GGUF incluido mediante native assets. CPU, hasta 4 hilos, contexto de 2048 tokens y respuestas de hasta 224 tokens. El dispositivo realiza la inferencia; no se usa Ollama ni un servidor para responder offline.
- Modelo: **Qwen2.5-0.5B-Instruct Q4_K_M**, repositorio oficial Qwen, licencia Apache 2.0. Revisión fijada: `9217f5db79a29953eb74d5343926648285ec7e67`.
- SHA-256: `74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db`.
- El archivo se descarga desde Hugging Face a almacenamiento privado persistente de la app. No se incluye el modelo de 492 MB dentro del APK.
- Las bibliotecas nativas se resuelven durante la compilación; ya deben estar incluidas en el APK para funcionar sin internet. El runtime documenta Android arm64/x64; no se ha configurado el companion de iOS ni se ha validado iOS en esta entrega.
- La rapidez y calidad dependen de memoria, CPU y temperatura del dispositivo. Es un modelo pequeño para orientación general y no equivale a Gemini ni tiene acceso offline a la ficha clínica o al plan aprobado.

## Historial, permisos y fallos

El historial local se guarda con FlutterSecureStorage, bajo una clave por usuario, limitado a 80 mensajes. El prompt local incluye hasta seis mensajes recientes, con límites de tamaño para el contexto. Cambiar de cuenta limpia el estado y descarta resultados tardíos; al cerrar la pantalla se solicita cancelar/liberar el motor.

La suscripción Premium debe estar vigente en la cuenta actual (se aprovecha la verificación/caché de suscripción existente con fecha de vencimiento). Un error 401/403 o un error interno del servidor no se convierte en respuesta local para saltarse las restricciones: el cambio automático ocurre cuando no hay conexión o la petición falla por red.

Si se borra el historial sin internet, se limpia el historial local y se conserva una marca cifrada para borrar el remoto cuando vuelva la conexión, antes de cargar/enviar nuevos mensajes online.

El modo offline mantiene instrucciones para responder en español y limitarse a orientación general, sin inventar antecedentes ni cambiar planes clínicos. No analiza imágenes; el análisis de fotos sigue siendo una función online separada.

## Comprobación

- Las pruebas automatizadas verifican integridad de descarga, archivo corrupto, ausencia de modelo, respuesta local sin HTTP, persistencia por cuenta, cambio de cuenta durante generación y errores de permisos. Los archivos pequeños de prueba y un runtime simulado permiten verificar el flujo sin descargar 492 MB en cada test.
- `tool/carlitos_offline_smoke.dart RUTA_MODELO_GGUF` carga un modelo real desde un archivo local y genera un saludo en español con llama.cpp. No llama a Gemini ni descarga el modelo durante la inferencia. Se probó con los pesos oficiales verificados en el entorno Windows de desarrollo.
- La validación de rendimiento en un teléfono físico Android sigue siendo necesaria: descargar el modelo en ese teléfono, activar modo avión y enviar una consulta. La generación Windows no certifica memoria ni velocidad de cada celular.

## Referencias

- Modelo y licencia: https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF
- Integración y plataformas: https://llamadart.leehack.com/docs/intro
- Configuración de runtimes: https://llamadart.leehack.com/docs/platforms/native-build-hooks
