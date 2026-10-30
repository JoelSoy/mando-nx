// Place small read-only instruments in free gaps. Control rectangles and already placed instruments are never covered.
import 'dart:math' as math;
import 'dart:ui';

import '../../pad_layout.dart';

class TelemetrySlot {
  const TelemetrySlot(this.id, this.size, this.preferred, {this.minWidth});
  final String id;
  final Size size;
  final Offset preferred;
  final double? minWidth;
}

Map<String, Rect> arrangeTelemetry(
  PadLayout layout,
  double top,
  List<TelemetrySlot> slots,
) {
  final used = [
    for (final r in layout.parts.values) r.inflate(5),
    Rect.fromLTWH(layout.size.width / 2 - 170, 0, 340, top),
  ];
  final result = <String, Rect>{};
  final safe = layout.safe.deflate(5);
  for (final slot in slots) {
    Rect? best;
    var score = double.infinity;
    for (final width in [
      slot.size.width,
      if (slot.minWidth != null) slot.minWidth!,
    ]) {
      if (width > safe.width ||
          slot.size.height > safe.height ||
          math.max(top, safe.top) > safe.bottom - slot.size.height) {
        continue;
      }
      final xs = [
        slot.preferred.dx - width / 2,
        for (double x = safe.left; x <= safe.right - width; x += 12) x,
      ];
      final ys = [
        slot.preferred.dy - slot.size.height / 2,
        for (
          double y = math.max(top, safe.top);
          y <= safe.bottom - slot.size.height;
          y += 12
        )
          y,
      ];
      for (final x in xs) {
        for (final y in ys) {
          final rect = Rect.fromLTWH(
            x.clamp(safe.left, safe.right - width),
            y.clamp(math.max(top, safe.top), safe.bottom - slot.size.height),
            width,
            slot.size.height,
          );
          if (used.any(rect.overlaps)) continue;
          final d =
              (rect.center - slot.preferred).distanceSquared +
              (slot.size.width - width) * 20;
          if (d < score) {
            score = d;
            best = rect;
          }
        }
      }
      if (best != null) break;
    }
    if (best != null) {
      result[slot.id] = best;
      used.add(best.inflate(4));
    }
  }
  return result;
}
