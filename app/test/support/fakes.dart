import 'dart:async';

import 'package:nosignal_pay/core/api_client.dart';
import 'package:nosignal_pay/core/api_exception.dart';
import 'package:nosignal_pay/models/payment_request.dart';
import 'package:nosignal_pay/models/transaction_item.dart';
import 'package:nosignal_pay/models/user.dart';
import 'package:nosignal_pay/models/wallet.dart';

final ana = User(
  id: '3f2a9c1e-5b7d-4e8a-9c21-7d4e5f6a8b90',
  email: 'ana@example.com',
  displayName: 'Ana',
  createdAt: DateTime.utc(2026, 11, 13),
);

ApiException apiError(int? status, String code) =>
    ApiException(statusCode: status, code: code, message: '');

/// An ApiClient that never touches the network: each test decides what the
/// auth calls return or throw.
class FakeApiClient extends ApiClient {
  FakeApiClient()
    : super(baseUrl: 'http://api.test', readToken: () async => null);

  Object? loginResult; // an AuthResult or an ApiException
  Object? meResult; // a User or an ApiException
  Object? walletResult; // a Wallet or an ApiException
  Object? paymentRequestResult; // a PaymentRequest or an ApiException

  /// Each call to pay() takes the next item: a MoneyOperation or an ApiException.
  final List<Object> payResults = [];
  final List<String> paymentRequestIds = []; // ids asked to getPaymentRequest
  final List<String> payKeys = []; // idempotency keys sent to pay()
  int loginCalls = 0;
  String? registeredName; // what the last register call sent

  /// When set, login and register wait for it, so a test can look at the
  /// screen while the request is still on its way.
  Completer<void>? gate;

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    await gate?.future;
    return _resultOrThrow(loginResult);
  }

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    registeredName = displayName;
    await gate?.future;
    return _resultOrThrow(loginResult);
  }

  @override
  Future<User> getMe() async {
    final result = meResult;
    if (result is ApiException && result.statusCode == 401) {
      onUnauthorized?.call(); // what the real interceptor does
    }
    return _resultOrThrow(meResult);
  }

  @override
  Future<Wallet> getWallet() async => _resultOrThrow(walletResult);

  @override
  Future<PaymentRequest> getPaymentRequest(String id) async {
    paymentRequestIds.add(id);
    return _resultOrThrow(paymentRequestResult);
  }

  @override
  Future<MoneyOperation> pay({
    required String paymentRequestId,
    required String idempotencyKey,
  }) async {
    payKeys.add(idempotencyKey);
    await gate?.future;
    return _resultOrThrow(payResults.removeAt(0));
  }

  T _resultOrThrow<T>(Object? result) {
    if (result is ApiException) throw result;
    return result as T;
  }
}

Wallet walletWith(int balanceCents) => Wallet(
  accountId: '9b1d0f4e-2c3a-4b5d-8e6f-7a8b9c0d1e2f',
  balanceCents: balanceCents,
  currency: 'MXN',
);

const requestId = '8c1d4e7a-2b6f-4a9d-b3e5-1f7a9c0d2e46';
const qrText = 'NSP:1:REQ:$requestId';

PaymentRequest chargeWith({
  int amountCents = 8550,
  String status = PaymentRequest.pending,
  String? description = 'Café y pan',
}) => PaymentRequest(
  id: requestId,
  amountCents: amountCents,
  currency: 'MXN',
  description: description,
  payeeName: 'Mariana Cruz',
  status: status,
  expiresAt: DateTime.utc(2026, 11, 13, 20, 37),
  createdAt: DateTime.utc(2026, 11, 13, 20, 27),
  qrPayload: qrText,
);

MoneyOperation paidWith({int amountCents = 8550, int balanceCents = 154450}) =>
    MoneyOperation(
      transaction: TransactionItem(
        id: 'b7e2c1d0-1111-4a9d-b3e5-1f7a9c0d2e46',
        type: 'payment',
        direction: 'out',
        amountCents: amountCents,
        counterpartyName: 'Mariana Cruz',
        description: 'Café y pan',
        createdAt: DateTime.utc(2026, 11, 13, 20, 28),
      ),
      balanceCents: balanceCents,
    );
