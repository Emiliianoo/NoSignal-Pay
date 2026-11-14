import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosignal_pay/core/api_client.dart';
import 'package:nosignal_pay/core/api_exception.dart';

/// A fake network: answers every request with [respond] and records what was sent.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(int status, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

const userJson = {
  'id': '3f2a9c1e-5b7d-4e8a-9c21-7d4e5f6a8b90',
  'email': 'ana@example.com',
  'display_name': 'Ana',
  'created_at': '2026-11-13T10:00:00Z',
};

const authJson = {
  'access_token': 'token-123',
  'token_type': 'bearer',
  'expires_in': 86400,
  'user': userJson,
};

ApiClient clientWith(FakeAdapter adapter, {String? token}) {
  return ApiClient(
    baseUrl: 'http://api.test',
    readToken: () async => token,
    dio: Dio()..httpClientAdapter = adapter,
  );
}

void main() {
  test('login parses the token and the user', () async {
    final adapter = FakeAdapter((_) => jsonBody(200, authJson));

    final result = await clientWith(adapter)
        .login(email: 'ana@example.com', password: 'correct-horse');

    expect(result.accessToken, 'token-123');
    expect(result.expiresIn, 86400);
    expect(result.user.displayName, 'Ana');
    expect(
      adapter.requests.single.uri.toString(),
      'http://api.test/api/v1/auth/login',
    );
  });

  test('register sends display_name in snake_case', () async {
    final adapter = FakeAdapter((_) => jsonBody(201, authJson));

    await clientWith(adapter).register(
      email: 'ana@example.com',
      password: 'correct-horse',
      displayName: 'Ana',
    );

    expect(adapter.requests.single.data, {
      'email': 'ana@example.com',
      'password': 'correct-horse',
      'display_name': 'Ana',
    });
  });

  test('adds the saved token to requests', () async {
    final adapter = FakeAdapter((_) => jsonBody(200, userJson));

    final user = await clientWith(adapter, token: 'token-123').getMe();

    expect(user.email, 'ana@example.com');
    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer token-123',
    );
  });

  test('sends no Authorization header when there is no token', () async {
    final adapter = FakeAdapter((_) => jsonBody(200, authJson));

    await clientWith(adapter).login(email: 'a@b.com', password: 'x');

    expect(
      adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
  });

  test('converts the API error format into an ApiException', () async {
    final adapter = FakeAdapter(
      (_) => jsonBody(401, {
        'error': {
          'code': 'invalid_credentials',
          'message': 'Incorrect email or password.',
          'details': null,
        },
      }),
    );

    final call = clientWith(adapter).login(email: 'a@b.com', password: 'x');

    await expectLater(
      call,
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.code, 'code', 'invalid_credentials'),
      ),
    );
  });

  test('a response outside the error format becomes unknown_error', () async {
    final adapter = FakeAdapter(
      (_) => ResponseBody.fromString('<html>Bad Gateway</html>', 502),
    );

    final call = clientWith(adapter).getMe();

    await expectLater(
      call,
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 502)
            .having((e) => e.code, 'code', ApiException.unknownError),
      ),
    );
  });

  test('no response at all becomes network_error', () async {
    final adapter = FakeAdapter(
      (options) => throw DioException.connectionError(
        requestOptions: options,
        reason: 'Connection refused',
      ),
    );

    final call = clientWith(adapter).getMe();

    await expectLater(
      call,
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', isNull)
            .having((e) => e.code, 'code', ApiException.networkError),
      ),
    );
  });

  test('a timeout becomes timeout', () {
    final error = DioException.receiveTimeout(
      timeout: const Duration(seconds: 10),
      requestOptions: RequestOptions(path: '/users/me'),
    );

    expect(ApiClient.toApiException(error).code, ApiException.timeout);
  });

  test('a 401 on a request with a token calls onUnauthorized', () async {
    var calls = 0;
    final adapter = FakeAdapter(
      (_) => jsonBody(401, {
        'error': {'code': 'token_expired', 'message': '', 'details': null},
      }),
    );
    final client = clientWith(adapter, token: 'old-token')
      ..onUnauthorized = () => calls++;

    await expectLater(client.getMe(), throwsA(isA<ApiException>()));

    expect(calls, 1);
  });

  test('a 401 on login (no token) does not call onUnauthorized', () async {
    var calls = 0;
    final adapter = FakeAdapter(
      (_) => jsonBody(401, {
        'error': {
          'code': 'invalid_credentials',
          'message': '',
          'details': null,
        },
      }),
    );
    final client = clientWith(adapter)..onUnauthorized = () => calls++;

    await expectLater(
      client.login(email: 'a@b.com', password: 'x'),
      throwsA(isA<ApiException>()),
    );

    expect(calls, 0);
  });
}
