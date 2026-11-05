import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../widgets/nutrition_ui.dart';
import '../subscriptions/subscription_receipts_section.dart';

class MyRecordsScreen extends StatefulWidget {
  const MyRecordsScreen({super.key});
  @override
  State<MyRecordsScreen> createState() => _MyRecordsScreenState();
}

class _MyRecordsScreenState extends State<MyRecordsScreen> {
  static const categories = {
    'food': 'Alimentación y fotos IA',
    'appointments': 'Mis citas',
    'payments': 'Pagos y recargas',
    'subscriptions': 'Pagos de suscripción',
  };
  String _entity = 'food';
  DateTimeRange? _range;
  Map<String, dynamic>? _report;
  bool _loading = true, _exporting = false;
  String? _error;
  int _version = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String _day(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String get _query => Uri(
    queryParameters: {
      'entity': _entity,
      if (_range != null) 'start_date': _day(_range!.start),
      if (_range != null) 'end_date': _day(_range!.end),
    },
  ).query;
  Future<void> _load() async {
    final version = ++_version;
    final api = context.read<ApiService>();
    final owner = api.currentUserId;
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });
    try {
      final result = await api.get('/reports/mine?$_query', usarCache: false);
      if (mounted && version == _version && owner == api.currentUserId) {
        setState(() => _report = Map<String, dynamic>.from(result as Map));
      }
    } catch (e) {
      if (mounted && version == _version) setState(() => _error = e.toString());
    } finally {
      if (mounted && version == _version) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (range != null && mounted) {
      setState(() => _range = range);
      await _load();
    }
  }

  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    try {
      final bytes = await context.read<ApiService>().getBytes(
        '/reports/mine/export?$_query&file_format=$format',
      );
      final name = 'Mi_reporte_$_entity.${format == 'pdf' ? 'pdf' : 'xlsx'}';
      if (format == 'pdf') {
        await saveReceiptPdf(bytes, name);
      } else {
        await FlutterFileDialog.saveFile(
          params: SaveFileDialogParams(
            data: bytes,
            fileName: name,
            mimeTypesFilter: const [
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo descargar el reporte: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final columns = (_report?['columns'] as List?) ?? [];
    final rows = (_report?['rows'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Mis reportes')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const NutritionHeading(
              'Tu información, en un solo lugar',
              subtitle: 'Consulta y descarga tus registros. Disponible para todas las cuentas.',
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _entity,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo de reporte'),
              items: categories.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: _exporting
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _entity = value);
                        _load();
                      }
                    },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _exporting ? null : _pickRange,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    _range == null
                        ? 'Todas las fechas'
                        : '${_day(_range!.start)} a ${_day(_range!.end)}',
                  ),
                ),
                if (_range != null)
                  TextButton(
                    onPressed: () {
                      setState(() => _range = null);
                      _load();
                    },
                    child: const Text('Quitar fechas'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              NutritionCard(
                child: Column(
                  children: [
                    Text(_error!),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            if (_report != null) ...[
              Text(
                _report!['summary']?.toString() ?? '',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const NutritionEmptyState(
                  icon: Icons.bar_chart_outlined,
                  title: 'Aún no hay registros',
                  message: 'Los registros de este apartado aparecerán aquí. También puedes cambiar las fechas.',
                ),
              if (rows.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      for (final col in columns)
                        DataColumn(label: Text(col['label'].toString())),
                    ],
                    rows: [
                      for (final row in rows)
                        DataRow(
                          cells: [
                            for (final col in columns)
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 220,
                                  ),
                                  child: Text('${row[col['key']] ?? ''}'),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              for (final note in (_report!['notes'] as List? ?? []))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(note.toString()),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _exporting ? null : () => _export('pdf'),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Descargar PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _exporting ? null : () => _export('excel'),
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Descargar Excel'),
                  ),
                ],
              ),
              if (_exporting) const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
