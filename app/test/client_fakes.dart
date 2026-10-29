// The client tests' fakes (client_test.dart, client_link_test.dart): a transport that keeps what was sent, a JSON datagram, two session ids.
import 'dart:convert';

import 'package:remote_pad/client.dart';

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
