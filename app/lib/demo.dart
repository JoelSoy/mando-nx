import 'dart:convert';

import 'client.dart';

class DemoTransport implements Transport {
  DemoTransport(this.receive);
  final void Function(List<int>) receive;
  @override
  void close() {}
  @override
  void send(List<int> bytes) {
    final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (j['t'] == 'hello') {
      Future.microtask(
        () => receive(
          utf8.encode(
            jsonEncode({
              'v': 1,
              't': 'welcome',
              'sid': '0123456789abcdef',
              'player': 2,
            }),
          ),
        ),
      );
      Future.microtask(
        () => receive(
          utf8.encode(
            jsonEncode({
              'v': 1,
              't': 'info',
              'sid': '0123456789abcdef',
              'is': 1,
              'player': 2,
              'game': 'Juego de demostración',
              'use': 'own',
              'seats': 4,
              'taken': 3,
            }),
          ),
        ),
      );
    } else if (j['t'] == 'state') {
      Future.microtask(
        () => receive(
          utf8.encode(
            jsonEncode({
              'v': 1,
              't': 'ack',
              'sid': '0123456789abcdef',
              'player': 2,
              'seq': j['seq'],
              'ms': j['ms'],
            }),
          ),
        ),
      );
    }
  }
}
