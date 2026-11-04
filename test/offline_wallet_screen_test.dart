import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:mobile/services/appointment_service.dart';
import 'package:mobile/services/offline_wallet_service.dart';
import 'package:mobile/modo_offline/cache_local_service.dart';
import 'package:mobile/modo_offline/cola_sincronizacion_service.dart';
import 'package:mobile/modo_offline/conectividad_service.dart';
import 'package:mobile/screens/payments/wallet_screen.dart';

class _OfflineConnection extends ConectividadService {
  _OfflineConnection() : super(iniciarMonitoreo: false);
  @override
  bool get estaConectado => false;
}

void main() {
  testWidgets(
    'Offline wallet shows reserved funds and a pending payment, not a completed receipt',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dir = await tester.runAsync(
        () => Directory.systemTemp.createTemp('nutri-wallet-ui-'),
      );
      final queue = ColaSincronizacionService(documentsDirectory: dir!);
      await tester.runAsync(() => queue.asegurarCuenta('patient'));
      final cache = CacheLocalService();
      await cache.guardar('/wallet', {
        'balance': 5,
        'movements': [],
        'currency': 'USD',
      }, userId: 'patient');
      await cache.guardar('/my-payments', [
        {
          'id': 'charge',
          'appointment_id': 'appointment',
          'status': 'PENDING',
          'concept': 'Consulta general',
          'amount': 5,
          'payment_method': 'PENDING',
        },
      ], userId: 'patient');
      final connection = _OfflineConnection();
      final api = ApiService(
        StorageService(),
        cacheService: cache,
        conectividadService: connection,
      )..currentUserId = 'patient';
      final appointments = AppointmentService(api);
      final wallet = OfflineWalletService(api, queue);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiService>.value(value: api),
            Provider<OfflineWalletService>.value(value: wallet),
            ChangeNotifierProvider<ColaSincronizacionService>.value(
              value: queue,
            ),
            ChangeNotifierProvider<ConectividadService>.value(
              value: connection,
            ),
            ChangeNotifierProvider<AppointmentService>.value(
              value: appointments,
            ),
          ],
          child: const MaterialApp(
            home: WalletScreen(appointmentId: 'appointment'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Pagar USD 5 con wallet'));
      await tester.tap(find.text('Pagar USD 5 con wallet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pagar USD 5'));
      await tester.pumpAndSettle();
      expect(queue.elementos.single.tipoAccion, 'PAGAR_WALLET');
      expect(
        find.textContaining('Pago con wallet pendiente de sincronizar'),
        findsOneWidget,
      );
      expect(find.textContaining('USD 5.00 reservados'), findsOneWidget);
      expect(find.text('Confirmada · pagada'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      queue.dispose();
      connection.dispose();
      appointments.dispose();
      api.dispose();
      await tester.runAsync(() async {
        if (!dir.absolute.path.startsWith(Directory.systemTemp.absolute.path) ||
            !dir.uri.pathSegments
                .where((s) => s.isNotEmpty)
                .last
                .startsWith('nutri-wallet-ui-')) {
          throw StateError('Unexpected test path');
        }
        await dir.delete(recursive: true);
      });
    },
  );
}
