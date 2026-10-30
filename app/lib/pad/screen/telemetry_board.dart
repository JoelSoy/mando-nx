// Live data is separated into small instruments: link/player stay above, course below, race numbers in gaps, loadout near the edges.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../games/courses.dart';
import '../../games/mk8_karts.dart';
import '../../games/mk8_racers.dart';
import 'telemetry_instrument.dart';
import '../../protocol.dart';
import '../../pad_layout.dart';
import 'game_card.dart';
import 'telemetry_layout.dart';

class TelemetryBoard extends StatelessWidget {
  const TelemetryBoard({
    super.key,
    required this.layout,
    required this.top,
    required this.info,
    this.race,
    this.roster,
    this.icon,
    this.picture,
  });
  final PadLayout layout;
  final double top;
  final GameInfo info;
  final RaceInfo? race;
  final Roster? roster;
  final Uint8List? icon;
  final Uint8List? Function(String? key)?
  picture; // the game's pictures (net/game_images.dart), by RaceInfo's keys
  @override
  Widget build(BuildContext context) {
    final w = layout.size.width, h = layout.size.height, r = race;
    final text = <String, String>{}, art = <String, Uint8List?>{};
    final slots = <TelemetrySlot>[
      TelemetrySlot(
        'game',
        const Size(310, 34),
        Offset(w * .5, top + 17),
        minWidth: 230,
      ),
      if (r == null)
        TelemetrySlot(
          'roster',
          const Size(220, 22),
          Offset(w * .5, top + 52),
          minWidth: 180,
        ),
    ];
    if (r != null) {
      final course = courseName(r.course);
      if (course.isNotEmpty) {
        text['course'] = course;
        slots.add(
          TelemetrySlot(
            'course',
            const Size(230, 24),
            Offset(w * .22, h - 35),
            minWidth: 155,
          ),
        );
      }
      if (r.racing) {
        text.addAll({
          'place': '${r.place}.º',
          'lap': 'Vuelta ${r.lap}',
          'coins': '${r.coins}',
        });
        art['coins'] = picture?.call(r.coinPicture);
        slots.addAll([
          TelemetrySlot(
            'place',
            const Size(68, 34),
            Offset(
              layout.parts[PadPart.l]!.center.dx,
              (layout.parts[PadPart.l]!.bottom +
                      layout.parts[PadPart.stick]!.top) /
                  2,
            ),
          ),
          TelemetrySlot(
            'lap',
            const Size(86, 22),
            Offset(
              layout.parts[PadPart.r]!.center.dx,
              (layout.parts[PadPart.r]!.bottom +
                      layout.parts[PadPart.face]!.top) /
                  2,
            ),
          ),
          TelemetrySlot('coins', const Size(56, 24), Offset(w * .30, h * .36)),
        ]);
      }
      if (r.hasKart) {
        text['kart'] = [
          driverName(r.driver),
          kartName(r.body, r.tires, r.glider),
        ].where((v) => v.isNotEmpty).join(' · ');
        slots.add(
          TelemetrySlot(
            'kart',
            const Size(270, 26),
            Offset(w * .78, h - 34),
            minWidth: 170,
          ),
        );
      }
      for (final (i, item) in [r.item, r.item2].indexed) {
        final name = itemName(item);
        if (name.isNotEmpty) {
          text['item$i'] = name;
          slots.add(
            TelemetrySlot(
              'item$i',
              const Size(125, 24),
              Offset(w * .84, h - 72 - i * 29),
              minWidth: 95,
            ),
          );
        }
      }
    }
    final rects = arrangeTelemetry(layout, top, slots);
    return IgnorePointer(
      child: Stack(
        children: [
          for (final e in rects.entries)
            Positioned.fromRect(
              rect: e.value,
              child: e.key == 'game'
                  ? TelemetryHeader(info: info, icon: icon)
                  : e.key == 'roster'
                  ? RosterLights(info: info, roster: roster)
                  : TelemetryInstrument(
                      id: e.key,
                      text: text[e.key]!,
                      art: art[e.key],
                    ),
            ),
        ],
      ),
    );
  }
}
