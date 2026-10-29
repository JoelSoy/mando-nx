// The phone's side of a session: hello until a welcome, then the whole state every tick (the heartbeat), sequence numbers, rejoin after a kick or a silent host.
// No timers of its own: the pad screen calls tick() about 60 times a second (17 ms) with the clock in ms, so tests drive it with a fake clock and a fake transport.
// The game's feed (rumble, info, roster, keyboard, icon) is game_feed.dart.
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../protocol.dart';
import 'game_feed.dart';
import 'transport.dart';

part 'remote_client_rx.dart';

enum LinkStatus {
  joining, // hello sent, no answer yet
  connected, // a player, the host answering
  reconnecting, // the host went quiet or forgot the session: joining again, the stream keeps going
  waiting, // every player is taken (full) or the host asked to wait (busy): trying again now and then
  rejected, // wrong code or another protocol version: stopped
  closed, // left
}

class RemoteClient extends ChangeNotifier with GameFeed {
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
  @override
  String? get sessionId => _sid;
  @override
  bool get feedLive => status == LinkStatus.connected && !_paused;
  @override
  int nowMs() => clock();
  @override
  void sendJson(String s) => transport.send(utf8.encode(s));
  int get sinceStartMs => clock() - _started;

  void setGameRumble(bool on) {
    gameRumbleEnabled = on;
    if (!on) rumbleSink(0, 0, 0);
    _hello();
  }

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
        feedTick();
        if (now - _lastRx > quietMs) _setStatus(LinkStatus.reconnecting);
      case LinkStatus.rejected:
      case LinkStatus.closed:
        break;
    }
  }

  void receive(List<int> data) {
    if (status == LinkStatus.closed) return;
    final m = decodeHostMessage(data);
    if (m != null) _take(m);
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
      sendJson(encodeBye(sid));
      sendJson(encodeBye(sid));
    }
    _sid = null;
    resetFeed();
    _setStatus(LinkStatus.closed);
    transport.close();
  }

  void _hello() {
    _lastHello = clock();
    sendJson(
      encodeHello(
        code: code,
        id: clientId,
        name: name,
        rumble: gameRumbleEnabled,
      ),
    );
  }

  void _sendState() {
    final sid = _sid;
    if (sid == null) return;
    _seq = (_seq + 1) & 0xffffffff;
    _lastSend = clock();
    sentStates++;
    sendJson(encodeState(sid: sid, seq: _seq, state: _state, ms: _lastSend));
  }

  void _notify() => notifyListeners();

  void _setStatus(LinkStatus s) {
    if (status == s) return;
    status = s;
    notifyListeners();
  }
}
