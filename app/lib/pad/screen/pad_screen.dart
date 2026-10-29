// The gamepad screen: every finger goes through one Listener to the TouchRouter (any number at once), the state goes to the client at once and on every 17 ms tick (the
// heartbeat). Touches repaint only the pad (painter.dart). Shows the player, the link, the game card (game_card.dart), the game's keyboard (keyboard_prompt.dart).
// Inactive (the Control Center, a system alert) only rests the tilt, since fingers that stay down still count (the system cancels the ones it takes); in the
// background nothing stays pressed, the sensors rest and the session pauses. Parts: pad_motion, pad_editing, pad_input, pad_view.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../client.dart';
import '../../gamer_theme.dart';
import '../../motion/sensors.dart';
import '../../motion/steering.dart';
import '../../native.dart';
import '../../pad_layout.dart';
import '../../protocol.dart';
import '../../storage.dart';
import 'edit_panel.dart';
import 'game_card.dart';
import 'keyboard_prompt.dart';
import 'painter.dart';
import 'settings_sheet.dart';
import 'status.dart';
import 'toast.dart';

part 'pad_editing.dart';
part 'pad_input.dart';
part 'pad_motion.dart';
part 'pad_view.dart';

class PadScreen extends StatefulWidget {
  const PadScreen({
    super.key,
    required this.client,
    this.haptics = true,
    this.accelerometer,
    this.gyroscope,
    this.prefs,
    this.onPrefsChanged,
  });
  final RemoteClient client;
  final bool haptics;
  final AccelStream? accelerometer; // tests
  final GyroStream? gyroscope;
  final PadPrefs?
  prefs; // the pad's kept preferences (the connect screen's); fresh when null
  final VoidCallback? onPrefsChanged; // a preference changed: write them down
  @override
  State<PadScreen> createState() => _PadScreenState();
}

/// The screen's state, shared by its parts: the motion (pad_motion.dart), the editor (pad_editing.dart) and the view (pad_view.dart)
abstract class _PadBase extends State<PadScreen> implements PadSettingsHost {
  @override
  late final PadPrefs prefs = widget.prefs ?? PadPrefs();
  @override
  final Steering steering = Steering();
  late final MotionInput _motion = MotionInput(
    steering: steering,
    onSteer: _onSteer,
    onUnavailable: _sensorUnavailable,
    accelerometer: widget.accelerometer,
    gyroscope: widget.gyroscope,
  );
  void _onSteer(double v); // pad_motion.dart
  void _sensorUnavailable();
  void _finishEditing({required bool keep}); // pad_editing.dart
  Future<void> _saveAs();
  final _touches = ValueNotifier<int>(0); // repaints the pad
  TouchRouter? _router;
  PadLayout? _layout;
  PadEditor? _editor;
  bool _panelLow = false,
      _steering = false,
      _kbdOpen = false,
      _gyroShown = false;
  double _steer = 0;
  String? _toast;
  Timer? _toastTimer, _timer;
  PlayerUse? _lastUse;
  @override
  RemoteClient get client => widget.client;
  @override
  bool get steeringOn => _steering;
  @override
  bool get gyroActive => _motion.gyroActive;
  @override
  void saved() => widget.onPrefsChanged?.call();

  void _say(String text) {
    _toastTimer?.cancel();
    setState(() => _toast = text);
    _toastTimer = Timer(
      const Duration(seconds: 3),
      () => mounted ? setState(() => _toast = null) : null,
    );
  }

  void _publish(); // pad_input.dart
}

class _PadScreenState extends _PadBase
    with WidgetsBindingObserver, _PadMotion, _PadEditing, _PadInput, _PadView {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    steering.sensitivity = prefs.sensitivity;
    _motion.useGyro = prefs.useGyro;
    if (client.gameRumbleEnabled != prefs.gameRumble) {
      client.setGameRumble(prefs.gameRumble);
    }
    client.rumbleSink = (i, s, ms) =>
        widget.haptics ? gameRumble(i, s, ms) : null;
    client.addListener(_changed);
    _timer = Timer.periodic(
      const Duration(milliseconds: 17),
      (_) => client.tick(),
    );
    if (prefs.tilt) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => mounted ? setTilt(true) : null,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _toastTimer?.cancel();
    _motion.stop();
    client.removeListener(_changed);
    client.leave();
    _touches.dispose();
    super.dispose();
  }

  void _changed() {
    final use = client.info?.use;
    if (use != _lastUse) {
      if (use == PlayerUse.own && widget.haptics) {
        HapticFeedback.mediumImpact(); // the game took this controller
      }
      _lastUse = use;
    }
    final k = client.keyboard;
    if (k != null && !_kbdOpen && mounted) {
      _kbdOpen = true;
      _router?.clear();
      _publish();
      showKeyboardPrompt(
        context,
        client,
        k,
      ).whenComplete(() => _kbdOpen = false);
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    switch (s) {
      case AppLifecycleState.resumed:
        client.resume();
        if (_steering && !_motion.running) _motion.start();
      case AppLifecycleState.inactive:
        _motion.stop();
        _steer = 0;
        _publish();
      case AppLifecycleState.hidden ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached:
        _router?.clear();
        _editor?.cancelFingers();
        _motion.stop();
        _steer = 0;
        client.pause();
    }
  }

  @override
  Widget build(BuildContext context) => _build(context);
}
