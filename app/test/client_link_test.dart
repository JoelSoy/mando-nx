import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/client.dart';
import 'package:remote_pad/protocol.dart';

import 'client_fakes.dart';

void main() {
  late FakeTransport t;
  late RemoteClient c;
  var now = 1000;
  void run(int ms) {
    for (var i = 0; i < ms; i += 17) {
      now += 17;
      c.tick();
    }
  }

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
  });

  test('acks of another session are ignored; malformed datagrams too', () {
    c.receive(j({'v': 1, 't': 'welcome', 'sid': sid, 'player': 2}));
    c.receive(j({'v': 1, 't': 'ack', 'sid': sid2, 'seq': 1, 'player': 7}));
    expect(c.player, 2);
    c.receive(utf8.encode('garbage'));
    expect(c.status, LinkStatus.connected);
  });

  test('pause sends a released state and stops; resume goes on', () {
    c.receive(j({'v': 1, 't': 'welcome', 'sid': sid, 'player': 2}));
    now += 20;
    c.setState(const PadState(buttons: Btn.a));
    c.pause();
    expect(t.sent.last['b'], 0);
    final n = t.sent.length;
    run(500);
    expect(t.sent.length, n);
    c.resume();
    expect(t.sent.length, n + 1);
    expect(c.status, LinkStatus.connected);
  });

  test('the host quits: waits and rejoins when it is back', () {
    c.receive(j({'v': 1, 't': 'welcome', 'sid': sid, 'player': 2}));
    c.receive(j({'v': 1, 't': 'bye', 'reason': 'host'}));
    expect(c.status, LinkStatus.waiting);
    expect(c.hostQuit, isTrue);
    final hellos = t.of('hello').length;
    run(2100);
    expect(t.of('hello').length, greaterThan(hellos));
  });

  test('leave: bye twice, the socket closed, nothing more', () {
    c.receive(j({'v': 1, 't': 'welcome', 'sid': sid, 'player': 2}));
    c.leave();
    expect(t.of('bye').length, 2);
    expect(t.closed, isTrue);
    expect(c.status, LinkStatus.closed);
    final n = t.sent.length;
    run(500);
    expect(t.sent.length, n);
  });

  test('over a real UDP socket on loopback, against a fake host', () async {
    final host = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final got = <Map<String, dynamic>>[];
    RemoteClient? rc;
    host.listen((ev) {
      if (ev != RawSocketEvent.read) return;
      final d = host.receive();
      if (d == null) return;
      final m = jsonDecode(utf8.decode(d.data)) as Map<String, dynamic>;
      got.add(m);
      if (m['t'] == 'hello') {
        host.send(
          j({
            'v': 1,
            't': 'welcome',
            'sid': sid,
            'player': 2,
            'hz': 60,
            'timeout_ms': 5000,
          }),
          d.address,
          d.port,
        );
      }
      if (m['t'] == 'state' && m['seq'] == 1) {
        host.send(
          j({
            'v': 1,
            't': 'ack',
            'sid': sid,
            'seq': 1,
            'player': 2,
            'ms': m['ms'],
          }),
          d.address,
          d.port,
        );
      }
    });
    final ut = await UdpTransport.open(
      '127.0.0.1',
      host.port,
      (d) => rc?.receive(d),
    );
    final watch = Stopwatch()..start();
    rc = RemoteClient(
      transport: ut,
      code: '482913',
      clientId: 'phoneid123456789',
      name: 'Ana',
      clock: () => watch.elapsedMilliseconds,
    )..start();
    for (
      var i = 0;
      i < 100 && (rc.status != LinkStatus.connected || rc.rttMs == null);
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      rc.tick();
    }
    expect(rc.status, LinkStatus.connected);
    expect(rc.player, 2);
    expect(rc.rttMs, isNotNull);
    expect(got.first['t'], 'hello');
    expect(got.where((m) => m['t'] == 'state'), isNotEmpty);
    rc.leave();
    host.close();
  });

  test('info: taken for this session only, in order; cleared when the session ends', () {
    Map<String, Object> info(
      int seq,
      String use, {
      String s = sid,
      int player = 2,
    }) => {
      'v': 1,
      't': 'info',
      'sid': s,
      'is': seq,
      'player': player,
      'game': 'Mario Kart 8 Deluxe',
      'use': use,
      'seats': 4,
      'taken': 3,
    };
    c.receive(j({'v': 1, 't': 'welcome', 'sid': sid, 'player': 2}));
    c.receive(j(info(1, 'own', s: sid2)));
    expect(c.info, isNull, reason: 'another session');
    c.receive(j(info(5, 'own')));
    expect(c.info!.use, PlayerUse.own);
    expect(c.info!.game, 'Mario Kart 8 Deluxe');
    c.receive(j(info(4, 'pause')));
    expect(
      c.info!.use,
      PlayerUse.own,
      reason: 'an older one arriving late is dropped',
    );
    c.receive(j(info(6, 'p1', player: 3)));
    expect([c.info!.use, c.player], [PlayerUse.p1, 3]);
    c.receive(j({'v': 1, 't': 'kick', 'reason': 'session'}));
    expect(c.info, isNull);
    c.receive(j({'v': 1, 't': 'welcome', 'sid': sid2, 'player': 2}));
    c.receive(j(info(1, 'off', s: sid2)));
    expect(
      c.info!.use,
      PlayerUse.off,
      reason: 'a new session counts from its own first info',
    );
    c.leave();
    expect(c.info, isNull);
  });
}
