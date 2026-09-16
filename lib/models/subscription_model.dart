class PlanFeature {
  final String text;
  final bool included;

  PlanFeature({
    required this.text,
    required this.included,
  });

  factory PlanFeature.fromJson(Map<String, dynamic> json) {
    return PlanFeature(
      text: json['text'] as String? ?? '',
      included: json['included'] as bool? ?? false,
    );
  }
}

class SubscriptionPlan {
  final String name;
  final String displayName;
  final double price;
  final String currency;
  final String period;
  final int? maxPatients;
  final bool recommended;
  final List<PlanFeature> features;

  SubscriptionPlan({
    required this.name,
    required this.displayName,
    required this.price,
    required this.currency,
    required this.period,
    this.maxPatients,
    required this.recommended,
    required this.features,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      period: json['period'] as String? ?? 'mes',
      maxPatients: json['max_patients'] as int?,
      recommended: json['recommended'] as bool? ?? false,
      features: (json['features'] as List<dynamic>? ?? [])
          .map((f) => PlanFeature.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Subscription {
  final String id;
  final String? tenantId;
  final String? userId;
  final String planName;
  final String status;
  final double amount;
  final String currency;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final String? paypalOrderId;

  Subscription({
    required this.id,
    this.tenantId,
    this.userId,
    required this.planName,
    required this.status,
    required this.amount,
    required this.currency,
    this.startedAt,
    this.expiresAt,
    this.createdAt,
    this.paypalOrderId,
  });

  bool get isPremium {
    return planName.toUpperCase().contains('PREMIUM') &&
        status.toUpperCase() == 'ACTIVE' &&
        (expiresAt == null || expiresAt!.isAfter(DateTime.now()));
  }

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  String get formattedExpiresAt {
    if (expiresAt == null) return '30 días';
    final d = expiresAt!;
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year;
    return '$day/$month/$year';
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String?,
      userId: json['user_id'] as String?,
      planName: json['plan_name'] as String? ?? 'CLIENTE_FREE',
      status: json['status'] as String? ?? 'ACTIVE',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at']) : null,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      paypalOrderId: json['paypal_order_id'] as String?,
    );
  }
}

class CreateOrderResponse {
  final String orderId;
  final String approvalUrl;

  CreateOrderResponse({
    required this.orderId,
    required this.approvalUrl,
  });

  factory CreateOrderResponse.fromJson(Map<String, dynamic> json) {
    return CreateOrderResponse(
      orderId: json['order_id'] as String? ?? '',
      approvalUrl: json['approval_url'] as String? ?? '',
    );
  }
}
