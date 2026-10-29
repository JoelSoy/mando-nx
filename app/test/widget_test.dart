import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/client.dart';
import 'package:remote_pad/main.dart';
import 'package:remote_pad/pad_layout.dart';
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
  testWidgets('connect screen: Spanish labels, checks, remembered settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1704, 786);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('mando');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = SettingsStore(dir);
    String? openedHost;
    int? openedPort;
    final t = FakeTransport();
    await tester.pumpWidget(
      MandoApp(
        store: store,
        haptics: false,
        open: (h, p, onData) async {
          openedHost = h;
          openedPort = p;
          return t;
        },
      ),
    );
    expect(find.text('IP del Mac'), findsOneWidget);
    expect(find.text('Código de emparejamiento'), findsOneWidget);
    await tester.tap(find.byKey(const Key('connect')));
    await tester.pump();
    expect(find.textContaining('Escribe la IP del Mac'), findsOneWidget);
    expect(find.text('Escribe el código que muestra el Mac'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('host')), '192.168.1.23');
    await tester.enterText(find.byKey(const Key('code')), '482 913');
    await tester.enterText(find.byKey(const Key('name')), 'Ana');
    await tester.tap(find.byKey(const Key('connect')));
    await tester.pump();
    await tester.pump();
    expect(openedHost, '192.168.1.23');
    expect(openedPort, defaultPort);
    expect(t.sent.first['t'], 'hello');
    expect(t.sent.first['code'], '482913');
    expect(t.sent.first['name'], 'Ana');
    final saved = store.load();
    expect(
      [saved.host, saved.code, saved.name],
      ['192.168.1.23', '482913', 'Ana'],
    );
    expect(validClientId(saved.clientId), isTrue);
    expect(
      store.load().clientId,
      saved.clientId,
      reason: 'the client id is kept',
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Conectando…'), findsOneWidget);
    await tester.tap(find.byKey(const Key('leave')));
    await tester.pumpAndSettle();
    expect(find.text('IP del Mac'), findsOneWidget);
  });

  testWidgets(
    'pad screen: player shown, two fingers at once reach the state sent',
    (tester) async {
      tester.view.physicalSize = const Size(1704, 786);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final t = FakeTransport();
      var now = 0;
      final c = RemoteClient(
        transport: t,
        code: '482913',
        clientId: 'phoneid123456789',
        name: 'Ana',
        clock: () => now,
      )..start();
      await tester.pumpWidget(
        MaterialApp(home: PadScreen(client: c, haptics: false)),
      );
      c.receive(
        j({'v': 1, 't': 'welcome', 'sid': '0123456789abcdef', 'player': 2}),
      );
      await tester.pump();
      expect(find.text('Jugador 2'), findsOneWidget);
      expect(find.text('Conectado'), findsOneWidget);
      final l = PadLayout.compute(const Size(852, 393));
      final a = l.buttons.firstWhere((b) => b.control == Control.a).center;
      final g1 = await tester.startGesture(a, pointer: 1);
      now += 20;
      final g2 = await tester.startGesture(l.stickHome, pointer: 2);
      now += 20;
      await g2.moveBy(Offset(-l.stickRadius, 0));
      await tester.pump();
      expect(c.state.buttons, Btn.a);
      expect(c.state.lx, -1.0);
      now += 20;
      await tester.pump(const Duration(milliseconds: 40));
      final last = t.sent.lastWhere((m) => m['t'] == 'state');
      expect(last['b'], Btn.a);
      expect(last['lx'], -1.0);
      await g1.up();
      await g2.up();
      await tester.pump();
      expect(c.state, PadState.neutral);
      c.receive(j({'v': 1, 't': 'reject', 'reason': 'code'}));
      c.receive(j({'v': 1, 't': 'kick', 'reason': 'session'}));
      await tester.pump();
      expect(find.text('Reconectando…'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(
        t.sent.where((m) => m['t'] == 'bye'),
        isEmpty,
        reason: 'no session when it closed: nothing to leave',
      );
    },
  );

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
