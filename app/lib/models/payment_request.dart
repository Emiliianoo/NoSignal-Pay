/// A QR charge (GET /payment-requests/{id}). The status is computed by the
/// server: `pending`, `paid` or `expired`.
class PaymentRequest {
  const PaymentRequest({
    required this.id,
    required this.amountCents,
    required this.currency,
    required this.description,
    required this.payeeName,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    required this.qrPayload,
  });

  factory PaymentRequest.fromJson(Map<String, dynamic> json) {
    return PaymentRequest(
      id: json['id'] as String,
      amountCents: json['amount_cents'] as int,
      currency: json['currency'] as String,
      description: json['description'] as String?,
      payeeName: json['payee_name'] as String,
      status: json['status'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      qrPayload: json['qr_payload'] as String,
    );
  }

  static const pending = 'pending';
  static const paid = 'paid';
  static const expired = 'expired';

  final String id;
  final int amountCents;
  final String currency;
  final String? description;
  final String payeeName;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;

  /// The exact text to draw as a QR: `NSP:1:REQ:<id>`.
  final String qrPayload;
}
