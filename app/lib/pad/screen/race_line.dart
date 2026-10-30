// The race lines under the game card (RaceInfo): the course by its Spanish name (games/courses.dart) and, once the host reads them, this player's place, lap and
// coins; below, their character and kart and the items they hold (games/mk8_*.dart).
import 'package:flutter/material.dart';

import '../../gamer_theme.dart';
import '../../games/courses.dart';
import '../../games/mk8_karts.dart';
import '../../games/mk8_racers.dart';
import '../../protocol.dart';

class RaceLine extends StatelessWidget {
  const RaceLine({super.key, required this.race});
  final RaceInfo race;

  @override
  Widget build(BuildContext context) {
    final r = race, name = courseName(r.course);
    final kart = r.hasKart
        ? [
            driverName(r.driver),
            kartName(r.body, r.tires, r.glider),
          ].where((s) => s.isNotEmpty).join(' · ')
        : '';
    final items = [
      itemName(r.item),
      itemName(r.item2),
    ].where((s) => s.isNotEmpty).toList();
    final top = _top(name);
    if (kart.isEmpty && items.isEmpty) return top;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        top,
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kart.isNotEmpty)
              Flexible(
                child: Text(
                  kart,
                  key: const Key('kart'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            for (final (i, item) in items.indexed)
              _Chip(
                key: Key('item$i'),
                text: item,
                icon: Icons.redeem,
                color: Colors.lightBlueAccent,
              ),
          ],
        ),
      ],
    );
  }

  Widget _top(String name) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (name.isNotEmpty)
          Flexible(
            child: Text(
              name,
              key: const Key('course'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (race.racing) ...[
          _Chip(key: const Key('place'), text: '${race.place}.º', color: lime),
          _Chip(key: const Key('lap'), text: 'Vuelta ${race.lap}'),
          _Chip(
            key: const Key('coins'),
            text: '${race.coins}',
            icon: Icons.monetization_on,
            color: Colors.amberAccent,
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.text,
    this.icon,
    this.color = Colors.white70,
  });
  final String text;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 2),
        ],
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
