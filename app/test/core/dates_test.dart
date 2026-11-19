import 'package:flutter_test/flutter_test.dart';
import 'package:nosignal_pay/core/dates.dart';

void main() {
  // Local times, so the result does not depend on the machine's time zone.
  test('formats afternoon times with p. m.', () {
    expect(
      formatDateTime(DateTime(2026, 11, 12, 20, 27)),
      '12 nov 2026, 8:27 p. m.',
    );
  });

  test('midnight and noon are 12', () {
    expect(
      formatDateTime(DateTime(2026, 1, 3, 0, 5)),
      '3 ene 2026, 12:05 a. m.',
    );
    expect(
      formatDateTime(DateTime(2026, 5, 9, 12, 0)),
      '9 may 2026, 12:00 p. m.',
    );
  });
}
