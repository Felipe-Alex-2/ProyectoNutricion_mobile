class PatientNutritionistLink {
  final String id;
  final String? tenantId;
  final String? tenantName;
  final String nutritionistId;
  final String nutritionistName;
  final String? nutritionistEmail;
  final String? patientId;
  final String? patientName;
  final String pairingCode;
  final String whatsappNumber;
  final String whatsappUrl;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? linkedAt;

  PatientNutritionistLink({
    required this.id,
    this.tenantId,
    this.tenantName,
    required this.nutritionistId,
    required this.nutritionistName,
    this.nutritionistEmail,
    this.patientId,
    this.patientName,
    required this.pairingCode,
    required this.whatsappNumber,
    required this.whatsappUrl,
    required this.status,
    this.notes,
    required this.createdAt,
    this.linkedAt,
  });

  factory PatientNutritionistLink.fromJson(Map<String, dynamic> json) {
    return PatientNutritionistLink(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      tenantName: json['tenant_name'] as String?,
      nutritionistId: json['nutritionist_id'] as String,
      nutritionistName: json['nutritionist_name'] as String? ?? 'Especialista',
      nutritionistEmail: json['nutritionist_email'] as String?,
      patientId: json['patient_id'] as String?,
      patientName: json['patient_name'] as String?,
      pairingCode: json['pairing_code'] as String,
      whatsappNumber: json['whatsapp_number'] as String? ?? '',
      whatsappUrl: json['whatsapp_url'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      linkedAt: json['linked_at'] != null ? DateTime.parse(json['linked_at'] as String) : null,
    );
  }
}
