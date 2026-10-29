// Wi-Fi controller protocol, version 1 (docs/wifi-controllers.md in the nxnative repository; the host side is dm/host/remote_proto.h).
// One JSON object per UDP datagram, at most 512 bytes. The phone sends hello until it gets a welcome, then its whole state 50-60 times a second.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const int protocolVersion = 1;
const int defaultPort = 47800;
const int maxPacket = 512;

/// Button bits, in nn::hid::NpadButton order (dm/host/dm_input.h).
abstract final class Btn {
  static const int a = 1 << 0, b = 1 << 1, x = 1 << 2, y = 1 << 3;
  static const int ls = 1 << 4, rs = 1 << 5, l = 1 << 6, r = 1 << 7;
  static const int zl = 1 << 8, zr = 1 << 9, plus = 1 << 10, minus = 1 << 11;
  static const int left = 1 << 12,
      up = 1 << 13,
      right = 1 << 14,
      down = 1 << 15;
  static const int all = 0xffff;
}

/// The whole controller state the phone sends: buttons and both sticks, each axis -1..1 with y up.
class PadState {
  const PadState({
    this.buttons = 0,
    this.lx = 0,
    this.ly = 0,
    this.rx = 0,
    this.ry = 0,
  });
  final int buttons;
  final double lx, ly, rx, ry;
  static const neutral = PadState();

  @override
  bool operator ==(Object other) =>
      other is PadState &&
      other.buttons == buttons &&
      other.lx == lx &&
      other.ly == ly &&
      other.rx == rx &&
      other.ry == ry;
  @override
  int get hashCode => Object.hash(buttons, lx, ly, rx, ry);
  @override
  String toString() => 'PadState(b=$buttons, l=($lx, $ly), r=($rx, $ry))';
}

/// A stick from a finger's offset (dx, dy) in units of the stick's radius, screen y down: clamped to the unit circle, a dead zone around the centre, the rest rescaled so
/// the edge of the dead zone is 0 and the rim is a full tilt. Returns (x, y) with y up, rounded to 3 decimals.
(double, double) normalizeStick(
  double dx,
  double dy, {
  double deadZone = 0.12,
}) {
  double x = dx, y = -dy;
  if (!x.isFinite || !y.isFinite) return (0, 0);
  final r = math.sqrt(x * x + y * y);
  if (r <= deadZone) return (0, 0);
  final scaled = (math.min(r, 1.0) - deadZone) / (1 - deadZone);
  x = x / r * scaled;
  y = y / r * scaled;
  double q(double v) => (v * 1000).roundToDouble() / 1000;
  return (q(x), q(y));
}

double _clampAxis(double v) => v.isFinite ? v.clamp(-1.0, 1.0) : 0.0;

String encodeHello({
  required String code,
  required String id,
  required String name,
  bool rumble = false,
}) => jsonEncode({
  'v': protocolVersion,
  't': 'hello',
  'code': code,
  'id': id,
  'name': sanitizeName(name),
  if (rumble) 'rumble': 1,
});

String encodeState({
  required String sid,
  required int seq,
  required PadState state,
  required int ms,
}) => jsonEncode({
  'v': protocolVersion,
  't': 'state',
  'sid': sid,
  'seq': seq & 0xffffffff,
  'b': state.buttons & Btn.all,
  'lx': _clampAxis(state.lx),
  'ly': _clampAxis(state.ly),
  'rx': _clampAxis(state.rx),
  'ry': _clampAxis(state.ry),
  'ms': ms,
});

String encodeBye(String sid) =>
    jsonEncode({'v': protocolVersion, 't': 'bye', 'sid': sid});

sealed class HostMessage {
  const HostMessage();
}

class Rumble extends HostMessage {
  const Rumble(this.sid, this.seq, this.intensity, this.sharpness, this.ms);
  final String sid;
  final int seq, ms;
  final double intensity, sharpness;
}

/// What the game makes of this phone's player: own (the game reads it as a player of its own), p1 (a one-player screen: it feeds player 1, with the others),
/// off (the game takes fewer players now: not used), pause (the game window on the Mac is not in front: released).
enum PlayerUse { own, p1, off, pause }

/// info: the game's name, what it makes of this player, the players it takes now (seats, 1-8) and which players have a controller (taken: bit n, player n + 1).
/// Sent when it changes and renewed every 2 s; seq orders them.
class GameInfo extends HostMessage {
  const GameInfo(
    this.sid,
    this.seq,
    this.player,
    this.game,
    this.use,
    this.seats,
    this.taken,
  );
  final String sid, game;
  final int seq, player, seats, taken;
  final PlayerUse use;
  bool holds(int p) => taken >> (p - 1) & 1 == 1;
}

class Welcome extends HostMessage {
  const Welcome(this.sid, this.player, this.timeoutMs);
  final String sid;
  final int player, timeoutMs;
}

class Reject extends HostMessage {
  const Reject(this.reason);
  final String reason; // code, full, busy, version
}

class Ack extends HostMessage {
  const Ack(this.sid, this.seq, this.player, this.ms);
  final String sid;
  final int seq, player;
  final int? ms;
}

class Kick extends HostMessage {
  const Kick(this.reason);
  final String reason; // session, timeout
}

class HostBye extends HostMessage {
  const HostBye(this.reason);
  final String reason; // left, host
}

final _sidRe = RegExp(r'^[0-9a-f]{16}$');

/// A datagram from the host, or null when it is not a valid message of this protocol version.
HostMessage? decodeHostMessage(List<int> bytes) {
  if (bytes.isEmpty || bytes.length > maxPacket) return null;
  Object? j;
  try {
    j = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    return null;
  }
  if (j is! Map<String, dynamic> || j['v'] != protocolVersion) return null;
  final t = j['t'];
  int? intOf(String k, int lo, int hi) {
    final v = j as Map<String, dynamic>;
    final n = v[k];
    return n is int && n >= lo && n <= hi ? n : null;
  }

  String? sidOf() {
    final s = j as Map<String, dynamic>;
    final v = s['sid'];
    return v is String && _sidRe.hasMatch(v) ? v : null;
  }

  String reason() => j is Map<String, dynamic> && j['reason'] is String
      ? j['reason'] as String
      : '';
  switch (t) {
    case 'rumble':
      final sid = sidOf(),
          seq = intOf('rs', 0, 0xffffffff),
          ms = intOf('ms', 0, 1000);
      final i = j['i'], s = j['s'];
      return sid != null &&
              seq != null &&
              ms != null &&
              i is num &&
              s is num &&
              i.isFinite &&
              s.isFinite &&
              i >= 0 &&
              i <= 1 &&
              s >= 0 &&
              s <= 1
          ? Rumble(sid, seq, i.toDouble(), s.toDouble(), ms)
          : null;
    case 'info':
      final sid = sidOf(),
          seq = intOf('is', 0, 0xffffffff),
          player = intOf('player', 1, 8),
          seats = intOf('seats', 1, 8),
          taken = intOf('taken', 0, 255);
      final game = j['game'], use = j['use'];
      final u = PlayerUse.values.where((v) => v.name == use).firstOrNull;
      return sid != null &&
              seq != null &&
              player != null &&
              seats != null &&
              taken != null &&
              u != null
          ? GameInfo(
              sid,
              seq,
              player,
              game is String && game.length <= 64 ? game.trim() : '',
              u,
              seats,
              taken,
            )
          : null;
    case 'welcome':
      final sid = sidOf(),
          player = intOf('player', 1, 8),
          timeout = intOf('timeout_ms', 100, 600000) ?? 5000;
      return sid != null && player != null
          ? Welcome(sid, player, timeout)
          : null;
    case 'ack':
      final sid = sidOf(),
          seq = intOf('seq', 0, 0xffffffff),
          player = intOf('player', 1, 8);
      return sid != null && seq != null && player != null
          ? Ack(sid, seq, player, intOf('ms', 0, 9007199254740991))
          : null;
    case 'reject':
      return Reject(reason());
    case 'kick':
      return Kick(reason());
    case 'bye':
      return HostBye(reason());
  }
  return null;
}

// ---- What the player types on the connect screen (messages in Spanish: they are shown as they are)

/// The pairing code as typed: spaces dropped. Valid: 4 to 32 letters and digits.
String normalizeCode(String s) => s.replaceAll(RegExp(r'\s'), '');
String? validateCode(String s) {
  final c = normalizeCode(s);
  if (c.isEmpty) return 'Escribe el código que muestra el Mac';
  if (!RegExp(r'^[A-Za-z0-9]{4,32}$').hasMatch(c)) {
    return 'El código tiene de 4 a 32 letras o números';
  }
  return null;
}

String? validateHost(String s) {
  final h = s.trim();
  if (h.isEmpty) return 'Escribe la IP del Mac (por ejemplo 192.168.1.23)';
  final ip = InternetAddress.tryParse(h);
  if (ip != null) {
    return ip.type == InternetAddressType.IPv4
        ? null
        : 'Usa la dirección IPv4 del Mac (por ejemplo 192.168.1.23)';
  }
  if (RegExp(r'^\d+(\.\d+)*$').hasMatch(h)) return 'IP no válida';
  if (h.length > 253 ||
      !RegExp(
        r'^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)*$',
      ).hasMatch(h)) {
    return 'IP o nombre no válido';
  }
  return null;
}

String? validatePort(String s) {
  final p = int.tryParse(s.trim());
  if (p == null || p < 1 || p > 65535) {
    return 'Puerto de 1 a 65535 (normalmente 47800)';
  }
  return null;
}

/// A display name the host takes: no control characters or quotes, at most 32 UTF-8 bytes; "Teléfono" when empty.
String sanitizeName(String s) {
  final out = StringBuffer();
  var bytes = 0;
  for (final r in s.trim().runes) {
    if (r < 0x20 ||
        r == 0x7f ||
        (r >= 0x80 && r < 0xa0) ||
        r == 0x22 ||
        r == 0x5c) {
      continue;
    }
    final n = utf8.encode(String.fromCharCode(r)).length;
    if (bytes + n > 32) break;
    bytes += n;
    out.writeCharCode(r);
  }
  final t = out.toString().trim();
  return t.isEmpty ? 'Teléfono' : t;
}

/// A new client id: 16 random letters and digits, kept for this installation so a rejoining phone gets its player back.
String newClientId([math.Random? rnd]) {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final r = rnd ?? math.Random.secure();
  return List.generate(16, (_) => chars[r.nextInt(chars.length)]).join();
}

bool validClientId(String s) => RegExp(r'^[A-Za-z0-9_-]{8,32}$').hasMatch(s);
