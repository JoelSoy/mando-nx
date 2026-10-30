// The game's pictures on the pad (pad/screen/game_art.dart): in a race whose host makes pictures, the course's picture fills the screen between the controls, the
// character's face rides the stick's knob and the held item takes L's place; without an item L is a letter again, and without pictures nothing changes.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/client.dart';
import 'package:remote_pad/pad_layout.dart';
import 'package:remote_pad/pad_screen.dart';
import 'package:remote_pad/pad/screen/game_art.dart';
import 'package:remote_pad/pad/screen/painter.dart';

import 'client_fakes.dart';

const png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

void main() {
  testWidgets(
    'the course on the screen, the face on the stick, the item on L',
    (w) async {
      w.view.physicalSize = const Size(1704, 786);
      w.view.devicePixelRatio = 2;
      addTearDown(w.view.reset);
      final t = FakeTransport();
      final c = RemoteClient(
        transport: t,
        code: '482913',
        clientId: 'phoneid123456789',
        name: 'Ana',
        clock: () => 0,
      )..start();
      await w.pumpWidget(
        MaterialApp(
          home: PadScreen(
            client: c,
            haptics: false,
            accelerometer: () => const Stream.empty(),
            gyroscope: () => const Stream.empty(),
          ),
        ),
      );
      c.receive(j({'v': 1, 't': 'welcome', 'sid': sid, 'player': 1}));
      Map<String, Object> race(int cs, int item, {int img = 1}) => {
        'v': 1,
        't': 'race',
        'sid': sid,
        'cs': cs,
        'crs': 'Gu_Cake',
        'pos': 2,
        'lap': 1,
        'coin': 3,
        'drv': 4,
        'dcl': 0,
        'body': 0,
        'tire': 0,
        'wing': 0,
        'itm': item,
        'itm2': -1,
        'img': img,
      };
      final bytes = base64Decode(png);
      Future<void> serve() async {
        // the host's answers: each picture asked for, whole in one piece
        for (var round = 0; round < 8; round++) {
          c.tick();
          for (final m in t.of('img').toList()) {
            c.receive(
              j({
                'v': 1,
                't': 'imgpart',
                'sid': sid,
                'im': m['im'],
                'ih': '0000beef',
                'isz': bytes.length,
                'off': 0,
                'd': png,
              }),
            );
          }
          await w.pump();
        }
      }

      CustomPaint paint() => w.widget<CustomPaint>(
        find.byWidgetPredicate(
          (x) => x is CustomPaint && x.painter is PadPainter,
        ),
      );
      PadPainter pad() => paint().painter as PadPainter;
      GameArtPainter art() => paint().foregroundPainter as GameArtPainter;

      c.receive(j(race(1, 3, img: 0)));
      await serve();
      expect(
        t.of('img'),
        isEmpty,
        reason: 'a host without pictures is not asked',
      );
      expect(find.byKey(const Key('race-screen')), findsNothing);
      expect(pad().hidden, isEmpty);

      c.receive(j(race(2, 3)));
      await serve();
      expect(find.byKey(const Key('race-screen')), findsOneWidget);
      expect(pad().hidden, {Control.l}, reason: 'the mushroom takes L');
      expect([art().face, art().item], everyElement(isNotNull));

      c.receive(j(race(3, -1)));
      await w.pump();
      expect(pad().hidden, isEmpty, reason: 'no item: L again');
      expect(art().item, isNull);
      expect(art().face, isNotNull);
      await w.pumpWidget(const SizedBox());
    },
  );
}
