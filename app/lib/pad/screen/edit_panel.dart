// The panel while editing the layout (pad_screen.dart): which part is selected, its size, reset, where the panel sits, and Cancelar / Guardar como / Listo.
import 'package:flutter/material.dart';

import '../../gamer_theme.dart';
import '../../pad_layout.dart';

/// The panel while editing the layout: which part is selected, its size, reset, where the panel sits, and Cancelar / Guardar como / Listo.
class EditPanel extends StatelessWidget {
  const EditPanel({
    super.key,
    required this.editor,
    required this.layout,
    required this.onScale,
    required this.onReset,
    required this.onMove,
    required this.onCancel,
    required this.onDone,
    required this.onSaveAs,
  });
  final PadEditor editor;
  final PadLayout layout;
  final ValueChanged<double> onScale;
  final VoidCallback onReset, onMove, onCancel, onDone, onSaveAs;

  @override
  Widget build(BuildContext context) {
    final s = editor.selected;
    final scale = s == null ? 1.0 : editor.config[s].scale;
    return Material(
      key: const Key('edit-panel'),
      color: panel.withValues(alpha: .94),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: lime, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.open_with_rounded, color: lime, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    s == null
                        ? 'Toca una pieza y arrástrala · pellizca para el tamaño'
                        : 'Editando: ${partNames[s]}',
                    key: const Key('edit-selected'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('edit-move-panel'),
                  tooltip: 'Mover este panel',
                  visualDensity: VisualDensity.compact,
                  onPressed: onMove,
                  icon: const Icon(Icons.swap_vert_rounded, size: 20),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Tamaño', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    key: const Key('edit-size'),
                    value: scale,
                    min: minScale,
                    max: maxScale,
                    onChanged: s == null ? null : onScale,
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${(scale * 100).round()}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                IconButton(
                  key: const Key('edit-reset'),
                  tooltip: s == null
                      ? 'Deshacer todo'
                      : 'Restablecer esta pieza',
                  visualDensity: VisualDensity.compact,
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt_rounded, size: 20),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      key: const Key('edit-cancel'),
                      onPressed: onCancel,
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      key: const Key('edit-save-as'),
                      onPressed: onSaveAs,
                      child: const Text('Guardar como…'),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      key: const Key('edit-done'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: onDone,
                      child: const Text('Listo'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
