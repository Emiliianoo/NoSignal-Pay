import 'package:flutter_test/flutter_test.dart';
import 'package:nosignal_pay/core/api_exception.dart';
import 'package:nosignal_pay/core/error_messages.dart';
import 'package:nosignal_pay/providers/payment_provider.dart';

void main() {
  final fallback = errorMessage('some_code_nobody_uses');

  test('every code the app shows has its own text', () {
    // If a code is missing from error_messages.dart it silently falls back to
    // "Algo salió mal"; this test catches that.
    for (final code in [
      'invalid_credentials',
      'email_already_registered',
      'validation_error',
      'not_authenticated',
      'token_expired',
      ApiException.networkError,
      ApiException.timeout,
      PaymentProvider.invalidQr,
      'payment_request_not_found',
      'payment_request_already_paid',
      'payment_request_expired',
      'cannot_pay_own_request',
      'insufficient_funds',
    ]) {
      expect(errorMessage(code), isNot(fallback), reason: code);
    }
  });
}
