import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../gamer_theme.dart';
import 'reading_dot.dart';
import '../../protocol.dart';
import 'status.dart';

class TelemetryInstrument extends StatelessWidget {
  const TelemetryInstrument({
    super.key,
    required this.id,
    required this.text,
    this.icon,
    this.art,
    this.reading,
  });
  final String id, text;
  final Uint8List? icon;
  final Uint8List? art; // the game's own picture for it (net/game_images.dart): the course, the character, the coin, the item
  final bool? reading;
  @override
  Widget build(BuildContext context) {
    final primary = id == 'place',
        accent = id == 'course'
            ? cyan
            : id == 'coins'
            ? Colors.amberAccent
            : id.startsWith('item')
            ? coral
            : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE6242A34),
        borderRadius: BorderRadius.circular(primary ? 11 : 8),
        border: Border.all(color: Colors.white.withValues(alpha: .13)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (reading != null)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: ReadingDot(on: reading!, color: cyan),
            ),
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Image.memory(
                  icon!,
                  key: const Key('game-icon'),
                  width: 16,
                  height: 16,
                ),
              ),
            ),
          if (art != null)
            Padding(
              padding: EdgeInsets.fromLTRB(0, 3, 5, 3),
              child: id == 'coins'
                  ? Image.memory(
                      art!,
                      key: Key('$id-art'),
                      width: 16,
                      height: 16,
                      gaplessPlayback: true,
                    )
                  : AspectRatio(
                      aspectRatio:
                          1, // as tall as the instrument: the face, the item
                      child: Image.memory(
                        art!,
                        key: Key('$id-art'),
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
            ),
          if (id == 'coins' && art == null)
            const Padding(
              padding: EdgeInsets.only(right: 3),
              child: Icon(
                Icons.monetization_on_rounded,
                size: 12,
                color: Colors.amberAccent,
              ),
            ),
          if (id.startsWith('item') && art == null)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.redeem_rounded, size: 12, color: coral),
            ),
          Flexible(
            child: Text(
              text,
              key: Key(id),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: primary
                    ? 19
                    : id == 'game'
                    ? 9
                    : 11,
                fontWeight: primary ? FontWeight.w800 : FontWeight.w600,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TelemetryHeader extends StatelessWidget {
  const TelemetryHeader({super.key, required this.info, this.icon});
  final GameInfo info;
  final Uint8List? icon;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (icon != null)
        Padding(
          padding: const EdgeInsets.only(right: 7),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.memory(
              icon!,
              key: const Key('game-icon'),
              width: 26,
              height: 26,
            ),
          ),
        ),
      Flexible(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              info.game.toUpperCase(),
              key: const Key('game'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReadingDot(on: info.reading, color: cyan),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    useText(info),
                    key: const Key('use'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9, color: Colors.white54),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
