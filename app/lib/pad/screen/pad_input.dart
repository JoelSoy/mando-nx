// The pad's fingers (pad_screen.dart): the layout for this screen, made again only when the screen, its safe area or the layout changed (a change of screen or safe area
// lets the fingers go: they were on the old places); playing fingers go to the touch router and repaint only the pad, editing fingers to the editor.
part of 'pad_screen.dart';

mixin _PadInput on _PadBase {
  /// The pad's state to the client: the router's, the tilt steering the stick while no finger holds it; nothing while editing or typing.
  @override
  void _publish() {
    final r = _router;
    if (r == null) return;
    if (_editor != null || _kbdOpen) {
      return client.setState(
        PadState.neutral,
      ); // editing or typing: the game gets nothing
    }
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

  PadLayout _layoutFor(Size size, EdgeInsets pad) {
    final cfg = _editor?.config ?? prefs.layout, old = _layout;
    final safe = Rect.fromLTRB(
      pad.left,
      0,
      size.width - pad.right,
      size.height - pad.bottom,
    );
    if (old != null &&
        old.size == size &&
        old.safe == safe &&
        identical(old.config, cfg)) {
      return old;
    }
    final l = PadLayout.compute(
      size,
      safeLeft: pad.left,
      safeRight: pad.right,
      safeBottom: pad.bottom,
      config: cfg,
    );
    _layout = l;
    final r = _router ??= TouchRouter(l);
    if (old != null && (old.size != size || old.safe != safe)) {
      r.clear(); // the phone turned round: the fingers were on the old places
      WidgetsBinding.instance.addPostFrameCallback((_) => _publish());
    }
    r.layout = l;
    return l;
  }

  void _touch(void Function(TouchRouter r) f) {
    final r = _router;
    if (r == null) return;
    final before = r.pressed;
    f(r);
    if (widget.haptics &&
        prefs.touchFeedback &&
        r.pressed.difference(before).isNotEmpty) {
      HapticFeedback.selectionClick();
    }
    _publish();
    _touches.value++;
  }

  void _edit(void Function(PadEditor e, PadLayout l) f) {
    final e = _editor, l = _layout;
    if (e == null || l == null) return;
    f(e, l);
    setState(() {});
  }

  void _leave() {
    client.leave();
    Navigator.of(context).maybePop();
  }
}
