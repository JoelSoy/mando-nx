import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/pad_layout.dart';

const screens = {
  'iPhone SE': Size(667, 375),
  'iPhone 15': Size(852, 393),
  'iPhone 15 Pro Max': Size(932, 430),
  'Android 20:9': Size(800, 360),
  'iPad': Size(1180, 820),
};

void main() {
  for (final cfg in PadConfig.presets) {
    for (final e in screens.entries) {
      test(
        '${cfg.name} on ${e.key}: every control on screen, none overlapping, the stick and the switches clear',
        () {
          final l = PadLayout.compute(
            e.value,
            safeLeft: 44,
            safeRight: 44,
            safeBottom: 21,
            config: cfg,
          );
          final full = Offset.zero & e.value;
          bool inside(Rect r) =>
              full.contains(r.topLeft) && full.contains(r.bottomRight);
          for (final b in l.buttons) {
            expect(inside(b.rect), isTrue, reason: '${b.label} ${b.rect}');
            expect(
              l.buttonAt(b.center)?.control,
              b.control,
              reason: '${b.label}: its centre presses it',
            );
            expect(
              b.rect.overlaps(l.parts[PadPart.stick]!),
              isFalse,
              reason: '${b.label} on the stick',
            );
          }
          for (var i = 0; i < l.buttons.length; i++) {
            for (var k = i + 1; k < l.buttons.length; k++) {
              final p = l.buttons[i], q = l.buttons[k];
              final apart = p.round && q.round
                  ? (p.center - q.center).distance >=
                        (p.rect.width + q.rect.width) / 2 - 0.01
                  : !p.rect.deflate(0.01).overlaps(q.rect.deflate(0.01));
              expect(apart, isTrue, reason: '${p.label} / ${q.label}');
            }
          }
          // the switch, Salir and the settings take the touches on them: never where the stick or a button is
          const widgets = [PadPart.tilt, PadPart.exit, PadPart.menu];
          for (final w in widgets) {
            final r = l.parts[w]!;
            expect(inside(r), isTrue, reason: '$w');
            expect(
              r.overlaps(l.stickZone),
              isFalse,
              reason: '$w in the stick zone',
            );
            for (final b in l.buttons) {
              expect(r.overlaps(b.rect), isFalse, reason: '$w / ${b.label}');
            }
            for (final v in widgets) {
              if (v.index > w.index) {
                expect(r.overlaps(l.parts[v]!), isFalse, reason: '$w / $v');
              }
            }
          }
          final home = Rect.fromCircle(
            center: l.stickHome,
            radius: l.stickRadius,
          );
          expect(
            l.stickZone.contains(home.topLeft) &&
                l.stickZone.contains(
                  home.bottomRight - const Offset(0.01, 0.01),
                ),
            isTrue,
          );
          expect(
            l.buttons.map((b) => b.control).toSet().length,
            Control.values.length,
          );
        },
      );
    }
  }

  test('the tilt switch is in the middle at the bottom by default', () {
    for (final size in screens.values) {
      final l = PadLayout.compute(size, safeLeft: 44, safeRight: 44);
      expect(l.parts[PadPart.tilt]!.center.dx, closeTo(size.width / 2, 0.5));
      expect(l.parts[PadPart.tilt]!.center.dy, greaterThan(size.height * 0.85));
    }
  });

  test('a place read back from the layout puts the part where it was, on every screen', () {
    for (final size in screens.values) {
      final l = PadLayout.compute(
        size,
        safeLeft: 44,
        safeRight: 44,
        safeBottom: 21,
      );
      for (final p in PadPart.values) {
        final c = l.parts[p]!.center;
        final again = PadLayout.compute(
          size,
          safeLeft: 44,
          safeRight: 44,
          safeBottom: 21,
          config: l.config.withPart(p, l.placeAt(p, c)),
        );
        expect(
          (again.parts[p]!.center - c).distance,
          lessThan(0.5),
          reason: '$p on $size',
        );
      }
    }
  });

  test('presets keep their distance from the nearer edge (in units) on a narrow screen, and the middle in the middle', () {
    final wide = PadLayout.compute(const Size(852, 393));
    final narrow = PadLayout.compute(const Size(667, 393));
    final uw = wide.unit, un = narrow.unit;
    expect(
      narrow.parts[PadPart.zl]!.left / un,
      closeTo(wide.parts[PadPart.zl]!.left / uw, 0.01),
    );
    expect(
      (667 - narrow.parts[PadPart.zr]!.right) / un,
      closeTo((852 - wide.parts[PadPart.zr]!.right) / uw, 0.01),
    );
    expect(narrow.parts[PadPart.tilt]!.center.dx, closeTo(667 / 2, 0.5));
  });
}
