// The pad's controls: each button's NpadButton bit, its label, where it is drawn and its touch area.
import 'dart:ui';

import '../protocol.dart';

enum Control { a, b, x, y, l, r, zl, zr, plus, minus, up, down, left, right }

const Map<Control, int> controlBits = {
  Control.a: Btn.a,
  Control.b: Btn.b,
  Control.x: Btn.x,
  Control.y: Btn.y,
  Control.l: Btn.l,
  Control.r: Btn.r,
  Control.zl: Btn.zl,
  Control.zr: Btn.zr,
  Control.plus: Btn.plus,
  Control.minus: Btn.minus,
  Control.up: Btn.up,
  Control.down: Btn.down,
  Control.left: Btn.left,
  Control.right: Btn.right,
};

class PadButton {
  const PadButton(this.control, this.label, this.rect, {this.round = false});
  final Control control;
  final String label;
  final Rect rect;
  final bool round;
  Offset get center => rect.center;

  /// The touch area: the drawn shape and a little more (fingers are wider than they look).
  bool hits(Offset p) {
    if (round) return (p - center).distance <= rect.width / 2 * 1.15;
    return rect.inflate(rect.shortestSide * 0.12).contains(p);
  }
}
