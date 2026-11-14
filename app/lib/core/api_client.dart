import 'package:dio/dio.dart';

import '../models/user.dart';
import '../models/wallet.dart';
import 'api_exception.dart';

/// Returns the saved access token, or null when nobody is signed in.
typedef TokenReader = Future<String?> Function();

/// The only class that uses dio. It adds the token to each request, turns JSON
/// into models and turns every failure into an [ApiException].
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this._readToken,
    Dio? dio, // tests pass their own Dio with a fake adapter
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = '$baseUrl/api/v1'
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 10)
      ..contentType = Headers.jsonContentType;
    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _addToken, onError: _detectUnauthorized),
    );
  }

  final Dio _dio;
  final TokenReader _readToken;

  /// Called when a request that carried a token gets a 401 (for example, the
  /// token expired). AuthProvider will set this to sign the user out.
  void Function()? onUnauthorized;

  // ---------- auth ----------

  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _send(
      () => _dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'display_name': displayName,
        },
      ),
      AuthResult.fromJson,
    );
  }

  Future<AuthResult> login({required String email, required String password}) {
    return _send(
      () => _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      ),
      AuthResult.fromJson,
    );
  }

  Future<User> getMe() {
    return _send(() => _dio.get('/users/me'), User.fromJson);
  }

  // ---------- wallet ----------

  Future<Wallet> getWallet() {
    return _send(() => _dio.get('/wallet'), Wallet.fromJson);
  }

  // ---------- internals ----------

  /// Runs a request and parses its JSON body, converting any failure into an
  /// [ApiException] so callers only ever catch one type.
  Future<T> _send<T>(
    Future<Response<dynamic>> Function() request,
    T Function(Map<String, dynamic> json) parse,
  ) async {
    try {
      final response = await request();
      return parse(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  Future<void> _addToken(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _readToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  void _detectUnauthorized(
    DioException error,
    ErrorInterceptorHandler handler,
  ) {
    // Only requests that carried a token: a wrong password on login is also a
    // 401, but it must not sign anybody out.
    final sentToken = error.requestOptions.headers.containsKey('Authorization');
    if (error.response?.statusCode == 401 && sentToken) {
      onUnauthorized?.call();
    }
    handler.next(error);
  }

  /// Converts a dio failure into an [ApiException]. Public for tests.
  static ApiException toApiException(DioException error) {
    final response = error.response;
    if (response == null) {
      const timeouts = {
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
      };
      return ApiException(
        statusCode: null,
        code: timeouts.contains(error.type)
            ? ApiException.timeout
            : ApiException.networkError,
        message: error.message ?? 'No response from the server.',
      );
    }

    // The API's error format: {"error": {"code": ..., "message": ..., "details": ...}}
    final data = response.data;
    if (data is Map && data['error'] is Map) {
      final body = data['error'] as Map;
      return ApiException(
        statusCode: response.statusCode,
        code: body['code'] as String? ?? ApiException.unknownError,
        message: body['message'] as String? ?? '',
      );
    }
    return ApiException(
      statusCode: response.statusCode,
      code: ApiException.unknownError,
      message: 'Unexpected response from the server.',
    );
  }
}
