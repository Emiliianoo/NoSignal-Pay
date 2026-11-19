import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

class DetailRow {
  const DetailRow(this.label, this.value, {this.emphasize = false});

  final String label;
  final String value;

  /// Weight 600 instead of 500, for totals ("Te quedarán", "Tu saldo").
  final bool emphasize;
}

/// White card with label/value rows separated by thin lines (radius 20,
/// padding 4x20, rows 14 vertical). Used by confirm, result and "pago recibido".
class DetailCard extends StatelessWidget {
  const DetailCard({super.key, required this.rows});

  final List<DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.bodyMedium!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          for (final (index, row) in rows.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: index == rows.length - 1
                    ? null
                    : const Border(
                        bottom: BorderSide(color: AppColors.divider),
                      ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.label,
                    style: text.copyWith(
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.right,
                      style: text.copyWith(
                        fontWeight: row.emphasize
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
