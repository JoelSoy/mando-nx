// The gamepad screen: every finger goes through one Listener to the TouchRouter (several at once: steer, accelerate and drift together), the state goes to the client
// at once and on every 17 ms tick (the heartbeat, about 59 Hz). Shows the player, the link and the latency; Salir leaves the session.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'client.dart';
import 'pad_layout.dart';
import 'protocol.dart';
import 'gamer_theme.dart';
import 'tilt.dart';
import 'native.dart';

import 'package:sensors_plus/sensors_plus.dart';

const playerColors = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFFFDD835),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
  Color(0xFF00ACC1),
  Color(0xFFD81B60),
];

String statusText(RemoteClient c) {
  if (c.isDemo) return "DEMO · Sin conexión real";
  switch (c.status) {
    case LinkStatus.joining:
      return c.sinceStartMs > 4000
          ? 'Sin respuesta del Mac. Revisa la IP, el puerto y que ambos estén en la misma red Wi-Fi.'
          : 'Conectando…';
    case LinkStatus.connected:
      return c.rttMs == null ? 'Conectado' : 'Conectado · ${c.rttMs} ms';
    case LinkStatus.reconnecting:
      return 'Reconectando…';
    case LinkStatus.waiting:
      if (c.hostQuit) {
        return 'El juego se cerró en el Mac. Se volverá a conectar cuando lo abras de nuevo.';
      }
      return c.reason == 'busy'
          ? 'Demasiados intentos con un código incorrecto. Espera un minuto…'
          : 'Todos los jugadores están ocupados. Esperando un lugar libre…';
    case LinkStatus.rejected:
      return c.reason == 'code'
          ? 'Código incorrecto. Revisa el código que muestra el Mac.'
          : 'Esta versión de la app no es compatible con el juego del Mac.';
    case LinkStatus.closed:
      return 'Desconectado';
  }
}

/// What the host's info says about this player, as a line under the game's name; null when there is nothing to say.
String? useText(GameInfo i) {
  switch (i.use) {
    case PlayerUse.own:
      return 'El juego lee tu mando como Jugador ${i.player}';
    case PlayerUse.p1:
      return 'Pantalla de 1 jugador: tu mando también mueve al Jugador 1';
    case PlayerUse.off:
      return i.seats == 1
          ? 'El juego acepta 1 jugador ahora: tu mando espera'
          : 'El juego acepta ${i.seats} jugadores ahora: tu mando espera';
    case PlayerUse.pause:
      return 'En pausa: pon la ventana del juego al frente en el Mac';
  }
}

/// The game card in the middle of the pad: the game's name, a light per player the game takes (this phone's in its colour, others with a controller dimmer) and what the
/// game makes of this player.
class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.info});
  final GameInfo info;
  @override
  Widget build(BuildContext context) {
    final lights = info.seats < info.player ? info.player : info.seats;
    final mine = playerColors[(info.player - 1) % playerColors.length];
    final ok = info.use == PlayerUse.own;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (info.game.isNotEmpty)
          Text(
            info.game.toUpperCase(),
            key: const Key('game'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
        const SizedBox(height: 6),
        Row(
          key: const Key('lights'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var p = 1; p <= lights; p++)
              Container(
                width: p == info.player ? 14 : 10,
                height: p == info.player ? 14 : 10,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p == info.player
                      ? mine
                      : info.holds(p)
                      ? Colors.white54
                      : Colors.transparent,
                  border: Border.all(
                    color: p == info.player ? mine : Colors.white38,
                    width: 1.5,
                  ),
                  boxShadow: p == info.player && ok
                      ? [
                          BoxShadow(
                            color: mine.withValues(alpha: .7),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          useText(info) ?? '',
          key: const Key('use'),
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(color: ok ? lime : Colors.amberAccent, fontSize: 12),
        ),
      ],
    );
  }
}

class PadScreen extends StatefulWidget {
  const PadScreen({
    super.key,
    required this.client,
    this.haptics = true,
    this.accelerometer,
  });
  final RemoteClient client;
  final bool haptics;
  final Stream<AccelerometerEvent> Function()? accelerometer;
  @override
  State<PadScreen> createState() => _PadScreenState();
}

class _PadScreenState extends State<PadScreen> with WidgetsBindingObserver {
  TouchRouter? _router;
  final _tilt = TiltSteering();
  StreamSubscription<AccelerometerEvent>? _motion;
  bool _steering = false, _touchFeedback = true;
  double _steer = 0;
  Timer? _sensorWatchdog;
  void _armSensorWatchdog() {
    _sensorWatchdog?.cancel();
    _sensorWatchdog = Timer(const Duration(seconds: 2), _sensorUnavailable);
  }

  void _sensorUnavailable() {
    if (!mounted || !_steering) return;
    _setTilt(false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Acelerómetro no disponible. Usa el joystick."),
      ),
    );
  }

  void _publish() {
    final r = _router;
    if (r == null) return;
    final s = r.state;
    client.setState(
      PadState(
        buttons: s.buttons,
        lx: _steering && !r.stickActive ? _steer : s.lx,
        ly: s.ly,
        rx: s.rx,
        ry: s.ry,
      ),
    );
  }

  void _setTilt(bool on) {
    _sensorWatchdog?.cancel();
    _sensorWatchdog = null;
    _motion?.cancel();
    _motion = null;
    setState(() => _steering = on);
    _steer = 0;
    _tilt.reset();
    _publish();
    if (!on) return;
    _armSensorWatchdog();
    try {
      final stream =
          widget.accelerometer?.call() ??
          accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval);
      _motion = stream.listen(
        (e) {
          if (!mounted || !_steering) return;
          if (!e.x.isFinite || !e.y.isFinite || !e.z.isFinite) return;
          _armSensorWatchdog();
          _steer = _tilt.sample(e.x, e.y, e.z);
          _publish();
        },
        onError: (Object e) => _sensorUnavailable(),
        onDone: _sensorUnavailable,
        cancelOnError: true,
      );
    } on Object {
      _sensorUnavailable();
    }
  }

  void _settings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "AJUSTES DE MANDO",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  SwitchListTile(
                    title: const Text("Volante por inclinación"),
                    subtitle: const Text(
                      "Usa el acelerómetro; no requiere giroscopio. El joystick tiene prioridad.",
                    ),
                    value: _steering,
                    onChanged: (v) {
                      _setTilt(v);
                      update(() {});
                    },
                  ),
                  Row(
                    children: [
                      const Text("Sensibilidad"),
                      Expanded(
                        child: Slider(
                          value: _tilt.sensitivity,
                          min: .5,
                          max: 3,
                          onChanged: (v) => update(() => _tilt.sensitivity = v),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _tilt.calibrate,
                    icon: const Icon(Icons.center_focus_strong),
                    label: const Text("Centrar volante"),
                  ),
                  SwitchListTile(
                    title: const Text("Vibración del juego"),
                    value: client.gameRumbleEnabled,
                    onChanged: (v) => update(() => client.setGameRumble(v)),
                  ),
                  SwitchListTile(
                    title: const Text("Respuesta al tocar"),
                    value: _touchFeedback,
                    onChanged: (v) => update(() => _touchFeedback = v),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Timer? _timer;
  RemoteClient get client => widget.client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    client.rumbleSink = (i, s, ms) {
      if (widget.haptics) gameRumble(i, s, ms);
    };
    client.addListener(_changed);
    _timer = Timer.periodic(
      const Duration(milliseconds: 17),
      (_) => client.tick(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _sensorWatchdog?.cancel();
    _motion?.cancel();
    client.removeListener(_changed);
    client.leave();
    super.dispose();
  }

  PlayerUse? _lastUse;
  void _changed() {
    final use = client.info?.use;
    if (use != _lastUse) {
      if (use == PlayerUse.own && widget.haptics) {
        HapticFeedback.mediumImpact(); // the game took this controller
      }
      _lastUse = use;
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      client.resume();
    } else {
      _router?.clear();
      if (_steering) _setTilt(false);
      _steer = 0;
      _tilt.reset();
      client.pause();
    }
  }

  void _touch(void Function(TouchRouter r) f) {
    final r = _router;
    if (r == null) return;
    final before = r.pressed;
    f(r);
    if (widget.haptics &&
        _touchFeedback &&
        r.pressed.difference(before).isNotEmpty) {
      HapticFeedback.selectionClick();
    }
    _publish();
    setState(() {});
  }

  void _leave() {
    client.leave();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final connected = client.status == LinkStatus.connected;
    final p = client.player;
    final color = p != null
        ? playerColors[(p - 1) % playerColors.length]
        : Colors.grey;
    return Scaffold(
      backgroundColor: ink,
      body: LayoutBuilder(
        builder: (context, box) {
          final layout = PadLayout.compute(
            box.biggest,
            safeLeft: pad.left,
            safeRight: pad.right,
            safeBottom: pad.bottom,
          );
          final r = _router ??= TouchRouter(layout);
          if (r.layout.size != layout.size) {
            r.layout = layout;
            r.clear();
          }
          return Stack(
            children: [
              const Positioned.fill(
                child: GridBackdrop(child: SizedBox.expand()),
              ),
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) =>
                      _touch((r) => r.down(e.pointer, e.localPosition)),
                  onPointerMove: (e) =>
                      _touch((r) => r.move(e.pointer, e.localPosition)),
                  onPointerUp: (e) => _touch((r) => r.up(e.pointer)),
                  onPointerCancel: (e) => _touch((r) => r.up(e.pointer)),
                  child: CustomPaint(painter: PadPainter(layout, r, color)),
                ),
              ),
              Positioned(
                right: 24 + pad.right,
                bottom: 8 + pad.bottom,
                child: IconButton(
                  key: const Key("settings"),
                  onPressed: _settings,
                  icon: const Icon(Icons.tune_rounded, color: cyan),
                ),
              ),
              Positioned(
                left: 24 + pad.left,
                bottom: 4 + pad.bottom,
                child: Tooltip(
                  message: 'Acelerómetro: no requiere giroscopio',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.screen_rotation_rounded,
                        color: cyan,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inclinación',
                            style: TextStyle(color: cyan, fontSize: 12),
                          ),
                          Text(
                            'Acelerómetro',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        key: const Key('tilt-toggle'),
                        value: _steering,
                        onChanged: _setTilt,
                      ),
                    ],
                  ),
                ),
              ),
              // the status at the top, between − and +
              Positioned(
                top: 6,
                left: box.maxWidth / 2 - 130,
                width: 260,
                child: IgnorePointer(
                  child: Column(
                    children: [
                      Container(
                        key: const Key('player'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: p != null ? color : Colors.white12,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          p != null ? 'Jugador $p' : 'Sin jugador',
                          style: TextStyle(
                            color: p != null && (p == 3)
                                ? Colors.black
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusText(client),
                        key: const Key('status'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: connected
                              ? Colors.white60
                              : Colors.amberAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // the game card in the free middle, under − and +, above the D-pad
              if (connected && client.info != null)
                Positioned(
                  top: 1.75 * layout.unit,
                  left: box.maxWidth / 2 - 150,
                  width: 300,
                  child: IgnorePointer(child: GameCard(info: client.info!)),
                ),
              Positioned(
                bottom: 4 + pad.bottom,
                left: box.maxWidth / 2 - 50,
                width: 100,
                child: TextButton.icon(
                  key: const Key('leave'),
                  onPressed: _leave,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Salir'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white60),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PadPainter extends CustomPainter {
  PadPainter(this.layout, this.router, this.accent)
    : pressed = router.pressed,
      knob = router.stickKnob,
      origin = router.stickOrigin,
      active = router.stickActive;
  final PadLayout layout;
  final TouchRouter router;
  final Color accent;
  final Set<Control> pressed;
  final Offset knob, origin;
  final bool active;

  static const faceColors = {
    Control.a: lime,
    Control.b: Color(0xFFFF719A),
    Control.x: cyan,
    Control.y: Color(0xFFB7A1FF),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = cyan.withValues(alpha: .35);
    // the stick: its base where the finger landed (or at home), the knob under the finger
    canvas.drawCircle(
      origin,
      layout.stickRadius,
      Paint()..color = Colors.white.withValues(alpha: active ? 0.10 : 0.05),
    );
    canvas.drawCircle(origin, layout.stickRadius, stroke);
    canvas.drawCircle(
      knob,
      layout.stickRadius * 0.42,
      Paint()
        ..color = active
            ? accent.withValues(alpha: 0.85)
            : cyan.withValues(alpha: .25),
    );
    for (final b in layout.buttons) {
      final on = pressed.contains(b.control);
      final base = faceColors[b.control] ?? cyan;
      final fill = Paint()
        ..color = on
            ? base.withValues(alpha: 0.85)
            : base.withValues(
                alpha: faceColors.containsKey(b.control) ? 0.28 : 0.10,
              );
      if (b.round) {
        canvas.drawCircle(b.center, b.rect.width / 2, fill);
        canvas.drawCircle(b.center, b.rect.width / 2, stroke);
      } else {
        final rr = RRect.fromRectAndRadius(
          b.rect,
          Radius.circular(b.rect.shortestSide * 0.3),
        );
        canvas.drawRRect(rr, fill);
        canvas.drawRRect(rr, stroke);
      }
      final tp = TextPainter(
        text: TextSpan(
          text: b.label,
          style: TextStyle(
            color: on ? Colors.black : Colors.white,
            fontSize: b.rect.shortestSide * 0.42,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, b.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(PadPainter old) =>
      old.pressed.length != pressed.length ||
      !old.pressed.containsAll(pressed) ||
      old.knob != knob ||
      old.origin != origin ||
      old.accent != accent ||
      old.layout != layout;
}
