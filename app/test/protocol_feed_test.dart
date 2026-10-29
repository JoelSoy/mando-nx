import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/protocol.dart';

List<int> j(Object o) => utf8.encode(jsonEncode(o));

void main() {
  test('stick normalization: dead zone, rescale, circle, y up', () {
    expect(normalizeStick(0.05, 0.05), (0.0, 0.0));
    expect(normalizeStick(1, 0), (1.0, 0.0));
    expect(normalizeStick(0, 1), (
      0.0,
      -1.0,
    ), reason: 'screen down is stick down');
    expect(normalizeStick(0, -3), (
      0.0,
      1.0,
    ), reason: 'past the rim is a full tilt');
    final (x, y) = normalizeStick(1, -1);
    expect(math.sqrt(x * x + y * y), closeTo(1, 0.002));
    final (hx, _) = normalizeStick(0.56, 0);
    expect(
      hx,
      closeTo(0.5, 0.001),
      reason: 'half way between the dead zone and the rim',
    );
    expect(normalizeStick(double.nan, 0), (0.0, 0.0));
  });

  test('connect screen checks', () {
    expect(validateHost('192.168.1.23'), isNull);
    expect(validateHost('mac-de-ana.local'), isNull);
    expect(validateHost(''), isNotNull);
    expect(validateHost('192.168.1'), isNotNull);
    expect(validateHost('999.1.1.1'), isNotNull);
    expect(validateHost('fe80::1'), isNotNull);
    expect(validateHost('a b'), isNotNull);
    expect(validatePort('47800'), isNull);
    expect(validatePort('0'), isNotNull);
    expect(validatePort('70000'), isNotNull);
    expect(validateCode(' 482 913 '), isNull);
    expect(normalizeCode(' 482 913 '), '482913');
    expect(validateCode('12'), isNotNull);
    expect(validateCode('12-34'), isNotNull);
    expect(sanitizeName(''), 'Teléfono');
    expect(utf8.encode(sanitizeName('é' * 40)).length, lessThanOrEqualTo(32));
    final id = newClientId(math.Random(1));
    expect(validClientId(id), isTrue);
    expect(id.length, 16);
  });

  test(
    'info: the game, what it makes of the player, seats and taken players',
    () {
      final i = decodeHostMessage(
        j({
          'v': 1,
          't': 'info',
          'sid': '0123456789abcdef',
          'is': 4,
          'player': 2,
          'game': 'Mario Kart 8 Deluxe',
          'use': 'own',
          'seats': 4,
          'taken': 7,
        }),
      );
      expect(i, isA<GameInfo>());
      final g = i as GameInfo;
      expect(
        [g.seq, g.player, g.game, g.use, g.seats, g.taken],
        [4, 2, 'Mario Kart 8 Deluxe', PlayerUse.own, 4, 7],
      );
      expect([g.holds(1), g.holds(3), g.holds(4)], [true, true, false]);
      for (final u in ['p1', 'off', 'pause']) {
        expect(
          (decodeHostMessage(
            j({
              'v': 1,
              't': 'info',
              'sid': '0123456789abcdef',
              'is': 1,
              'player': 1,
              'use': u,
              'seats': 1,
              'taken': 1,
            }),
          ) as GameInfo).game,
          '',
          reason: 'no game name: empty',
        );
      }
      for (final bad in [
        {
          'v': 1,
          't': 'info',
          'sid': '0123456789abcdef',
          'is': 1,
          'player': 1,
          'use': 'jump',
          'seats': 1,
          'taken': 1,
        },
        {
          'v': 1,
          't': 'info',
          'sid': '0123456789abcdef',
          'is': 1,
          'player': 9,
          'use': 'own',
          'seats': 1,
          'taken': 1,
        },
        {
          'v': 1,
          't': 'info',
          'sid': '0123456789abcdef',
          'is': 1,
          'player': 1,
          'use': 'own',
          'seats': 0,
          'taken': 1,
        },
        {
          'v': 1,
          't': 'info',
          'sid': '0123456789abcdef',
          'is': 1,
          'player': 1,
          'use': 'own',
          'seats': 4,
          'taken': 256,
        },
        {
          'v': 1,
          't': 'info',
          'sid': '0123456789abcdef',
          'player': 1,
          'use': 'own',
          'seats': 4,
          'taken': 1,
        },
        {
          'v': 1,
          't': 'info',
          'sid': 'nope',
          'is': 1,
          'player': 1,
          'use': 'own',
          'seats': 4,
          'taken': 1,
        },
      ]) {
        expect(decodeHostMessage(j(bad)), isNull, reason: '$bad');
      }
    },
  );
}
