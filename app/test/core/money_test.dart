import 'package:flutter_test/flutter_test.dart';
import 'package:nosignal_pay/core/money.dart';

void main() {
  test('formats cents as pesos with thousands separators', () {
    expect(formatCents(0), r'$0.00');
    expect(formatCents(5), r'$0.05');
    expect(formatCents(8550), r'$85.50');
    expect(formatCents(100000), r'$1,000.00');
    expect(formatCents(163000), r'$1,630.00');
    expect(formatCents(123456789), r'$1,234,567.89');
  });

  test('negative amounts use the U+2212 minus sign', () {
    expect(formatCents(-12000), '−\$120.00');
  });
}
