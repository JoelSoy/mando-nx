// What the player types on the connect screen (messages in Spanish: they are shown as they are), names, client ids.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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

/// At most max UTF-8 bytes of s, never cutting a character.
String cutUtf8(String s, int max) {
  final out = StringBuffer();
  var bytes = 0;
  for (final r in s.runes) {
    final n = utf8.encode(String.fromCharCode(r)).length;
    if (bytes + n > max) break;
    bytes += n;
    out.writeCharCode(r);
  }
  return out.toString();
}

/// A display name the host takes: no control characters or quotes, at most 32 UTF-8 bytes; "Teléfono" when empty.
String sanitizeName(String s) {
  final kept = StringBuffer();
  for (final r in s.trim().runes) {
    if (r < 0x20 ||
        r == 0x7f ||
        (r >= 0x80 && r < 0xa0) ||
        r == 0x22 ||
        r == 0x5c) {
      continue;
    }
    kept.writeCharCode(r);
  }
  final t = cutUtf8(kept.toString(), 32).trim();
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
