// A datagram from the host → a HostMessage, or null when it is not a valid message of this protocol version.
import 'dart:convert';

import 'encode.dart';
import 'host_messages.dart';

final _sidRe = RegExp(r'^[0-9a-f]{16}$'), _hashRe = RegExp(r'^[0-9a-f]{8}$');

HostMessage? decodeHostMessage(List<int> bytes) {
  if (bytes.isEmpty || bytes.length > maxPacket) return null;
  Object? j;
  try {
    j = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    return null;
  }
  if (j is! Map<String, dynamic> || j['v'] != protocolVersion) return null;
  return _decode(_Fields(j));
}

class _Fields {
  _Fields(this.j);
  final Map<String, dynamic> j;
  int? int_(String k, int lo, int hi) {
    final n = j[k];
    return n is int && n >= lo && n <= hi ? n : null;
  }

  double? unit(String k) {
    final n = j[k];
    return n is num && n.isFinite && n >= 0 && n <= 1 ? n.toDouble() : null;
  }

  String? sid() =>
      j['sid'] is String && _sidRe.hasMatch(j['sid']) ? j['sid'] : null;
  String str(String k, int max) =>
      j[k] is String && (j[k] as String).length <= max
      ? (j[k] as String).trim()
      : '';
  String reason() => j['reason'] is String ? j['reason'] as String : '';
}

HostMessage? _decode(_Fields f) {
  final sid = f.sid();
  switch (f.j['t']) {
    case 'welcome':
      final player = f.int_('player', 1, 8);
      return sid != null && player != null
          ? Welcome(sid, player, f.int_('timeout_ms', 100, 600000) ?? 5000)
          : null;
    case 'ack':
      final seq = f.int_('seq', 0, 0xffffffff), player = f.int_('player', 1, 8);
      return sid != null && seq != null && player != null
          ? Ack(sid, seq, player, f.int_('ms', 0, 9007199254740991))
          : null;
    case 'reject':
      return Reject(f.reason());
    case 'kick':
      return Kick(f.reason());
    case 'bye':
      return HostBye(f.reason());
    case 'rumble':
      final seq = f.int_('rs', 0, 0xffffffff), ms = f.int_('ms', 0, 1000);
      final i = f.unit('i'), s = f.unit('s');
      return sid != null && seq != null && ms != null && i != null && s != null
          ? Rumble(sid, seq, i, s, ms)
          : null;
    case 'info':
      return sid == null ? null : _info(f, sid);
    case 'roster':
      final seq = f.int_('rs', 0, 0xffffffff);
      if (sid == null || seq == null) return null;
      return Roster(sid, seq, {
        for (var p = 1; p <= 8; p++)
          if (f.str('n$p', 32).isNotEmpty) p: f.str('n$p', 32),
      });
    case 'kbd':
      final id = f.int_('ks', 0, 0xffffffff);
      if (sid == null || id == null) return null;
      return KeyboardRequest(
        sid,
        id,
        done: f.j['done'] == 1,
        max: f.int_('max', 1, 500) ?? 32,
        title: f.str('title', 64),
        initial: f.str('init', 160),
      );
    case 'iconpart':
      final off = f.int_('off', 0, 1 << 24), d = f.j['d'], h = f.j['ih'];
      if (sid == null ||
          off == null ||
          d is! String ||
          h is! String ||
          !_hashRe.hasMatch(h)) {
        return null;
      }
      try {
        return IconPart(sid, h, off, base64Decode(d));
      } on FormatException {
        return null;
      }
  }
  return null;
}

GameInfo? _info(_Fields f, String sid) {
  final seq = f.int_('is', 0, 0xffffffff),
      player = f.int_('player', 1, 8),
      seats = f.int_('seats', 1, 8),
      taken = f.int_('taken', 0, 255);
  final use = PlayerUse.values.where((v) => v.name == f.j['use']).firstOrNull;
  if (seq == null ||
      player == null ||
      seats == null ||
      taken == null ||
      use == null) {
    return null;
  }
  final ih = f.j['ih'], isz = f.int_('isz', 0, 1 << 20) ?? 0;
  final hash =
      ih is String && _hashRe.hasMatch(ih) && ih != '00000000' && isz > 0
      ? ih
      : null;
  return GameInfo(
    sid,
    seq,
    player,
    f.j['game'] is String && (f.j['game'] as String).length <= 64
        ? (f.j['game'] as String).trim()
        : '',
    use,
    seats,
    taken,
    reading: f.j['rd'] == 1,
    iconHash: hash,
    iconSize: hash == null ? 0 : isz,
  );
}
