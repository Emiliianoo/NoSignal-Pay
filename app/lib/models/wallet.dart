/// GET /wallet: the user's account and balance, always in integer cents.
class Wallet {
  const Wallet({
    required this.accountId,
    required this.balanceCents,
    required this.currency,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      accountId: json['account_id'] as String,
      balanceCents: json['balance_cents'] as int,
      currency: json['currency'] as String,
    );
  }

  final String accountId;
  final int balanceCents;
  final String currency;
}
