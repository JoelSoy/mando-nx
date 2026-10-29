// Layouts on the pad (pad_screen.dart): using a preset or one of the player's, forgetting one of the player's, and the editor (pad/editor.dart, edit_panel.dart):
// Listo keeps the change (as Personalizado when it started from a preset), Guardar como names it, Cancelar leaves the layout as it was.
part of 'pad_screen.dart';

mixin _PadEditing on _PadBase {
  @override
  void useLayout(PadConfig c) {
    setState(() => prefs.layout = c);
    saved();
  }

  @override
  void forgetLayout(String name) {
    setState(() => prefs.forget(name));
    saved();
  }

  @override
  void startEditing() {
    _router?.clear();
    setState(() => _editor = PadEditor(prefs.layout));
    _publish();
  }

  @override
  void _finishEditing({required bool keep}) {
    final e = _editor;
    if (e == null) return;
    if (keep && e.changed) {
      prefs.keep(
        e.config.named(e.start.builtIn ? 'Personalizado' : e.start.name),
      );
      saved();
    }
    setState(() => _editor = null);
    _publish();
  }

  @override
  Future<void> _saveAs() async {
    final e = _editor;
    if (e == null) return;
    final name = TextEditingController(
      text: e.start.builtIn ? 'Mi diseño' : e.start.name,
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guardar diseño'),
        content: TextField(
          key: const Key('layout-name'),
          controller: name,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('layout-save'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    final n = name.text.trim();
    name.dispose();
    if (ok != true || n.isEmpty || !mounted) return;
    if (PadConfig.presets.any((p) => p.name == n)) {
      return _say('"$n" es un diseño incluido: usa otro nombre');
    }
    prefs.keep(e.config.named(n));
    saved();
    setState(() => _editor = null);
    _publish();
  }
}
