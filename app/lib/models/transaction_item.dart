/// One movement as the API returns it (payments, top-ups and history).
class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.type,
    required this.direction,
    required this.amountCents,
    required this.counterpartyName,
    required this.description,
    required this.createdAt,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'] as String,
      type: json['type'] as String,
      direction: json['direction'] as String,
      amountCents: json['amount_cents'] as int,
      counterpartyName: json['counterparty_name'] as String?,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;

  /// `top_up` or `payment`.
  final String type;

  /// `in` or `out`; [amountCents] is always positive.
  final String direction;
  final int amountCents;

  /// The other person's name, or null for top-ups.
  final String? counterpartyName;
  final String? description;
  final DateTime createdAt;

  bool get isIncoming => direction == 'in';
}

/// What POST /payments and POST /wallet/top-ups return.
class MoneyOperation {
  const MoneyOperation({required this.transaction, required this.balanceCents});

  factory MoneyOperation.fromJson(Map<String, dynamic> json) {
    return MoneyOperation(
      transaction: TransactionItem.fromJson(
        json['transaction'] as Map<String, dynamic>,
      ),
      balanceCents: json['balance_cents'] as int,
    );
  }

  final TransactionItem transaction;

  /// The balance right after the operation (also on a replayed request).
  final int balanceCents;
}
