import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/protocol.dart';

List<int> j(Object o) => utf8.encode(jsonEncode(o));

void main() {
  test('button bits follow NpadButton', () {
    expect(
      [
        Btn.a,
        Btn.b,
        Btn.x,
        Btn.y,
        Btn.l,
        Btn.r,
        Btn.zl,
        Btn.zr,
        Btn.plus,
        Btn.minus,
      ],
      [1, 2, 4, 8, 64, 128, 256, 512, 1024, 2048],
    );
    expect([Btn.left, Btn.up, Btn.right, Btn.down], [4096, 8192, 16384, 32768]);
  });

  test('hello, state and bye as the host reads them', () {
    final h = jsonDecode(
      encodeHello(code: '482913', id: 'abcdefgh12345678', name: ' Ana\n"x" '),
    );
    expect(h, {
      'v': 1,
      't': 'hello',
      'code': '482913',
      'id': 'abcdefgh12345678',
      'name': 'Anax',
    });
    final s = jsonDecode(
      encodeState(
        sid: '0123456789abcdef',
        seq: 0x100000001,
        state: const PadState(
          buttons: Btn.a | 0x70000,
          lx: 2,
          ly: -0.5,
          rx: double.nan,
        ),
        ms: 77,
      ),
    );
    expect(s['seq'], 1, reason: 'seq wraps at 32 bits');
    expect(s['b'], Btn.a, reason: 'only the 16 buttons');
    expect(
      [s['lx'], s['ly'], s['rx'], s['ry']],
      [1.0, -0.5, 0.0, 0.0],
      reason: 'axes clamped, NaN is 0',
    );
    expect(s['ms'], 77);
    expect(
      utf8
          .encode(
            encodeState(
              sid: '0123456789abcdef',
              seq: 4294967295,
              state: const PadState(
                buttons: 0xffff,
                lx: -1,
                ly: -1,
                rx: -1,
                ry: -1,
              ),
              ms: 9007199254740991,
            ),
          )
          .length,
      lessThan(maxPacket),
    );
    expect(jsonDecode(encodeBye('0123456789abcdef')), {
      'v': 1,
      't': 'bye',
      'sid': '0123456789abcdef',
    });
  });

  test('host messages are validated', () {
    final w = decodeHostMessage(
      j({
        'v': 1,
        't': 'welcome',
        'sid': '0123456789abcdef',
        'player': 3,
        'hz': 60,
        'timeout_ms': 5000,
      }),
    );
    expect(w, isA<Welcome>());
    expect((w as Welcome).player, 3);
    final a = decodeHostMessage(
      j({
        'v': 1,
        't': 'ack',
        'sid': '0123456789abcdef',
        'seq': 9,
        'player': 2,
        'ms': 120,
      }),
    );
    expect(a, isA<Ack>());
    expect((a as Ack).ms, 120);
    expect(
      (decodeHostMessage(
        j({'v': 1, 't': 'reject', 'reason': 'code'}),
      ) as Reject).reason,
      'code',
    );
    expect(
      (decodeHostMessage(
        j({'v': 1, 't': 'kick', 'reason': 'session'}),
      ) as Kick).reason,
      'session',
    );
    expect(
      (decodeHostMessage(
        j({'v': 1, 't': 'bye', 'reason': 'host'}),
      ) as HostBye).reason,
      'host',
    );
    for (final bad in [
      {'v': 2, 't': 'welcome', 'sid': '0123456789abcdef', 'player': 1},
      {'v': 1, 't': 'welcome', 'sid': 'XYZ', 'player': 1},
      {'v': 1, 't': 'welcome', 'sid': '0123456789abcdef', 'player': 9},
      {'v': 1, 't': 'ack', 'sid': '0123456789abcdef', 'seq': -1, 'player': 1},
      {'v': 1, 't': 'nope'},
    ]) {
      expect(decodeHostMessage(j(bad)), isNull, reason: '$bad');
    }
    expect(decodeHostMessage(utf8.encode('{not json')), isNull);
    expect(decodeHostMessage(utf8.encode('[1,2]')), isNull);
    expect(decodeHostMessage(List.filled(600, 32)), isNull);
    expect(decodeHostMessage([0xff, 0xfe]), isNull);
  });
}
