// Drawing the pad: the stick (its base where the finger landed, the knob under it), every button lit while pressed, and the parts' outlines while editing. It reads the
// touch router when it paints and repaints when the touches change (repaint), so a finger moving does not rebuild the screen.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../classic_theme.dart';
import '../../pad_layout.dart';

class ClassicPadPainter extends CustomPainter {
  ClassicPadPainter(
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
    Control.a: lime,
    Control.b: Color(0xFFFF719A),
    Control.x: cyan,
    Control.y: Color(0xFFB7A1FF),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final pressed = router.pressed,
        knob = router.stickKnob,
        origin = router.stickOrigin,
        active = router.stickActive;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = cyan.withValues(alpha: .35);
    // the stick: its base where the finger landed (or at home), the knob under the finger
    canvas.drawCircle(
      origin,
      layout.stickRadius,
      Paint()..color = Colors.white.withValues(alpha: active ? 0.10 : 0.05),
    );
    canvas.drawCircle(origin, layout.stickRadius, stroke);
    canvas.drawCircle(
      knob,
      layout.stickRadius * 0.42,
      Paint()
        ..color = active
            ? accent.withValues(alpha: 0.85)
            : cyan.withValues(alpha: .25),
    );
    for (final b in layout.buttons) {
      final on = pressed.contains(b.control);
      final base = faceColors[b.control] ?? cyan;
      final fill = Paint()
        ..color = on
            ? base.withValues(alpha: 0.85)
            : base.withValues(
                alpha: faceColors.containsKey(b.control) ? 0.28 : 0.10,
              );
      if (b.round) {
        canvas.drawCircle(b.center, b.rect.width / 2, fill);
        canvas.drawCircle(b.center, b.rect.width / 2, stroke);
      } else {
        final rr = RRect.fromRectAndRadius(
          b.rect,
          Radius.circular(b.rect.shortestSide * 0.3),
        );
        canvas.drawRRect(rr, fill);
        canvas.drawRRect(rr, stroke);
      }
      if (hidden.contains(b.control)) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: b.label,
          style: TextStyle(
            color: on ? Colors.black : Colors.white,
            fontSize: b.rect.shortestSide * 0.42,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, b.center - Offset(tp.width / 2, tp.height / 2));
    }
    if (editing) {
      // every part's outline; the selected one in lime with its name
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
            ..color = on ? lime : Colors.white.withValues(alpha: .35),
        );
        if (on) {
          final tp = TextPainter(
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
          tp.paint(canvas, e.value.topLeft.translate(0, -tp.height - 6));
        }
      }
    }
  }

  @override
  bool shouldRepaint(ClassicPadPainter old) =>
      old.router != router ||
      old.accent != accent ||
      old.editing != editing ||
      old.selected != selected ||
      !setEquals(old.hidden, hidden) ||
      old.layout != layout;
}
