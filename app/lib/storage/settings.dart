// What the app remembers (the Mac's address, port, code, name; the pad's layout, the player's saved layouts, tilt, sensitivity and vibration) and this installation's
// client id, as a small JSON file in the app's own storage. No plugin:
// iOS gives the app a HOME of its own (its sandbox: Library/Application Support is kept and backed up); Android's temporary folder is the app's cache folder, whose parent is
// the app's private data folder (files/ beside it is kept). When neither is found the settings live only as long as the app runs.
import 'dart:convert';
import 'dart:io';

import '../protocol.dart';
import 'pad_prefs.dart';

class Settings {
  Settings({
    this.host = '',
    this.port = defaultPort,
    this.code = '',
    this.name = '',
    String? clientId,
    PadPrefs? pad,
  }) : clientId = clientId ?? newClientId(),
       pad = pad ?? PadPrefs();
  String host, code, name;
  int port;
  final String clientId;
  final PadPrefs pad;

  Map<String, Object> toJson() => {
    'host': host,
    'port': port,
    'code': code,
    'name': name,
    'id': clientId,
    'pad': pad.toJson(),
  };
  factory Settings.fromJson(Object? j) {
    if (j is! Map<String, dynamic>) return Settings();
    String str(String k, int max) =>
        j[k] is String && (j[k] as String).length <= max ? j[k] as String : '';
    final port = j['port'] is int && validatePort('${j['port']}') == null
        ? j['port'] as int
        : defaultPort;
    final id = str('id', 32);
    return Settings(
      host: str('host', 253),
      port: port,
      code: str('code', 32),
      name: str('name', 64),
      clientId: validClientId(id) ? id : null,
      pad: PadPrefs.fromJson(j['pad']),
    );
  }
}

class SettingsStore {
  SettingsStore(this.dir);
  final Directory? dir;
  static const fileName = 'nxnative_mando.json';

  static Directory? platformDir() {
    try {
      Directory? d;
      if (Platform.isIOS || Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          d = Directory('$home/Library/Application Support');
        }
      } else if (Platform.isAndroid) {
        d = Directory('${Directory.systemTemp.parent.path}/files');
      }
      if (d == null) return null;
      d.createSync(recursive: true);
      return d;
    } on Object {
      return null;
    }
  }

  File? get _file => dir == null ? null : File('${dir!.path}/$fileName');

  Settings load() {
    try {
      final f = _file;
      if (f != null && f.existsSync() && f.lengthSync() < 65536) {
        return Settings.fromJson(jsonDecode(f.readAsStringSync()));
      }
    } on Object {
      // unreadable or not JSON: the defaults, written again on the next save
    }
    return Settings();
  }

  void save(Settings s) {
    try {
      final f = _file;
      if (f == null) return;
      final tmp = File('${f.path}.tmp');
      tmp.writeAsStringSync(jsonEncode(s.toJson()), flush: true);
      tmp.renameSync(f.path);
    } on Object {
      // not kept: the app still works
    }
  }
}
