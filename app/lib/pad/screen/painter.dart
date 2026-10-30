// Tactile drawing only; every circle and rounded rectangle uses the router's exact hit geometry.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../gamer_theme.dart';
import '../../pad_layout.dart';

class PadPainter extends CustomPainter {
  PadPainter(
    this.layout,
    this.router,
    this.accent, {
    this.editing = false,
    this.selected,
    this.hidden = const {},
    super.repaint,
  });
  final PadLayout layout;
  final TouchRouter router;
  final Color accent;
  final bool editing;
  final PadPart? selected;
  final Set<Control>
  hidden; // labels left out: a picture takes their place (game_art.dart)
  static const faceColors = {
    Control.a: coral,
    Control.b: Colors.white,
    Control.x: cyan,
    Control.y: Colors.white,
  };
  @override
  void paint(Canvas canvas, Size size) {
    final pressed = router.pressed,
        origin = router.stickOrigin,
        knob = router.stickKnob;
    final base = Rect.fromCircle(center: origin, radius: layout.stickRadius);
    canvas.drawCircle(
      origin.translate(0, 3),
      layout.stickRadius,
      Paint()..color = Colors.black.withValues(alpha: .35),
    );
    canvas.drawCircle(
      origin,
      layout.stickRadius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF303641), Color(0xFF171B22)],
        ).createShader(base),
    );
    canvas.drawCircle(
      origin,
      layout.stickRadius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF5B6673),
    );
    canvas.drawCircle(
      origin,
      layout.stickRadius * .78,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: .08),
    );
    final cap = Rect.fromCircle(center: knob, radius: layout.stickRadius * .43);
    canvas.drawCircle(
      knob.translate(0, 3),
      cap.width / 2,
      Paint()..color = Colors.black54,
    );
    canvas.drawCircle(
      knob,
      cap.width / 2,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: router.stickActive
              ? [const Color(0xFF607582), const Color(0xFF293C48)]
              : [const Color(0xFF505865), const Color(0xFF292F39)],
        ).createShader(cap),
    );
    canvas.drawCircle(
      knob,
      cap.width * .34,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: .16),
    );
    for (final b in layout.buttons) {
      final on = pressed.contains(b.control);
      final shape = Path();
      if (b.round) {
        shape.addOval(b.rect);
      } else {
        shape.addRRect(
          RRect.fromRectAndRadius(
            b.rect,
            Radius.circular(b.rect.shortestSide * .26),
          ),
        );
      }
      canvas.drawShadow(shape, Colors.black, on ? 1 : 3, true);
      canvas.drawPath(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: on
                ? [const Color(0xFF59636F), const Color(0xFF303A46)]
                : [const Color(0xFF353C47), const Color(0xFF1C212A)],
          ).createShader(b.rect),
      );
      canvas.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = on ? 2 : 1.2
          ..color = on
              ? Colors.white.withValues(alpha: .8)
              : Colors.white.withValues(alpha: .24),
      );
      if (hidden.contains(b.control)) continue;
      final text = TextPainter(
        text: TextSpan(
          text: b.label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: on ? 1 : .92),
            fontSize: b.rect.shortestSide * .40,
            fontWeight: FontWeight.w800,
            shadows: const [
              Shadow(color: Colors.black54, offset: Offset(0, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        b.center -
            Offset(text.width / 2, text.height / 2) +
            (on ? const Offset(0, 1) : Offset.zero),
      );
    }
    if (editing) {
      for (final e in layout.parts.entries) {
        final on = e.key == selected;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            e.value.inflate(4),
            const Radius.circular(10),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = on ? 2.5 : 1
            ..color = on ? lime : Colors.white.withValues(alpha: .45),
        );
        if (on) {
          final label = TextPainter(
            text: TextSpan(
              text: partNames[e.key],
              style: const TextStyle(
                color: lime,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          label.paint(canvas, e.value.topLeft.translate(0, -label.height - 6));
        }
      }
    }
  }

  @override
  bool shouldRepaint(PadPainter old) =>
      old.router != router ||
      old.accent != accent ||
      old.editing != editing ||
      old.selected != selected ||
      !setEquals(old.hidden, hidden) ||
      old.layout != layout;
}
