import 'package:flutter_test/flutter_test.dart';
import 'package:nosignal_pay/core/qr_payload.dart';

void main() {
  const id = '3f2a9c1e-5b7d-4e8a-9c21-7d4e5f6a8b90';

  test('reads the id from a valid charge QR', () {
    expect(parsePaymentRequestQr('NSP:1:REQ:$id'), id);
  });

  test('ignores spaces around pasted text and normalizes case', () {
    expect(parsePaymentRequestQr('  NSP:1:REQ:${id.toUpperCase()}\n'), id);
    expect(parsePaymentRequestQr('nsp:1:req:$id'), id);
  });

  test('rejects anything that is not exactly a charge QR', () {
    for (final raw in [
      '',
      id, // no prefix
      'https://example.com/NSP:1:REQ:$id',
      'NSP:2:REQ:$id', // unknown version
      'NSP:1:OREQ:$id', // other type
      'NSP:1:REQ:$id extra',
      'NSP:1:REQ:3f2a9c1e-5b7d-1e8a-9c21-7d4e5f6a8b90', // UUID v1, not v4
      'NSP:1:REQ:not-a-uuid',
    ]) {
      expect(parsePaymentRequestQr(raw), isNull, reason: raw);
    }
  });
}
