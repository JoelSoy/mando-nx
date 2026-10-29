// The controller state a phone sends: NpadButton bits, both sticks, the stick normalization (dead zone, unit circle).
import 'dart:math' as math;

/// Button bits, in nn::hid::NpadButton order (dm/host/dm_input.h).
abstract final class Btn {
  static const int a = 1 << 0, b = 1 << 1, x = 1 << 2, y = 1 << 3;
  static const int ls = 1 << 4, rs = 1 << 5, l = 1 << 6, r = 1 << 7;
  static const int zl = 1 << 8, zr = 1 << 9, plus = 1 << 10, minus = 1 << 11;
  static const int left = 1 << 12,
      up = 1 << 13,
      right = 1 << 14,
      down = 1 << 15;
  static const int all = 0xffff;
}

/// The whole controller state the phone sends: buttons and both sticks, each axis -1..1 with y up.
class PadState {
  const PadState({
    this.buttons = 0,
    this.lx = 0,
    this.ly = 0,
    this.rx = 0,
    this.ry = 0,
  });
  final int buttons;
  final double lx, ly, rx, ry;
  static const neutral = PadState();

  @override
  bool operator ==(Object other) =>
      other is PadState &&
      other.buttons == buttons &&
      other.lx == lx &&
      other.ly == ly &&
      other.rx == rx &&
      other.ry == ry;
  @override
  int get hashCode => Object.hash(buttons, lx, ly, rx, ry);
  @override
  String toString() => 'PadState(b=$buttons, l=($lx, $ly), r=($rx, $ry))';
}

/// A stick from a finger's offset (dx, dy) in units of the stick's radius, screen y down: clamped to the unit circle, a dead zone around the centre, the rest rescaled so
/// the edge of the dead zone is 0 and the rim is a full tilt. Returns (x, y) with y up, rounded to 3 decimals.
(double, double) normalizeStick(
  double dx,
  double dy, {
  double deadZone = 0.12,
}) {
  double x = dx, y = -dy;
  if (!x.isFinite || !y.isFinite) return (0, 0);
  final r = math.sqrt(x * x + y * y);
  if (r <= deadZone) return (0, 0);
  final scaled = (math.min(r, 1.0) - deadZone) / (1 - deadZone);
  x = x / r * scaled;
  y = y / r * scaled;
  double q(double v) => (v * 1000).roundToDouble() / 1000;
  return (q(x), q(y));
}

double clampAxis(double v) => v.isFinite ? v.clamp(-1.0, 1.0) : 0.0;
