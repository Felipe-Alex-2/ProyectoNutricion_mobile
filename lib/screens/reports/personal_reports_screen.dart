import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import 'my_records_screen.dart';

class PersonalReportsScreen extends StatefulWidget {
  const PersonalReportsScreen({super.key});
  @override
  State<PersonalReportsScreen> createState() => _PersonalReportsScreenState();
}

class _PersonalReportsScreenState extends State<PersonalReportsScreen> {
  final _command = TextEditingController();
  final _search = TextEditingController();
  final _status = TextEditingController();
  final _speech = SpeechToText();
  final _tts = FlutterTts();
  List<dynamic> _entities = [], _saved = [], _companies = [], _branches = [];
  Map<String, dynamic> _query = {'entity': 'patients', 'limit': 500};
  Map<String, dynamic>? _report, _reportQuery;
  String? _error, _explanation, _savedId;
  bool _busy = true, _listening = false, _speaking = false;
  int _generation = 0;
  ApiService get api => context.read<ApiService>();
  List<dynamic> get _columns =>
      (_entities
              .where((e) => e['entity'] == _query['entity'])
              .firstOrNull?['available_columns']
          as List?) ??
      [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _generation++;
    _speech.cancel();
    _tts.stop();
    _command.dispose();
    _search.dispose();
    _status.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final entities = await api.get('/reports/entities', usarCache: false);
      if (!mounted) return;
      setState(() {
        _entities = entities as List;
        _busy = false;
      });
      try {
        final scope = await api.get('/reports/scope', usarCache: false);
        if (mounted) {
          setState(() {
            _companies = scope['companies'];
            _branches = scope['branches'];
          });
        }
      } catch (e) {
        if (mounted) setState(() => _error = '$e');
      }
      await _run();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  void _change(String key, dynamic value) {
    setState(() {
      if (key == 'tenant_id') {
        _query.remove('branch_ids');
      }
      if (key == 'entity') {
        _query = {
          'entity': value,
          'limit': 500,
          if (_query['tenant_id'] != null) 'tenant_id': _query['tenant_id'],
          if (_query['branch_ids'] != null) 'branch_ids': _query['branch_ids'],
        };
        _search.clear();
        _status.clear();
        return;
      }
      if (value == null) {
        _query.remove(key);
      } else {
        _query[key] = value;
      }
    });
  }

  Future<void> _run({bool voice = false}) async {
    final version = ++_generation;
    final owner = api.currentUserId;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_speaking) await _tts.stop();
      final request = Map<String, dynamic>.from(_query);
      final result = await api.post(
        voice ? '/reports/voice-command' : '/reports/query',
        body: voice
            ? {
                'transcript': _command.text,
                if (_query['tenant_id'] != null)
                  'tenant_id': _query['tenant_id'],
                if (_query['branch_ids'] != null)
                  'branch_ids': _query['branch_ids'],
              }
            : request,
      );
      if (!mounted || version != _generation || owner != api.currentUserId) {
        return;
      }
      setState(() {
        if (voice) {
          _query = Map<String, dynamic>.from(result['parsed_request']);
          _report = Map<String, dynamic>.from(result['report_data']);
          _explanation = result['explanation'];
          _search.text = _query['search'] ?? '';
          _status.text = _query['status'] ?? '';
        } else {
          _report = Map<String, dynamic>.from(result);
          _explanation = null;
        }
        _reportQuery = Map<String, dynamic>.from(voice ? _query : request);
        _savedId = null;
      });
    } catch (e) {
      if (mounted && version == _generation) setState(() => _error = '$e');
    } finally {
      if (mounted && version == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _dictate() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    try {
      await _tts.stop();
      final ready = await _speech.initialize(
        onStatus: (status) {
          if (mounted) setState(() => _listening = status == 'listening');
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _listening = false;
              _error = 'No se pudo escuchar. Revisa el permiso de micrófono o escribe tu consulta.';
            });
          }
        },
      );
      if (!ready) {
        throw Exception(
          'Activa el permiso de micrófono y el reconocimiento de voz del teléfono. También puedes escribir.',
        );
      }
      final locales = await _speech.locales();
      final spanish = locales
          .where((l) => l.localeId.startsWith('es'))
          .firstOrNull;
      await _speech.listen(
        onResult: (r) {
          if (mounted) setState(() => _command.text = r.recognizedWords);
        },
        listenOptions: SpeechListenOptions(
          localeId: spanish?.localeId,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _speak() async {
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() {
      _speaking = true;
      _error = null;
    });
    try {
      await _speech.stop();
      final r = _report!;
      final summary = await api.post(
        '/reports/voice-summary',
        body: {
          'entity': r['entity'],
          'title': r['title'],
          'total_rows': r['total_rows'],
          'summary': r['summary'],
          'notes': r['notes'] ?? [],
          'columns': [for (final c in r['columns']) c['label']],
          'sample_rows': (r['rows'] as List).take(20).toList(),
        },
      );
      if (!mounted || !_speaking) return;
      await _tts.setLanguage('es-ES');
      await _tts.setSpeechRate(0.45);
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(
        '${summary['summary_text']}. ${(summary['bullet_points'] as List? ?? []).join('. ')}',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo reproducir el resumen: $e');
      }
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _export(String format) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = _savedId != null
          ? await api.getBytes(
              '/reports/saved/$_savedId/export?file_format=$format',
            )
          : await api.postBytes('/reports/export/$format', _reportQuery!);
      await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          data: bytes,
          fileName:
              'Reporte_${_report!['entity']}.${format == 'pdf' ? 'pdf' : 'xlsx'}',
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo descargar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFilter() async {
    final field = TextEditingController();
    final value = TextEditingController();
    String operator = 'contains';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Filtro por campo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Campo'),
                  items: [
                    for (final c in _columns)
                      DropdownMenuItem(
                        value: c['key'] as String,
                        child: Text(c['label']),
                      ),
                  ],
                  onChanged: (v) => field.text = v ?? '',
                ),
                DropdownButtonFormField<String>(
                  initialValue: operator,
                  decoration: const InputDecoration(labelText: 'Operador'),
                  items: const [
                    DropdownMenuItem(
                      value: 'contains',
                      child: Text('Contiene'),
                    ),
                    DropdownMenuItem(value: 'eq', child: Text('Igual')),
                    DropdownMenuItem(value: 'ne', child: Text('Distinto')),
                    DropdownMenuItem(value: 'gt', child: Text('Mayor')),
                    DropdownMenuItem(value: 'lt', child: Text('Menor')),
                  ],
                  onChanged: (v) => update(() => operator = v!),
                ),
                TextField(
                  controller: value,
                  decoration: const InputDecoration(labelText: 'Valor'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (field.text.isNotEmpty && value.text.isNotEmpty) {
                  Navigator.pop(ctx, {
                    'field': field.text,
                    'operator': operator,
                    'value': num.tryParse(value.text) ?? value.text,
                  });
                }
              },
              child: const Text('Añadir'),
            ),
          ],
        ),
      ),
    );
    field.dispose();
    value.dispose();
    if (result != null && mounted) {
      _change('filters', [...(_query['filters'] as List? ?? []), result]);
    }
  }

  Future<void> _dates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (range != null && mounted) {
      setState(() {
        _query['start_date'] = range.start.toIso8601String().split('T').first;
        _query['end_date'] = range.end.toIso8601String().split('T').first;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await api.post('/reports/saved', body: _reportQuery!);
      await _loadSaved();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSaved(Map report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar reporte guardado'),
        content: Text('¿Eliminar "${report['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await api.delete('/reports/saved/${report['id']}');
      if (!mounted) return;
      if (_savedId == report['id']) {
        setState(() {
          _report = null;
          _savedId = null;
        });
      }
      await _loadSaved();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _loadSaved() async {
    try {
      final rows = await api.get('/reports/saved', usarCache: false);
      if (mounted) setState(() => _saved = rows as List);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Widget _select(
    String label,
    String key,
    Map<String, String> options, {
    String? fallback,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$key-${_query[key]}'),
      initialValue: options.containsKey(_query[key]) ? _query[key] : fallback,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: _busy ? null : (v) => _change(key, v),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final rows = (_report?['rows'] as List?) ?? [];
    final cols = (_report?['columns'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes dinámicos')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          OutlinedButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MyRecordsScreen())),
            icon: const Icon(Icons.person_outline),
            label: const Text('Mis registros: alimentación, pagos y citas'),
          ),
          const Text(
            'Configura, dicta, escucha y descarga tus reportes.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (_companies.isNotEmpty)
            _select('Empresa', 'tenant_id', {
              for (final c in _companies) c['id']: c['name'],
            }),
          if (_branches.isNotEmpty)
            ExpansionTile(
              title: const Text('Sucursales'),
              children: [
                for (final branch in _branches.where(
                  (b) =>
                      _query['tenant_id'] == null ||
                      b['tenant_id'] == _query['tenant_id'],
                ))
                  CheckboxListTile(
                    title: Text(branch['name']),
                    value: (_query['branch_ids'] as List? ?? []).contains(
                      branch['id'],
                    ),
                    onChanged: _busy
                        ? null
                        : (v) {
                            final selected = List<String>.from(
                              _query['branch_ids'] ?? [],
                            );
                            v == true
                                ? selected.add(branch['id'])
                                : selected.remove(branch['id']);
                            _change('branch_ids', selected);
                          },
                  ),
                const Text('Sin selección: todas las sucursales disponibles.'),
              ],
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _command,
            onChanged: (_) => setState(() {}),
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Pide un reporte por voz o texto',
              hintText: 'Reporte de citas confirmadas de este mes',
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _dictate,
                icon: Icon(_listening ? Icons.stop : Icons.mic),
                label: Text(_listening ? 'Detener dictado' : 'Dictar por voz'),
              ),
              FilledButton(
                onPressed: _busy || _command.text.trim().isEmpty
                    ? null
                    : () => _run(voice: true),
                child: const Text('Procesar'),
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('Consultas definidas'),
            children: [
              for (final text in [
                'Clientes activos y contacto',
                'Recetas con calorías y proteínas',
                'Citas confirmadas de este mes',
                'Pagos completados por mes',
                'Fichas clínicas y diagnósticos',
                'Bitácora de auditoría',
                'Planes nutricionales aprobados',
              ])
                ListTile(
                  title: Text(text),
                  onTap: () => setState(() => _command.text = text),
                ),
            ],
          ),
          if (_entities.isNotEmpty)
            _select('Entidad a reportar', 'entity', {
              for (final e in _entities) e['entity']: e['label'],
            }, fallback: 'patients'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Resumen con agrupación'),
            value: _query['aggregate'] == true,
            onChanged: _busy ? null : (v) => _change('aggregate', v),
          ),
          if (_query['aggregate'] == true) ...[
            _select('Agrupar por', 'group_by', const {
              'company': 'Empresa',
              'branch': 'Sucursal',
              'month': 'Mes',
              'status': 'Estado',
              'nutritionist': 'Especialista',
              'payment_method': 'Método de pago',
            }),
            _select('Cálculo', 'metric', const {
              'count': 'Cantidad',
              'sum': 'Suma',
              'average': 'Promedio',
              'unique_patients': 'Pacientes únicos',
              'cancellation_rate': 'Tasa de cancelación',
            }, fallback: 'count'),
            if (['sum', 'average'].contains(_query['metric']))
              _select('Campo numérico', 'value_field', {
                for (final c in _columns.where((c) => c['type'] == 'number'))
                  c['key']: c['label'],
              }),
          ],
          ExpansionTile(
            title: const Text('Columnas del listado y exportación'),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => _change('columns', null),
                    child: const Text('Todas'),
                  ),
                  TextButton(
                    onPressed: () => _change('columns', <String>[]),
                    child: const Text('Ninguna'),
                  ),
                ],
              ),
              for (final c in _columns)
                CheckboxListTile(
                  title: Text(c['label']),
                  value:
                      _query['columns'] == null ||
                      (_query['columns'] as List).contains(c['key']),
                  onChanged: _busy
                      ? null
                      : (v) {
                          final selected = List<String>.from(
                            _query['columns'] ?? _columns.map((c) => c['key']),
                          );
                          v == true
                              ? selected.add(c['key'])
                              : selected.remove(c['key']);
                          _change('columns', selected);
                        },
                ),
            ],
          ),
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Buscar nombre o contenido',
            ),
            onChanged: (v) => _change('search', v),
          ),
          TextField(
            controller: _status,
            decoration: const InputDecoration(
              labelText: 'Estado o categoría',
              helperText: 'Ej.: CONFIRMED, COMPLETED, APPROVED, activo',
            ),
            onChanged: (v) => _change('status', v.isEmpty ? null : v),
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : _dates,
                child: Text(
                  _query['start_date'] == null
                      ? 'Elegir fechas'
                      : '${_query['start_date']} a ${_query['end_date']}',
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _query = {'entity': _query['entity'], 'limit': 500};
                    _search.clear();
                    _status.clear();
                  });
                },
                child: const Text('Limpiar filtros'),
              ),
            ],
          ),
          OutlinedButton(
            onPressed: _busy ? null : _addFilter,
            child: const Text('Añadir filtro por campo'),
          ),
          for (final filter in (_query['filters'] as List? ?? []))
            ListTile(
              title: Text(
                '${filter['field']} ${filter['operator']} ${filter['value']}',
              ),
              trailing: IconButton(
                tooltip: 'Quitar filtro',
                icon: const Icon(Icons.close),
                onPressed: () => _change(
                  'filters',
                  List.from(_query['filters'])..remove(filter),
                ),
              ),
            ),
          if (_query['entity'] == 'payments')
            _select('Moneda', 'currency', const {'USD': 'USD', 'BOB': 'BOB'}),
          ExpansionTile(
            title: const Text('Orden y límite'),
            children: [
              _select('Ordenar por', 'sort_by', {
                for (final c in _columns) c['key']: c['label'],
              }),
              _select('Dirección', 'sort_order', const {
                'asc': 'Ascendente',
                'desc': 'Descendente',
              }, fallback: 'desc'),
              _select('Máximo de registros', 'limitText', const {
                '100': '100',
                '500': '500',
                '1000': '1000',
                '5000': '5000',
              }, fallback: '500'),
            ],
          ),
          FilledButton(
            onPressed: _busy
                ? null
                : () {
                    _query['limit'] = int.parse(
                      _query.remove('limitText') ?? '500',
                    );
                    _run();
                  },
            child: const Text('Generar / actualizar vista previa'),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_entities.isEmpty && !_busy)
            TextButton(onPressed: _init, child: const Text('Reintentar carga')),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_explanation != null) Text(_explanation!),
          if (_report != null) ...[
            if (_report!['chart'] != null && rows.isNotEmpty)
              ...rows.take(12).map((row) {
                final values = rows.map(
                  (r) => (r['value'] as num? ?? 0).abs().toDouble(),
                );
                final max = values.fold<double>(0, (a, b) => a > b ? a : b);
                final value = (row['value'] as num? ?? 0).toDouble();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row.entries.where((e) => e.key != 'value').map((e) => e.value).join(' · ')}: $value',
                      ),
                      LinearProgressIndicator(
                        value: max == 0 ? 0 : (value.abs() / max).clamp(0, 1),
                        minHeight: 12,
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 20),
            Text(
              _report!['title'],
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(_report!['summary'] ?? '${_report!['total_rows']} registros'),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _speak,
                  icon: Icon(_speaking ? Icons.stop : Icons.volume_up),
                  label: Text(
                    _speaking ? 'Detener lectura' : 'Escuchar resumen',
                  ),
                ),
                OutlinedButton(
                  onPressed: _busy || _reportQuery == null ? null : _save,
                  child: const Text('Guardar reporte'),
                ),
              ],
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Sin registros para estos filtros.'),
              ),
            if (rows.isNotEmpty && cols.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    for (final c in cols) DataColumn(label: Text(c['label'])),
                  ],
                  rows: [
                    for (final row in rows.take(100))
                      DataRow(
                        cells: [
                          for (final c in cols)
                            DataCell(
                              SizedBox(
                                width: 160,
                                child: Text(
                                  '${row[c['key']] ?? ''}',
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            if (rows.length > 100)
              Text(
                'Vista previa: 100 de ${rows.length}. La exportación incluye el resultado completo.',
              ),
            for (final note in _report!['notes'] ?? []) Text('$note'),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy || (_reportQuery == null && _savedId == null)
                      ? null
                      : () => _export('pdf'),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Descargar PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy || (_reportQuery == null && _savedId == null)
                      ? null
                      : () => _export('excel'),
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Descargar Excel'),
                ),
              ],
            ),
          ],
          ExpansionTile(
            title: const Text('Reportes guardados'),
            onExpansionChanged: (v) {
              if (v) _loadSaved();
            },
            children: [
              for (final r in _saved)
                ListTile(
                  title: Text(r['title']),
                  subtitle: Text('${r['created_at']}'),
                  trailing: IconButton(
                    tooltip: 'Eliminar reporte guardado',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteSaved(r),
                  ),
                  onTap: () async {
                    try {
                      final data = await api.get(
                        '/reports/saved/${r['id']}',
                        usarCache: false,
                      );
                      if (mounted) {
                        setState(() {
                          _report = Map<String, dynamic>.from(data);
                          _reportQuery = null;
                          _savedId = r['id'];
                        });
                      }
                    } catch (e) {
                      if (mounted) setState(() => _error = '$e');
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
