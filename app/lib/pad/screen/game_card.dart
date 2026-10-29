// The game card in the middle of the pad: the game's icon and name; a light per player the game takes, with who holds it (this phone's in its colour, glowing while
// the game reads it); what the game makes of this player, with a dot that beats while the game is reading this controller.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../gamer_theme.dart';
import '../../protocol.dart';
import 'reading_dot.dart';
import 'status.dart';

class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.info, this.roster, this.icon});
  final GameInfo info;
  final Roster? roster;
  final Uint8List? icon;

  @override
  Widget build(BuildContext context) {
    final ok = info.use == PlayerUse.own || info.use == PlayerUse.p1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                icon!,
                key: const Key('game-icon'),
                width: 52,
                height: 52,
                gaplessPlayback: true,
              ),
            ),
          ),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (info.game.isNotEmpty)
                Text(
                  info.game.toUpperCase(),
                  key: const Key('game'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              const SizedBox(height: 5),
              _Lights(info: info, roster: roster),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ReadingDot(
                    on: info.reading,
                    color: ok ? lime : Colors.amberAccent,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      useText(info),
                      key: const Key('use'),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ok ? lime : Colors.amberAccent,
                        fontSize: 12,
                      ),
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
}

class _Lights extends StatelessWidget {
  const _Lights({required this.info, this.roster});
  final GameInfo info;
  final Roster? roster;
  @override
  Widget build(BuildContext context) {
    final n = info.seats < info.player ? info.player : info.seats;
    return Row(
      key: const Key('lights'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var p = 1; p <= n; p++)
          SizedBox(
            width: 54,
            child: Column(
              children: [
                Container(
                  width: p == info.player ? 14 : 10,
                  height: p == info.player ? 14 : 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p == info.player
                        ? playerColor(p)
                        : info.holds(p)
                        ? Colors.white54
                        : Colors.transparent,
                    border: Border.all(
                      color: p == info.player ? playerColor(p) : Colors.white38,
                      width: 1.5,
                    ),
                    boxShadow: p == info.player && info.reading
                        ? [
                            BoxShadow(
                              color: playerColor(p).withValues(alpha: .7),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p == info.player ? 'Tú' : playerName(roster?.names[p] ?? ''),
                  key: Key('who-$p'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p == info.player ? Colors.white : Colors.white54,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
