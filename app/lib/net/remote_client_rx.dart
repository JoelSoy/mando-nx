// What the host's messages do to the session (remote_client.dart): welcome, ack, reject, kick and bye; the rest is the game's feed (game_feed.dart).
part of 'remote_client.dart';

extension _Rx on RemoteClient {
  void _take(HostMessage m) {
    final now = clock();
    switch (m) {
      case Welcome():
        if (status == LinkStatus.rejected) return;
        if (m.sid != _sid) {
          _seq = 0;
          resetFeed();
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
        _notify();
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
        resetFeed();
        _setStatus(LinkStatus.reconnecting);
        _hello();
      case HostBye():
        reason = m.reason;
        if (m.reason == 'host') {
          // the game on the Mac quit: join again by ourselves when it comes back
          hostQuit = true;
          _sid = null;
          player = null;
          resetFeed();
          _setStatus(LinkStatus.waiting);
        }
      case GameInfo():
        if (feed(m) && player != m.player) player = m.player;
      default:
        feed(m);
    }
  }
}
