import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/pad_layout.dart';
import 'package:remote_pad/storage.dart';
import 'package:remote_pad/motion/steering.dart';

void main() {
  const size = Size(852, 393);
  PadLayout layout(PadEditor e) => PadLayout.compute(size, config: e.config);

  test('one finger selects a part and drags it, keeping where it took it', () {
    final e = PadEditor(PadConfig.classic);
    var l = layout(e);
    final a = l.parts[PadPart.face]!.center;
    e.down(1, a + const Offset(10, 5), l);
    expect(e.selected, PadPart.face);
    e.move(1, a + const Offset(-90, -40), l);
    l = layout(e);
    expect(
      (l.parts[PadPart.face]!.center - (a + const Offset(-100, -45))).distance,
      lessThan(0.5),
    );
    e.up(1);
    expect(e.changed, isTrue);
    e.down(2, const Offset(426, 230), layout(e));
    expect(e.selected, isNull, reason: 'empty space: nothing selected');
  });

  test(
    'a second finger pinches the selected part; the size stays within limits',
    () {
      final e = PadEditor(PadConfig.classic);
      final l = layout(e);
      final c = l.parts[PadPart.stick]!.center;
      e.down(1, c, l);
      e.down(2, c + const Offset(100, 0), l);
      e.move(2, c + const Offset(150, 0), l);
      expect(e.config[PadPart.stick].scale, closeTo(1.5, 0.001));
      expect(
        layout(e).parts[PadPart.stick]!.center.dx,
        isNot(closeTo(c.dx + 50, 1)),
        reason: 'pinching does not move it',
      );
      e.move(2, c + const Offset(900, 0), l);
      expect(e.config[PadPart.stick].scale, maxScale);
      e.move(2, c + const Offset(1, 0), l);
      expect(e.config[PadPart.stick].scale, minScale);
      e.up(2);
      e.up(1);
    },
  );

  test('size from the slider; reset puts the part back; with nothing selected, everything', () {
    final e = PadEditor(PadConfig.marioKart);
    final l = layout(e);
    e.down(1, l.parts[PadPart.r]!.center, l);
    e.up(1);
    e.setScale(0.7, l);
    expect(e.config[PadPart.r].scale, closeTo(0.7, 0.001));
    e.resetSelected();
    expect(e.config[PadPart.r], PadConfig.marioKart[PadPart.r]);
    e.setScale(1.8, l);
    e.selected = null;
    e.resetSelected();
    expect(e.changed, isFalse);
  });

  test('pad preferences: round trip; a broken layout falls back to Clásico part by part', () {
    final p = PadPrefs(
      tilt: true,
      sensitivity: 2.2,
      gameRumble: false,
      touchFeedback: false,
    );
    final mine = PadConfig.marioKart
        .withPart(PadPart.face, const PartPlace(0.7, 0.5, 1.3))
        .named('Mío');
    p.keep(mine);
    final back = PadPrefs.fromJson(p.toJson());
    expect(
      [back.tilt, back.sensitivity, back.gameRumble, back.touchFeedback],
      [true, 2.2, false, false],
    );
    expect(back.layout.name, 'Mío');
    expect(back.layout[PadPart.face], const PartPlace(0.7, 0.5, 1.3));
    expect(back.saved.single.name, 'Mío');
    expect(back.choices.length, PadConfig.presets.length + 1);
    back.layout = PadConfig.leftHanded;
    expect(
      PadPrefs.fromJson(back.toJson()).layout.name,
      'Zurdo',
      reason: 'a preset is kept by name',
    );
    final broken = PadConfig.fromJson({
      'name': 'x',
      'face': [0.2, 'a', 1],
      'stick': [5, -1, 9],
    })!;
    expect(broken[PadPart.face], PadConfig.classic[PadPart.face]);
    expect(
      broken[PadPart.stick],
      const PartPlace(1, 0, maxScale),
      reason: 'clamped',
    );
    expect(PadPrefs.fromJson('nope').layout.name, 'Clásico');
    for (var i = 0; i < 10; i++) {
      p.keep(PadConfig.classic.named('D$i'));
    }
    expect(p.saved.length, PadPrefs.maxSaved);
    p.forget(p.layout.name);
    expect(p.layout.name, 'Clásico');
  });

  test('tilt steers the same way whichever way round the phone is held, in either sign convention', () {
    // held as a wheel: gravity along the short side (x); turning right moves it towards +y on one side and -y on the other
    double turnRight(double side, double sign) {
      final t = Steering();
      t.accel(sign * side * 9.8, 0, 0); // centred
      var v = 0.0;
      for (var i = 0; i < 30; i++) {
        v = t.accel(sign * side * 9.8 * 0.94, sign * side * 9.8 * 0.34, 0);
      }
      return v;
    }

    for (final sign in [1.0, -1.0]) {
      final a = turnRight(1, sign), b = turnRight(-1, sign);
      expect(
        a.sign,
        b.sign,
        reason: 'the same turn steers the same way (convention $sign)',
      );
      expect(a.abs(), greaterThan(0.3));
    }
    final t = Steering();
    t.accel(9.8, 0, 0);
    expect(t.side, 1);
    t.accel(-9.8, 0, 0);
    expect(t.side, -1, reason: 'turned round');
    expect(t.accel(-9.8, 0, 0), 0, reason: 'and centred again');
  });
}
