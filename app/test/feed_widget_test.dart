import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/client.dart';
import 'package:remote_pad/pad_screen.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'client_fakes.dart';

const png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

void main() {
  late FakeTransport t;
  late RemoteClient c;
  Future<void> pad(
    WidgetTester w, {
    Stream<AccelerometerEvent> Function()? acc,
  }) async {
    w.view.physicalSize = const Size(1704, 786);
    w.view.devicePixelRatio = 2;
    addTearDown(w.view.reset);
    t = FakeTransport();
    c = RemoteClient(
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
          accelerometer: acc,
          gyroscope: () => const Stream.empty(),
        ),
      ),
    );
    c.receive(j({'v': 1, 't': 'welcome', 'sid': sid, 'player': 2}));
    await w.pump();
  }

  testWidgets(
    'the game\'s keyboard: asked on the phone, the text goes back, the dialog closes',
    (w) async {
      await pad(w);
      c.receive(
        j({
          'v': 1,
          't': 'kbd',
          'sid': sid,
          'ks': 3,
          'max': 10,
          'title': 'Nombre del piloto',
          'init': 'Ana',
        }),
      );
      await w.pumpAndSettle();
      expect(find.text('Nombre del piloto'), findsOneWidget);
      await w.enterText(find.byKey(const Key('keyboard-text')), 'Joel');
      await w.tap(find.byKey(const Key('keyboard-send')));
      await w.pumpAndSettle();
      expect(find.byKey(const Key('keyboard-dialog')), findsNothing);
      expect(t.of('text').first, containsPair('text', 'Joel'));
      c.receive(j({'v': 1, 't': 'kbd', 'sid': sid, 'ks': 4, 'title': 'Otro'}));
      await w.pumpAndSettle();
      expect(find.text('Otro'), findsOneWidget);
      c.receive(j({'v': 1, 't': 'kbd', 'sid': sid, 'ks': 4, 'done': 1}));
      await w.pumpAndSettle();
      expect(
        find.byKey(const Key('keyboard-dialog')),
        findsNothing,
        reason: 'answered on the Mac: closed by itself',
      );
      await w.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'the game card: who plays, the icon, the game reading this controller',
    (w) async {
      await pad(w);
      c.receive(
        j({
          'v': 1,
          't': 'roster',
          'sid': sid,
          'rs': 1,
          'n1': 'keyboard',
          'n2': 'Ana',
          'n3': 'Luis',
        }),
      );
      c.receive(
        j({
          'v': 1,
          't': 'info',
          'sid': sid,
          'is': 1,
          'player': 2,
          'game': 'Mario Kart 8 Deluxe',
          'use': 'own',
          'seats': 4,
          'taken': 7,
          'rd': 1,
          'ih': 'cafe0001',
          'isz': base64Decode(png).length,
        }),
      );
      c.receive(
        j({
          'v': 1,
          't': 'iconpart',
          'sid': sid,
          'ih': 'cafe0001',
          'off': 0,
          'd': png,
        }),
      );
      await w.pump();
      expect(find.text('Teclado'), findsOneWidget);
      expect(find.text('Tú'), findsOneWidget);
      expect(find.text('Luis'), findsOneWidget);
      expect(find.byKey(const Key('game-icon')), findsOneWidget);
      expect(find.byKey(const Key('reading-on')), findsOneWidget);
      c.receive(
        j({
          'v': 1,
          't': 'info',
          'sid': sid,
          'is': 2,
          'player': 2,
          'game': 'Mario Kart 8 Deluxe',
          'use': 'own',
          'seats': 4,
          'taken': 7,
          'rd': 0,
        }),
      );
      await w.pump();
      expect(find.byKey(const Key('reading-off')), findsOneWidget);
      await w.pumpWidget(const SizedBox());
    },
  );
}
