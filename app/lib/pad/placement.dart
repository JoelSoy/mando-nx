// Where a part of a layout goes on a real screen: its place is a fraction of the reference screen's safe area (iPhone 15); pixels keep their distance in layout units
// from the nearer edge, as drawn there, except in a band around the middle, which takes up what a wider or narrower screen has more or less, so a part in the middle
// stays in the middle. toFraction is the inverse (the editor), keepInside keeps a part whole inside the safe area.
import 'dart:math' as math;

/// The safe area of the screen the presets were drawn on (iPhone 15), in units. Positions keep their distance in units from the nearer edge, as drawn there,
/// except in a band around the middle, which takes up what a wider or narrower screen has more or less: a part in the middle stays in the middle.
const double refWidth = 19.44, refHeight = 9.466;

double keepInside(double v, double lo, double hi, double half) =>
    hi - lo <= 2 * half ? (lo + hi) / 2 : v.clamp(lo + half, hi - half);

// A fraction of the reference extent → pixels between lo and hi on this screen
double toPixels(double f, double lo, double hi, double ref, double band) {
  final half = (hi - lo) / 2, edgeEnd = ref / 2 - band;
  final d =
      (f <= 0.5 ? f : 1 - f) * ref; // from the nearer edge, on the reference
  final from = d <= edgeEnd || half <= edgeEnd
      ? math.min(d, half)
      : edgeEnd + (d - edgeEnd) * (half - edgeEnd) / band;
  return f <= 0.5 ? lo + from : hi - from;
}

// The inverse: pixels on this screen → the fraction of the reference extent
double toFraction(double px, double lo, double hi, double ref, double band) {
  final half = (hi - lo) / 2, edgeEnd = ref / 2 - band;
  final left = px <= lo + half;
  final from = (left ? px - lo : hi - px).clamp(0.0, half);
  final d = from <= edgeEnd || half <= edgeEnd
      ? from
      : edgeEnd + (from - edgeEnd) * band / (half - edgeEnd);
  final f = (d / ref).clamp(0.0, 0.5);
  return left ? f : 1 - f;
}
