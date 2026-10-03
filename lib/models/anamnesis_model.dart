class PatientAnamnesisModel {
  final String? id;
  final String? patientId;
  final String? tenantId;

  // Datos biométricos y ML
  final DateTime? birthDate;
  final String gender;
  final double weightKg;
  final double heightCm;
  final double? targetWeightKg;
  final int? targetWeeks;

  // Antecedentes y alergias
  final String? pathologies;
  final String? allergies;
  final String? medications;
  final String? otherAllergies;
  final String? otherPathologies;

  // Hábitos de vida y estilo
  final double waterIntakeLiters;
  final String alcoholFrequency;
  final String smokeHabit;
  final int coffeeCups;
  final double sleepHours;

  // Porciones y sistema experto
  final int fruitsVegetablesDaily;
  final int sugaryDrinksWeekly;
  final int mealsPerDay;
  final bool isPregnantOrLactating;

  // Actividad física y digestión
  final String physicalActivity;
  final String? digestiveSymptoms;
  final String? foodPreferences;
  final String goal;
  final bool consentDataProcessing;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  PatientAnamnesisModel({
    this.id,
    this.patientId,
    this.tenantId,
    this.birthDate,
    this.gender = 'M',
    this.weightKg = 70.0,
    this.heightCm = 170.0,
    this.targetWeightKg,
    this.targetWeeks,
    this.pathologies,
    this.allergies,
    this.medications,
    this.otherAllergies,
    this.otherPathologies,
    this.waterIntakeLiters = 1.5,
    this.alcoholFrequency = 'Nunca',
    this.smokeHabit = 'No fuma',
    this.coffeeCups = 1,
    this.sleepHours = 7.0,
    this.fruitsVegetablesDaily = 3,
    this.sugaryDrinksWeekly = 0,
    this.mealsPerDay = 4,
    this.isPregnantOrLactating = false,
    this.physicalActivity = 'Ligero',
    this.digestiveSymptoms,
    this.foodPreferences,
    this.goal = 'Pérdida de grasa',
    this.consentDataProcessing = true,
    this.createdAt,
    this.updatedAt,
  });

  factory PatientAnamnesisModel.fromJson(Map<String, dynamic> json) {
    return PatientAnamnesisModel(
      id: json['id'] as String?,
      patientId: json['patient_id'] as String?,
      tenantId: json['tenant_id'] as String?,
      birthDate: json['birth_date'] != null ? DateTime.tryParse(json['birth_date'] as String) : null,
      gender: json['gender'] as String? ?? 'M',
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 70.0,
      heightCm: (json['height_cm'] as num?)?.toDouble() ?? 170.0,
      targetWeightKg: (json['target_weight_kg'] as num?)?.toDouble(),
      targetWeeks: (json['target_weeks'] as num?)?.toInt(),
      pathologies: json['pathologies'] as String?,
      allergies: json['allergies'] as String?,
      medications: json['medications'] as String?,
      otherAllergies: json['other_allergies'] as String?,
      otherPathologies: json['other_pathologies'] as String?,
      waterIntakeLiters: (json['water_intake_liters'] as num?)?.toDouble() ?? 1.5,
      alcoholFrequency: json['alcohol_frequency'] as String? ?? 'Nunca',
      smokeHabit: json['smoke_habit'] as String? ?? 'No fuma',
      coffeeCups: (json['coffee_cups'] as num?)?.toInt() ?? 1,
      sleepHours: (json['sleep_hours'] as num?)?.toDouble() ?? 7.0,
      fruitsVegetablesDaily: (json['fruits_vegetables_daily'] as num?)?.toInt() ?? 3,
      sugaryDrinksWeekly: (json['sugary_drinks_weekly'] as num?)?.toInt() ?? 0,
      mealsPerDay: (json['meals_per_day'] as num?)?.toInt() ?? 4,
      isPregnantOrLactating: json['is_pregnant_or_lactating'] as bool? ?? false,
      physicalActivity: json['physical_activity'] as String? ?? 'Ligero',
      digestiveSymptoms: json['digestive_symptoms'] as String?,
      foodPreferences: json['food_preferences'] as String?,
      goal: json['goal'] as String? ?? 'Pérdida de grasa',
      consentDataProcessing: json['consent_data_processing'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (birthDate != null) 'birth_date': birthDate!.toIso8601String(),
      'gender': gender,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      if (targetWeightKg != null) 'target_weight_kg': targetWeightKg,
      if (targetWeeks != null) 'target_weeks': targetWeeks,
      'pathologies': pathologies,
      'allergies': allergies,
      'medications': medications,
      'other_allergies': otherAllergies,
      'other_pathologies': otherPathologies,
      'water_intake_liters': waterIntakeLiters,
      'alcohol_frequency': alcoholFrequency,
      'smoke_habit': smokeHabit,
      'coffee_cups': coffeeCups,
      'sleep_hours': sleepHours,
      'fruits_vegetables_daily': fruitsVegetablesDaily,
      'sugary_drinks_weekly': sugaryDrinksWeekly,
      'meals_per_day': mealsPerDay,
      'is_pregnant_or_lactating': isPregnantOrLactating,
      'physical_activity': physicalActivity,
      'digestive_symptoms': digestiveSymptoms,
      'food_preferences': foodPreferences,
      'goal': goal,
      'consent_data_processing': consentDataProcessing,
    };
  }
}
