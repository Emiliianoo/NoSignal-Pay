import 'package:flutter/material.dart';

/// A labeled text field: label above (14/500, 8 apart), a 52-high field and
/// optional help text below. Borders and padding come from
/// `inputDecorationTheme` in theme.dart.
///
/// The screen owns the [controller]: it creates it, reads its text on submit
/// and disposes it.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.helperText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.enabled = true,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? helperText;
  final TextInputType? keyboardType;

  /// What the keyboard's action key does: `next` moves to the next field,
  /// `done` closes the keyboard and calls [onSubmitted].
  final TextInputAction? textInputAction;

  /// Lets the system offer saved emails and passwords.
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: text.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          obscureText: obscureText,
          enabled: enabled,
          onSubmitted: onSubmitted,
          autocorrect:
              !obscureText && keyboardType != TextInputType.emailAddress,
          style: text.bodyLarge,
          // The label lives above the field (not inside it), as in the design.
          decoration: const InputDecoration(),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 8),
          Text(helperText!, style: text.bodySmall),
        ],
      ],
    );
  }
}
