import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/client.dart';
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
    c.receive(j({'v': 1, 't': 'welcome', 'sid': sid, 'player': 2}));
  });
  Map<String, Object> info(int seq, {String? ih, int isz = 0, int rd = 0}) => {
    'v': 1,
    't': 'info',
    'sid': sid,
    'is': seq,
    'player': 2,
    'game': 'Mario Kart 8 Deluxe',
    'use': 'own',
    'seats': 4,
    'taken': 3,
    'rd': rd,
    'ih': ?ih,
    'isz': isz,
  };

  test('roster: for this session, in order', () {
    c.receive(j({'v': 1, 't': 'roster', 'sid': sid2, 'rs': 1, 'n1': 'x'}));
    expect(c.roster, isNull);
    c.receive(
      j({
        'v': 1,
        't': 'roster',
        'sid': sid,
        'rs': 2,
        'n1': 'keyboard',
        'n2': 'Ana',
        'n4': 'Pro Controller',
      }),
    );
    expect(c.roster!.names, {1: 'keyboard', 2: 'Ana', 4: 'Pro Controller'});
    c.receive(j({'v': 1, 't': 'roster', 'sid': sid, 'rs': 1, 'n1': 'old'}));
    expect(c.roster!.names[1], 'keyboard', reason: 'an older one is dropped');
  });

  test('info: the game reads this controller', () {
    c.receive(j(info(1, rd: 1)));
    expect(c.info!.reading, isTrue);
    c.receive(j(info(2)));
    expect(c.info!.reading, isFalse);
  });

  test('keyboard: shown once, answered (twice on the wire), a late repeat is not shown again; done closes it', () {
    c.receive(
      j({
        'v': 1,
        't': 'kbd',
        'sid': sid,
        'ks': 4,
        'max': 10,
        'title': 'Nombre',
        'init': 'Ana',
      }),
    );
    expect(
      [c.keyboard!.id, c.keyboard!.max, c.keyboard!.title, c.keyboard!.initial],
      [4, 10, 'Nombre', 'Ana'],
    );
    c.answerKeyboard('Joel', true);
    expect(c.keyboard, isNull);
    final sent = t.of('text').toList();
    expect(sent.length, 2);
    expect(sent.first, containsPair('ks', 4));
    expect(sent.first, containsPair('text', 'Joel'));
    expect(sent.first, containsPair('ok', 1));
    c.receive(j({'v': 1, 't': 'kbd', 'sid': sid, 'ks': 4, 'title': 'Nombre'}));
    expect(
      c.keyboard,
      isNull,
      reason: 'the host asks again before it heard the answer',
    );
    c.receive(j({'v': 1, 't': 'kbd', 'sid': sid, 'ks': 5, 'title': 'Otro'}));
    expect(c.keyboard!.id, 5);
    c.receive(j({'v': 1, 't': 'kbd', 'sid': sid, 'ks': 5, 'done': 1}));
    expect(
      c.keyboard,
      isNull,
      reason: 'answered on the Mac or by another phone',
    );
    c.answerKeyboard('late', true);
    expect(t.of('text').length, 2, reason: 'nothing to answer');
  });

  test('icon: pulled in pieces, a few at a time, asked again when lost, kept by its CRC', () {
    final icon = List<int>.generate(700, (i) => i * 7 & 255);
    Map<String, Object> part(int off, {String ih = 'cafe0001'}) => {
      'v': 1,
      't': 'iconpart',
      'sid': sid,
      'ih': ih,
      'off': off,
      'd': base64Encode(icon.sublist(off, off + 300 > 700 ? 700 : off + 300)),
    };
    c.receive(j(info(1, ih: 'cafe0001', isz: 700)));
    expect(t.of('icon').map((m) => m['off']), [
      0,
      300,
      600,
    ], reason: 'three pieces, all asked at once (window of four)');
    c.receive(j(part(300)));
    c.receive(j(part(0, ih: 'beef0002')));
    expect(c.icon, isNull, reason: 'a piece of another icon is not taken');
    now += 450;
    c.tick();
    expect(t.of('icon').map((m) => m['off']).skip(3), [
      0,
      600,
    ], reason: 'the lost ones asked again');
    c.receive(j(part(0)));
    c.receive(j(part(600)));
    expect(c.icon, icon);
    final asked = t.of('icon').length;
    c.receive(j({'v': 1, 't': 'kick', 'reason': 'session'}));
    c.receive(j({'v': 1, 't': 'welcome', 'sid': sid2, 'player': 2}));
    c.receive(j({...info(1, ih: 'cafe0001', isz: 700), 'sid': sid2}));
    expect(
      t.of('icon').length,
      asked,
      reason: 'the same icon is not pulled again',
    );
    expect(c.icon, icon);
  });

  test('decoding the feed: bad pieces and fields are refused', () {
    for (final bad in [
      {'v': 1, 't': 'iconpart', 'sid': sid, 'ih': 'xyz', 'off': 0, 'd': 'AAAA'},
      {
        'v': 1,
        't': 'iconpart',
        'sid': sid,
        'ih': 'cafe0001',
        'off': 0,
        'd': '***',
      },
      {'v': 1, 't': 'kbd', 'sid': sid},
      {'v': 1, 't': 'roster', 'sid': sid},
    ]) {
      expect(decodeHostMessage(j(bad)), isNull, reason: '$bad');
    }
    final i =
        decodeHostMessage(j(info(1, ih: '00000000', isz: 10))) as GameInfo;
    expect(i.iconHash, isNull, reason: 'no icon');
  });
}
