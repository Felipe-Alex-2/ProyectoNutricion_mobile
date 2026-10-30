import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/nutrition_diary_service.dart';
import '../../modo_offline/cola_sincronizacion_service.dart';
import '../../modo_offline/conectividad_service.dart';
import '../../modo_offline/sincronizador_service.dart';
import 'food_vision_screen.dart';

class NutritionDiaryScreen extends StatefulWidget {
  const NutritionDiaryScreen({super.key});
  @override
  State<NutritionDiaryScreen> createState() => _NutritionDiaryScreenState();
}

class _NutritionDiaryScreenState extends State<NutritionDiaryScreen> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fats = TextEditingController();
  String _meal = 'Almuerzo';
  DateTime _consumedAt = DateTime.now();
  Map<String, dynamic>? _plan;
  List<dynamic> _history = [];
  bool _loading = true, _saving = false;
  String? _error;
  SincronizadorService? _sync;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sync = context.read<SincronizadorService>();
      _sync!.addListener(_onSync);
      _load();
    });
  }

  void _onSync() {
    if (_sync?.estaSincronizando == false && mounted) _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiService>();
    final owner = api.currentUserId;
    String? error;
    Map<String, dynamic>? plan;
    List<dynamic> history = [];
    try {
      plan = await api.get('/plans/my-plan') as Map<String, dynamic>?;
    } catch (e) {
      error = e.toString();
    }
    try {
      history = (await api.get('/food/history') as List?) ?? [];
    } catch (e) {
      error ??= e.toString();
    }
    if (mounted && owner == api.currentUserId) {
      setState(() {
        _plan = plan;
        _history = history;
        _error = error;
        _loading = false;
      });
    }
  }

  double _number(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await NutritionDiaryService(
        context.read<ApiService>(),
        context.read<ColaSincronizacionService>(),
      ).save(
        description: _description.text,
        mealType: _meal,
        consumedAt: _consumedAt,
        calories: _number(_calories),
        protein: _number(_protein),
        carbs: _number(_carbs),
        fats: _number(_fats),
      );
      if (!mounted) return;
      for (final c in [_description, _calories, _protein, _carbs, _fats]) {
        c.clear();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Comida guardada. Se enviará al servidor cuando haya conexión.',
          ),
        ),
      );
      setState(() => _consumedAt = DateTime.now());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _consumedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_consumedAt),
    );
    if (time != null && mounted) {
      setState(
        () => _consumedAt = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Widget _numeric(String label, TextEditingController controller, double max) =>
      SizedBox(
        width: 150,
        child: TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, helperText: 'Opcional'),
          validator: (text) {
            if (text == null || text.trim().isEmpty) return null;
            final n = double.tryParse(text.replaceAll(',', '.'));
            return n == null || !n.isFinite || n < 0 || n > max
                ? 'Entre 0 y $max'
                : null;
          },
        ),
      );

  Widget _card(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final connected = context.watch<ConectividadService>().estaConectado;
    final queue = context.watch<ColaSincronizacionService>();
    final sync = context.watch<SincronizadorService>();
    final user = context.read<ApiService>().currentUserId;
    final pending = queue.elementos
        .where(
          (e) => e.userId == user && e.tipoAccion == 'REGISTRAR_ALIMENTACION',
        )
        .toList();
    final meals = (_plan?['meals'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi nutrición'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar información',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _card(
                    connected
                        ? 'Tu alimentación, día a día'
                        : 'Estás sin conexión',
                    [
                      Text(
                        connected
                            ? 'Registra tus comidas y consulta el plan indicado por tu profesional.'
                            : 'Puedes registrar comidas y consultar lo descargado en esta cuenta durante los últimos 30 días. El plan puede haber cambiado: actualízalo al recuperar internet.',
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                  _card('Mi plan asignado', [
                    if (_plan == null)
                      const Text(
                        'Aún no hay un plan aprobado descargado. Tu nutricionista debe aprobar y asignar tu plan.',
                      )
                    else ...[
                      Text('${_plan!['title']}'),
                      Text(
                        '${_plan!['daily_calories']} kcal · Proteínas ${_plan!['protein_g']} g · Carbohidratos ${_plan!['carbs_g']} g · Grasas ${_plan!['fats_g']} g',
                      ),
                      if (_plan!['approved_at'] != null)
                        Text(
                          'Aprobado: ${_plan!['approved_at'].toString().split('T').first}',
                        ),
                      for (final meal in meals)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text('${meal['meal_name']}'),
                          subtitle: Text('${meal['total_calories']} kcal'),
                          children: [
                            for (final food in (meal['foods'] as List? ?? []))
                              ListTile(
                                title: Text('${food['name']}'),
                                subtitle: Text('${food['portion']}'),
                                trailing: Text('${food['calories']} kcal'),
                              ),
                          ],
                        ),
                    ],
                  ]),
                  _card('Registrar alimentación', [
                    const Text(
                      'Disponible con o sin internet. Las cantidades son opcionales y corresponden a lo que tú indiques.',
                    ),
                    const SizedBox(height: 12),
                    Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _meal,
                            decoration: const InputDecoration(
                              labelText: 'Comida',
                            ),
                            items:
                                [
                                      'Desayuno',
                                      'Almuerzo',
                                      'Merienda',
                                      'Cena',
                                      'Snack',
                                    ]
                                    .map(
                                      (m) => DropdownMenuItem(
                                        value: m,
                                        child: Text(m),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) => setState(() => _meal = v!),
                          ),
                          TextFormField(
                            controller: _description,
                            maxLength: 500,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: '¿Qué comiste?',
                              hintText: 'Ej.: pollo con arroz y ensalada',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Describe tu comida'
                                : null,
                          ),
                          TextButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.schedule),
                            label: Text(
                              'Fecha y hora: ${_consumedAt.toLocal().toString().substring(0, 16)}',
                            ),
                          ),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _numeric('Calorías (kcal)', _calories, 10000),
                              _numeric('Proteínas (g)', _protein, 1000),
                              _numeric('Carbohidratos (g)', _carbs, 1000),
                              _numeric('Grasas (g)', _fats, 1000),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              _saving ? 'Guardando…' : 'Guardar comida',
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: connected
                                ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => const FoodVisionScreen(),
                                    ),
                                  ).then((_) => _load())
                                : null,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Registrar con foto e IA'),
                          ),
                          if (!connected)
                            const Text(
                              'El análisis de fotos requiere internet. Puedes describir tu comida aquí.',
                            ),
                        ],
                      ),
                    ),
                  ]),
                  _card('Registros pendientes (${pending.length})', [
                    if (pending.isEmpty)
                      const Text('No tienes comidas pendientes de envío.'),
                    for (final item in pending)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.descripcionHumana),
                        subtitle: Text(
                          item.mensajeError ??
                              (item.estado == 'SINCRONIZANDO'
                                  ? 'Enviando…'
                                  : 'Guardado en este dispositivo · Pendiente de envío'),
                        ),
                        trailing: item.estado == 'SINCRONIZANDO'
                            ? const CircularProgressIndicator()
                            : IconButton(
                                tooltip: 'Reintentar registro',
                                icon: const Icon(Icons.replay),
                                onPressed: sync.estaSincronizando
                                    ? null
                                    : () async {
                                        await queue.reintentar(
                                          item.id,
                                          userId: user!,
                                        );
                                        await sync.sincronizarCola(
                                          userId: user,
                                        );
                                      },
                              ),
                      ),
                    OutlinedButton.icon(
                      onPressed: !connected || sync.estaSincronizando
                          ? null
                          : () => sync.sincronizarCola(userId: user),
                      icon: const Icon(Icons.sync),
                      label: Text(
                        sync.estaSincronizando
                            ? 'Sincronizando…'
                            : 'Sincronizar pendientes',
                      ),
                    ),
                  ]),
                  _card('Historial de alimentación', [
                    if (_history.isEmpty)
                      const Text('Tus comidas enviadas aparecerán aquí.'),
                    for (final record in _history)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${record['notes'] ?? 'Comida registrada'}',
                        ),
                        subtitle: Text(
                          '${(record['details']?['consumed_at'] ?? record['created_at']).toString().replaceFirst('T', ' ').substring(0, 16)} · ${record['estimated_calories']} kcal\nProteínas ${record['estimated_protein']} g · Carbohidratos ${record['estimated_carbs']} g · Grasas ${record['estimated_fats']} g',
                        ),
                        leading: Icon(
                          record['confidence'] == 'manual'
                              ? Icons.edit_note
                              : Icons.camera_alt_outlined,
                        ),
                      ),
                  ]),
                  _card('Asistente sin conexión', [
                    const Text(
                      'Guía local de consulta. Disponible sin internet; no genera respuestas con IA ni modifica tu tratamiento.',
                    ),
                    const ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('¿Cómo sigo mi plan?'),
                      children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Consulta las comidas y porciones de tu plan asignado arriba. Registra lo que consumes para revisarlo con tu nutricionista.',
                          ),
                        ),
                      ],
                    ),
                    const ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('¿Qué pasa con mis registros sin internet?'),
                      children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Se conservan de forma segura en este dispositivo y se envían al recuperar conexión con tu sesión activa. Cada comida tiene un identificador para evitar duplicados.',
                          ),
                        ),
                      ],
                    ),
                    const ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('¿Puedo consultar nutrientes sin conexión?'),
                      children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Sí. El plan descargado muestra calorías y macronutrientes por alimento. El historial conserva las estimaciones de las fotos ya analizadas. Descarga esa información primero con internet.',
                          ),
                        ),
                      ],
                    ),
                  ]),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _sync?.removeListener(_onSync);
    for (final c in [_description, _calories, _protein, _carbs, _fats]) {
      c.dispose();
    }
    super.dispose();
  }
}
