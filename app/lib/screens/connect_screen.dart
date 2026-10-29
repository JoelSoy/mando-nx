// The connect screen: the Mac's IP address and port, the pairing code the Mac shows, a name; kept for the next start (storage.dart).
import 'package:flutter/material.dart';

import '../client.dart';
import '../pad_screen.dart';
import '../protocol.dart';
import '../storage.dart';
import '../demo.dart';
import 'connect_form.dart';

typedef TransportOpener = Future<Transport> Function(
  String host,
  int port,
  void Function(List<int>) onData,
);

Future<Transport> openUdp(
  String host,
  int port,
  void Function(List<int>) onData,
) => UdpTransport.open(host, port, onData);

final Stopwatch _watch = Stopwatch()..start();
int monotonicMs() => _watch.elapsedMilliseconds;

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({
    super.key,
    required this.store,
    this.open = openUdp,
    this.haptics = true,
    this.demo = false,
  });
  final SettingsStore store;
  final TransportOpener open;
  final bool haptics;
  final bool demo;
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _form = GlobalKey<FormState>();
  late final Settings _s = widget.store.load();
  late final _host = TextEditingController(text: _s.host);
  late final _port = TextEditingController(text: '${_s.port}');
  late final _code = TextEditingController(text: _s.code);
  late final _name = TextEditingController(text: _s.name);
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.demo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _connect(demo: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_host, _port, _code, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _connect({bool demo = false}) async {
    if (_busy || (!demo && !(_form.currentState?.validate() ?? false))) return;
    if (demo) {
      RemoteClient? preview;
      final wire = DemoTransport((d) => preview?.receive(d));
      preview = RemoteClient(
        transport: wire,
        code: 'DEMO',
        clientId: 'preview12345678',
        name: 'Demo',
        clock: monotonicMs,
      )..isDemo = true;
      preview.start();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PadScreen(
            client: preview!,
            haptics: widget.haptics,
            prefs: _s.pad,
            onPrefsChanged: () => widget.store.save(_s),
          ),
        ),
      );
      return;
    }
    _s
      ..host = _host.text.trim()
      ..port = int.parse(_port.text.trim())
      ..code = normalizeCode(_code.text)
      ..name = _name.text.trim();
    widget.store.save(_s);
    setState(() {
      _busy = true;
      _error = null;
    });
    RemoteClient? client;
    try {
      final t = demo
          ? DemoTransport((d) => client?.receive(d))
          : await widget.open(_s.host, _s.port, (d) => client?.receive(d));
      client = RemoteClient(
        transport: t,
        code: _s.code,
        clientId: _s.clientId,
        name: sanitizeName(_s.name),
        clock: monotonicMs,
      )..isDemo = demo;
      client.start();
    } on Object catch (e) {
      setState(() {
        _busy = false;
        _error = 'No se pudo abrir la conexión con ${_s.host}: $e';
      });
      return;
    }
    if (!mounted) {
      client.leave();
      return;
    }
    setState(() => _busy = false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PadScreen(
          client: client!,
          haptics: widget.haptics,
          prefs: _s.pad,
          onPrefsChanged: () => widget.store.save(_s),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ConnectForm(
    formKey: _form,
    host: _host,
    port: _port,
    code: _code,
    name: _name,
    busy: _busy,
    error: _error,
    onConnect: () => _connect(),
    onDemo: () => _connect(demo: true),
    onScanned: setState,
  );
}
