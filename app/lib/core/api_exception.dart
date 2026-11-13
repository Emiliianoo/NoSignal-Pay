/// Every failed API call ends up as an ApiException. Providers never see dio types.
///
/// Decide what to do by [code], never by [message]: [code] is the server's error
/// code (for example `invalid_credentials`) or one of the local codes below.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  /// No response arrived (no network, server down, wrong address).
  static const networkError = 'network_error';

  /// The server took longer than the timeout to answer.
  static const timeout = 'timeout';

  /// A response arrived but it was not in the API's error format.
  static const unknownError = 'unknown_error';

  /// HTTP status, or null when no response arrived.
  final int? statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';
}
