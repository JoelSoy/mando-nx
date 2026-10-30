import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/pad_layout.dart';
import 'package:remote_pad/pad/screen/telemetry_layout.dart';

void main() {
  test("custom top controls can leave no telemetry room without throwing", () {
    final layout = PadLayout.compute(const Size(667, 375));
    expect(
      arrangeTelemetry(layout, 375, [
        const TelemetrySlot("x", Size(80, 24), Offset(300, 360)),
      ]),
      isEmpty,
    );
  });
  for (final cfg in PadConfig.presets) {
    for (final size in [
      const Size(667, 375),
      const Size(852, 393),
      const Size(932, 430),
      const Size(1180, 820),
    ]) {
      test(
        '${cfg.name} $size: distributed instruments never cover controls or each other',
        () {
          final l = PadLayout.compute(
            size,
            safeLeft: 44,
            safeRight: 44,
            safeBottom: 21,
            config: cfg,
          );
          final top =
              [
                l.parts[PadPart.minus]!.bottom,
                l.parts[PadPart.plus]!.bottom,
              ].reduce((a, b) => a > b ? a : b) +
              24;
          final slots = [
            TelemetrySlot(
              'game',
              const Size(290, 22),
              Offset(size.width * .5, top + 11),
              minWidth: 210,
            ),
            TelemetrySlot(
              'course',
              const Size(230, 24),
              Offset(size.width * .22, size.height - 35),
              minWidth: 155,
            ),
            TelemetrySlot(
              'place',
              const Size(68, 34),
              Offset(size.width * .53, size.height * .57),
            ),
            TelemetrySlot(
              'lap',
              const Size(86, 26),
              Offset(size.width * .61, size.height * .67),
            ),
            TelemetrySlot(
              'coins',
              const Size(56, 26),
              Offset(size.width * .57, size.height * .81),
            ),
            TelemetrySlot(
              'kart',
              const Size(270, 26),
              Offset(size.width * .78, size.height - 34),
              minWidth: 170,
            ),
          ];
          final rects = arrangeTelemetry(l, top, slots);
          expect(rects.length, greaterThanOrEqualTo(3));
          for (final r in rects.values) {
            expect(
              l.safe.contains(r.topLeft) && l.safe.contains(r.bottomRight),
              true,
            );
            for (final control in l.parts.values) {
              expect(r.overlaps(control), false);
            }
          }
          final all = rects.values.toList();
          for (var i = 0; i < all.length; i++) {
            for (var j = i + 1; j < all.length; j++) {
              expect(all[i].overlaps(all[j]), false);
            }
          }
        },
      );
    }
  }
}
