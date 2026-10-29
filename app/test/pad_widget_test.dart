import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/client.dart';
import 'package:remote_pad/pad_screen.dart';
import 'package:remote_pad/protocol.dart';
import 'package:remote_pad/storage.dart';

class FakeTransport implements Transport {
  final sent = <Map<String, dynamic>>[];
  @override
  void send(List<int> data) =>
      sent.add(jsonDecode(utf8.decode(data)) as Map<String, dynamic>);
  @override
  void close() {}
}

List<int> j(Object o) => utf8.encode(jsonEncode(o));

void main() {
  test('settings store: round trip, a broken file gives the defaults', () {
    final dir = Directory.systemTemp.createTempSync('mando');
    addTearDown(() => dir.deleteSync(recursive: true));
    final s = SettingsStore(dir);
    final a = Settings(
      host: '10.0.0.2',
      port: 47801,
      code: 'abcd',
      name: 'Luis',
    );
    s.save(a);
    final b = s.load();
    expect(
      [b.host, b.port, b.code, b.name, b.clientId],
      [a.host, a.port, a.code, a.name, a.clientId],
    );
    File('${dir.path}/${SettingsStore.fileName}')
        .writeAsStringSync('{"host": 5, "port": 99999, "id": "bad id!"}');
    final c = s.load();
    expect([c.host, c.port], ['', defaultPort]);
    expect(validClientId(c.clientId), isTrue);
    expect(SettingsStore(null).load().host, '');
  });

  testWidgets('pad screen: the game card follows the host\'s info', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1688, 780);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final t = FakeTransport();
    final c = RemoteClient(
      transport: t,
      code: '482913',
      clientId: 'phoneid123456789',
      name: 'Ana',
      clock: () => 0,
    )..start();
    await tester.pumpWidget(
      MaterialApp(home: PadScreen(client: c, haptics: false)),
    );
    c.receive(
      j({'v': 1, 't': 'welcome', 'sid': '0123456789abcdef', 'player': 2}),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('game')),
      findsNothing,
      reason: 'no card before the first info',
    );
    c.receive(
      j({
        'v': 1,
        't': 'info',
        'sid': '0123456789abcdef',
        'is': 1,
        'player': 2,
        'game': 'Mario Kart 8 Deluxe',
        'use': 'own',
        'seats': 4,
        'taken': 3,
      }),
    );
    await tester.pump();
    expect(find.text('MARIO KART 8 DELUXE'), findsOneWidget);
    expect(find.text('El juego lee tu mando como Jugador 2'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('lights')),
        matching: find.byType(Container),
      ),
      findsNWidgets(4),
    );
    c.receive(
      j({
        'v': 1,
        't': 'info',
        'sid': '0123456789abcdef',
        'is': 2,
        'player': 2,
        'game': 'Mario Kart 8 Deluxe',
        'use': 'p1',
        'seats': 1,
        'taken': 3,
      }),
    );
    await tester.pump();
    expect(
      find.text('Pantalla de 1 jugador: tu mando también mueve al Jugador 1'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('lights')),
        matching: find.byType(Container),
      ),
      findsNWidgets(2),
      reason: 'at least up to this player',
    );
    c.receive(
      j({
        'v': 1,
        't': 'info',
        'sid': '0123456789abcdef',
        'is': 3,
        'player': 2,
        'game': 'Mario Kart 8 Deluxe',
        'use': 'pause',
        'seats': 4,
        'taken': 3,
      }),
    );
    await tester.pump();
    expect(
      find.text('En pausa: pon la ventana del juego al frente en el Mac'),
      findsOneWidget,
    );
    expect(
      tester.takeException(),
      isNull,
      reason: 'no overflow on an iPhone 14 screen',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
