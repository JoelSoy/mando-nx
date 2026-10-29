// The game card's live dot (game_card.dart): it beats while the game reads this controller and stays hollow while it does not.
import 'package:flutter/material.dart';

/// A dot that beats while the game reads this controller, and stays hollow while it does not.
class ReadingDot extends StatefulWidget {
  const ReadingDot({super.key, required this.on, required this.color});
  final bool on;
  final Color color;
  @override
  State<ReadingDot> createState() => ReadingDotState();
}

class ReadingDotState extends State<ReadingDot>
    with SingleTickerProviderStateMixin {
  late final _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  @override
  void didUpdateWidget(ReadingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.on && !_beat.isAnimating) _beat.repeat(reverse: true);
    if (!widget.on && _beat.isAnimating) _beat.stop();
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: widget.on
        ? Tween(begin: 0.35, end: 1.0).animate(_beat)
        : const AlwaysStoppedAnimation(1),
    child: Container(
      key: Key(widget.on ? 'reading-on' : 'reading-off'),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.on ? widget.color : Colors.transparent,
        border: Border.all(color: widget.on ? widget.color : Colors.white38),
      ),
    ),
  );
}
