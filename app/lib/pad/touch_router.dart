// Fingers → buttons and stick, on one layout (layout.dart).
import 'dart:math' as math;
import 'dart:ui';

import '../protocol.dart';
import 'controls.dart';
import 'layout.dart';

/// Fingers → buttons and stick. A finger that lands on a button presses it and, as it slides, whichever button it is on; a finger that lands in the stick zone (on no button)
/// becomes the stick, centred where it landed (kept far enough inside the zone for a full tilt), until it lifts. Only one finger drives the stick.
class TouchRouter {
  TouchRouter(this.layout);
  PadLayout layout;
  final Map<int, Control?> _buttonFingers = {};
  final Map<int, Offset> _at = {}; // where each finger is
  int? _stickFinger;
  Offset _stickOrigin = Offset.zero, _stickPos = Offset.zero;

  Offset get stickOrigin =>
      _stickFinger == null ? layout.stickHome : _stickOrigin;
  Offset get stickKnob =>
      _stickFinger == null ? layout.stickHome : _stickOrigin + _clampedOffset();
  bool get stickActive => _stickFinger != null;
  Set<Control> get pressed =>
      _buttonFingers.values.whereType<Control>().toSet();

  void down(int pointer, Offset p) {
    _at[pointer] = p;
    final btn = layout.buttonAt(p);
    if (btn == null && _stickFinger == null && layout.stickZone.contains(p)) {
      _takeStick(pointer, p);
      return;
    }
    _buttonFingers[pointer] = btn?.control;
  }

  void _takeStick(int pointer, Offset p) {
    _buttonFingers.remove(pointer);
    _stickFinger = pointer;
    final r = layout.stickRadius, z = layout.stickZone;
    _stickOrigin = Offset(
      p.dx.clamp(
        z.left + r * 0.6,
        math.max(z.left + r * 0.6, z.right - r * 0.6),
      ),
      p.dy.clamp(
        z.top + r * 0.6,
        math.max(z.top + r * 0.6, z.bottom - r * 0.6),
      ),
    );
    _stickPos = p;
  }

  void move(int pointer, Offset p) {
    if (!_at.containsKey(pointer)) {
      return; // a finger this router never saw go down (it was let go)
    }
    _at[pointer] = p;
    if (pointer == _stickFinger) {
      _stickPos = p;
      return;
    }
    if (_buttonFingers.containsKey(pointer)) {
      _buttonFingers[pointer] = layout.buttonAt(p)?.control;
    }
  }

  /// A finger lifts (or the system took it: cancel). When it was the stick, a finger resting in the stick's zone on no button takes the stick over.
  void up(int pointer) {
    _at.remove(pointer);
    if (pointer == _stickFinger) {
      _stickFinger = null;
      for (final e in _buttonFingers.entries) {
        final at = _at[e.key];
        if (e.value == null && at != null && layout.stickZone.contains(at)) {
          _takeStick(e.key, at);
          break;
        }
      }
      return;
    }
    _buttonFingers.remove(pointer);
  }

  void clear() {
    _buttonFingers.clear();
    _at.clear();
    _stickFinger = null;
  }

  int get fingers => _at.length;

  Offset _clampedOffset() {
    final d = _stickPos - _stickOrigin, r = layout.stickRadius;
    return d.distance > r ? d / d.distance * r : d;
  }

  PadState get state {
    var bits = 0;
    for (final c in pressed) {
      bits |= controlBits[c]!;
    }
    var lx = 0.0, ly = 0.0;
    if (_stickFinger != null) {
      final d = _stickPos - _stickOrigin;
      (lx, ly) = normalizeStick(
        d.dx / layout.stickRadius,
        d.dy / layout.stickRadius,
      );
    }
    return PadState(buttons: bits, lx: lx, ly: ly);
  }
}
