// The phone's motion sensors for tilt steering (steering.dart): the accelerometer always, the gyroscope when the phone has one and the player wants it. While on, the
// steering value goes to onSteer; two seconds without an accelerometer sample (or a sensor error) is onUnavailable. pause() rests the sensors (the app is not in front),
// resume() starts them again: the player's choice to steer by tilting is not lost.
import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

import 'steering.dart';

typedef AccelStream = Stream<AccelerometerEvent> Function();
typedef GyroStream = Stream<GyroscopeEvent> Function();

class MotionInput {
  MotionInput({
    required this.steering,
    required this.onSteer,
    required this.onUnavailable,
    this.accelerometer,
    this.gyroscope,
  });
  final Steering steering;
  final void Function(double) onSteer;
  final void Function() onUnavailable;
  final AccelStream? accelerometer; // tests
  final GyroStream? gyroscope;
  bool useGyro = true;
  StreamSubscription<AccelerometerEvent>? _acc;
  StreamSubscription<GyroscopeEvent>? _gyro;
  Timer? _watchdog;
  DateTime? _lastGyro;
  bool get running => _acc != null;
  bool get gyroActive => steering.usingGyro;

  void start() {
    stop();
    _arm();
    try {
      final a =
          accelerometer?.call() ??
          accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval);
      _acc = a.listen(
        (e) {
          if (!e.x.isFinite || !e.y.isFinite || !e.z.isFinite) return;
          _arm();
          onSteer(steering.accel(e.x, e.y, e.z));
        },
        onError: (Object _) => _fail(),
        onDone: _fail,
        cancelOnError: true,
      );
    } on Object {
      _fail();
      return;
    }
    if (useGyro) _startGyro();
  }

  void _startGyro() {
    try {
      final g =
          gyroscope?.call() ??
          gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval);
      _gyro = g.listen(
        (e) {
          final t = e.timestamp, last = _lastGyro;
          _lastGyro = t;
          if (last == null) return;
          onSteer(
            steering.gyro(
              e.x,
              e.y,
              e.z,
              t.difference(last).inMicroseconds / 1e6,
            ),
          );
        },
        onError: (Object _) => _gyroGone(),
        onDone: _gyroGone,
        cancelOnError: true,
      );
    } on Object {
      _gyroGone(); // no gyroscope: the accelerometer steers alone
    }
  }

  void _gyroGone() {
    _gyro = null;
    _lastGyro = null;
    steering.gyroOff();
  }

  void _arm() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 2), _fail);
  }

  void _fail() {
    if (!running) return;
    stop();
    onUnavailable();
  }

  void stop() {
    _watchdog?.cancel();
    _watchdog = null;
    _acc?.cancel();
    _acc = null;
    _gyro?.cancel();
    _gyroGone();
    steering.reset();
  }
}
