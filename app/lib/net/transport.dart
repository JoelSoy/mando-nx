// Where the datagrams go: a UDP socket towards the Mac on the phone, a fake in tests.
import 'dart:async';
import 'dart:io';

/// Where the datagrams go: a UDP socket on the phone, a fake in tests.
abstract class Transport {
  void send(List<int> data);
  void close();
}

class UdpTransport implements Transport {
  UdpTransport._(this._socket, this._host, this._port);
  final RawDatagramSocket _socket;
  final InternetAddress _host;
  final int _port;
  StreamSubscription<RawSocketEvent>? _sub;

  /// Opens a socket towards host:port (an IPv4 address, or a name resolved to one) and passes each datagram that comes back from there to onData.
  static Future<UdpTransport> open(
    String host,
    int port,
    void Function(List<int>) onData,
  ) async {
    var addr = InternetAddress.tryParse(host.trim());
    if (addr == null) {
      final found = await InternetAddress.lookup(
        host.trim(),
        type: InternetAddressType.IPv4,
      );
      if (found.isEmpty) throw const SocketException('no IPv4 address');
      addr = found.first;
    }
    final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final t = UdpTransport._(s, addr, port);
    t._sub = s.listen((ev) {
      if (ev != RawSocketEvent.read) return;
      Datagram? d;
      while ((d = s.receive()) != null) {
        if (d!.address == t._host && d.port == t._port) onData(d.data);
      }
    });
    return t;
  }

  @override
  void send(List<int> data) {
    try {
      _socket.send(data, _host, _port);
    } on SocketException {
      // no route for now (Wi-Fi off, the phone asleep): the heartbeat tries again
    }
  }

  @override
  void close() {
    _sub?.cancel();
    _socket.close();
  }
}
