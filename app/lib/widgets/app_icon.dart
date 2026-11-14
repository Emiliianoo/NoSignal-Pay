import 'package:flutter/material.dart';
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
  logout('M9 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h3M16 16l4-4-4-4M20 12H10');

  const AppIcons(this.path);

  final String path;
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size = 24, required this.color});

  final AppIcons icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Decorative: the button or row around it carries the label.
    return ExcludeSemantics(
      child: SvgPicture.string(
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" '
        'stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">'
        '<path d="${icon.path}"/></svg>',
        width: size,
        height: size,
        theme: SvgTheme(currentColor: color),
      ),
    );
  }
}
