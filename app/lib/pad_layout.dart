// The touch gamepad in landscape: where each control is (PadLayout) and which fingers press what (TouchRouter). Pure Dart: tests check the layout on several screens and the
// multi-touch routing (a finger may slide from one button to the next; the stick is floating: it is centred where the finger lands in its zone).
import 'dart:math' as math;
import 'dart:ui';

import 'protocol.dart';

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

class PadLayout {
  PadLayout._(
    this.size,
    this.buttons,
    this.stickZone,
    this.stickHome,
    this.stickRadius,
  );
  final Size size;
  final List<PadButton> buttons;
  final Rect stickZone;
  final Offset stickHome;
  final double stickRadius;

  /// The layout's unit: a tenth of the height, or an eighteenth of the width on a wide screen.
  double get unit => math.min(size.height / 10, size.width / 18);

  /// The layout for a landscape screen of this size, inside its safe area (the notch, the home indicator).
  factory PadLayout.compute(
    Size size, {
    double safeLeft = 0,
    double safeRight = 0,
    double safeBottom = 0,
  }) {
    final w = size.width, h = size.height;
    final u = math.min(h / 10, w / 18); // = unit
    final left = safeLeft, right = w - safeRight, bottom = h - safeBottom;
    Rect box(double x, double y, double bw, double bh) =>
        Rect.fromLTWH(x, y, bw, bh);
    Rect circle(Offset c, double r) => Rect.fromCircle(center: c, radius: r);
    final b = <PadButton>[];
    // shoulders in the top corners: ZL / ZR on top, L / R under them
    b.add(
      PadButton(
        Control.zl,
        'ZL',
        box(left + 0.4 * u, 0.4 * u, 3.2 * u, 1.2 * u),
      ),
    );
    b.add(
      PadButton(Control.l, 'L', box(left + 0.4 * u, 1.8 * u, 3.2 * u, 1.2 * u)),
    );
    b.add(
      PadButton(
        Control.zr,
        'ZR',
        box(right - 3.6 * u, 0.4 * u, 3.2 * u, 1.2 * u),
      ),
    );
    b.add(
      PadButton(
        Control.r,
        'R',
        box(right - 3.6 * u, 1.8 * u, 3.2 * u, 1.2 * u),
      ),
    );
    // − and + at the top, either side of the status in the middle
    b.add(
      PadButton(
        Control.minus,
        '−',
        circle(Offset(w / 2 - 2.6 * u, 1.0 * u), 0.55 * u),
        round: true,
      ),
    );
    b.add(
      PadButton(
        Control.plus,
        '+',
        circle(Offset(w / 2 + 2.6 * u, 1.0 * u), 0.55 * u),
        round: true,
      ),
    );
    // the D-pad right of the stick
    final dc = Offset(left + 7.6 * u, bottom - 2.8 * u), ds = 1.05 * u;
    b.add(
      PadButton(
        Control.up,
        '▲',
        Rect.fromCenter(center: dc.translate(0, -ds), width: ds, height: ds),
      ),
    );
    b.add(
      PadButton(
        Control.down,
        '▼',
        Rect.fromCenter(center: dc.translate(0, ds), width: ds, height: ds),
      ),
    );
    b.add(
      PadButton(
        Control.left,
        '◀',
        Rect.fromCenter(center: dc.translate(-ds, 0), width: ds, height: ds),
      ),
    );
    b.add(
      PadButton(
        Control.right,
        '▶',
        Rect.fromCenter(center: dc.translate(ds, 0), width: ds, height: ds),
      ),
    );
    // A B X Y as on the Switch: A right, B bottom, X top, Y left
    final fc = Offset(right - 3.4 * u, bottom - 3.4 * u),
        off = 1.4 * u,
        br = 0.85 * u;
    b.add(
      PadButton(Control.a, 'A', circle(fc.translate(off, 0), br), round: true),
    );
    b.add(
      PadButton(Control.b, 'B', circle(fc.translate(0, off), br), round: true),
    );
    b.add(
      PadButton(Control.x, 'X', circle(fc.translate(0, -off), br), round: true),
    );
    b.add(
      PadButton(Control.y, 'Y', circle(fc.translate(-off, 0), br), round: true),
    );
    final stickZone = Rect.fromLTRB(left, 3.2 * u, left + 5.9 * u, h);
    final stickRadius = 2.0 * u;
    final stickHome = Offset(left + 3.0 * u, bottom - 3.0 * u);
    return PadLayout._(size, b, stickZone, stickHome, stickRadius);
  }

  /// The button under p: of those whose touch area holds it, the one with the nearest centre.
  PadButton? buttonAt(Offset p) {
    PadButton? best;
    var bd = double.infinity;
    for (final b in buttons) {
      if (!b.hits(p)) continue;
      final d = (p - b.center).distance;
      if (d < bd) {
        bd = d;
        best = b;
      }
    }
    return best;
  }
}

/// Fingers → buttons and stick. A finger that lands on a button presses it and, as it slides, whichever button it is on; a finger that lands in the stick zone (on no button)
/// becomes the stick, centred where it landed (kept far enough inside the zone for a full tilt), until it lifts. Only one finger drives the stick.
class TouchRouter {
  TouchRouter(this.layout);
  PadLayout layout;
  final Map<int, Control?> _buttonFingers = {};
  int? _stickFinger;
  Offset _stickOrigin = Offset.zero, _stickPos = Offset.zero;

  Offset get stickOrigin =>
      _stickFinger == null ? layout.stickHome : _stickOrigin;
  Offset get stickKnob =>
      _stickFinger == null ? layout.stickHome : _stickOrigin + _clampedOffset();
  bool get stickActive => _stickFinger != null;
  Set<Control> get pressed =>
      _buttonFingers.values.whereType<Control>().toSet();

  void down(int pointer, Offset p) {
    final btn = layout.buttonAt(p);
    if (btn == null && _stickFinger == null && layout.stickZone.contains(p)) {
      _stickFinger = pointer;
      final r = layout.stickRadius, z = layout.stickZone;
      _stickOrigin = Offset(
        p.dx.clamp(
          z.left + r * 0.6,
          math.max(z.left + r * 0.6, z.right - r * 0.6),
        ),
        p.dy.clamp(
          z.top + r * 0.6,
          math.max(z.top + r * 0.6, z.bottom - r * 0.6),
        ),
      );
      _stickPos = p;
      return;
    }
    _buttonFingers[pointer] = btn?.control;
  }

  void move(int pointer, Offset p) {
    if (pointer == _stickFinger) {
      _stickPos = p;
      return;
    }
    if (_buttonFingers.containsKey(pointer)) {
      _buttonFingers[pointer] = layout.buttonAt(p)?.control;
    }
  }

  void up(int pointer) {
    if (pointer == _stickFinger) {
      _stickFinger = null;
      return;
    }
    _buttonFingers.remove(pointer);
  }

  void clear() {
    _buttonFingers.clear();
    _stickFinger = null;
  }

  Offset _clampedOffset() {
    final d = _stickPos - _stickOrigin, r = layout.stickRadius;
    return d.distance > r ? d / d.distance * r : d;
  }

  PadState get state {
    var bits = 0;
    for (final c in pressed) {
      bits |= controlBits[c]!;
    }
    var lx = 0.0, ly = 0.0;
    if (_stickFinger != null) {
      final d = _stickPos - _stickOrigin;
      (lx, ly) = normalizeStick(
        d.dx / layout.stickRadius,
        d.dy / layout.stickRadius,
      );
    }
    return PadState(buttons: bits, lx: lx, ly: ly);
  }
}
