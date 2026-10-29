// Tilt steering: the phone held in landscape as a wheel (upright, or flat like a tray). The wheel's angle is the tilt along the phone's long side (y): from the
// accelerometer alone, asin of gravity's y; with a gyroscope (more precise, no shaking from the car's bumps), its turn rate about the same axis is added up and the
// accelerometer only pulls it slowly back (a complementary filter, so it does not drift). The gyro's rate about that axis is (wx·uz − wz·ux) / √(ux² + uz²) with u the
// accelerometer's unit vector: exactly the rate at which asin(uy) changes, so the two agree by construction and in either platform's sign convention; a gyro that
// still disagrees for a while (a sensor that reports another way) is turned round. Which way is right depends on which way round the phone is held (the camera on the
// left or on the right): gravity along the short side (x) says which; a change re-centres the wheel.
import 'dart:math' as math;

class Steering {
  double sensitivity = 1.6, deadZone = .06;
  static const pull = 0.02; // how much of the accelerometer's angle each of its samples blends into the gyro's
  double _zero = 0,
      _angle = 0,
      _acc = 0,
      _value = 0,
      _ux = 0,
      _uz = 1,
      _agree = 0;
  int _side = 1, _gyroSign = 1;
  bool _has = false, _gyro = false;
  int get side => _side;
  bool get usingGyro => _gyro;
  double get value => _value;

  void calibrate() {
    _zero = _angle;
    _value = 0;
  }

  void reset() => _value = 0;

  /// The gyroscope stopped (or is off): the accelerometer alone again.
  void gyroOff() => _gyro = false;

  /// An accelerometer sample (any unit; gravity included); returns the steering, -1..1.
  double accel(double x, double y, double z) {
    if (!x.isFinite || !y.isFinite || !z.isFinite) return _value;
    final n = math.sqrt(x * x + y * y + z * z);
    if (n < 1) return _value;
    if (x.abs() / n > 0.35) {
      final side = x >= 0 ? 1 : -1;
      if (side != _side) {
        _side = side;
        _has = false; // turned round: centre again
      }
    }
    _ux = x / n;
    _uz = z / n;
    _acc = _side * math.asin((y / n).clamp(-1.0, 1.0));
    if (!_has || !_gyro) {
      _angle = _acc;
    } else {
      _angle += pull * (_acc - _angle);
    }
    if (!_has) {
      _has = true;
      calibrate();
    }
    return _output();
  }

  /// A gyroscope sample (rad/s) dt seconds after the previous one.
  double gyro(double wx, double wy, double wz, double dt) {
    if (!_has ||
        !wx.isFinite ||
        !wz.isFinite ||
        !dt.isFinite ||
        dt <= 0 ||
        dt > 0.1) {
      return _value;
    }
    final h = math.sqrt(_ux * _ux + _uz * _uz);
    if (h < 0.2) {
      return _value; // the long side points up or down: no wheel axis
    }
    final d = _side * _gyroSign * (wx * _uz - wz * _ux) / h * dt;
    final before = _angle;
    _angle += d;
    _gyro = true;
    // does the gyro turn the way the accelerometer does? (over many samples; a fast turn counts most)
    final drift = _acc - before;
    if (d.abs() > 0.002) {
      _agree = (_agree * 0.98 + (d.sign == drift.sign ? 1 : -1) * d.abs())
          .clamp(-1.0, 1.0);
      if (_agree < -0.5) {
        _gyroSign = -_gyroSign;
        _agree = 0;
        _angle = _acc;
      }
    }
    return _output();
  }

  double _output() {
    final raw = ((_angle - _zero) * sensitivity).clamp(-1.0, 1.0);
    final target = raw.abs() < deadZone
        ? 0.0
        : raw.sign * (raw.abs() - deadZone) / (1 - deadZone);
    _value += .25 * (target - _value);
    return _value;
  }
}
