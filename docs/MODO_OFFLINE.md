# Mobile: copia y operaciones sin conexión

1. Instalar la versión nueva e iniciar sesión con internet.
2. En **Perfil → Copia para usar sin conexión**, esperar una fecha en **Última copia**.
3. Se descargan perfil, citas, especialistas, ficha, plan aprobado, recetas asignadas e historial alimentario. **Copiar ahora** actualiza esos datos cuando se quiera.
4. Al perder conexión aparece un aviso superior, también dentro de las pantallas secundarias. Al desplegarlo se ve la lista numerada de operaciones pendientes.
5. Se pueden solicitar citas y registrar comidas o fotografías. Las citas necesitan confirmación posterior del servidor; guardar una solicitud local no garantiza el horario.
6. Las fotos quedan guardadas de forma cifrada. La estimación con IA se realiza al recuperar internet, sin inventar resultados locales. Límite: 10 fotografías pendientes, de hasta 10 MB cada una.
7. Con conexión y la cuenta activa, la cola se sincroniza automáticamente. Los errores permanecen visibles; desde Perfil se pueden reintentar. El plan y los registros también se consultan en Alimentación y fotos IA.

Los datos se separan por cuenta y se conservan hasta 30 días desde su descarga. La fecha de última copia solo cambia si termina la descarga completa; una descarga interrumpida conserva lo obtenido y muestra un aviso. Cerrar sesión limpia la copia de lectura; las operaciones pendientes permanecen aisladas para cuando vuelva a iniciar sesión su propietario. Desinstalar la aplicación elimina los datos locales.

La sincronización automática funciona mientras la aplicación está activa o al volver a abrirla. No depende de Firebase. Para Carlitos generativo local, consultar `CARLITOS_OFFLINE.md`; requiere descargar su modelo por separado.

## Pagos con wallet sin conexión

La copia también descarga `/wallet` y `/my-payments`. Una consulta aceptada cuyo cobro esté descargado puede pagarse con wallet sin internet. Cada consulta cuesta USD 5; el importe se reserva en el dispositivo y aparece como **pendiente de sincronizar**, en la pantalla de pago y en la lista numerada general. Las reservas se restan del saldo disponible para evitar gastar dos veces el mismo saldo local. Una consulta con una orden PayPal iniciada no permite crear otro pago con wallet.

El servidor confirma el pago al reconectarse y comprueba el saldo real, la propiedad y el estado de la cita. Si otro dispositivo gastó el saldo o cambió el cobro, la solicitud puede rechazarse y queda visible con su error. Solo después de confirmar se descuenta en el registro oficial, se confirma la cita y se habilita el comprobante. Una respuesta perdida no produce otro débito; un movimiento ya confirmado no se resta otra vez como reserva local. Las recargas de PayPal necesitan internet.

Pruebas adicionales: `flutter test --no-pub test/offline_wallet_test.dart test/offline_wallet_screen_test.dart test/wallet_screen_test.dart`.

## Validación

`flutter analyze --no-pub lib/main.dart lib/modo_offline lib/services/api_service.dart lib/services/auth_service.dart lib/services/food_vision_service.dart lib/screens/food lib/screens/home/home_screen.dart test/offline_copy_photo_test.dart`

`flutter test --no-pub test/offline_copy_photo_test.dart test/nutrition_diary_test.dart test/nutrition_diary_screen_test.dart test/api_security_test.dart`

Probar en un teléfono: iniciar sesión, esperar la copia, activar modo avión, abrir el plan, solicitar una cita futura y tomar una foto. Cerrar y reabrir la app, revisar el contador, desactivar modo avión y comprobar la sincronización. Una respuesta perdida debe reutilizar el mismo identificador, sin duplicar registros.
