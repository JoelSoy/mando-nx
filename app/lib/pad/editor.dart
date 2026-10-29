// Editing the pad's layout: what the fingers do while the player arranges the controls. One finger on a part selects it and drags it (it keeps where the finger
// took it); a second finger anywhere pinches the selected part bigger or smaller. Sizes also come from the editing panel's slider (setScale). Pure Dart: the pad
// screen passes the fingers and the layout of the config being edited, and draws the result; tests drive it directly.
import 'dart:ui';

import 'config.dart';
import 'layout.dart';
import 'layout_edit.dart';

class PadEditor {
  PadEditor(this.start) : config = start;

  /// The layout editing started from (Cancelar goes back to it)
  final PadConfig start;
  PadConfig config;
  PadPart? selected;
  bool get changed => !config.samePlaces(start);

  final Map<int, Offset> _fingers = {};
  int? _dragFinger;
  Offset _grab = Offset.zero; // from the part's centre to the dragging finger
  double? _pinchDistance, _pinchScale;

  void down(int pointer, Offset p, PadLayout l) {
    _fingers[pointer] = p;
    if (_fingers.length == 1) {
      selected = l.partAt(p);
      final s = selected;
      if (s != null) {
        _dragFinger = pointer;
        _grab = p - l.parts[s]!.center;
      }
    } else if (_fingers.length == 2 && selected != null) {
      final f = _fingers.values.toList();
      _pinchDistance = (f[0] - f[1]).distance;
      _pinchScale = config[selected!].scale;
      _dragFinger = null; // two fingers: resizing, not moving
    }
  }

  void move(int pointer, Offset p, PadLayout l) {
    if (!_fingers.containsKey(pointer)) return;
    _fingers[pointer] = p;
    final s = selected;
    if (s == null) return;
    if (_pinchDistance != null && _fingers.length >= 2) {
      final f = _fingers.values.toList();
      final d = (f[0] - f[1]).distance;
      if (_pinchDistance! > 8) setScale(_pinchScale! * d / _pinchDistance!, l);
    } else if (pointer == _dragFinger) {
      config = config.withPart(s, l.placeAt(s, p - _grab));
    }
  }

  void up(int pointer) {
    _fingers.remove(pointer);
    if (pointer == _dragFinger) _dragFinger = null;
    if (_fingers.length < 2) {
      _pinchDistance = null;
      _pinchScale = null;
    }
  }

  void cancelFingers() {
    _fingers.clear();
    _dragFinger = null;
    _pinchDistance = null;
    _pinchScale = null;
  }

  /// The selected part at this size (minScale..maxScale), its centre kept (moved in only as far as needed to stay on screen).
  void setScale(double scale, PadLayout l) {
    final s = selected;
    if (s == null) return;
    final v = scale.clamp(minScale, maxScale);
    config = config.withPart(s, l.placeAt(s, l.parts[s]!.center, scale: v));
  }

  /// The selected part back to where the layout editing started from has it (all of them when none is selected).
  void resetSelected() {
    final s = selected;
    config = s == null ? start : config.withPart(s, start[s]);
  }

  /// Another layout to start from (a preset or a saved one), keeping this editing session.
  void use(PadConfig c) {
    config = c;
    selected = null;
  }
}
