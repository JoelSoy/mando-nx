// What the layout editor (editor.dart) asks of a layout: the part under a finger, and the place (fractions, placement.dart) that puts a part's centre at a point.
import 'dart:ui';

import 'config.dart';
import 'layout.dart';
import 'placement.dart';

extension LayoutEditing on PadLayout {
  /// The part under p while editing: of those whose outline (a little bigger) holds it, the one with the nearest centre.
  PadPart? partAt(Offset p) {
    PadPart? best;
    var bd = double.infinity;
    for (final e in parts.entries) {
      if (!e.value.inflate(unit * 0.3).contains(p)) continue;
      final d = (p - e.value.center).distance;
      if (d < bd) {
        bd = d;
        best = e.key;
      }
    }
    return best;
  }

  /// Where part goes with its centre at c (kept inside the safe area), as the fractions a config keeps.
  PartPlace placeAt(PadPart part, Offset c, {double? scale}) {
    final s = scale ?? config[part].scale, u = unit;
    final half = Size(
      PadLayout.baseSize[part]!.width * s * u / 2,
      PadLayout.baseSize[part]!.height * s * u / 2,
    );
    return PartPlace(
      toFraction(
        keepInside(c.dx, safe.left, safe.right, half.width),
        safe.left,
        safe.right,
        refWidth * u,
        3 * u,
      ),
      toFraction(
        keepInside(c.dy, safe.top, safe.bottom, half.height),
        safe.top,
        safe.bottom,
        refHeight * u,
        2 * u,
      ),
      s,
    );
  }
}
