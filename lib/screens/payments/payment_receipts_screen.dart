import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../widgets/nutrition_ui.dart';
import '../subscriptions/subscription_receipts_section.dart';

String receiptDate(dynamic raw) {
  final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (date == null) return 'Pago confirmado';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class PaymentReceiptsScreen extends StatefulWidget {
  const PaymentReceiptsScreen({super.key});
  @override
  State<PaymentReceiptsScreen> createState() => _PaymentReceiptsScreenState();
}

class _PaymentReceiptsScreenState extends State<PaymentReceiptsScreen> {
  final List<Map<String, dynamic>> _receipts = [];
  bool _loading = false, _hasMore = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<ApiService>();
    final owner = api.currentUserId;
    try {
      final data = await api.get(
        '/my-receipts?limit=50&offset=${more ? _receipts.length : 0}',
        usarCache: false,
      ) as List;
      if (mounted && owner == api.currentUserId) {
        setState(() {
          if (!more) _receipts.clear();
          _receipts.addAll(
            data.map((e) => Map<String, dynamic>.from(e as Map)),
          );
          _hasMore = data.length == 50;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mis comprobantes')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const NutritionHeading(
            'Un recibo por cada pago',
            subtitle: 'Consultas, pagos con wallet, recargas y suscripciones confirmadas.',
          ),
          const SizedBox(height: 20),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            NutritionCard(
              child: Column(
                children: [
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('Reintentar')),
                ],
              ),
            ),
          if (!_loading && _error == null && _receipts.isEmpty)
            const NutritionEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Todavía no tienes comprobantes',
              message: 'Cada pago confirmado tendrá aquí su propio recibo.',
            ),
          for (final receipt in _receipts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NutritionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt['concept'].toString(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(receipt['amount'] as num).toStringAsFixed(2)} ${receipt['currency']} · ${receipt['method']}',
                    ),
                    Text(receiptDate(receipt['paid_at'])),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PaymentReceiptDetailScreen(receipt: receipt),
                        ),
                      ),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Ver recibo detallado'),
                    ),
                  ],
                ),
              ),
            ),
          if (_hasMore && _receipts.isNotEmpty)
            TextButton(
              onPressed: _loading ? null : () => _load(more: true),
              child: const Text('Cargar más comprobantes'),
            ),
        ],
      ),
    ),
  );
}

class PaymentReceiptDetailScreen extends StatefulWidget {
  final Map<String, dynamic> receipt;
  const PaymentReceiptDetailScreen({super.key, required this.receipt});
  @override
  State<PaymentReceiptDetailScreen> createState() =>
      _PaymentReceiptDetailScreenState();
}

class _PaymentReceiptDetailScreenState
    extends State<PaymentReceiptDetailScreen> {
  bool _busy = false;
  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      final bytes = await context.read<ApiService>().getBytes(
        widget.receipt['pdf_path'] as String,
      );
      await saveReceiptPdf(bytes, 'Recibo_${widget.receipt['id']}.pdf');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo descargar el recibo. Vuelve a intentar.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.receipt;
    return Scaffold(
      appBar: AppBar(title: const Text('Recibo de pago')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          NutritionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const NutritionHeading(
                  'NutriSalud',
                  subtitle: 'Comprobante de pago',
                ),
                const SizedBox(height: 20),
                const NutritionStatus(
                  'Pagado',
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(height: 20),
                Text(
                  r['concept'].toString(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Divider(height: 32),
                Text('Cliente: ${r['buyer_name']}'),
                if (r['buyer_email'] != null)
                  Text('Correo: ${r['buyer_email']}'),
                const SizedBox(height: 16),
                Text('Fecha: ${receiptDate(r['paid_at'])}'),
                Text('Método: ${r['method']}'),
                const SizedBox(height: 16),
                Text(
                  'Total pagado: ${(r['amount'] as num).toStringAsFixed(2)} ${r['currency']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                SelectableText('Comprobante: ${r['id']}'),
                SelectableText('Referencia: ${r['reference']}'),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : _download,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Descargar recibo PDF'),
                ),
                if (_busy) const LinearProgressIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
