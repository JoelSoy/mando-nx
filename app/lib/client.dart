// The phone's side of a session: hello until a welcome, then the whole state every tick (the heartbeat), sequence numbers, rejoin after a kick or a silent host.
// No timers of its own: the pad screen calls tick() about 60 times a second (17 ms) with the clock in ms, so tests drive it with a fake clock and a fake transport.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'protocol.dart';

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

enum LinkStatus {
  joining, // hello sent, no answer yet
  connected, // a player, the host answering
  reconnecting, // the host went quiet or forgot the session: joining again, the stream keeps going
  waiting, // every player is taken (full) or the host asked to wait (busy): trying again now and then
  rejected, // wrong code or another protocol version: stopped
  closed, // left
}

class RemoteClient extends ChangeNotifier {
  RemoteClient({
    required this.transport,
    required this.code,
    required this.clientId,
    required this.name,
    required this.clock,
  });
  final Transport transport;
  final String code, clientId, name;
  final int Function() clock; // ms, monotonic

  static const int helloEveryMs = 500,
      waitEveryMs = 2000,
      quietMs = 2000,
      minGapMs = 8;

  LinkStatus status = LinkStatus.joining;
  int? player;
  String reason = ''; // the host's reason for the last reject / kick / bye
  int? rttMs;
  bool hostQuit = false;
  bool isDemo = false;
  bool gameRumbleEnabled = true;
  void Function(double, double, int) rumbleSink = (i, s, ms) {};
  int? _rumbleSeq;
  GameInfo? info; // the host's latest info for this session (null until the first, or after the session ended)
  int? _infoSeq;
  void setGameRumble(bool on) {
    gameRumbleEnabled = on;
    if (!on) rumbleSink(0, 0, 0);
    _hello();
  }

  int sentStates = 0;

  String? _sid;
  int _seq = 0,
      _lastHello = -1 << 40,
      _lastRx = 0,
      _lastSend = -1 << 40,
      _started = 0;
  bool _paused = false;
  PadState _state = PadState.neutral;
  PadState get state => _state;
  String? get sessionId => _sid;
  int get sinceStartMs => clock() - _started;

  void start() {
    _started = clock();
    _setStatus(LinkStatus.joining);
    _hello();
  }

  /// The pad changed: sent at once (not more often than every 8 ms; the next tick sends the rest).
  void setState(PadState s) {
    if (s == _state) return;
    _state = s;
    if (_sid != null && !_paused && clock() - _lastSend >= minGapMs) {
      _sendState();
    }
  }

  /// About every 17 ms.
  void tick() {
    if (status == LinkStatus.closed ||
        status == LinkStatus.rejected ||
        _paused) {
      return;
    }
    final now = clock();
    switch (status) {
      case LinkStatus.joining:
        if (now - _lastHello >= helloEveryMs) _hello();
      case LinkStatus.waiting:
        if (now - _lastHello >= waitEveryMs) _hello();
      case LinkStatus.reconnecting:
        if (_sid != null) _sendState();
        if (now - _lastHello >= helloEveryMs * 2) _hello();
      case LinkStatus.connected:
        _sendState();
        if (now - _lastRx > quietMs) _setStatus(LinkStatus.reconnecting);
      case LinkStatus.rejected:
      case LinkStatus.closed:
        break;
    }
  }

  void receive(List<int> data) {
    if (status == LinkStatus.closed) return;
    final m = decodeHostMessage(data);
    if (m == null) return;
    final now = clock();
    switch (m) {
      case Rumble():
        if (m.sid != _sid ||
            _paused ||
            !gameRumbleEnabled ||
            status != LinkStatus.connected) {
          return;
        }
        final diff = _rumbleSeq == null
            ? 1
            : (m.seq - _rumbleSeq!) & 0xffffffff;
        if (diff == 0 || diff >= 0x80000000) return;
        _rumbleSeq = m.seq;
        rumbleSink(m.intensity, m.sharpness, m.ms);
      case GameInfo():
        if (m.sid != _sid) return;
        if (_infoSeq != null) {
          final diff = (m.seq - _infoSeq!) & 0xffffffff;
          if (diff == 0 || diff >= 0x80000000) return; // late or repeated
        }
        _infoSeq = m.seq;
        info = m;
        player = m.player;
        notifyListeners();
      case Welcome():
        if (status == LinkStatus.rejected) return;
        if (m.sid != _sid) {
          _seq = 0;
          _rumbleSeq = null;
          _infoSeq = null;
          rumbleSink(0, 0, 0);
        }
        _sid = m.sid;
        player = m.player;
        _lastRx = now;
        hostQuit = false;
        _setStatus(LinkStatus.connected);
        if (!_paused) _sendState();
      case Ack():
        if (m.sid != _sid) return;
        _lastRx = now;
        player = m.player;
        if (m.ms != null && m.ms! <= now) rttMs = now - m.ms!;
        if (status != LinkStatus.connected) _setStatus(LinkStatus.connected);
        notifyListeners();
      case Reject():
        reason = m.reason;
        if (status == LinkStatus.connected && _sid != null) {
          return; // a late answer to an old hello
        }
        _setStatus(
          m.reason == 'full' || m.reason == 'busy'
              ? LinkStatus.waiting
              : LinkStatus.rejected,
        );
      case Kick():
        reason = m.reason;
        _sid = null;
        info = null;
        _setStatus(LinkStatus.reconnecting);
        _hello();
      case HostBye():
        reason = m.reason;
        if (m.reason == 'host') {
          // the game on the Mac quit: join again by ourselves when it comes back
          hostQuit = true;
          _sid = null;
          player = null;
          info = null;
          _setStatus(LinkStatus.waiting);
        }
    }
  }

  /// The app went to the background: a released state first, so nothing stays pressed; nothing more until resume.
  void pause() {
    rumbleSink(0, 0, 0);
    if (_paused) return;
    _state = PadState.neutral;
    if (_sid != null) _sendState();
    _paused = true;
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    _lastRx = clock(); // the host's acks were not read meanwhile
    tick();
  }

  /// Leaves: bye (sent twice, UDP may lose one), then the socket is closed.
  void leave() {
    rumbleSink(0, 0, 0);
    if (status == LinkStatus.closed) return;
    final sid = _sid;
    if (sid != null) {
      final bye = _utf8(encodeBye(sid));
      transport.send(bye);
      transport.send(bye);
    }
    _sid = null;
    info = null;
    _setStatus(LinkStatus.closed);
    transport.close();
  }

  void _hello() {
    _lastHello = clock();
    transport.send(
      _utf8(
        encodeHello(
          code: code,
          id: clientId,
          name: name,
          rumble: gameRumbleEnabled,
        ),
      ),
    );
  }

  void _sendState() {
    final sid = _sid;
    if (sid == null) return;
    _seq = (_seq + 1) & 0xffffffff;
    _lastSend = clock();
    sentStates++;
    transport.send(
      _utf8(encodeState(sid: sid, seq: _seq, state: _state, ms: _lastSend)),
    );
  }

  void _setStatus(LinkStatus s) {
    if (status == s) return;
    status = s;
    notifyListeners();
  }
}

List<int> _utf8(String s) => utf8.encode(s);
