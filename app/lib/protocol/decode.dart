// A datagram from the host → a HostMessage, or null when it is not a valid message of this protocol version.
import 'dart:convert';
import 'dart:typed_data';

import 'encode.dart';
import 'host_messages.dart';

final _sidRe = RegExp(r'^[0-9a-f]{16}$'), _hashRe = RegExp(r'^[0-9a-f]{8}$');
final _courseRe = RegExp(r'^[A-Za-z0-9_]{0,24}$');
final _imageKeyRe = RegExp(r'^[A-Za-z0-9_/]{1,32}$');

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
    case 'race':
      final seq = f.int_('cs', 0, 0xffffffff), crs = f.j['crs'];
      if (sid == null || seq == null || crs is! String) return null;
      if (!_courseRe.hasMatch(crs)) return null;
      final pos = f.int_('pos', 1, 99), lap = f.int_('lap', 1, 99);
      final coins = f.int_('coin', 0, 999);
      final known = pos != null && lap != null && coins != null;
      final drv = f.int_('drv', 0, 63), body = f.int_('body', 0, 63);
      final tire = f.int_('tire', 0, 63), wing = f.int_('wing', 0, 63);
      final kart = drv != null && body != null && tire != null && wing != null;
      final itm = f.int_('itm', -1, 63), itm2 = f.int_('itm2', -1, 63);
      final items = itm != null && itm2 != null;
      return RaceInfo(
        sid,
        seq,
        crs,
        place: known ? pos : null,
        lap: known ? lap : null,
        coins: known ? coins : null,
        driver: kart ? drv : null,
        color: kart ? f.int_('dcl', 0, 63) ?? 0 : 0,
        body: kart ? body : null,
        tires: kart ? tire : null,
        glider: kart ? wing : null,
        item: items ? itm : null,
        item2: items ? itm2 : null,
        pictures: f.j['img'] == 1,
      );
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
    case 'imgpart':
      final key = f.j['im'], size = f.int_('isz', 0, 1 << 20);
      if (sid == null || key is! String || !_imageKeyRe.hasMatch(key)) {
        return null;
      }
      if (size == 0) return ImagePart(sid, key, '', 0, 0, Uint8List(0));
      final off = f.int_('off', 0, 1 << 20), d = f.j['d'], h = f.j['ih'];
      if (size == null ||
          off == null ||
          d is! String ||
          h is! String ||
          !_hashRe.hasMatch(h)) {
        return null;
      }
      try {
        return ImagePart(sid, key, h, size, off, base64Decode(d));
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
