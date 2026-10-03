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
  // 1. Datos Biométricos y ML
  DateTime? _birthDate;
  String _selectedGender = 'M';
  final TextEditingController _weightController = TextEditingController(text: '70');
  final TextEditingController _heightController = TextEditingController(text: '170');
  final TextEditingController _targetWeightController = TextEditingController();
  final TextEditingController _targetWeeksController = TextEditingController();
  bool _isPregnantOrLactating = false;

  // 2. Sistema Experto & Hábitos Dietéticos
  int _fruitsDaily = 3;
  int _sugaryDrinksWeekly = 0;
  int _mealsPerDay = 4;

  // 3. Alergias y Patologías
  final List<String> _allergiesList = [
    'Ninguna',
    'Lactosa',
    'Gluten (Celiaquía)',
    'Frutos secos',
    'Mariscos',
    'Huevo',
    'Soya',
    'Otros',
  ];
  final Set<String> _selectedAllergies = {'Ninguna'};
  final TextEditingController _otherAllergiesController = TextEditingController();

  final List<String> _pathologiesList = [
    'Ninguna',
    'Diabetes',
    'Hipertensión arterial',
    'Hipotiroidismo',
    'Gastritis / Reflujo',
    'Colesterol alto',
    'Otros',
  ];
  final Set<String> _selectedPathologies = {'Ninguna'};
  final TextEditingController _otherPathologiesController = TextEditingController();

  // 4. Objetivos y Estilo de Vida
  final List<String> _goalsList = [
    'Pérdida de grasa',
    'Aumento de masa muscular',
    'Salud y control de peso',
    'Rendimiento deportivo',
    'Otro',
  ];
  String _selectedGoal = 'Pérdida de grasa';
  final TextEditingController _otherGoalController = TextEditingController();

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

  // 5. Consentimiento Legal de Datos de Salud
  bool _consentDataProcessing = true;

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
        _birthDate = data.birthDate;
        _selectedGender = data.gender;
        _weightController.text = data.weightKg.toStringAsFixed(1);
        _heightController.text = data.heightCm.toStringAsFixed(1);
        if (data.targetWeightKg != null) {
          _targetWeightController.text = data.targetWeightKg!.toStringAsFixed(1);
        }
        if (data.targetWeeks != null) {
          _targetWeeksController.text = data.targetWeeks.toString();
        }
        _isPregnantOrLactating = data.isPregnantOrLactating;

        _fruitsDaily = data.fruitsVegetablesDaily;
        _sugaryDrinksWeekly = data.sugaryDrinksWeekly;
        _mealsPerDay = data.mealsPerDay;

        _waterLiters = data.waterIntakeLiters;
        _sleepHours = data.sleepHours;
        _coffeeCups = data.coffeeCups;
        _selectedActivity = data.physicalActivity;
        _selectedAlcohol = data.alcoholFrequency;
        _selectedSmoke = data.smokeHabit;

        _medicationsController.text = data.medications ?? '';
        _foodPreferencesController.text = data.foodPreferences ?? '';
        _digestiveController.text = data.digestiveSymptoms ?? '';
        _consentDataProcessing = data.consentDataProcessing;

        if (data.goal.isNotEmpty) {
          if (_goalsList.sublist(0, 4).contains(data.goal)) {
            _selectedGoal = data.goal;
          } else {
            _selectedGoal = 'Otro';
            _otherGoalController.text = data.goal;
          }
        }

        if (data.allergies != null && data.allergies!.isNotEmpty) {
          _selectedAllergies.clear();
          final items = data.allergies!.split(', ').map((e) => e.trim());
          for (final item in items) {
            if (item.startsWith('Otro:')) {
              _selectedAllergies.add('Otros');
              _otherAllergiesController.text = item.substring(5).trim();
            } else if (_allergiesList.contains(item)) {
              _selectedAllergies.add(item);
            } else {
              _selectedAllergies.add('Otros');
              _otherAllergiesController.text = item;
            }
          }
          if (_selectedAllergies.isEmpty) _selectedAllergies.add('Ninguna');
        }

        if (data.otherAllergies != null && data.otherAllergies!.isNotEmpty) {
          _selectedAllergies.add('Otros');
          _otherAllergiesController.text = data.otherAllergies!;
        }

        if (data.pathologies != null && data.pathologies!.isNotEmpty) {
          _selectedPathologies.clear();
          final items = data.pathologies!.split(', ').map((e) => e.trim());
          for (final item in items) {
            if (item.startsWith('Otro:')) {
              _selectedPathologies.add('Otros');
              _otherPathologiesController.text = item.substring(5).trim();
            } else if (_pathologiesList.contains(item)) {
              _selectedPathologies.add(item);
            } else {
              _selectedPathologies.add('Otros');
              _otherPathologiesController.text = item;
            }
          }
          if (_selectedPathologies.isEmpty) _selectedPathologies.add('Ninguna');
        }

        if (data.otherPathologies != null && data.otherPathologies!.isNotEmpty) {
          _selectedPathologies.add('Otros');
          _otherPathologiesController.text = data.otherPathologies!;
        }
      });
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _targetWeightController.dispose();
    _targetWeeksController.dispose();
    _otherAllergiesController.dispose();
    _otherPathologiesController.dispose();
    _otherGoalController.dispose();
    _medicationsController.dispose();
    _foodPreferencesController.dispose();
    _digestiveController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _saveAnamnesis() async {
    final service = context.read<AnamnesisService>();

    if (!_consentDataProcessing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar el consentimiento para el tratamiento de tus datos de salud.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final weight = double.tryParse(_weightController.text.trim()) ?? 70.0;
    final height = double.tryParse(_heightController.text.trim()) ?? 170.0;
    final targetWeight = double.tryParse(_targetWeightController.text.trim());
    final targetWeeks = int.tryParse(_targetWeeksController.text.trim());

    if (_selectedGoal == 'Otro' && _otherGoalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor escribe tu objetivo personalizado en el campo de texto.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final pathologies = _selectedPathologies.map((p) {
      if (p == 'Otros' && _otherPathologiesController.text.trim().isNotEmpty) {
        return 'Otro: ${_otherPathologiesController.text.trim()}';
      }
      return p;
    }).toList();

    final allergies = _selectedAllergies.map((a) {
      if (a == 'Otros' && _otherAllergiesController.text.trim().isNotEmpty) {
        return 'Otro: ${_otherAllergiesController.text.trim()}';
      }
      return a;
    }).toList();

    final goal = (_selectedGoal == 'Otro' && _otherGoalController.text.trim().isNotEmpty)
        ? _otherGoalController.text.trim()
        : _selectedGoal;

    final model = PatientAnamnesisModel(
      birthDate: _birthDate,
      gender: _selectedGender,
      weightKg: weight,
      heightCm: height,
      targetWeightKg: targetWeight,
      targetWeeks: targetWeeks,
      isPregnantOrLactating: _selectedGender == 'F' ? _isPregnantOrLactating : false,
      fruitsVegetablesDaily: _fruitsDaily,
      sugaryDrinksWeekly: _sugaryDrinksWeekly,
      mealsPerDay: _mealsPerDay,
      pathologies: pathologies.join(', '),
      allergies: allergies.join(', '),
      otherAllergies: _otherAllergiesController.text.trim().isNotEmpty ? _otherAllergiesController.text.trim() : null,
      otherPathologies: _otherPathologiesController.text.trim().isNotEmpty ? _otherPathologiesController.text.trim() : null,
      medications: _medicationsController.text.trim(),
      waterIntakeLiters: _waterLiters,
      alcoholFrequency: _selectedAlcohol,
      smokeHabit: _selectedSmoke,
      coffeeCups: _coffeeCups,
      sleepHours: _sleepHours,
      physicalActivity: _selectedActivity,
      digestiveSymptoms: _digestiveController.text.trim(),
      foodPreferences: _foodPreferencesController.text.trim(),
      goal: goal,
      consentDataProcessing: _consentDataProcessing,
    );

    final ok = await service.saveMyAnamnesis(model);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Ficha de salud guardada exitosamente! Tu plan ya puede calcularse.'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(service.errorMessage ?? 'Error al guardar los datos de salud'),
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
                            'Anamnesis Nutricional & IA',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tus datos biométricos alimentan el motor de cálculo calórico (Mifflin-St Jeor) y las reglas de seguridad.',
                            style: TextStyle(fontSize: 12, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 0. Datos Biométricos
              _buildSectionHeader(Icons.accessibility_new_rounded, 'Datos Biométricos (Para el cálculo calórico)', textPrimary),
              const SizedBox(height: 12),

              // Fecha de Nacimiento y Sexo
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _pickBirthDate,
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(
                        _birthDate == null
                            ? 'Fec. Nacimiento'
                            : '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}',
                        style: TextStyle(fontSize: 13, color: textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sexo M / F
                  ChoiceChip(
                    label: const Text('Hombre (M)'),
                    selected: _selectedGender == 'M',
                    selectedColor: primaryGreen,
                    labelStyle: TextStyle(color: _selectedGender == 'M' ? Colors.white : textPrimary),
                    onSelected: (val) {
                      if (val) setState(() => _selectedGender = 'M');
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Mujer (F)'),
                    selected: _selectedGender == 'F',
                    selectedColor: primaryGreen,
                    labelStyle: TextStyle(color: _selectedGender == 'F' ? Colors.white : textPrimary),
                    onSelected: (val) {
                      if (val) setState(() => _selectedGender = 'F');
                    },
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Peso y Talla
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Peso actual (kg)',
                        filled: true,
                        fillColor: cardBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _heightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Talla (cm)',
                        filled: true,
                        fillColor: cardBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Peso Objetivo y Plazo
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _targetWeightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Peso objetivo (kg)',
                        hintText: 'Opcional',
                        filled: true,
                        fillColor: cardBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _targetWeeksController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Plazo (semanas)',
                        hintText: 'Ej. 12',
                        filled: true,
                        fillColor: cardBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),

              if (_selectedGender == 'F') ...[
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Embarazo o Lactancia', style: TextStyle(fontSize: 14, color: textPrimary)),
                  subtitle: Text('Aplica reglas de seguridad nutricional especiales.', style: TextStyle(fontSize: 12, color: textSecondary)),
                  value: _isPregnantOrLactating,
                  onChanged: (val) => setState(() => _isPregnantOrLactating = val),
                ),
              ],

              const SizedBox(height: 24),

              // 1. Objetivo Principal
              _buildSectionHeader(Icons.track_changes_rounded, 'Objetivo Principal', textPrimary),
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
              if (_selectedGoal == 'Otro') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _otherGoalController,
                  decoration: InputDecoration(
                    hintText: 'Escribe tu objetivo personalizado...',
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // 2. Alergias e Intolerancias
              _buildSectionHeader(Icons.warning_amber_rounded, 'Alergias e Intolerancias Alimentarias', textPrimary, iconColor: AppTheme.accentCoral),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allergiesList.map((allergy) {
                  final isSel = _selectedAllergies.contains(allergy);
                  return FilterChip(
                    label: Text(allergy),
                    selected: isSel,
                    selectedColor: AppTheme.accentCoral.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.accentCoral,
                    labelStyle: TextStyle(
                      color: isSel ? AppTheme.accentCoral : textPrimary,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      setState(() {
                        if (allergy == 'Ninguna') {
                          _selectedAllergies.clear();
                          if (val) _selectedAllergies.add('Ninguna');
                        } else {
                          _selectedAllergies.remove('Ninguna');
                          if (val) {
                            _selectedAllergies.add(allergy);
                          } else {
                            _selectedAllergies.remove(allergy);
                          }
                          if (_selectedAllergies.isEmpty) _selectedAllergies.add('Ninguna');
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              if (_selectedAllergies.contains('Otros')) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _otherAllergiesController,
                  decoration: InputDecoration(
                    hintText: 'Especifica otras alergias (ej. mariscos, ajonjolí)...',
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // 3. Patologías y Antecedentes
              _buildSectionHeader(Icons.medical_information_rounded, 'Antecedentes de Salud y Patologías', textPrimary),
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
                          if (val) _selectedPathologies.add('Ninguna');
                        } else {
                          _selectedPathologies.remove('Ninguna');
                          if (val) {
                            _selectedPathologies.add(pathology);
                          } else {
                            _selectedPathologies.remove(pathology);
                          }
                          if (_selectedPathologies.isEmpty) _selectedPathologies.add('Ninguna');
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              if (_selectedPathologies.contains('Otros')) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _otherPathologiesController,
                  decoration: InputDecoration(
                    hintText: 'Especifica antecedentes (ej. hipotiroidismo)...',
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // 4. Parámetros del Sistema Experto (Frutas, Bebidas azucaradas, Comidas)
              _buildSectionHeader(Icons.restaurant_rounded, 'Hábitos Dietéticos Clave (Sistema Experto)', textPrimary),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Text('Porciones de frutas y verduras / día: $_fruitsDaily',
                        style: TextStyle(fontSize: 14, color: textPrimary)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _fruitsDaily > 0 ? () => setState(() => _fruitsDaily--) : null,
                  ),
                  Text('$_fruitsDaily', style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _fruitsDaily < 10 ? () => setState(() => _fruitsDaily++) : null,
                  ),
                ],
              ),

              Row(
                children: [
                  Expanded(
                    child: Text('Bebidas azucaradas / semana: $_sugaryDrinksWeekly',
                        style: TextStyle(fontSize: 14, color: textPrimary)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _sugaryDrinksWeekly > 0 ? () => setState(() => _sugaryDrinksWeekly--) : null,
                  ),
                  Text('$_sugaryDrinksWeekly', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentCoral)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _sugaryDrinksWeekly++),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Text('Número de comidas al día:', style: TextStyle(fontSize: 13, color: textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [3, 4, 5, 6].map((count) {
                  final isSel = _mealsPerDay == count;
                  return ChoiceChip(
                    label: Text('$count comidas'),
                    selected: isSel,
                    selectedColor: primaryGreen,
                    labelStyle: TextStyle(color: isSel ? Colors.white : textPrimary),
                    onSelected: (val) {
                      if (val) setState(() => _mealsPerDay = count);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // 5. Hidratación y Descanso
              _buildSectionHeader(Icons.water_drop_rounded, 'Hidratación y Descanso', textPrimary, iconColor: AppTheme.accentBlue),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Agua al día: ${_waterLiters.toStringAsFixed(1)} Litros', style: TextStyle(fontSize: 14, color: textPrimary)),
                  Text('${(_waterLiters * 4).round()} vasos aprox', style: TextStyle(fontSize: 12, color: textSecondary)),
                ],
              ),
              Slider(
                value: _waterLiters,
                min: 0.5,
                max: 5.0,
                divisions: 18,
                activeColor: AppTheme.accentBlue,
                label: '${_waterLiters.toStringAsFixed(1)} L',
                onChanged: (val) => setState(() => _waterLiters = val),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Sueño promedio: ${_sleepHours.toStringAsFixed(1)} horas/noche', style: TextStyle(fontSize: 14, color: textPrimary)),
                ],
              ),
              Slider(
                value: _sleepHours,
                min: 4.0,
                max: 12.0,
                divisions: 16,
                activeColor: primaryGreen,
                label: '${_sleepHours.toStringAsFixed(1)} h',
                onChanged: (val) => setState(() => _sleepHours = val),
              ),

              const SizedBox(height: 20),

              // 6. Actividad Física
              _buildSectionHeader(Icons.fitness_center_rounded, 'Nivel de Actividad Física', textPrimary),
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
              _buildSectionHeader(Icons.local_cafe_outlined, 'Hábitos (Café, Alcohol, Tabaco)', textPrimary, iconColor: AppTheme.accentOrange),
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

              // 8. Textos complementarios
              _buildSectionHeader(Icons.medication_outlined, 'Medicamentos o Suplementos', textPrimary),
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

              _buildSectionHeader(Icons.restaurant_menu_rounded, 'Preferencias y Aversiones', textPrimary),
              const SizedBox(height: 6),
              TextField(
                controller: _foodPreferencesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Ej: Vegetariano, me encanta el pollo, no me gusta el brócoli...',
                  filled: true,
                  fillColor: cardBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 16),

              _buildSectionHeader(Icons.healing_rounded, 'Digestión y Síntomas', textPrimary),
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

              const SizedBox(height: 24),

              // 9. Consentimiento de datos de salud
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _consentDataProcessing,
                      activeColor: primaryGreen,
                      onChanged: (val) => setState(() => _consentDataProcessing = val ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Doy mi consentimiento para el tratamiento de mis datos de salud, biométricos y hábitos con fines estrictamente clínicos y de seguimiento nutricional.',
                          style: TextStyle(fontSize: 12, color: textSecondary, height: 1.3),
                        ),
                      ),
                    ),
                  ],
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

  Widget _buildSectionHeader(IconData icon, String title, Color textColor, {Color? iconColor}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor ?? AppTheme.primaryGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}
