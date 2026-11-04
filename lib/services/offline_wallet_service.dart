import 'dart:math';

import '../modo_offline/cola_sincronizacion_service.dart';
import '../modo_offline/elemento_cola.dart';
import 'api_service.dart';

/// Offline payments reserve local funds; only the server can settle the ledger.
class OfflineWalletService {
  final ApiService api;
  final ColaSincronizacionService queue;
  bool _saving = false;
  OfflineWalletService(this.api, this.queue);

  ElementoCola? pendingFor(String appointmentId) => queue.elementos
      .where(
        (e) =>
            e.userId == api.currentUserId &&
            e.tipoAccion == 'PAGAR_WALLET' &&
            e.metadata?['appointment_id'] == appointmentId,
      )
      .firstOrNull;

  double reserved(Map<String, dynamic>? wallet) {
    final settled = ((wallet?['movements'] as List?) ?? [])
        .where((m) => ((m['amount'] as num?) ?? 0) < 0)
        .map((m) => m['payment_id'])
        .toSet();
    return queue.elementos
            .where(
              (e) =>
                  e.userId == api.currentUserId &&
                  e.tipoAccion == 'PAGAR_WALLET' &&
                  !e.estado.startsWith('ERROR') &&
                  !settled.contains(e.metadata?['payment_id']),
            )
            .length *
        5.0;
  }

  double available(Map<String, dynamic>? wallet) =>
      max(
        0,
        (((wallet?['balance'] as num?) ?? 0) * 100).round() -
            (reserved(wallet) * 100).round(),
      ) /
      100;

  Future<Map<String, dynamic>> pay(String appointmentId) async {
    if (_saving) throw StateError('Espera a que termine la operación actual.');
    final owner = api.currentUserId;
    if (owner == null) throw StateError('Inicia sesión para pagar con wallet.');
    _saving = true;
    try {
      await queue.asegurarCuenta(owner);
      if (owner != api.currentUserId) throw StateError('La cuenta cambió.');
      if (pendingFor(appointmentId) != null) {
        throw StateError(
          'Esta consulta ya tiene un pago con wallet pendiente.',
        );
      }
      final wallet = await api.get('/wallet');
      final payments = await api.get('/my-payments');
      if (owner != api.currentUserId) throw StateError('La cuenta cambió.');
      final charge = payments is List
          ? payments
                .where((p) => p['appointment_id'] == appointmentId)
                .firstOrNull
          : null;
      if (charge == null) {
        throw StateError(
          'Descarga primero la cita aceptada y su cobro con internet.',
        );
      }
      if (charge['status'] == 'COMPLETED') {
        return {'status': 'COMPLETED', 'payment_id': charge['id']};
      }
      if (charge['status'] != 'PENDING' ||
          charge['cashier_id'] != null ||
          charge['paypal_order_id'] != null) {
        throw StateError(
          'Este cobro no permite pagar con wallet. Revisa su estado con internet.',
        );
      }
      if (wallet is! Map<String, dynamic> || available(wallet) < 5) {
        throw StateError(
          'Saldo disponible insuficiente: los pagos pendientes ya reservan su importe. Recarga con internet desde Perfil.',
        );
      }
      final operation = ElementoCola(
        id: 'wallet_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}',
        userId: owner,
        metodo: 'POST',
        endpoint: '/appointments/$appointmentId/pay',
        cuerpo: {'method': 'WALLET', 'mobile': true},
        tipoAccion: 'PAGAR_WALLET',
        descripcionHumana: 'Pago de consulta con wallet · USD 5',
        fechaCreacion: DateTime.now(),
        metadata: {
          'appointment_id': appointmentId,
          'payment_id': charge['id'],
          'amount': 5,
        },
      );
      try {
        if (api.conectividadService?.estaConectado == false) {
          throw ApiException('Sin conexión', statusCode: 0);
        }
        final result = await api.post(
          operation.endpoint,
          body: operation.cuerpo,
          idempotencyKey: operation.id,
        );
        return Map<String, dynamic>.from(result);
      } on ApiException catch (error) {
        if (error.statusCode != 0 || owner != api.currentUserId) rethrow;
        await queue.encolar(operation);
        return {
          'status': 'PENDING_SYNC',
          'payment_id': charge['id'],
          'offline_pending': true,
        };
      }
    } finally {
      _saving = false;
    }
  }
}
