// What the phone sends: hello, its whole state, bye, an answer to the game's keyboard, a request for a piece of the game's icon (docs/protocol.md).
import 'dart:convert';

import 'pad_state.dart';
import 'validate.dart';

const int protocolVersion = 1;
const int defaultPort = 47800;
const int maxPacket = 512;

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
  'lx': clampAxis(state.lx),
  'ly': clampAxis(state.ly),
  'rx': clampAxis(state.rx),
  'ry': clampAxis(state.ry),
  'ms': ms,
});

String encodeBye(String sid) =>
    jsonEncode({'v': protocolVersion, 't': 'bye', 'sid': sid});

/// The text for the game's keyboard request ks (ok false: cancelled), cut to what the host takes: 128 UTF-8 bytes
String encodeText(String sid, int ks, String text, bool ok) => jsonEncode({
  'v': protocolVersion,
  't': 'text',
  'sid': sid,
  'ks': ks & 0xffffffff,
  'text': cutUtf8(text, 128),
  'ok': ok ? 1 : 0,
});

String encodeIconRequest(String sid, int off) =>
    jsonEncode({'v': protocolVersion, 't': 'icon', 'sid': sid, 'off': off});

String encodeImageRequest(String sid, String key, int off) => jsonEncode({
  'v': protocolVersion,
  't': 'img',
  'sid': sid,
  'im': key,
  'off': off,
});
