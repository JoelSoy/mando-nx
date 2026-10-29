// The game's keyboard on the phone: the host asks for text (client.keyboard: title, initial text, length); the dialog sends the answer (Enviar) or a cancel, and closes
// by itself when the request is over without this phone (another phone or the Mac answered, or the box closed there).
import 'package:flutter/material.dart';

import '../../client.dart';
import '../../protocol.dart';

Future<void> showKeyboardPrompt(
  BuildContext context,
  RemoteClient client,
  KeyboardRequest k,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _KeyboardDialog(client: client, request: k),
);

class _KeyboardDialog extends StatefulWidget {
  const _KeyboardDialog({required this.client, required this.request});
  final RemoteClient client;
  final KeyboardRequest request;
  @override
  State<_KeyboardDialog> createState() => _KeyboardDialogState();
}

class _KeyboardDialogState extends State<_KeyboardDialog> {
  late final _text = TextEditingController(text: widget.request.initial);
  bool _closed = false;

  void _gone() {
    if (_closed || widget.client.keyboard?.id == widget.request.id) return;
    _closed = true;
    if (mounted) Navigator.of(context).pop();
  }

  void _answer(bool ok) {
    if (_closed) return;
    _closed = true;
    widget.client.answerKeyboard(_text.text, ok);
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    widget.client.addListener(_gone);
  }

  @override
  void dispose() {
    widget.client.removeListener(_gone);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('keyboard-dialog'),
    title: Text(
      widget.request.title.isEmpty
          ? 'El juego pide un texto'
          : widget.request.title,
    ),
    content: TextField(
      key: const Key('keyboard-text'),
      controller: _text,
      autofocus: true,
      maxLength: widget.request.max,
      onSubmitted: (_) => _answer(true),
      decoration: const InputDecoration(
        helperText: 'Se escribe en el juego del Mac',
      ),
    ),
    actions: [
      TextButton(
        key: const Key('keyboard-cancel'),
        onPressed: () => _answer(false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('keyboard-send'),
        onPressed: () => _answer(true),
        child: const Text('Enviar'),
      ),
    ],
  );
}
