import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The NoSignal logo: signal bars, the last one dotted, white on an accent box.
/// Login uses size 48 (radius 16); Splash uses 88 (radius 28).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, required this.size, required this.radius});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logotipo de NoSignal',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(radius),
        ),
        alignment: Alignment.center,
        // The icon is a bit over half the box: 26 in 48, 48 in 88.
        child: CustomPaint(
          size: Size.square(size * 0.545),
          painter: _BarsPainter(),
        ),
      ),
    );
  }
}

/// Draws the logo's paths from the design on a 24x24 grid, scaled to [size].
class _BarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final stroke = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // M5 19v-3  M10 19v-7  M15 19V8
    canvas.drawLine(const Offset(5, 19), const Offset(5, 16), stroke);
    canvas.drawLine(const Offset(10, 19), const Offset(10, 12), stroke);
    canvas.drawLine(const Offset(15, 19), const Offset(15, 8), stroke);

    // M20 19V5 with dasharray "0.1 4": round dots every 4.1 units.
    final dot = Paint()..color = Colors.white;
    for (var y = 19.0; y >= 5; y -= 4.1) {
      canvas.drawCircle(Offset(20, y), 1, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
