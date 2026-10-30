// The pictures the host makes from the game's files (host → phone "imgpart"): a course's picture, a character's and an item's icon, by key ("crs/Gu_WaterPark",
// "drv/40/0", "itm/3"; RaceInfo names them). picture(key) gives one once it is here and otherwise puts it in line. One picture is pulled at a time, a few pieces in
// flight, a piece asked again when it does not come within imageRetryMs. A key the host has no picture for, or that gets no answer for imageGiveUpMs (a host
// still making it answers as soon as it can; an older host never does), is not asked again in this session. Pictures are kept by key while the app runs.

import 'package:flutter/foundation.dart';

import '../protocol.dart';
import 'game_feed.dart';

mixin GameImages on GameFeed {
  static const imageChunk = 264,
      imageWindow = 4,
      imageRetryMs = 400,
      imageGiveUpMs = 8000,
      maxImages = 96;
  final Map<String, Uint8List> _pictures = {};
  final Set<String> _missing = {};
  final List<String> _line = [];
  String? _key; // being pulled
  Uint8List? _buf;
  String? _hash;
  int _heard = 0; // when the host last answered for _key (or it was started)
  final Map<int, int> _imgAsked = {}; // offset → when asked
  final Set<int> _imgGot = {};

  /// The picture for key once it is here; null for now (asked for, unless the host has none)
  Uint8List? picture(String? key) {
    if (key == null) return null;
    final p = _pictures[key];
    if (p != null || _missing.contains(key) || key == _key) return p;
    if (!_line.contains(key) && _pictures.length + _line.length < maxImages) {
      _line.add(key);
    }
    return null;
  }

  @override
  void resetFeed() {
    super.resetFeed();
    _missing.clear();
    _line.clear();
    _key = _buf = _hash = null;
  }

  @override
  bool feed(HostMessage m) => m is ImagePart ? _takeImage(m) : super.feed(m);

  @override
  void feedTick() {
    super.feedTick();
    final sid = sessionId;
    if (sid == null || !feedLive) return;
    final now = nowMs();
    if (_key == null) {
      if (_line.isEmpty) return;
      _key = _line.removeAt(0);
      _buf = _hash = null;
      _heard = now;
      _imgAsked.clear();
      _imgGot.clear();
    }
    final key = _key!, buf = _buf;
    if (now - _heard >= imageGiveUpMs) return _done(missing: true);
    _imgAsked.removeWhere((off, at) => now - at >= imageRetryMs);
    final size = buf?.length ?? 1; // before the first piece: ask for offset 0
    for (
      var off = 0;
      off < size && _imgAsked.length < imageWindow;
      off += imageChunk
    ) {
      if (_imgGot.contains(off) || _imgAsked.containsKey(off)) continue;
      _imgAsked[off] = now;
      sendJson(encodeImageRequest(sid, key, off));
    }
  }

  bool _takeImage(ImagePart m) {
    if (m.sid != sessionId || m.key != _key) return false;
    _heard = nowMs();
    if (m.size == 0) {
      _done(missing: true);
      feedTick();
      return true;
    }
    var buf = _buf;
    if (buf == null || m.hash != _hash || buf.length != m.size) {
      buf = _buf = Uint8List(m.size); // the first piece, or the picture changed
      _hash = m.hash;
      _imgAsked.clear();
      _imgGot.clear();
    }
    final n = m.bytes.length;
    if (m.off % imageChunk != 0 ||
        n == 0 ||
        m.off + n > buf.length ||
        (n != imageChunk && m.off + n != buf.length)) {
      return false;
    }
    buf.setRange(m.off, m.off + n, m.bytes);
    _imgAsked.remove(m.off);
    _imgGot.add(m.off);
    if (_imgGot.length >= (buf.length + imageChunk - 1) ~/ imageChunk) {
      _pictures[m.key] = buf;
      _done(missing: false);
    }
    feedTick();
    return true;
  }

  void _done({required bool missing}) {
    if (missing) _missing.add(_key!);
    _key = _buf = _hash = null;
    notifyListeners();
  }
}
