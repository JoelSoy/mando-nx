import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/client.dart';
import 'package:remote_pad/protocol.dart';

class FakeTransport implements Transport {
  final sent = <Map<String, dynamic>>[];
  bool closed = false;
  @override
  void send(List<int> data) =>
      sent.add(jsonDecode(utf8.decode(data)) as Map<String, dynamic>);
  @override
  void close() => closed = true;
  Iterable<Map<String, dynamic>> of(String t) => sent.where((m) => m['t'] == t);
}

List<int> j(Object o) => utf8.encode(jsonEncode(o));
const sid = '0123456789abcdef', sid2 = 'fedcba9876543210';

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

  test('joins: hello repeated every 500 ms until the welcome', () {
    expect(c.status, LinkStatus.joining);
    expect(t.of('hello').single, containsPair('code', '482913'));
    run(1100);
    expect(t.of('hello').length, 3);
    expect(t.of('state'), isEmpty);
    c.receive(
      j({
        'v': 1,
        't': 'welcome',
        'sid': sid,
        'player': 2,
        'hz': 60,
        'timeout_ms': 5000,
      }),
    );
    expect(c.status, LinkStatus.connected);
    expect(c.player, 2);
    expect(
      t.of('state').single['seq'],
      1,
      reason: 'the first state goes at once',
    );
  });

  test('heartbeat: the whole state about 59 times a second, seq increasing; changes sent at once', () {
    c.receive(j({'v': 1, 't': 'welcome', 'sid': sid, 'player': 2}));
    final first = t.sent.length;
    for (var i = 0; i < 59; i++) {
      now += 17;
      c.tick();
      if (i % 15 == 0) {
        c.receive(
          j({
            'v': 1,
            't': 'ack',
            'sid': sid,
            'seq': 1,
            'player': 2,
            'ms': now - 5,
          }),
        );
      }
    }
    final states = t.of('state').toList();
    expect(t.sent.length - first, 59, reason: 'one per tick: ${1000 ~/ 17} Hz');
    final seqs = states.map((m) => m['seq'] as int).toList();
    for (var i = 1; i < seqs.length; i++) {
      expect(seqs[i], seqs[i - 1] + 1);
    }
    expect(c.rttMs, 5);
    now += 10;
    c.setState(const PadState(buttons: Btn.a, lx: 1));
    expect(t.sent.last['b'], Btn.a);
    expect(t.sent.last['lx'], 1.0);
    final n = t.sent.length;
    now += 2;
    c.setState(const PadState(buttons: Btn.a | Btn.r, lx: 1));
    expect(t.sent.length, n, reason: 'not more often than every 8 ms');
    now += 17;
    c.tick();
    expect(t.sent.last['b'], Btn.a | Btn.r, reason: 'the next tick carries it');
  });

  test('a silent host: reconnecting, states and hellos go on; an ack brings it back', () {
    c.receive(j({'v': 1, 't': 'welcome', 'sid': sid, 'player': 3}));
    run(2100);
    expect(c.status, LinkStatus.reconnecting);
    final hellos = t.of('hello').length;
    run(1100);
    expect(t.of('hello').length, greaterThan(hellos));
    expect(t.sent.last['t'], anyOf('state', 'hello'));
    c.receive(j({'v': 1, 't': 'ack', 'sid': sid, 'seq': 5, 'player': 3}));
    expect(c.status, LinkStatus.connected);
  });

  test('kick: joins again at once and starts a new seq on the new session', () {
    c.receive(j({'v': 1, 't': 'welcome', 'sid': sid, 'player': 2}));
    run(200);
    final hellos = t.of('hello').length;
    c.receive(j({'v': 1, 't': 'kick', 'reason': 'session'}));
    expect(c.status, LinkStatus.reconnecting);
    expect(t.of('hello').length, hellos + 1);
    final before = t.of('state').length;
    run(100);
    expect(
      t.of('state').length,
      before,
      reason: 'no session id: nothing to send',
    );
    c.receive(j({'v': 1, 't': 'welcome', 'sid': sid2, 'player': 2}));
    expect(c.status, LinkStatus.connected);
    expect(t.sent.last['sid'], sid2);
    expect(t.sent.last['seq'], 1);
  });

  test('rejects: a wrong code stops, full waits and tries again', () {
    c.receive(j({'v': 1, 't': 'reject', 'reason': 'code'}));
    expect(c.status, LinkStatus.rejected);
    final n = t.sent.length;
    run(3000);
    expect(t.sent.length, n);

    final t2 = FakeTransport();
    final c2 = RemoteClient(
      transport: t2,
      code: '482913',
      clientId: 'phoneid123456789',
      name: 'Ana',
      clock: () => now,
    )..start();
    c2.receive(j({'v': 1, 't': 'reject', 'reason': 'full'}));
    expect(c2.status, LinkStatus.waiting);
    for (var i = 0; i < 130; i++) {
      now += 17;
      c2.tick();
    }
    expect(t2.of('hello').length, 2, reason: 'one more hello after 2 s');
    c2.receive(j({'v': 1, 't': 'welcome', 'sid': sid, 'player': 4}));
    expect(c2.status, LinkStatus.connected);
  });

  test('a late reject does not end a session that is up', () {
    c.receive(j({'v': 1, 't': 'welcome', 'sid': sid, 'player': 2}));
    c.receive(j({'v': 1, 't': 'reject', 'reason': 'full'}));
    expect(c.status, LinkStatus.connected);
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
