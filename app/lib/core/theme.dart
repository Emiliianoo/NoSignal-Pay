import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Color tokens from DESIGN.md. Widgets read colors from here or from the
/// theme, never as hex literals.
abstract final class AppColors {
  static const background = Color(0xFFF4F5F7);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0D1117);
  static const inkRaised = Color(0xFF1E242D);
  static const textSecondary = Color(0xFF4A5361);
  static const textOnDarkSecondary = Color(0xFFC9CED6);
  static const fieldBorder = Color(0xFF8A93A1);
  static const divider = Color(0xFFE3E6EB);
  static const chip = Color(0xFFEEF0F3);
  static const accent = Color(0xFF0A7D4B);
  static const accentPressed = Color(0xFF075C37);
  static const accentSoft = Color(0xFFE6F4EC);
  static const scanLine = Color(0xFF34C27F);
}

/// Corner radii from DESIGN.md. Inner radius = outer radius - padding.
abstract final class AppRadius {
  /// Balance card, QR card, bottom sheets.
  static const sheet = 28.0;

  /// List and detail cards, buttons inside the balance card.
  static const card = 20.0;

  /// Buttons, keys, options.
  static const button = 16.0;

  /// Text fields, icon buttons.
  static const field = 14.0;

  /// Row icons, inside the QR card.
  static const small = 12.0;
}

/// Screen padding from DESIGN.md.
abstract final class AppSpacing {
  static const screenSide = 24.0;
  static const screenTop = 56.0;
}

const _tabular = [FontFeature.tabularFigures()];

/// Builds a style from the type scale: [size]/[lineHeight] in logical pixels.
/// Every style uses tabular figures so amounts and times line up.
TextStyle _style(
  double size,
  double lineHeight,
  FontWeight weight, {
  double letterSpacing = 0,
  Color color = AppColors.ink,
}) {
  return TextStyle(
    fontSize: size,
    height: lineHeight / size, // Flutter takes line height as a multiplier
    fontWeight: weight,
    letterSpacing: letterSpacing,
    color: color,
    fontFeatures: _tabular,
  );
}

/// The type scale from DESIGN.md mapped onto Material's named styles, so
/// widgets can write `Theme.of(context).textTheme.headlineLarge`.
final _textTheme = TextTheme(
  // Amount being typed: 60/68 600 -1.5
  displayLarge: _style(60, 68, FontWeight.w600, letterSpacing: -1.5),
  // Balance: 44/52 600 -0.5
  displayMedium: _style(44, 52, FontWeight.w600, letterSpacing: -0.5),
  // Screen title: 32/38 600 -0.5
  headlineLarge: _style(32, 38, FontWeight.w600, letterSpacing: -0.5),
  // Secondary title: 28/34 600 -0.4
  headlineMedium: _style(28, 34, FontWeight.w600, letterSpacing: -0.4),
  // Sheet title and greeting: 24/30 600 -0.3
  headlineSmall: _style(24, 30, FontWeight.w600, letterSpacing: -0.3),
  // Button and section header: 16/24 600
  titleMedium: _style(16, 24, FontWeight.w600),
  // Secondary/text button: 15/22 600
  titleSmall: _style(15, 22, FontWeight.w600),
  // Text inside fields: 16/24 400
  bodyLarge: _style(16, 24, FontWeight.w400),
  // List row and detail: 15/22 500
  bodyMedium: _style(15, 22, FontWeight.w500),
  // Supporting text: 13/18 400, the minimum size
  bodySmall: _style(13, 18, FontWeight.w400, color: AppColors.textSecondary),
  // Field label: 14/20 500
  labelLarge: _style(14, 20, FontWeight.w500),
);

ThemeData buildAppTheme() {
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.field),
    borderSide: const BorderSide(color: AppColors.fieldBorder, width: 1.5),
  );

  return ThemeData(
    colorScheme: const ColorScheme.light(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
    ),
    scaffoldBackgroundColor: AppColors.background,
    // Roboto everywhere. Android already has it; on iOS google_fonts
    // downloads it the first time and caches it.
    textTheme: GoogleFonts.robotoTextTheme(_textTheme),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      // 14 + 24 (line height) + 14 = 52, the field height in the design.
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.accent, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        textStyle: WidgetStatePropertyAll(
          GoogleFonts.roboto(textStyle: _textTheme.titleMedium),
        ),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        // WidgetStateProperty: the color depends on the button's state.
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.accent.withValues(alpha: 0.6);
          }
          if (states.contains(WidgetState.pressed)) {
            return AppColors.accentPressed;
          }
          return AppColors.accent;
        }),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(44, 48)),
        foregroundColor: const WidgetStatePropertyAll(AppColors.ink),
        textStyle: WidgetStatePropertyAll(
          GoogleFonts.roboto(textStyle: _textTheme.titleSmall),
        ),
      ),
    ),
  );
}
