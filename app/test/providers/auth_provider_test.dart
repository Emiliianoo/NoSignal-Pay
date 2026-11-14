import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosignal_pay/core/api_client.dart';
import 'package:nosignal_pay/core/api_exception.dart';
import 'package:nosignal_pay/core/token_storage.dart';
import 'package:nosignal_pay/models/user.dart';
import 'package:nosignal_pay/providers/auth_provider.dart';

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
  int loginCalls = 0;

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    return _resultOrThrow(loginResult);
  }

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  }) async => _resultOrThrow(loginResult);

  @override
  Future<User> getMe() async {
    final result = meResult;
    if (result is ApiException && result.statusCode == 401) {
      onUnauthorized?.call(); // what the real interceptor does
    }
    return _resultOrThrow(meResult);
  }

  T _resultOrThrow<T>(Object? result) {
    if (result is ApiException) throw result;
    return result as T;
  }
}

void main() {
  late FakeApiClient api;
  late TokenStorage storage;
  late AuthProvider auth;

  void start({String? savedToken}) {
    // flutter_secure_storage's in-memory version for tests.
    FlutterSecureStorage.setMockInitialValues(
      savedToken == null ? {} : {'access_token': savedToken},
    );
    api = FakeApiClient();
    storage = TokenStorage();
    auth = AuthProvider(api: api, tokenStorage: storage);
  }

  test('starts as unknown', () {
    start();
    expect(auth.status, AuthStatus.unknown);
  });

  group('restoreSession', () {
    test('no saved token: signedOut', () async {
      start();
      await auth.restoreSession();
      expect(auth.status, AuthStatus.signedOut);
    });

    test('valid token: signedIn with the user', () async {
      start(savedToken: 'token-123');
      api.meResult = ana;

      await auth.restoreSession();

      expect(auth.status, AuthStatus.signedIn);
      expect(auth.user?.displayName, 'Ana');
    });

    test('expired token: signedOut and the token is deleted', () async {
      start(savedToken: 'old-token');
      api.meResult = apiError(401, 'token_expired');

      await auth.restoreSession();

      expect(auth.status, AuthStatus.signedOut);
      expect(await storage.read(), isNull);
    });

    test('no network: signedOut with network_error, token kept', () async {
      start(savedToken: 'token-123');
      api.meResult = apiError(null, ApiException.networkError);

      await auth.restoreSession();

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.errorCode, ApiException.networkError);
      expect(await storage.read(), 'token-123');
    });
  });

  group('login', () {
    test('success saves the token and signs in', () async {
      start();
      api.loginResult = AuthResult(
        accessToken: 'token-123',
        expiresIn: 86400,
        user: ana,
      );

      final ok = await auth.login(
        email: 'ana@example.com',
        password: 'secret-123',
      );

      expect(ok, isTrue);
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.user?.email, 'ana@example.com');
      expect(await storage.read(), 'token-123');
    });

    test('wrong password sets errorCode and stays signed out', () async {
      start();
      await auth.restoreSession();
      api.loginResult = apiError(401, 'invalid_credentials');

      final ok = await auth.login(email: 'ana@example.com', password: 'nope');

      expect(ok, isFalse);
      expect(auth.errorCode, 'invalid_credentials');
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.isLoading, isFalse);
    });

    test('isLoading is true while waiting and blocks a second call', () async {
      start();
      api.loginResult = AuthResult(accessToken: 't', expiresIn: 1, user: ana);

      final first = auth.login(email: 'a@b.com', password: 'x');
      expect(auth.isLoading, isTrue);
      final second = await auth.login(email: 'a@b.com', password: 'x');

      expect(second, isFalse);
      expect(await first, isTrue);
      expect(api.loginCalls, 1);
      expect(auth.isLoading, isFalse);
    });
  });

  test('register failure exposes email_already_registered', () async {
    start();
    api.loginResult = apiError(409, 'email_already_registered');

    final ok = await auth.register(
      email: 'ana@example.com',
      password: 'secret-123',
      displayName: 'Ana',
    );

    expect(ok, isFalse);
    expect(auth.errorCode, 'email_already_registered');
  });

  test('logout deletes the token and signs out', () async {
    start(savedToken: 'token-123');
    api.meResult = ana;
    await auth.restoreSession();

    await auth.logout();

    expect(auth.status, AuthStatus.signedOut);
    expect(auth.user, isNull);
    expect(await storage.read(), isNull);
  });

  test('notifies listeners when the state changes', () async {
    start();
    var notifications = 0;
    auth.addListener(() => notifications++);

    await auth.restoreSession();

    expect(notifications, greaterThan(0));
  });
}
