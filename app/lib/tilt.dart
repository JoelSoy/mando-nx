import 'dart:math' as math;

class TiltSteering {
  double sensitivity = 1.6, deadZone = .06;
  double _zero = 0, _angle = 0, _value = 0;
  bool _has = false;
  void calibrate() {
    _zero = _angle;
    _value = 0;
  }

  void reset() {
    _value = 0;
  }

  double sample(double x, double y, double z) {
    if (!x.isFinite || !y.isFinite || !z.isFinite) return _value;
    final n = math.sqrt(x * x + y * y + z * z);
    if (n < 1) return _value;
    _angle = math.asin((y / n).clamp(-1.0, 1.0));
    if (!_has) {
      _has = true;
      calibrate();
    }
    final raw = ((_angle - _zero) * sensitivity).clamp(-1.0, 1.0);
    final target = raw.abs() < deadZone
        ? 0.0
        : raw.sign * (raw.abs() - deadZone) / (1 - deadZone);
    _value += .25 * (target - _value);
    return _value;
  }
}
