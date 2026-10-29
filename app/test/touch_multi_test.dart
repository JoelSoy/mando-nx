import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/pad_layout.dart';
import 'package:remote_pad/protocol.dart';

void main() {
  for (final cfg in PadConfig.presets) {
    final l = PadLayout.compute(const Size(852, 393), config: cfg);
    Offset at(Control c) => l.buttons.firstWhere((b) => b.control == c).center;

    test(
      '${cfg.name}: five fingers at once, lifted in any order, each keeps its own press',
      () {
        final r = TouchRouter(l);
        r.down(1, l.stickHome);
        r.move(1, l.stickHome + Offset(l.stickRadius, 0));
        r.down(2, at(Control.a));
        r.down(3, at(Control.r));
        r.down(4, at(Control.zl));
        r.down(5, at(Control.b));
        expect(r.state.buttons, Btn.a | Btn.r | Btn.zl | Btn.b);
        expect(r.state.lx, 1.0);
        r.up(3);
        expect(r.state.buttons, Btn.a | Btn.zl | Btn.b);
        r.down(6, at(Control.r)); // pressed again while the others hold
        expect(r.state.buttons, Btn.a | Btn.zl | Btn.b | Btn.r);
        for (final p in [5, 1, 2, 6, 4]) {
          r.up(p);
        }
        expect(r.state, PadState.neutral);
        expect(r.fingers, 0);
      },
    );
  }

  final l = PadLayout.compute(const Size(852, 393));
  Offset at(Control c) => l.buttons.firstWhere((b) => b.control == c).center;

  test('the stick lifts while another finger rests in its zone: that finger takes the stick over', () {
    final r = TouchRouter(l);
    r.down(1, l.stickHome);
    final rest = l.stickHome + const Offset(-20, 30);
    r.down(2, rest); // a second thumb in the zone, on no button
    r.up(1);
    expect(r.stickActive, isTrue);
    expect(r.stickOrigin, rest, reason: 'centred where it rests');
    r.move(2, rest + Offset(0, -l.stickRadius));
    expect(r.state.ly, 1.0);
    r.up(2);
    expect(r.state, PadState.neutral);
  });

  test('a cancel (the system took the finger) releases only that finger', () {
    final r = TouchRouter(l);
    r.down(1, at(Control.a));
    r.down(2, at(Control.b));
    r.up(1); // PointerCancel goes through up
    expect(r.state.buttons, Btn.b);
  });

  test('a finger slides off a button onto another and back, and taps quickly many times', () {
    final r = TouchRouter(l);
    r.down(1, at(Control.y));
    r.move(1, at(Control.x));
    expect(r.state.buttons, Btn.x);
    r.move(1, at(Control.y));
    expect(r.state.buttons, Btn.y);
    r.up(1);
    for (var i = 0; i < 50; i++) {
      r.down(10 + i, at(Control.a));
      expect(r.state.buttons, Btn.a);
      r.up(10 + i);
      expect(r.state.buttons, 0);
    }
  });

  test('a finger let go by clear is ignored until it lifts; new fingers work at once', () {
    final r = TouchRouter(l);
    r.down(1, at(Control.a));
    r.clear();
    r.move(1, at(Control.b));
    expect(r.state.buttons, 0);
    r.down(2, at(Control.b));
    expect(r.state.buttons, Btn.b);
    r.up(1);
    expect(r.state.buttons, Btn.b);
  });
}
