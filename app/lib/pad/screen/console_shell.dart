// Decorative hardware shells only: controls and their hit rectangles remain owned by PadLayout.
import 'package:flutter/material.dart';

import '../../gamer_theme.dart';

class ConsoleShell extends CustomPainter {
  const ConsoleShell();
  @override
  void paint(Canvas c, Size size) {
    c.drawRect(Offset.zero & size, Paint()..color = ink);
    final w = size.width, h = size.height;
    void side(Rect rect, Color color, bool left) {
      final shape = RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(left ? 44 : 18),
        bottomLeft: Radius.circular(left ? 44 : 18),
        topRight: Radius.circular(left ? 18 : 44),
        bottomRight: Radius.circular(left ? 18 : 44),
      );
      c.drawRRect(
        shape.shift(const Offset(0, 3)),
        Paint()..color = Colors.black.withValues(alpha: .55),
      );
      c.drawRRect(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, Colors.black, .22)!],
          ).createShader(rect),
      );
      c.drawRRect(
        shape.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: .22),
      );
      final x = left ? rect.right - 6 : rect.left + 6;
      c.drawLine(
        Offset(x, 32),
        Offset(x, h - 32),
        Paint()
          ..color = Colors.black.withValues(alpha: .15)
          ..strokeWidth = 2,
      );
    }

    side(
      Rect.fromLTWH(8, 7, w * .285 - 8, h - 14),
      const Color(0xFF27B8CD),
      true,
    );
    side(
      Rect.fromLTWH(w * .715, 7, w * .285 - 8, h - 14),
      const Color(0xFFED6962),
      false,
    );
    final mid = Rect.fromLTWH(w * .3, 10, w * .4, h - 20);
    c.drawRRect(
      RRect.fromRectAndRadius(mid, const Radius.circular(20)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF252A33), Color(0xFF171A20)],
        ).createShader(mid),
    );
  }

  @override
  bool shouldRepaint(ConsoleShell oldDelegate) => false;
}
