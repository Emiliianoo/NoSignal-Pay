import 'package:material_ui/material_ui.dart';

/// The main action of a screen: full width, 56 high, accent background.
/// Colors, height and radius come from `filledButtonTheme` in theme.dart.
///
/// While [isLoading] is true the button is disabled and shows a spinner, so a
/// second tap cannot send the same request twice.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? Semantics(
                label: label,
                child: const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            : Text(label),
      ),
    );
  }
}
