// The race (host → phone "race"): decoding, the feed taking it for this session and in order, the course names, and the race line on the game card.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/client.dart';
import 'package:remote_pad/games/courses.dart';
import 'package:remote_pad/pad/screen/game_card.dart';
import 'package:remote_pad/protocol.dart';

import 'client_fakes.dart';

Map<String, Object> race(int cs, String crs, {int? pos, int? lap, int? coin}) =>
    {
      'v': 1,
      't': 'race',
      'sid': sid,
      'cs': cs,
      'crs': crs,
      'pos': ?pos,
      'lap': ?lap,
      'coin': ?coin,
    };

void main() {
  test(
    'decode: course, and place, lap and coins only when all three are good',
    () {
      final r = decodeHostMessage(
        j(race(4, 'Gu_WaterPark', pos: 3, lap: 2, coin: 7)),
      );
      expect(r, isA<RaceInfo>());
      r as RaceInfo;
      expect(
        [r.seq, r.course, r.place, r.lap, r.coins, r.racing],
        [4, 'Gu_WaterPark', 3, 2, 7, true],
      );
      final c = decodeHostMessage(j(race(5, 'Gu_Menu'))) as RaceInfo;
      expect([c.course, c.racing], ['Gu_Menu', false]);
      final bad = decodeHostMessage(j(race(6, 'Gu', pos: 0, lap: 1, coin: 2)));
      expect(
        (bad as RaceInfo).racing,
        isFalse,
        reason: 'place 0 is not a place',
      );
      expect(decodeHostMessage(j(race(7, 'Gu "x"'))), isNull);
      expect(decodeHostMessage(j(race(8, 'A' * 25))), isNull);
      expect(decodeHostMessage(j({...race(9, 'Gu'), 'cs': -1})), isNull);
      expect(decodeHostMessage(j({...race(9, 'Gu'), 'sid': 'nope'})), isNull);
    },
  );

  test('feed: this session, in order; no course and no data is no race', () {
    final c = RemoteClient(
      transport: FakeTransport(),
      code: '482913',
      clientId: 'phoneid123456789',
      name: 'Ana',
      clock: () => 1000,
    )..start();
    c.receive(j({'v': 1, 't': 'welcome', 'sid': sid, 'player': 1}));
    c.receive(j({...race(1, 'Gu_Cake', pos: 1, lap: 1, coin: 0), 'sid': sid2}));
    expect(c.race, isNull, reason: 'another session');
    c.receive(j(race(2, 'Gu_Cake', pos: 5, lap: 1, coin: 3)));
    expect(c.race?.place, 5);
    c.receive(j(race(1, 'Gu_Cake', pos: 9, lap: 1, coin: 3)));
    expect(c.race?.place, 5, reason: 'an older one is dropped');
    c.receive(j(race(3, 'Gu_Cake', pos: 4, lap: 2, coin: 4)));
    expect([c.race?.place, c.race?.lap, c.race?.coins], [4, 2, 4]);
    c.receive(j(race(4, '')));
    expect(c.race, isNull, reason: 'back in the menus');
    c.receive(j(race(5, 'Gu_Ocean')));
    expect([c.race?.course, c.race?.racing], ['Gu_Ocean', false]);
    c.resetFeed();
    expect(c.race, isNull);
  });

  test('course names: Spanish, a retro course with its console', () {
    expect(courseName('Gu_WaterPark'), 'Parque Acuático');
    expect(courseName('Gu_FirstCircuit'), 'Estadio Mario Kart');
    expect(courseName('G64_RainbowRoad'), 'N64 Senda Arco Iris');
    expect(courseName('Gwii_MooMooMeadows'), 'Wii Pradera Mu-Mu');
    expect(courseName('Du_Animal_Winter'), 'Animal Crossing');
    expect(courseName('B3ds_WuhuTown'), '3DS Pueblo Wuhu');
    expect(courseName('Cnsw_11'), 'Bulevares de París');
    expect(courseName('Some_New_Course'), 'Some New Course');
    expect(courseName(''), '');
  });

  testWidgets('the game card shows the race line', (tester) async {
    const info = GameInfo(
      sid,
      1,
      1,
      'Mario Kart 8 Deluxe',
      PlayerUse.own,
      4,
      1,
    );
    Widget card(RaceInfo? r) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: GameCard(info: info, race: r),
        ),
      ),
    );
    await tester.pumpWidget(card(null));
    expect(find.byKey(const Key('course')), findsNothing);
    await tester.pumpWidget(
      card(const RaceInfo(sid, 2, 'Gu_Airport', place: 1, lap: 3, coins: 10)),
    );
    expect(find.text('Aeropuerto Soleado'), findsOneWidget);
    expect(find.text('1.º'), findsOneWidget);
    expect(find.text('Vuelta 3'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    await tester.pumpWidget(card(const RaceInfo(sid, 3, 'Gu_Cloud')));
    expect(find.text('Ruta Celeste'), findsOneWidget);
    expect(find.byKey(const Key('place')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
