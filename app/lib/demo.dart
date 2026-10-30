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
              't': 'roster',
              'sid': '0123456789abcdef',
              'rs': 1,
              'n1': 'keyboard',
              'n2': 'Demo',
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
              'rd': 1,
            }),
          ),
        ),
      );
      Future.microtask(
        () => receive(
          utf8.encode(
            jsonEncode({
              'v': 1,
              't': 'race',
              'sid': '0123456789abcdef',
              'cs': 1,
              'crs': 'Gu_WaterPark',
              'pos': 3,
              'lap': 2,
              'coin': 7,
              'drv': 40,
              'body': 15,
              'tire': 20,
              'wing': 0,
              'itm': 3,
              'itm2': -1,
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
