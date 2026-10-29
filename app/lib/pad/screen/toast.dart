// A short message on the pad (the sensor stopped, a name taken): it shows for three seconds over the middle and takes no touches, unlike a snack bar, which would sit
// over the stick and the buttons at the bottom and swallow presses while it is up.
import 'package:flutter/material.dart';

import '../../gamer_theme.dart';

class PadToast extends StatelessWidget {
  const PadToast({super.key, required this.text});
  final String? text;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedOpacity(
      opacity: text == null ? 0 : 1,
      duration: const Duration(milliseconds: 200),
      child: text == null
          ? const SizedBox.shrink()
          : Container(
              key: const Key('toast'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: panel.withValues(alpha: .95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amberAccent),
              ),
              child: Text(
                text!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.amberAccent, fontSize: 13),
              ),
            ),
    ),
  );
}
