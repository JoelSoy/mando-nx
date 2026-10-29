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
}
