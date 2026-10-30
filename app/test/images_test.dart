// The game's pictures (host → phone "imgpart", net/game_images.dart): the race's keys, decoding, the pull (one picture at a time, a few pieces, lost ones asked
// again), a key the host has none for or never answers, and an instrument showing the picture.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/client.dart';
import 'package:remote_pad/pad/screen/telemetry_instrument.dart';
import 'package:remote_pad/protocol.dart';

import 'client_fakes.dart';

void main() {
  late FakeTransport t;
  late RemoteClient c;
  var now = 1000;
  setUp(() {
    now = 1000;
    t = FakeTransport();
    c = RemoteClient(
      transport: t,
      code: '482913',
      clientId: 'phoneid123456789',
      name: 'Ana',
      clock: () => now,
    )..start();
    c.receive(j({'v': 1, 't': 'welcome', 'sid': sid, 'player': 1}));
  });
  final pic = List<int>.generate(600, (i) => i * 5 + 1 & 255);
  Map<String, Object> part(String key, int off, {String ih = '1234abcd'}) => {
    'v': 1,
    't': 'imgpart',
    'sid': sid,
    'im': key,
    'ih': ih,
    'isz': 600,
    'off': off,
    'd': base64Encode(pic.sublist(off, off + 264 > 600 ? 600 : off + 264)),
  };
  Iterable<Object?> asked() => t.of('img').map((m) => '${m['im']}@${m['off']}');

  test('the race names its pictures only when the host makes them', () {
    final race = {'v': 1, 't': 'race', 'sid': sid, 'cs': 1, 'crs': 'Gu_Cake'};
    final kart = {'drv': 4, 'dcl': 3, 'body': 0, 'tire': 0, 'wing': 0};
    var r = decodeHostMessage(j({...race, ...kart, 'img': 1})) as RaceInfo;
    expect(
      [r.coursePicture, r.driverPicture, r.coinPicture, r.itemPicture(3)],
      ['crs/Gu_Cake', 'drv/4/3', 'itm/15', 'itm/3'],
    );
    expect(r.itemPicture(-1), isNull, reason: 'an empty slot');
    r = decodeHostMessage(j({...race, ...kart})) as RaceInfo;
    expect([r.coursePicture, r.driverPicture, r.color], [null, null, 3]);
  });

  test('decoding pieces: none, bad keys and bad data refused', () {
    final none = decodeHostMessage(
      j({'v': 1, 't': 'imgpart', 'sid': sid, 'im': 'itm/99', 'isz': 0}),
    ) as ImagePart;
    expect([none.key, none.size], ['itm/99', 0]);
    for (final bad in [
      {...part('itm/3', 0), 'im': 'itm/"3'},
      {...part('itm/3', 0), 'im': 'a' * 33},
      {...part('itm/3', 0), 'ih': 'xyz'},
      {...part('itm/3', 0), 'd': '%%%'},
      {...part('itm/3', 0), 'isz': -1},
    ]) {
      expect(decodeHostMessage(j(bad)), isNull, reason: '$bad');
    }
  });

  test(
    'pulled one at a time, a few pieces in flight, lost ones asked again',
    () {
      expect(c.picture('drv/4/3'), isNull);
      expect(c.picture('itm/3'), isNull);
      c.tick();
      expect(asked(), ['drv/4/3@0'], reason: 'first the size: offset 0');
      now += 450;
      c.tick();
      expect(
        asked().last,
        'drv/4/3@0',
        reason: 'still being made: asked again',
      );
      c.receive(j(part('drv/4/3', 0)));
      expect(asked().skip(2), [
        'drv/4/3@264',
        'drv/4/3@528',
      ], reason: 'the rest at once');
      c.receive(j(part('itm/3', 264)));
      c.receive(j(part('drv/4/3', 528)));
      expect(c.picture('drv/4/3'), isNull, reason: 'one piece still missing');
      now += 450;
      c.tick();
      expect(asked().last, 'drv/4/3@264', reason: 'the lost piece asked again');
      var told = 0;
      c.addListener(() => told++);
      c.receive(j(part('drv/4/3', 264)));
      expect(c.picture('drv/4/3'), Uint8List.fromList(pic));
      expect(told, greaterThan(0), reason: 'the screen hears of it');
      expect(asked().last, 'itm/3@0', reason: 'then the next picture');
    },
  );

  test(
    'a picture the host has none for, or never answers, is not asked again',
    () {
      c.picture('itm/99');
      c.picture('itm/2');
      c.tick();
      c.receive(
        j({'v': 1, 't': 'imgpart', 'sid': sid, 'im': 'itm/99', 'isz': 0}),
      );
      expect(asked().last, 'itm/2@0');
      for (var i = 0; i < 25; i++) {
        now += 400;
        c.tick();
      }
      final n = t.of('img').length;
      c.picture('itm/99');
      c.picture('itm/2');
      now += 400;
      c.tick();
      expect(t.of('img').length, n, reason: 'neither is asked again');
      expect([c.picture('itm/99'), c.picture('itm/2')], [null, null]);
    },
  );

  testWidgets('an instrument shows the game\'s picture beside its text', (
    tester,
  ) async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 24,
            child: TelemetryInstrument(id: 'coins', text: '7', art: png),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('coins-art')), findsOneWidget);
    expect(find.byIcon(Icons.monetization_on_rounded), findsNothing);
    expect(find.text('7'), findsOneWidget);
  });
}
