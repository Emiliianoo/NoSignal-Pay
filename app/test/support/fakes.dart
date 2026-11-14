import 'dart:async';

import 'package:nosignal_pay/core/api_client.dart';
import 'package:nosignal_pay/core/api_exception.dart';
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
  int loginCalls = 0;

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
