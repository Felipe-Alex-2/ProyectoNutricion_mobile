import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/anamnesis_model.dart';
import '../../services/anamnesis_service.dart';
import '../../services/theme_service.dart';

class AnamnesisScreen extends StatefulWidget {
  const AnamnesisScreen({super.key});

  @override
  State<AnamnesisScreen> createState() => _AnamnesisScreenState();
}

class _AnamnesisScreenState extends State<AnamnesisScreen> {
  // Lista de opciones para Chips
  final List<String> _allergiesList = [
    'Ninguna',
    'Lactosa',
    'Gluten (Celiaquía)',
    'Frutos secos',
    'Mariscos',
    'Huevo',
    'Soya',
  ];
  final Set<String> _selectedAllergies = {'Ninguna'};

  final List<String> _pathologiesList = [
    'Ninguna',
    'Diabetes',
    'Hipertensión arterial',
    'Hipotiroidismo',
    'Gastritis / Reflujo',
    'Colesterol alto',
  ];
  final Set<String> _selectedPathologies = {'Ninguna'};

  final List<String> _goalsList = [
    'Pérdida de grasa',
    'Aumento de masa muscular',
    'Salud y control de peso',
    'Rendimiento deportivo',
  ];
  String _selectedGoal = 'Pérdida de grasa';

  final List<String> _activityList = [
    'Sedentario',
    'Ligero (1-2 días)',
    'Moderado (3-4 días)',
    'Intenso (5+ días)',
  ];
  String _selectedActivity = 'Moderado (3-4 días)';

  final List<String> _alcoholList = ['Nunca', 'Ocasional', 'Frecuente'];
  String _selectedAlcohol = 'Ocasional';

  final List<String> _smokeList = ['No fuma', 'Ocasional', 'Habitual'];
  String _selectedSmoke = 'No fuma';

  double _waterLiters = 2.0;
  double _sleepHours = 7.5;
  int _coffeeCups = 1;

  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _foodPreferencesController = TextEditingController();
  final TextEditingController _digestiveController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingData();
    });
  }

  Future<void> _loadExistingData() async {
    final service = context.read<AnamnesisService>();
    await service.fetchMyAnamnesis();

    final data = service.anamnesis;
    if (data != null && mounted) {
      setState(() {
        _waterLiters = data.waterIntakeLiters;
        _sleepHours = data.sleepHours;
        _coffeeCups = data.coffeeCups;
        _selectedGoal = data.goal;
        _selectedActivity = data.physicalActivity;
        _selectedAlcohol = data.alcoholFrequency;
        _selectedSmoke = data.smokeHabit;

        _medicationsController.text = data.medications ?? '';
        _foodPreferencesController.text = data.foodPreferences ?? '';
        _digestiveController.text = data.digestiveSymptoms ?? '';

        if (data.allergies != null && data.allergies!.isNotEmpty) {
          _selectedAllergies.clear();
          _selectedAllergies.addAll(data.allergies!.split(', ').map((e) => e.trim()));
        }

        if (data.pathologies != null && data.pathologies!.isNotEmpty) {
          _selectedPathologies.clear();
          _selectedPathologies.addAll(data.pathologies!.split(', ').map((e) => e.trim()));
        }
      });
    }
  }

  @override
  void dispose() {
    _medicationsController.dispose();
    _foodPreferencesController.dispose();
    _digestiveController.dispose();
    super.dispose();
  }

  Future<void> _saveAnamnesis() async {
    final service = context.read<AnamnesisService>();

    final model = PatientAnamnesisModel(
      pathologies: _selectedPathologies.join(', '),
      allergies: _selectedAllergies.join(', '),
      medications: _medicationsController.text.trim(),
      waterIntakeLiters: _waterLiters,
      alcoholFrequency: _selectedAlcohol,
      smokeHabit: _selectedSmoke,
      coffeeCups: _coffeeCups,
      sleepHours: _sleepHours,
      physicalActivity: _selectedActivity,
      digestiveSymptoms: _digestiveController.text.trim(),
      foodPreferences: _foodPreferencesController.text.trim(),
      goal: _selectedGoal,
    );

    final ok = await service.saveMyAnamnesis(model);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Ficha de salud guardada exitosamente! Tu nutricionista ya puede verla.'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(service.errorMessage ?? 'Error al guardar'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final isDark = themeService.isDarkMode;
    final primaryGreen = isDark ? AppTheme.primaryGreenDark : AppTheme.primaryGreen;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final anamnesisService = context.watch<AnamnesisService>();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: const Text('Mi Ficha de Salud'),
        backgroundColor: isDark ? AppTheme.darkSidebar : AppTheme.lightSidebar,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0x0A000000)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.health_and_safety_rounded, color: primaryGreen, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Anamnesis Nutricional',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Llena estos campos sencillos para que tu especialista diseñe tu plan a medida.',
                            style: TextStyle(fontSize: 12, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 1. Objetivo Principal
              _buildSectionTitle('🎯 Objetivo Principal', textPrimary),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _goalsList.map((goal) {
                  final isSel = _selectedGoal == goal;
                  return ChoiceChip(
                    label: Text(goal),
                    selected: isSel,
                    selectedColor: primaryGreen,
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : textPrimary,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedGoal = goal);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // 2. Alergias e Intolerancias
              _buildSectionTitle('⚠️ Alergias e Intolerancias', textPrimary),
              const SizedBox(height: 4),
              Text('Selecciona todas las que apliquen', style: TextStyle(fontSize: 12, color: textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allergiesList.map((allergy) {
                  final isSel = _selectedAllergies.contains(allergy);
                  return FilterChip(
                    label: Text(allergy),
                    selected: isSel,
                    selectedColor: Colors.redAccent.withValues(alpha: 0.2),
                    checkmarkColor: Colors.redAccent,
                    labelStyle: TextStyle(
                      color: isSel ? Colors.redAccent : textPrimary,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      setState(() {
                        if (allergy == 'Ninguna') {
                          _selectedAllergies.clear();
                          _selectedAllergies.add('Ninguna');
                        } else {
                          _selectedAllergies.remove('Ninguna');
                          if (val) {
                            _selectedAllergies.add(allergy);
                          } else {
                            _selectedAllergies.remove(allergy);
                            if (_selectedAllergies.isEmpty) _selectedAllergies.add('Ninguna');
                          }
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // 3. Antecedentes Médicos
              _buildSectionTitle('🩺 Antecedentes de Salud', textPrimary),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _pathologiesList.map((pathology) {
                  final isSel = _selectedPathologies.contains(pathology);
                  return FilterChip(
                    label: Text(pathology),
                    selected: isSel,
                    selectedColor: primaryGreen.withValues(alpha: 0.2),
                    checkmarkColor: primaryGreen,
                    labelStyle: TextStyle(
                      color: isSel ? primaryGreen : textPrimary,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      setState(() {
                        if (pathology == 'Ninguna') {
                          _selectedPathologies.clear();
                          _selectedPathologies.add('Ninguna');
                        } else {
                          _selectedPathologies.remove('Ninguna');
                          if (val) {
                            _selectedPathologies.add(pathology);
                          } else {
                            _selectedPathologies.remove(pathology);
                            if (_selectedPathologies.isEmpty) _selectedPathologies.add('Ninguna');
                          }
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // 4. Ingesta de Agua
              _buildSectionTitle('💧 Ingesta de Agua Diaria', textPrimary),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_waterLiters.toStringAsFixed(1)} Litros / día',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen)),
                  Text('${(_waterLiters * 4).round()} vasos aprox.',
                      style: TextStyle(fontSize: 12, color: textSecondary)),
                ],
              ),
              Slider(
                value: _waterLiters,
                min: 0.5,
                max: 5.0,
                divisions: 9,
                activeColor: primaryGreen,
                onChanged: (val) => setState(() => _waterLiters = val),
              ),

              const SizedBox(height: 16),

              // 5. Horas de Sueño
              _buildSectionTitle('😴 Horas de Sueño Promedio', textPrimary),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_sleepHours.toStringAsFixed(1)} horas / noche',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen)),
                  Text(_sleepHours >= 7 ? 'Buen descanso' : 'Requiere descanso',
                      style: TextStyle(fontSize: 12, color: textSecondary)),
                ],
              ),
              Slider(
                value: _sleepHours,
                min: 4.0,
                max: 12.0,
                divisions: 16,
                activeColor: primaryGreen,
                onChanged: (val) => setState(() => _sleepHours = val),
              ),

              const SizedBox(height: 20),

              // 6. Actividad Física
              _buildSectionTitle('🏃 Nivel de Actividad Física', textPrimary),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _activityList.map((act) {
                  final isSel = _selectedActivity == act;
                  return ChoiceChip(
                    label: Text(act),
                    selected: isSel,
                    selectedColor: primaryGreen,
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : textPrimary,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedActivity = act);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // 7. Café, Alcohol y Tabaco
              _buildSectionTitle('☕ Hábitos (Café, Alcohol, Tabaco)', textPrimary),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text('Tazas de café al día: $_coffeeCups',
                        style: TextStyle(fontSize: 14, color: textPrimary)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _coffeeCups > 0 ? () => setState(() => _coffeeCups--) : null,
                  ),
                  Text('$_coffeeCups', style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _coffeeCups++),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Text('Consumo de alcohol:', style: TextStyle(fontSize: 13, color: textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _alcoholList.map((item) {
                  final isSel = _selectedAlcohol == item;
                  return ChoiceChip(
                    label: Text(item),
                    selected: isSel,
                    selectedColor: primaryGreen,
                    labelStyle: TextStyle(color: isSel ? Colors.white : textPrimary),
                    onSelected: (val) => setState(() => _selectedAlcohol = item),
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),
              Text('Hábito de fumar:', style: TextStyle(fontSize: 13, color: textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _smokeList.map((item) {
                  final isSel = _selectedSmoke == item;
                  return ChoiceChip(
                    label: Text(item),
                    selected: isSel,
                    selectedColor: primaryGreen,
                    labelStyle: TextStyle(color: isSel ? Colors.white : textPrimary),
                    onSelected: (val) => setState(() => _selectedSmoke = item),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // 8. Campos de texto complementarios
              _buildSectionTitle('💊 Medicamentos o Suplementos', textPrimary),
              const SizedBox(height: 6),
              TextField(
                controller: _medicationsController,
                decoration: InputDecoration(
                  hintText: 'Ej: Vitaminas, creatina, ninguno...',
                  filled: true,
                  fillColor: cardBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 16),

              _buildSectionTitle('🍽️ Preferencias y Aversiones', textPrimary),
              const SizedBox(height: 6),
              TextField(
                controller: _foodPreferencesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Ej: Vegetariano, me encanta el pollo, odio las berenjenas...',
                  filled: true,
                  fillColor: cardBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 16),

              _buildSectionTitle('🩺 Digestión / Síntomas', textPrimary),
              const SizedBox(height: 6),
              TextField(
                controller: _digestiveController,
                decoration: InputDecoration(
                  hintText: 'Ej: Distensión nocturna, reflujo ocasional...',
                  filled: true,
                  fillColor: cardBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 32),

              // Botón Guardar
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: anamnesisService.isLoading ? null : _saveAnamnesis,
                  child: anamnesisService.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Guardar Mi Ficha de Salud',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }
}
