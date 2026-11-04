import '../../modo_offline/conectividad_service.dart';
import '../../services/offline_wallet_service.dart';
import '../../modo_offline/cola_sincronizacion_service.dart';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/appointment_service.dart';
import '../../widgets/nutrition_ui.dart';
import '../subscriptions/subscription_receipts_section.dart';

class WalletScreen extends StatefulWidget {
  final String? appointmentId;
  const WalletScreen({super.key, this.appointmentId});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with WidgetsBindingObserver {
  static const _paymentsUnavailable =
      'Los pagos online no están disponibles temporalmente. No se realizó ningún cobro. Intenta más tarde o contacta a la clínica.';
  Map<String, dynamic>? _wallet;
  List<Map<String, dynamic>> _payments = [];
  bool _busy = false;
  bool _hadWalletPending = false;
  String? _error, _message;
  String? _activeOrderId;
  final Map<int, String> _keys = {};
  bool get _isWallet => widget.appointmentId == null;
  Iterable<Map<String, dynamic>> get _visiblePayments => _payments.where(
    (p) => _isWallet
        ? p['purpose'] == 'WALLET_TOPUP' ||
              p['payment_method'] == 'WALLET' ||
              p['appointment_id'] == null
        : p['appointment_id'] == widget.appointmentId,
  );
  ApiService get _api => context.read<ApiService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resumeAndVerify());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _resumeAndVerify();
  }

  Future<void> _resumeAndVerify() async {
    await _load();
    if (!mounted || _busy) return;
    final pending = _visiblePayments
        .where(
          (p) =>
              p['status'] == 'PENDING' &&
              p['paypal_order_id'] != null &&
              (_activeOrderId == null ||
                  p['paypal_order_id'] == _activeOrderId),
        )
        .take(1)
        .toList();
    for (final payment in pending) {
      if (!mounted) return;
      await _verify(payment, automatic: true);
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    await _run(() async {
      Object? loadError;
      final results = await Future.wait([
        _api.get('/wallet').catchError((Object e) {
          loadError = e;
          return null;
        }),
        _api.get('/my-payments').catchError((Object e) {
          loadError = e;
          return null;
        }),
      ]);
      if (!mounted) return;
      setState(() {
        if (loadError == null && _error == _paymentsUnavailable) _error = null;
        _wallet = results[0] is Map
            ? Map<String, dynamic>.from(results[0])
            : null;
        _payments = results[1] is List
            ? (results[1] as List)
                  .map((p) => Map<String, dynamic>.from(p))
                  .toList()
            : [];
      });
      if (loadError != null) throw loadError!;
    }, clearError: false);
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool clearError = true,
  }) async {
    if (!mounted || _busy) return;
    setState(() {
      _busy = true;
      if (clearError) {
        _error = null;
        _message = null;
      }
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException && e.statusCode == 404
              ? _paymentsUnavailable
              : e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openOrder(dynamic result) async {
    if (result['status'] == 'COMPLETED') {
      if (mounted) {
        setState(
          () => _message =
              'Pago completado. Actualiza para ver el saldo y la cita.',
        );
      }
      return;
    }
    _activeOrderId = result['paypal_order_id'] as String?;
    final url = result['approval_url'] as String?;
    if (url != null && url.isNotEmpty) {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw Exception('No se pudo abrir PayPal. Vuelve a intentar.');
      }
    }
    if (mounted) {
      setState(
        () => _message =
            'Completa PayPal y vuelve aquí para pulsar Verificar pago.',
      );
    }
  }

  Future<void> _topup(int amount) async {
    await _run(() async {
      final key = _keys.putIfAbsent(
        amount,
        () =>
            'topup_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}',
      );
      final result = await _api.post(
        '/wallet/topups',
        body: {'amount': amount},
        idempotencyKey: key,
      );
      await _openOrder(result);
      if (result['status'] == 'COMPLETED') _keys.remove(amount);
    });
    await _load();
  }

  Future<void> _pay(String method) async {
    if (method == 'WALLET') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar pago con wallet'),
          content: const Text(
            'Se usarán USD 5 de tu wallet. Sin internet, el importe quedará reservado en este dispositivo y el pago pendiente de validación al reconectarse.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pagar USD 5'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await _run(() async {
      final offlineWallet = context.read<OfflineWalletService?>();
      final result = method == 'WALLET' && offlineWallet != null
          ? await offlineWallet.pay(widget.appointmentId!)
          : await _api.post(
              '/appointments/${widget.appointmentId}/pay',
              body: {'method': method, 'mobile': true},
            );
      if (result['offline_pending'] == true) {
        if (mounted) {
          setState(
            () => _message = 'Pago con wallet guardado como pendiente. USD 5 reservados en este dispositivo. Se confirmará al recuperar internet y validar el saldo.',
          );
        }
        return;
      }
      if (method == 'PRESENCIAL') {
        if (mounted) {
          setState(
            () => _message = 'Elegiste pago presencial. Abona USD 5 en caja; el pago sigue pendiente.',
          );
        }
      } else {
        await _openOrder(result);
      }
      if (mounted) await context.read<AppointmentService>().fetchAppointments();
    });
    await _load();
    if (mounted && method == 'WALLET') {
      final paid = _visiblePayments
          .where((p) => p['status'] == 'COMPLETED')
          .firstOrNull;
      if (paid != null) {
        _showReceipt(paid);
      }
    }
  }

  Future<void> _verify(
    Map<String, dynamic> payment, {
    bool automatic = false,
  }) async {
    await _run(() async {
      try {
        await _api.post(
          '/payments/capture',
          body: {'paypal_order_id': payment['paypal_order_id']},
        );
      } on ApiException catch (error) {
        if (automatic && error.statusCode == 409) return;
        rethrow;
      }
      if (!mounted) return;
      _keys.clear();
      setState(
        () => _message = payment['purpose'] == 'WALLET_TOPUP'
            ? 'Recarga confirmada. Tu saldo ya está disponible.'
            : 'Pago confirmado. Tu cita está confirmada.',
      );
      await context.read<AppointmentService>().fetchAppointments();
    });
    await _load();
  }

  Future<void> _cancelChoice() async {
    await _run(() async {
      final result = await _api.post(
        '/appointments/${widget.appointmentId}/cancel-payment-choice',
        body: {},
      );
      _activeOrderId = null;
      if (mounted) {
        setState(
          () => _message = result['status'] == 'COMPLETED'
              ? 'PayPal ya había aprobado el pago. La consulta quedó pagada.'
              : 'Selección cancelada. Puedes elegir otro método de pago.',
        );
      }
      if (mounted) await context.read<AppointmentService>().fetchAppointments();
    });
    await _load();
  }

  Future<void> _showReceipt(Map<String, dynamic> payment) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recibo de pago'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(payment['concept']?.toString() ?? 'Consulta general'),
              const SizedBox(height: 12),
              Text(
                'Importe: USD ${(payment['amount'] as num).toStringAsFixed(2)}',
              ),
              Text('Método: ${payment['payment_method']}'),
              Text(
                'Fecha: ${payment['paid_at'] ?? payment['created_at'] ?? 'Pago confirmado'}',
              ),
              Text('Referencia: ${payment['id']}'),
              const Text('Estado: Pagado'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ColaSincronizacionService?>();
    context.watch<ConectividadService?>();
    final offlineWallet = context.read<OfflineWalletService?>();
    final walletPending = widget.appointmentId == null
        ? null
        : offlineWallet?.pendingFor(widget.appointmentId!);
    if (_hadWalletPending && walletPending == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_busy) _load();
      });
    }
    _hadWalletPending = walletPending != null;
    final offline = _api.conectividadService?.estaConectado == false;
    final pending = _visiblePayments
        .where((p) => p['status'] == 'PENDING' && p['paypal_order_id'] != null)
        .toList();
    final charge = _payments
        .where(
          (p) =>
              p['appointment_id'] == widget.appointmentId &&
              widget.appointmentId != null,
        )
        .firstOrNull;
    final paid = charge?['status'] == 'COMPLETED';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.appointmentId == null
              ? 'Mi wallet y pagos'
              : 'Pago de consulta general',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_message!),
              ),
            NutritionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Saldo disponible en wallet · USD'),
                  const SizedBox(height: 8),
                  Text(
                    _wallet == null
                        ? '—'
                        : '\$${(offlineWallet?.available(_wallet) ?? (_wallet!['balance'] as num).toDouble()).toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  if (offlineWallet != null &&
                      offlineWallet.reserved(_wallet) > 0)
                    Text(
                      'USD ${offlineWallet.reserved(_wallet).toStringAsFixed(2)} reservados en pagos pendientes. Saldo confirmado: USD ${(_wallet?['balance'] as num?)?.toStringAsFixed(2) ?? '—'}.',
                    ),
                  if (offline)
                    const Text(
                      'Sin conexión: se muestra el último saldo descargado. Las recargas PayPal requieren internet.',
                    ),
                  if (_isWallet) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Recarga con PayPal Sandbox. El saldo se acredita después de verificar el pago.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final amount in [5])
                          OutlinedButton(
                            onPressed: _busy || offline || _wallet == null
                                ? null
                                : () => _topup(amount),
                            child: Text(
                              'Recargar wallet USD $amount con PayPal',
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (widget.appointmentId != null)
              NutritionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const NutritionHeading('Consulta general · USD 5'),
                    const SizedBox(height: 12),
                    if (paid)
                      const NutritionStatus(
                        'Confirmada · pagada',
                        icon: Icons.check_circle,
                      )
                    else if (walletPending != null)
                      Text(
                        walletPending.mensajeError ?? 'Pago con wallet pendiente de sincronizar · USD 5. La cita se confirmará cuando el servidor valide el pago.',
                      )
                    else if (charge == null)
                      const Text(
                        'El especialista debe aceptar la cita para habilitar el pago.',
                      )
                    else if (charge['status'] != 'PENDING')
                      Text('Cobro ${charge['status']}. Actualiza tus citas.')
                    else ...[
                      const Text(
                        'Cita aceptada. Completa el pago para confirmar tu reserva.',
                      ),
                      const SizedBox(height: 16),
                      const Text('¿Cómo deseas pagar?'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed:
                                _busy ||
                                    offline ||
                                    charge['paypal_order_id'] != null
                                ? null
                                : () => _pay('PRESENCIAL'),
                            icon: const Icon(Icons.storefront_outlined),
                            label: const Text('Presencial · USD 5'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy || offline
                                ? null
                                : () => _pay('ONLINE'),
                            icon: const Icon(Icons.language),
                            label: const Text('Online · PayPal · USD 5'),
                          ),
                        ],
                      ),
                      if (charge['payment_method'] == 'PRESENCIAL') ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Pago presencial seleccionado. Pendiente de cobro en caja; elegir esta opción no registra un pago.',
                        ),
                      ],
                      if (charge['payment_method'] != 'PENDING' ||
                          charge['paypal_order_id'] != null)
                        TextButton.icon(
                          onPressed: _busy || offline ? null : _cancelChoice,
                          icon: const Icon(Icons.close),
                          label: const Text(
                            'Cancelar selección y volver a elegir',
                          ),
                        ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed:
                            _busy ||
                                _wallet == null ||
                                charge['paypal_order_id'] != null
                            ? null
                            : () => _pay('WALLET'),
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                        label: const Text('Pagar USD 5 con wallet'),
                      ),
                    ],
                  ],
                ),
              ),
            for (final p in pending) ...[
              const SizedBox(height: 12),
              NutritionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p['concept']} · \$${p['amount']} USD'),
                    const SizedBox(height: 8),
                    const Text(
                      'Pago iniciado. Si ya lo aprobaste, verifica el resultado.',
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              final result = await _api.post(
                                '/my-payments/${p['id']}/checkout',
                                body: {},
                              );
                              await _openOrder(result);
                            }),
                      child: const Text('Volver a abrir PayPal'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => _verify(p),
                      child: const Text('Verificar pago'),
                    ),
                  ],
                ),
              ),
            ],
            if (_isWallet) ...[
              const SizedBox(height: 20),
              const NutritionHeading('Historial de movimientos'),
              if (_wallet != null && (_wallet!['movements'] as List).isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Aún no tienes movimientos en tu wallet.'),
                ),
              if (_wallet != null)
                for (final m in _wallet!['movements'])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      (m['amount'] as num) > 0
                          ? Icons.add_circle_outline
                          : Icons.remove_circle_outline,
                    ),
                    title: Text(m['concept']),
                    subtitle: Text(m['created_at'].toString().substring(0, 10)),
                    trailing: Text(
                      '\$${(m['amount'] as num).toStringAsFixed(2)}',
                    ),
                  ),
            ],
            const SizedBox(height: 20),
            const NutritionHeading('Mis comprobantes'),
            for (final p in _visiblePayments.where(
              (p) => p['status'] == 'COMPLETED',
            ))
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => _showReceipt(p),
                title: Text(p['concept']),
                subtitle: Text('\$${p['amount']} USD · ${p['payment_method']}'),
                trailing: IconButton(
                  tooltip: 'Descargar comprobante',
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          final bytes = await _api.getBytes(
                            '/payments/${p['id']}/pdf',
                          );
                          await saveReceiptPdf(
                            bytes,
                            'Comprobante_${p['id']}.pdf',
                          );
                        }),
                  icon: const Icon(Icons.download_outlined),
                ),
              ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar saldo y pagos'),
            ),
          ],
        ),
      ),
    );
  }
}
