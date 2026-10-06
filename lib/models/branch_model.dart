class Branch {
  final String id;
  final String name;
  final String code;
  final String? phone;
  final String? email;
  final String? address;
  final String? description;
  final bool isActive;

  Branch({
    required this.id,
    required this.name,
    required this.code,
    this.phone,
    this.email,
    this.address,
    this.description,
    this.isActive = true,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'phone': phone,
      'email': email,
      'address': address,
      'description': description,
      'is_active': isActive,
    };
  }
}
