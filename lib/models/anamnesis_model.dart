class PatientAnamnesisModel {
  final String? id;
  final String? patientId;
  final String? tenantId;
  final String? pathologies;
  final String? allergies;
  final String? medications;
  final double waterIntakeLiters;
  final String alcoholFrequency;
  final String smokeHabit;
  final int coffeeCups;
  final double sleepHours;
  final String physicalActivity;
  final String? digestiveSymptoms;
  final String? foodPreferences;
  final String goal;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PatientAnamnesisModel({
    this.id,
    this.patientId,
    this.tenantId,
    this.pathologies,
    this.allergies,
    this.medications,
    this.waterIntakeLiters = 1.5,
    this.alcoholFrequency = 'Nunca',
    this.smokeHabit = 'No fuma',
    this.coffeeCups = 1,
    this.sleepHours = 7.0,
    this.physicalActivity = 'Ligero',
    this.digestiveSymptoms,
    this.foodPreferences,
    this.goal = 'Pérdida de grasa',
    this.createdAt,
    this.updatedAt,
  });

  factory PatientAnamnesisModel.fromJson(Map<String, dynamic> json) {
    return PatientAnamnesisModel(
      id: json['id'] as String?,
      patientId: json['patient_id'] as String?,
      tenantId: json['tenant_id'] as String?,
      pathologies: json['pathologies'] as String?,
      allergies: json['allergies'] as String?,
      medications: json['medications'] as String?,
      waterIntakeLiters: (json['water_intake_liters'] as num?)?.toDouble() ?? 1.5,
      alcoholFrequency: json['alcohol_frequency'] as String? ?? 'Nunca',
      smokeHabit: json['smoke_habit'] as String? ?? 'No fuma',
      coffeeCups: (json['coffee_cups'] as num?)?.toInt() ?? 1,
      sleepHours: (json['sleep_hours'] as num?)?.toDouble() ?? 7.0,
      physicalActivity: json['physical_activity'] as String? ?? 'Ligero',
      digestiveSymptoms: json['digestive_symptoms'] as String?,
      foodPreferences: json['food_preferences'] as String?,
      goal: json['goal'] as String? ?? 'Pérdida de grasa',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pathologies': pathologies,
      'allergies': allergies,
      'medications': medications,
      'water_intake_liters': waterIntakeLiters,
      'alcohol_frequency': alcoholFrequency,
      'smoke_habit': smokeHabit,
      'coffee_cups': coffeeCups,
      'sleep_hours': sleepHours,
      'physical_activity': physicalActivity,
      'digestive_symptoms': digestiveSymptoms,
      'food_preferences': foodPreferences,
      'goal': goal,
    };
  }
}
