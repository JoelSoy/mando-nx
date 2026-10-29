import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/motion/steering.dart';

// A phone held upright in landscape as a wheel, turned by angle a about the screen's normal: the accelerometer's up vector in the phone's frame, and the gyroscope's
// rate about z. side: which way round it is held; conv: the platform's sign for the accelerometer (Android up, iOS raw down)
(double, double, double) up(double a, int side, double conv) =>
    (conv * side * 9.8 * math.cos(a), conv * side * 9.8 * math.sin(a), 0);

void main() {
  double turn(
    Steering s, {
    required int side,
    required double conv,
    double gyroSign = 1,
    bool gyro = true,
    double to = 0.3,
  }) {
    const dt = 0.02, rate = 1.5; // rad/s
    var a = 0.0;
    var (x, y, z) = up(a, side, conv);
    s.accel(x, y, z);
    while (a < to) {
      a += rate * dt;
      if (gyro) {
        s.gyro(
          0,
          0,
          -gyroSign * rate,
          dt,
        ); // turning clockwise, seen from the front: negative about +z
      }
      (x, y, z) = up(a, side, conv);
      s.accel(x, y, z);
    }
    for (var i = 0; i < 20; i++) {
      s.accel(x, y, z);
    }
    return s.value;
  }

  test('the same turn steers the same way with the gyroscope or without, held either way round, in either convention', () {
    final results = <double>[];
    for (final gyro in [true, false]) {
      for (final side in [1, -1]) {
        for (final conv in [1.0, -1.0]) {
          final v = turn(Steering(), side: side, conv: conv, gyro: gyro);
          results.add(v);
          expect(
            v.abs(),
            greaterThan(0.3),
            reason: 'gyro $gyro side $side conv $conv',
          );
        }
      }
    }
    expect(
      results.every((v) => v.sign == results.first.sign),
      isTrue,
      reason: '$results',
    );
  });

  test('with the gyroscope the angle follows the turn; the accelerometer keeps it from drifting', () {
    final s = Steering();
    turn(s, side: 1, conv: 1);
    expect(s.usingGyro, isTrue);
    for (var i = 0; i < 300; i++) {
      s.gyro(
        0,
        0,
        0.05,
        0.02,
      ); // a gyro that drifts while the phone stays still
      final (x, y, z) = up(0.3, 1, 1);
      s.accel(x, y, z);
    }
    final still = Steering();
    turn(still, side: 1, conv: 1, gyro: false);
    expect(
      (s.value - still.value).abs(),
      lessThan(0.15),
      reason: 'pulled back to the accelerometer',
    );
  });

  test('a gyroscope that reports the other way is turned round', () {
    final s = Steering();
    for (var k = 0; k < 6; k++) {
      turn(s, side: 1, conv: 1, gyroSign: -1, to: 0.2 * (k + 1));
    }
    final ok = Steering();
    turn(ok, side: 1, conv: 1, to: 1.2);
    expect(s.value.sign, ok.value.sign);
  });

  test(
    'no wheel axis (the long side points down) and bad samples change nothing',
    () {
      final s = Steering();
      s.accel(0, 9.8, 0);
      final v = s.value;
      expect(s.gyro(0, 0, 3, 0.02), v);
      expect(s.gyro(double.nan, 0, 0, 0.02), v);
      expect(s.gyro(0, 0, 1, 5), v, reason: 'a gap too long');
      expect(s.accel(double.infinity, 0, 0), v);
    },
  );
}
