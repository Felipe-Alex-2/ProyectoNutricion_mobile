class AppointmentModel {
  final String id;
  final String? tenantId;
  final String? tenantName;
  final String patientId;
  final String? patientName;
  final String? patientEmail;
  final String nutritionistId;
  final String? nutritionistName;
  final DateTime scheduledAt;
  final String? reason;
  final String status; // PENDING, CONFIRMED, CANCELLED
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppointmentModel({
    required this.id,
    this.tenantId,
    this.tenantName,
    required this.patientId,
    this.patientName,
    this.patientEmail,
    required this.nutritionistId,
    this.nutritionistName,
    required this.scheduledAt,
    this.reason,
    required this.status,
    this.cancellationReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      tenantName: json['tenant_name'] as String?,
      patientId: json['patient_id'] as String,
      patientName: json['patient_name'] as String?,
      patientEmail: json['patient_email'] as String?,
      nutritionistId: json['nutritionist_id'] as String,
      nutritionistName: json['nutritionist_name'] as String?,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      reason: json['reason'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      cancellationReason: json['cancellation_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'tenant_name': tenantName,
      'patient_id': patientId,
      'patient_name': patientName,
      'patient_email': patientEmail,
      'nutritionist_id': nutritionistId,
      'nutritionist_name': nutritionistName,
      'scheduled_at': scheduledAt.toIso8601String(),
      'reason': reason,
      'status': status,
      'cancellation_reason': cancellationReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class NutritionistItem {
  final String id;
  final String fullName;
  final String email;
  final String? phone;

  NutritionistItem({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
  });

  factory NutritionistItem.fromJson(Map<String, dynamic> json) {
    return NutritionistItem(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
    );
  }
}
