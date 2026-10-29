import 'dart:io';

import 'protocol.dart';

class Pairing {
  const Pairing(this.host, this.port, this.code);
  final String host, code;
  final int port;
  static Pairing? parse(String raw) {
    if (raw.length > 512) return null;
    final u = Uri.tryParse(raw);
    if (u == null ||
        u.scheme != 'nxmando' ||
        u.host != 'pair' ||
        u.path.isNotEmpty ||
        u.fragment.isNotEmpty ||
        u.userInfo.isNotEmpty) {
      return null;
    }
    final q = u.queryParametersAll;
    if (q.length != 4 ||
        q.values.any((v) => v.length != 1) ||
        q['v']?.single != '1') {
      return null;
    }
    final h = q['host']?.single ?? '',
        p = q['port']?.single ?? '',
        c = q['code']?.single ?? '';
    final ip = InternetAddress.tryParse(h);
    if (ip == null ||
        ip.type != InternetAddressType.IPv4 ||
        h == '0.0.0.0' ||
        validatePort(p) != null ||
        validateCode(c) != null) {
      return null;
    }
    return Pairing(h, int.parse(p), c);
  }
}
