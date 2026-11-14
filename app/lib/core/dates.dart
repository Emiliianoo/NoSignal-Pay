const _months = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// "12 nov 2026, 8:27 p. m." in the phone's local time, as in the design.
String formatDateTime(DateTime value) {
  final local = value.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minutes = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'a. m.' : 'p. m.';
  return '${local.day} ${_months[local.month - 1]} ${local.year}, '
      '$hour12:$minutes $period';
}
