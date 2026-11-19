import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The design's stroke icons: 24 grid, 1.75 stroke, round caps and joins.
/// Paths copied from design/screens/System.dc.html.
enum AppIcons {
  charge(
    'M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h2v2h-2zM18 18h2v2h-2zM18 14h2M14 18v2',
  ),
  pay(
    'M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2M4 12h16',
  ),
  topUp('M12 5v14M5 12h14'),
  incoming('M17 7L7 17M7 17h8M7 17V9'),
  outgoing('M7 17L17 7M17 7H9M17 7v8'),
  back('M15 18l-6-6 6-6'),
  close('M6 6l12 12M18 6L6 18'),
  done('M5 12.5l4.5 4.5L19 7.5'),
  copy(
    'M9 9h10a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1V10a1 1 0 0 1 1-1zM16 5V4a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h1',
  ),
  logout('M9 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h3M16 16l4-4-4-4M20 12H10'),

  /// Wi-Fi with a slash, from Result.dc.html.
  noSignal(
    'M4 4l16 16M8.5 16.5a5 5 0 0 1 7 0M5 13a10 10 0 0 1 5.2-2.7M19 13a10 10 0 0 0-3.4-2.2M2 9.5a15 15 0 0 1 4.6-3M22 9.5a15 15 0 0 0-11.3-3.9M12 20h.01',
  );

  const AppIcons(this.path);

  final String path;
}

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = 24,
    required this.color,
    this.strokeWidth = 1.75,
  });

  final AppIcons icon;
  final double size;
  final Color color;

  /// In 24-grid units, so it scales with [size] like the design's SVGs.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    // Decorative: the button or row around it carries the label.
    return ExcludeSemantics(
      child: SvgPicture.string(
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" '
        'stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round">'
        '<path d="${icon.path}"/></svg>',
        width: size,
        height: size,
        theme: SvgTheme(currentColor: color),
      ),
    );
  }
}
