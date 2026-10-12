class SubscriptionReceipt {
  final String id,
      buyerName,
      buyerEmail,
      planName,
      currency,
      orderId,
      captureId;
  final double amount;
  final bool isSandbox;
  final DateTime paidAt;
  final DateTime? expiresAt;
  SubscriptionReceipt.fromJson(Map<String, dynamic> data)
    : id = data['id'] as String,
      buyerName = data['buyer_name'] as String,
      buyerEmail = data['buyer_email'] as String,
      planName = data['plan_name'] as String,
      currency = data['currency'] as String,
      orderId = data['paypal_order_id'] as String,
      captureId = data['paypal_capture_id'] as String,
      amount = (data['amount'] as num).toDouble(),
      isSandbox = data['is_sandbox'] == true,
      paidAt = DateTime.parse(data['paid_at'] as String).toUtc(),
      expiresAt = data['expires_at'] == null
          ? null
          : DateTime.parse(data['expires_at'] as String).toUtc();
  String get filename => 'Recibo_NutriSalud_$id.pdf';
}
