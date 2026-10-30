// The pad's view (pad_screen.dart): the touch layer (playing or editing, pad_input.dart), the parts that are widgets (the tilt switch, Salir, the settings), the player
// and the link, the game card or the editing panel, and the toast.
part of 'pad_screen.dart';

mixin _PadView on _PadInput {
  Widget _tiltSwitch() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.screen_rotation_rounded, color: cyan, size: 18),
      const SizedBox(width: 6),
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inclinación',
            style: TextStyle(color: cyan, fontSize: 12),
          ),
          Text(
            _steering && _gyroShown ? 'Giroscopio' : 'Acelerómetro',
            key: const Key('tilt-sensor'),
            style: const TextStyle(color: Colors.white54, fontSize: 9),
          ),
        ],
      ),
      Switch(
        key: const Key('tilt-toggle'),
        value: _steering,
        onChanged: setTilt,
      ),
    ],
  );

  Widget _build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final connected = client.status == LinkStatus.connected,
        editing = _editor != null,
        p = client.player;
    final color = p != null ? playerColor(p) : Colors.grey;
    return Scaffold(
      backgroundColor: ink,
      body: LayoutBuilder(
        builder: (context, box) {
          final layout = _layoutFor(box.biggest, pad), r = _router!;
          final pm = layout.parts[PadPart.minus]!,
              pp = layout.parts[PadPart.plus]!;
          final statusTop =
              (pm.bottom > pp.bottom ? pm.bottom : pp.bottom) +
              2; // under − and +
          Widget part(PadPart which, Widget child) => Positioned.fromRect(
            rect: layout.parts[which]!,
            child: IgnorePointer(
              ignoring: editing,
              child: FittedBox(child: child),
            ),
          );
          Widget center(double top, double w, Widget child) => Positioned(
            top: top,
            left: box.maxWidth / 2 - w / 2,
            width: w,
            child: child,
          );
          return Stack(
            children: [
              const Positioned.fill(
                child: GridBackdrop(child: SizedBox.expand()),
              ),
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => editing
                      ? _edit((ed, l) => ed.down(e.pointer, e.localPosition, l))
                      : _touch((r) => r.down(e.pointer, e.localPosition)),
                  onPointerMove: (e) => editing
                      ? _edit((ed, l) => ed.move(e.pointer, e.localPosition, l))
                      : _touch((r) => r.move(e.pointer, e.localPosition)),
                  onPointerUp: (e) => editing
                      ? _edit((ed, l) => ed.up(e.pointer))
                      : _touch((r) => r.up(e.pointer)),
                  onPointerCancel: (e) => editing
                      ? _edit((ed, l) => ed.up(e.pointer))
                      : _touch((r) => r.up(e.pointer)),
                  child: CustomPaint(
                    painter: PadPainter(
                      layout,
                      r,
                      color,
                      editing: editing,
                      selected: _editor?.selected,
                      repaint: _touches,
                    ),
                  ),
                ),
              ),
              part(PadPart.tilt, _tiltSwitch()),
              part(
                PadPart.exit,
                TextButton.icon(
                  key: const Key('leave'),
                  onPressed: _leave,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Salir'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white60),
                ),
              ),
              part(
                PadPart.menu,
                IconButton(
                  key: const Key('settings'),
                  onPressed: () => showPadSettings(context, this),
                  icon: const Icon(Icons.tune_rounded, color: cyan),
                ),
              ),
              if (!editing) ...[
                center(
                  6,
                  200,
                  IgnorePointer(
                    child: Center(
                      child: PlayerPill(player: p, color: color),
                    ),
                  ),
                ),
                center(
                  statusTop,
                  320,
                  IgnorePointer(
                    child: Text(
                      statusText(client),
                      key: const Key('status'),
                      textAlign: TextAlign.center,
                      maxLines: connected ? 1 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: connected ? Colors.white60 : Colors.amberAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                if (connected && client.info != null)
                  center(
                    statusTop + 22,
                    400,
                    IgnorePointer(
                      child: Center(
                        child: GameCard(
                          info: client.info!,
                          roster: client.roster,
                          icon: client.icon,
                          race: client.race,
                        ),
                      ),
                    ),
                  ),
              ] else
                Positioned(
                  left: box.maxWidth / 2 - 180,
                  width: 360,
                  top: _panelLow ? null : 3.1 * layout.unit,
                  bottom: _panelLow ? 4 + pad.bottom : null,
                  child: EditPanel(
                    editor: _editor!,
                    layout: layout,
                    onScale: (v) => _edit((ed, l) => ed.setScale(v, l)),
                    onReset: () => _edit((ed, l) => ed.resetSelected()),
                    onMove: () => setState(() => _panelLow = !_panelLow),
                    onCancel: () => _finishEditing(keep: false),
                    onDone: () => _finishEditing(keep: true),
                    onSaveAs: _saveAs,
                  ),
                ),
              center(
                box.maxHeight * 0.42,
                360,
                Center(child: PadToast(text: _toast)),
              ),
            ],
          );
        },
      ),
    );
  }
}
