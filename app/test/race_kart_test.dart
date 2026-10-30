// The race's character, kart and items (host → phone "race": drv, body, tire, wing, itm, itm2): decoding, all or nothing for each group; their Spanish names;
// the second race line on the game card.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/games/mk8_karts.dart';
import 'package:remote_pad/games/mk8_racers.dart';
import 'package:remote_pad/pad/screen/game_card.dart';
import 'package:remote_pad/protocol.dart';

import 'client_fakes.dart';

Map<String, Object> race(Map<String, Object> more) => {
  'v': 1,
  't': 'race',
  'sid': sid,
  'cs': 3,
  'crs': 'Gu_MarioCircuit',
  'pos': 6,
  'lap': 1,
  'coin': 5,
  ...more,
};
const kart = {'drv': 40, 'body': 15, 'tire': 20, 'wing': 0};

void main() {
  test(
    'decode: the character and kart, and the items, each all or nothing',
    () {
      final r = decodeHostMessage(
        j(race({...kart, 'itm': 3, 'itm2': -1})),
      ) as RaceInfo;
      expect(
        [r.driver, r.body, r.tires, r.glider, r.item, r.item2, r.hasKart],
        [40, 15, 20, 0, 3, -1, true],
      );
      expect(r.place, 6, reason: 'the place still comes with them');
      final none = decodeHostMessage(j(race({}))) as RaceInfo;
      expect([none.hasKart, none.item], [false, null], reason: 'an older host');
      final half = decodeHostMessage(
        j(race({...kart, 'wing': 64, 'itm': 2})),
      ) as RaceInfo;
      expect(
        [half.hasKart, half.body, half.item],
        [false, null, null],
        reason: 'a glider id out of range drops the kart; one slot drops both',
      );
      final odd =
          decodeHostMessage(j(race({'itm': -2, 'itm2': 'x'}))) as RaceInfo;
      expect([odd.item, odd.racing], [null, true]);
    },
  );

  test('names: the game\'s Spanish names in its id order', () {
    expect(driverName(4), 'Yoshi');
    expect(driverName(40), 'Rey Boo');
    expect(driverName(44), 'Birdo');
    expect(driverName(49), 'Funky Kong');
    expect(driverName(99), '');
    expect(kartName(14, 20, 0), 'Moto estándar · Leaf · Superala');
    expect(kartName(15, 99, 0), 'Torbellino · Superala');
    expect(itemName(0), 'Plátano');
    expect(itemName(1), 'Caparazón verde');
    expect(itemName(2), 'Caparazón rojo');
    expect(itemName(3), 'Champiñón');
    expect(itemName(15), 'Moneda');
    expect(itemName(22), 'Boo');
    expect([itemName(-1), itemName(23), itemName(null)], ['', '', '']);
  });

  testWidgets('the game card shows the character, kart and items', (
    tester,
  ) async {
    const info = GameInfo(
      sid,
      1,
      1,
      'Mario Kart 8 Deluxe',
      PlayerUse.own,
      4,
      1,
    );
    Widget card(RaceInfo r) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: GameCard(info: info, race: r),
        ),
      ),
    );
    await tester.pumpWidget(
      card(
        const RaceInfo(
          sid,
          2,
          'Gu_MarioCircuit',
          place: 6,
          lap: 1,
          coins: 5,
          driver: 40,
          body: 15,
          tires: 20,
          glider: 0,
          item: 3,
          item2: 0,
        ),
      ),
    );
    expect(find.text('Rey Boo · Torbellino · Leaf · Superala'), findsOneWidget);
    expect(find.text('Champiñón'), findsOneWidget);
    expect(find.text('Plátano'), findsOneWidget);
    await tester.pumpWidget(
      card(const RaceInfo(sid, 3, 'Gu_MarioCircuit', item: -1, item2: -1)),
    );
    expect(find.byKey(const Key('kart')), findsNothing);
    expect(find.byKey(const Key('item0')), findsNothing);
    expect(find.text('Circuito Mario'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
