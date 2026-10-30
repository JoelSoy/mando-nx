// The game's feed on the phone: game rumble, info (with the icon's CRC and size), the roster, the race, the game's keyboard, and the icon, pulled in pieces. Each is taken only
// for the current session and in order (a sequence number; an older or repeated one is dropped). The icon is pulled with a few requests in flight, a piece asked
// again when it does not come within iconRetryMs, and kept by its CRC for the next session.

import 'package:flutter/foundation.dart';

import '../protocol.dart';

mixin GameFeed on ChangeNotifier {
  String? get sessionId; // the client's session
  bool get feedLive; // connected and in front
  int nowMs();
  void sendJson(String s);

  static const iconChunk = 300, iconWindow = 4, iconRetryMs = 400;
  bool gameRumbleEnabled = true;
  void Function(double, double, int) rumbleSink = (i, s, ms) {};
  GameInfo? info;
  Roster? roster;
  RaceInfo? race; // the race this player is in; null in the menus, or a game without race data
  KeyboardRequest?
  keyboard; // the game's keyboard waiting for this phone's text
  Uint8List? icon; // the game's icon (JPEG) once complete
  int? _rumbleSeq, _infoSeq, _rosterSeq, _raceSeq, _answeredKs;
  String? _iconHash; // of icon, or of the one being pulled
  Uint8List? _iconBuf;
  final Map<int, int> _asked = {}; // icon offset → when asked
  final Set<int> _got = {};

  static bool newer(int? last, int seq) {
    if (last == null) return true;
    final d = (seq - last) & 0xffffffff;
    return d != 0 && d < 0x80000000;
  }

  void resetFeed() {
    _rumbleSeq = _infoSeq = _rosterSeq = _raceSeq = null;
    info = null;
    roster = null;
    race = null;
    keyboard = null;
    _asked.clear();
    if (icon == null) _iconHash = null;
  }

  /// A feed message for this session: true when taken.
  bool feed(HostMessage m) {
    switch (m) {
      case Rumble():
        if (m.sid != sessionId ||
            !feedLive ||
            !gameRumbleEnabled ||
            !newer(_rumbleSeq, m.seq)) {
          return false;
        }
        _rumbleSeq = m.seq;
        rumbleSink(m.intensity, m.sharpness, m.ms);
      case GameInfo():
        if (m.sid != sessionId || !newer(_infoSeq, m.seq)) return false;
        _infoSeq = m.seq;
        info = m;
        _wantIcon(m.iconHash, m.iconSize);
      case Roster():
        if (m.sid != sessionId || !newer(_rosterSeq, m.seq)) return false;
        _rosterSeq = m.seq;
        roster = m;
      case RaceInfo():
        if (m.sid != sessionId || !newer(_raceSeq, m.seq)) return false;
        _raceSeq = m.seq;
        race = m.course.isEmpty && !m.racing ? null : m;
      case KeyboardRequest():
        if (m.sid != sessionId) return false;
        if (m.done) {
          if (keyboard?.id != m.id) return false;
          keyboard = null;
        } else {
          if (m.id == _answeredKs || keyboard?.id == m.id) return false;
          keyboard = m;
        }
      case IconPart():
        if (m.sid != sessionId || !_takePiece(m)) return false;
      default:
        return false;
    }
    notifyListeners();
    return true;
  }

  /// The player's text for the game's keyboard (ok false: cancelled); sent twice, as UDP may lose one.
  void answerKeyboard(String text, bool ok) {
    final k = keyboard, sid = sessionId;
    if (k == null || sid == null) return;
    _answeredKs = k.id;
    keyboard = null;
    final msg = encodeText(sid, k.id, text, ok);
    sendJson(msg);
    sendJson(msg);
    notifyListeners();
  }

  void _wantIcon(String? hash, int size) {
    if (hash == null || hash == _iconHash) return;
    _iconHash = hash;
    icon = null;
    _iconBuf = Uint8List(size);
    _asked.clear();
    _got.clear();
    feedTick();
  }

  bool _takePiece(IconPart m) {
    final buf = _iconBuf;
    if (buf == null ||
        m.hash != _iconHash ||
        m.off % iconChunk != 0 ||
        m.off >= buf.length) {
      return false;
    }
    final n = m.bytes.length;
    if (n == 0 ||
        m.off + n > buf.length ||
        (n != iconChunk && m.off + n != buf.length)) {
      return false;
    }
    buf.setRange(m.off, m.off + n, m.bytes);
    _asked.remove(m.off);
    _got.add(m.off);
    if (_got.length >= (buf.length + iconChunk - 1) ~/ iconChunk) {
      icon = buf;
      _iconBuf = null;
    }
    feedTick();
    return true;
  }

  /// Asks for the icon's missing pieces: at most iconWindow in flight, one not answered within iconRetryMs asked again.
  void feedTick() {
    final buf = _iconBuf, sid = sessionId;
    if (buf == null || sid == null || !feedLive) return;
    final now = nowMs();
    _asked.removeWhere((off, at) => now - at >= iconRetryMs);
    for (
      var off = 0;
      off < buf.length && _asked.length < iconWindow;
      off += iconChunk
    ) {
      if (_got.contains(off) || _asked.containsKey(off)) continue;
      _asked[off] = now;
      sendJson(encodeIconRequest(sid, off));
    }
  }
}
