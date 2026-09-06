class User {
  final String id;
  final String email;
  final String fullName;
  final String? roleId;
  final String? tenantId;
  final bool isActive;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    this.roleId,
    this.tenantId,
    required this.isActive,
    required this.isVerified,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      roleId: json['role_id'] as String?,
      tenantId: json['tenant_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role_id': roleId,
      'tenant_id': tenantId,
      'is_active': isActive,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
