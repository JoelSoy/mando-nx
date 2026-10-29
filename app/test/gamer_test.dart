import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/pairing.dart';
import 'package:remote_pad/motion/steering.dart';
import 'package:remote_pad/client.dart';

class Wire implements Transport {
  @override
  void close() {}
  @override
  void send(List<int> data) {}
}

void main() {
  test(
    'QR accepts only versioned Mando IPv4 payload without duplicate keys',
    () {
      const good = 'nxmando://pair?v=1&host=192.168.1.3&port=47800&code=ABC123';
      expect(Pairing.parse(good)?.host, '192.168.1.3');
      for (final s in [
        good.replaceFirst('nxmando', 'https'),
        '$good&v=1',
        '$good&evil=1',
        good.replaceFirst('192.168.1.3', '0.0.0.0'),
        good.replaceFirst('47800', '99999'),
        good.replaceFirst('v=1', 'v=2'),
        '$good#x',
      ]) {
        expect(Pairing.parse(s), isNull, reason: s);
      }
    },
  );
  test(
    'tilt is calibrated, bounded, filtered, ignores invalid sensor and centres',
    () {
      final t = Steering();
      expect(t.accel(0, 0, 9.8), 0);
      for (var i = 0; i < 20; i++) {
        t.accel(0, 9.8, 0);
      }
      expect(t.accel(0, 9.8, 0), greaterThan(.9));
      t.calibrate();
      expect(t.accel(0, 9.8, 0), 0);
      expect(t.accel(double.nan, 0, 0), 0);
      t.reset();
      expect(t.accel(0, 9.8, 0), 0);
    },
  );
  test('rumble validates session and sequence; pause stops output', () {
    final c = RemoteClient(
      transport: Wire(),
      code: '123456',
      clientId: 'abcdefgh1234',
      name: 'Phone',
      clock: () => 0,
    );
    final output = <double>[];
    c.rumbleSink = (i, s, ms) => output.add(i);
    c.start();
    void rx(Map<String, Object> j) =>
        c.receive(utf8.encode(jsonEncode({'v': 1, ...j})));
    rx({'t': 'welcome', 'sid': '0123456789abcdef', 'player': 2});
    output.clear();
    Map<String, Object> packet(int seq) => {
      't': 'rumble',
      'sid': '0123456789abcdef',
      'rs': seq,
      'i': .8,
      's': .3,
      'ms': 150,
    };
    rx(packet(2));
    rx(packet(1));
    rx(packet(2));
    expect(output, [.8]);
    rx({...packet(3), 'sid': 'abcdef0123456789'});
    expect(output.length, 1);
    rx({...packet(3), 'ms': 999999});
    expect(output.length, 1);
    c.pause();
    expect(output.last, 0);
    rx(packet(3));
    expect(output.length, 2);
    c.leave();
  });
}
