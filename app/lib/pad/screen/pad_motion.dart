// Tilt steering on the pad (pad_screen.dart, motion/): the player's choice is kept; the sensors run while it is on and the app is in front. The gyroscope steers when
// the phone has one and the player wants it (more precise), the accelerometer otherwise. A sensor that stops is said in a toast, which takes no touches.
part of 'pad_screen.dart';

mixin _PadMotion on _PadBase {
  @override
  void setTilt(bool on) {
    if (mounted) setState(() => _steering = on);
    if (prefs.tilt != on) {
      prefs.tilt = on;
      saved();
    }
    _steer = 0;
    if (on) {
      _motion.start();
    } else {
      _motion.stop();
    }
    _publish();
  }

  @override
  void setUseGyro(bool on) {
    prefs.useGyro = on;
    _motion.useGyro = on;
    saved();
    if (_steering) _motion.start();
    if (mounted) setState(() {});
  }

  @override
  void _onSteer(double v) {
    if (!mounted || !_steering) return;
    _steer = v;
    _publish();
    if (_motion.gyroActive != _gyroShown) {
      setState(
        () => _gyroShown = _motion.gyroActive,
      ); // the switch says which sensor steers
    }
  }

  @override
  void _sensorUnavailable() {
    if (!mounted || !_steering) return;
    setTilt(false);
    _say('Acelerómetro no disponible. Usa el joystick.');
  }
}
