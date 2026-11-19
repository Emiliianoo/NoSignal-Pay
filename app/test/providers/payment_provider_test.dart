import 'package:flutter_test/flutter_test.dart';
import 'package:nosignal_pay/core/api_exception.dart';
import 'package:nosignal_pay/models/payment_request.dart';
import 'package:nosignal_pay/providers/payment_provider.dart';

import '../support/fakes.dart';

void main() {
  late FakeApiClient api;
  late PaymentProvider payment;

  setUp(() {
    api = FakeApiClient();
    payment = PaymentProvider(api: api);
  });

  group('loadFromQr', () {
    test('an invalid code fails without calling the server', () async {
      final ok = await payment.loadFromQr('https://example.com');

      expect(ok, isFalse);
      expect(payment.errorCode, PaymentProvider.invalidQr);
      expect(api.paymentRequestIds, isEmpty);
    });

    test('a pending charge is ready and gets an idempotency key', () async {
      api.paymentRequestResult = chargeWith();

      final ok = await payment.loadFromQr(qrText);

      expect(ok, isTrue);
      expect(payment.status, PaymentStatus.ready);
      expect(payment.request?.payeeName, 'Mariana Cruz');
      expect(api.paymentRequestIds, [requestId]);
      expect(payment.idempotencyKey, hasLength(36));
    });

    test('a paid charge stops at the scan screen', () async {
      api.paymentRequestResult = chargeWith(status: PaymentRequest.paid);

      expect(await payment.loadFromQr(qrText), isFalse);
      expect(payment.errorCode, 'payment_request_already_paid');
    });

    test('an expired charge stops at the scan screen', () async {
      api.paymentRequestResult = chargeWith(status: PaymentRequest.expired);

      expect(await payment.loadFromQr(qrText), isFalse);
      expect(payment.errorCode, 'payment_request_expired');
    });

    test('a 404 from the server is shown by its code', () async {
      api.paymentRequestResult = apiError(404, 'payment_request_not_found');

      expect(await payment.loadFromQr(qrText), isFalse);
      expect(payment.errorCode, 'payment_request_not_found');
    });
  });

  group('confirm', () {
    setUp(() async {
      api.paymentRequestResult = chargeWith();
      await payment.loadFromQr(qrText);
    });

    test('success keeps the result and the new balance', () async {
      api.payResults.add(paidWith(balanceCents: 154450));

      final ok = await payment.confirm();

      expect(ok, isTrue);
      expect(payment.status, PaymentStatus.success);
      expect(payment.result?.balanceCents, 154450);
    });

    test('a retry after no response reuses the same key', () async {
      api.payResults
        ..add(apiError(null, ApiException.timeout))
        ..add(paidWith());

      expect(await payment.confirm(), isFalse);
      expect(payment.canRetry, isTrue);
      expect(await payment.confirm(), isTrue);

      expect(api.payKeys, hasLength(2));
      expect(api.payKeys[0], api.payKeys[1]);
    });

    test('a clear "no" from the server is not retryable', () async {
      api.payResults.add(apiError(422, 'insufficient_funds'));

      await payment.confirm();

      expect(payment.errorCode, 'insufficient_funds');
      expect(payment.canRetry, isFalse);
    });

    test('a second tap while paying sends nothing', () async {
      api.payResults.add(paidWith());

      final first = payment.confirm();
      final second = await payment.confirm();

      expect(second, isFalse);
      expect(await first, isTrue);
      expect(api.payKeys, hasLength(1));
    });

    test('clear drops the key; loading again creates a new one', () async {
      final firstKey = payment.idempotencyKey;

      payment.clear();
      expect(payment.idempotencyKey, isNull);
      expect(payment.request, isNull);

      await payment.loadFromQr(qrText);
      expect(payment.idempotencyKey, isNot(firstKey));
    });
  });
}
