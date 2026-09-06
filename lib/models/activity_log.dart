class ActivityLog {
  final String id;
  final String? userId;
  final String? userEmail;
  final String? userName;
  final String action;
  final String description;
  final String category;
  final String? ipAddress;
  final DateTime createdAt;

  ActivityLog({
    required this.id,
    this.userId,
    this.userEmail,
    this.userName,
    required this.action,
    required this.description,
    required this.category,
    this.ipAddress,
    required this.createdAt,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String?,
      userEmail: json['user_email'] as String?,
      userName: json['user_name'] as String?,
      action: json['action'] as String? ?? 'GENERAL',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'SISTEMA',
      ipAddress: json['ip_address'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_email': userEmail,
      'user_name': userName,
      'action': action,
      'description': description,
      'category': category,
      'ip_address': ipAddress,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
