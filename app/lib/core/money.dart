/// Formats integer cents as pesos: 163000 -> "$1,630.00", -12000 -> "−$120.00".
///
/// Uses integer math only (no double), so there is never a rounding error.
/// The minus sign is U+2212, as in the design.
String formatCents(int cents) {
  final sign = cents < 0 ? '−' : '';
  final abs = cents.abs();
  final pesos = (abs ~/ 100).toString();
  final centavos = (abs % 100).toString().padLeft(2, '0');

  // Insert a comma every three digits from the right: 1630 -> 1,630.
  final grouped = StringBuffer();
  for (var i = 0; i < pesos.length; i++) {
    if (i > 0 && (pesos.length - i) % 3 == 0) grouped.write(',');
    grouped.write(pesos[i]);
  }
  return '$sign\$$grouped.$centavos';
}
