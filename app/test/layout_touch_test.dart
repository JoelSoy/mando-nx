import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/pad_layout.dart';
import 'package:remote_pad/protocol.dart';

const screens = {
  'iPhone SE': Size(667, 375),
  'iPhone 15': Size(852, 393),
  'iPhone 15 Pro Max': Size(932, 430),
  'Android 20:9': Size(800, 360),
  'iPad': Size(1180, 820),
};

void main() {
  test('a part made bigger near the edge stays on screen', () {
    const size = Size(852, 393);
    final l = PadLayout.compute(
      size,
      config: PadConfig.classic.withPart(PadPart.zr, const PartPlace(1, 0, 2)),
    );
    final r = l.parts[PadPart.zr]!;
    expect(r.right, lessThanOrEqualTo(size.width + 0.01));
    expect(r.top, greaterThanOrEqualTo(-0.01));
  });

  group('multi-touch', () {
    final l = PadLayout.compute(const Size(852, 393));
    Offset at(Control c) => l.buttons.firstWhere((b) => b.control == c).center;

    test('steer, accelerate and drift at once', () {
      final r = TouchRouter(l);
      r.down(1, at(Control.a));
      r.down(2, l.stickHome);
      r.move(2, l.stickHome + Offset(l.stickRadius, 0));
      r.down(3, at(Control.r));
      final s = r.state;
      expect(s.buttons, Btn.a | Btn.r);
      expect(s.lx, 1.0);
      expect(s.ly, 0.0);
      r.up(1);
      expect(r.state.buttons, Btn.r);
      r.up(2);
      expect(r.state.lx, 0.0);
      r.up(3);
      expect(r.state, PadState.neutral);
    });

    test('the stick is centred where the finger lands; past the rim is a full tilt; y up', () {
      final r = TouchRouter(l);
      final p = l.stickHome + const Offset(-10, 15);
      r.down(7, p);
      expect(r.state, PadState.neutral);
      r.move(7, p + Offset(0, -3 * l.stickRadius));
      expect(r.state.ly, 1.0);
      expect(
        r.stickKnob.dy,
        closeTo(p.dy - l.stickRadius, 0.001),
        reason: 'the knob stays on the rim',
      );
      r.down(8, l.stickHome + const Offset(20, 20));
      expect(
        r.state.ly,
        1.0,
        reason: 'a second finger in the zone does not take the stick',
      );
    });

    test('a finger slides from B to A', () {
      final r = TouchRouter(l);
      r.down(1, at(Control.b));
      expect(r.state.buttons, Btn.b);
      r.move(1, at(Control.a));
      expect(r.state.buttons, Btn.a);
      r.move(1, const Offset(426, 200));
      expect(r.state.buttons, 0, reason: 'off every button');
      r.move(1, at(Control.y));
      expect(r.state.buttons, Btn.y);
    });

    test('two fingers on one button, one lifts: still pressed', () {
      final r = TouchRouter(l);
      r.down(1, at(Control.zl));
      r.down(2, at(Control.zl) + const Offset(5, 0));
      r.up(1);
      expect(r.state.buttons, Btn.zl);
      r.clear();
      expect(r.state, PadState.neutral);
    });
  });
}
