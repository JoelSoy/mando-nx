// The game card in the middle of the pad: the game's icon and name; a light per player the game takes, with who holds it (this phone's in its colour, glowing while
// the game reads it); what the game makes of this player, with a dot that beats while the game is reading this controller; in a race, the race line.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../gamer_theme.dart';
import '../../protocol.dart';
import 'race_line.dart';
import 'reading_dot.dart';
import 'status.dart';

class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.info,
    this.roster,
    this.icon,
    this.race,
  });
  final GameInfo info;
  final Roster? roster;
  final RaceInfo? race;
  final Uint8List? icon;

  @override
  Widget build(BuildContext context) {
    final ok = info.use == PlayerUse.own || info.use == PlayerUse.p1;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF20252D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF424B58)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
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
                  width: 40,
                  height: 40,
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
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                const SizedBox(height: 2),
                RosterLights(info: info, roster: roster),
                const SizedBox(height: 2),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ok ? lime : Colors.amberAccent,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                if (race != null) ...[
                  const SizedBox(height: 2),
                  RaceLine(race: race!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RosterLights extends StatelessWidget {
  const RosterLights({super.key, required this.info, this.roster});
  final GameInfo info;
  final Roster? roster;
  @override
  Widget build(BuildContext context) {
    final n = info.seats < info.player ? info.player : info.seats;
    return Row(
      key: const Key('lights'),
      children: [
        for (var p = 1; p <= n; p++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p == info.player
                          ? playerColor(p)
                          : info.holds(p)
                          ? Colors.white54
                          : Colors.transparent,
                      border: Border.all(
                        color: p == info.player
                            ? playerColor(p)
                            : Colors.white24,
                      ),
                      boxShadow: p == info.player && info.reading
                          ? [
                              BoxShadow(
                                color: playerColor(p).withValues(alpha: .5),
                                blurRadius: 5,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      p == info.player
                          ? 'Tú'
                          : playerName(roster?.names[p] ?? ''),
                      key: Key('who-$p'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p == info.player ? Colors.white : Colors.white54,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
