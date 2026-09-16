class NotificationModel {
  final String id;
  final String userId;
  final String? tenantId;
  final String title;
  final String message;
  final String type; // CITA_CREADA, CITA_CONFIRMADA, CITA_CANCELADA, SISTEMA
  final String? referenceId;
  bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    this.tenantId,
    required this.title,
    required this.message,
    required this.type,
    this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 0) return 'Hace ${diff.inDays} d';
    if (diff.inHours > 0) return 'Hace ${diff.inHours} h';
    if (diff.inMinutes > 0) return 'Hace ${diff.inMinutes} min';
    return 'Hace un momento';
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tenantId: json['tenant_id'] as String?,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String? ?? 'SISTEMA',
      referenceId: json['reference_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'tenant_id': tenantId,
      'title': title,
      'message': message,
      'type': type,
      'reference_id': referenceId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
