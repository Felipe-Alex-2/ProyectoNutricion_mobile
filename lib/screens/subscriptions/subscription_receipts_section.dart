import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/subscription_receipt.dart';
import '../../services/subscription_service.dart';
import '../../widgets/nutrition_ui.dart';

Future<bool> saveReceiptPdf(Uint8List bytes, String filename) async {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    final saved = await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(
        data: bytes,
        fileName: filename,
        mimeTypesFilter: const ['application/pdf'],
      ),
    );
    return saved != null;
  }
  return Printing.sharePdf(bytes: bytes, filename: filename);
}

class SubscriptionReceiptsSection extends StatefulWidget {
  final bool showLatestOnly;
  const SubscriptionReceiptsSection({super.key, this.showLatestOnly = false});
  @override
  State<SubscriptionReceiptsSection> createState() =>
      _SubscriptionReceiptsSectionState();
}

class _SubscriptionReceiptsSectionState
    extends State<SubscriptionReceiptsSection> {
  String? _busyId;
  Future<void> _open(
    SubscriptionReceipt receipt, {
    required bool download,
  }) async {
    final service = context.read<SubscriptionService>();
    setState(() => _busyId = receipt.id);
    try {
      final bytes = await service.downloadReceipt(receipt);
      if (!mounted) return;
      if (download) {
        final saved = await saveReceiptPdf(bytes, receipt.filename);
        if (mounted && saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Comprobante guardado.')),
          );
        }
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                SubscriptionReceiptPdfScreen(receipt: receipt, bytes: bytes),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo abrir o guardar el PDF. Revisa tu conexión e intenta de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _date(DateTime date) {
    final local = date.toLocal();
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SubscriptionService>();
    final receipts = widget.showLatestOnly
        ? service.receipts.take(1)
        : service.receipts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Mis comprobantes',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar comprobantes',
              onPressed: service.receiptsLoading
                  ? null
                  : () => service.fetchReceipts(),
              icon: const Icon(Icons.refresh),
            ),
            if (widget.showLatestOnly)
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SubscriptionReceiptsScreen(),
                  ),
                ),
                child: const Text('Ver todos'),
              ),
          ],
        ),
        const Text('Tus pagos confirmados, siempre disponibles.'),
        const SizedBox(height: 12),
        if (service.receiptsLoading) const LinearProgressIndicator(),
        if (service.receiptsError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(service.receiptsError!),
          ),
        if (service.receipts.isEmpty &&
            !service.receiptsLoading &&
            service.receiptsError == null)
          const NutritionEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Tu próximo pago quedará aquí',
            message: 'Al confirmar un pago podrás ver y descargar su comprobante en PDF.',
          ),
        for (final receipt in receipts)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const NutritionIcon(Icons.receipt_long_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _date(receipt.paidAt),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Suscripción Premium',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${receipt.amount.toStringAsFixed(2)} ${receipt.currency}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const NutritionStatus('Pagado'),
                    ],
                  ),
                  if (receipt.isSandbox)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Sandbox · pago de prueba',
                        style: TextStyle(color: Colors.deepOrange),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Divider(),
                  if (_busyId == receipt.id) const LinearProgressIndicator(),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: _busyId == null
                            ? () => _open(receipt, download: false)
                            : null,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Ver recibo'),
                      ),
                      TextButton.icon(
                        onPressed: _busyId == null
                            ? () => _open(receipt, download: true)
                            : null,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Descargar PDF'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (!widget.showLatestOnly && service.hasMoreReceipts)
          TextButton(
            onPressed: service.receiptsLoading
                ? null
                : () => service.fetchReceipts(loadMore: true),
            child: const Text('Ver más comprobantes'),
          ),
      ],
    );
  }
}

class SubscriptionReceiptsScreen extends StatefulWidget {
  const SubscriptionReceiptsScreen({super.key});
  @override
  State<SubscriptionReceiptsScreen> createState() =>
      _SubscriptionReceiptsScreenState();
}

class _SubscriptionReceiptsScreenState
    extends State<SubscriptionReceiptsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SubscriptionService>().fetchReceipts();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Comprobantes de pago')),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: () => context.read<SubscriptionService>().fetchReceipts(),
        child: const SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(20),
          child: SubscriptionReceiptsSection(),
        ),
      ),
    ),
  );
}

class SubscriptionReceiptPdfScreen extends StatefulWidget {
  final SubscriptionReceipt receipt;
  final Uint8List bytes;
  const SubscriptionReceiptPdfScreen({
    super.key,
    required this.receipt,
    required this.bytes,
  });
  @override
  State<SubscriptionReceiptPdfScreen> createState() =>
      _SubscriptionReceiptPdfScreenState();
}

class _SubscriptionReceiptPdfScreenState
    extends State<SubscriptionReceiptPdfScreen> {
  bool _saving = false;
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = await saveReceiptPdf(widget.bytes, widget.receipt.filename);
      if (mounted && saved) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Comprobante guardado.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar el comprobante. Intenta de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Comprobante de pago'),
      actions: [
        IconButton(
          tooltip: 'Descargar PDF',
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.download_outlined),
        ),
      ],
    ),
    body: Column(
      children: [
        if (_saving) const LinearProgressIndicator(),
        Expanded(
          child: PdfPreview(
            build: (_) async => widget.bytes,
            pdfFileName: widget.receipt.filename,
            useActions: false,
            canDebug: false,
            canChangeOrientation: false,
            canChangePageFormat: false,
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.download_outlined),
          label: Text(_saving ? 'Guardando…' : 'Descargar PDF'),
        ),
      ),
    ),
  );
}
