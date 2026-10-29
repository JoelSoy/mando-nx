// The connect screen: the Mac's IP address and port, the pairing code the Mac shows, a name; kept for the next start (storage.dart).
import 'package:flutter/material.dart';

import 'client.dart';
import 'pad_screen.dart';
import 'protocol.dart';
import 'storage.dart';
import 'gamer_theme.dart';
import 'pairing.dart';
import 'scan_screen.dart';
import 'demo.dart';

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
          builder: (_) => PadScreen(client: preview!, haptics: widget.haptics),
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
        builder: (_) => PadScreen(client: client!, haptics: widget.haptics),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label, String hint) => InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      isDense: true,
    );
    return Scaffold(
      body: GridBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.sports_esports_rounded,
                            color: cyan,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'MANDO',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                          const Text(
                            ' NX',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: cyan,
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: () => _connect(demo: true),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Probar mando'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'TU TELÉFONO. TU PRÓXIMA VICTORIA.',
                        style: TextStyle(
                          color: lime,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Conecta con tu Mac en la misma red Wi-Fi. Escanea su QR o introduce los datos de conexión.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              key: const Key('host'),
                              controller: _host,
                              decoration: deco('IP del Mac', '192.168.1.23'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              autocorrect: false,
                              validator: (v) => validateHost(v ?? ''),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              key: const Key('port'),
                              controller: _port,
                              decoration: deco('Puerto', '$defaultPort'),
                              keyboardType: TextInputType.number,
                              validator: (v) => validatePort(v ?? ''),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('code'),
                              controller: _code,
                              decoration: deco(
                                'Código de emparejamiento',
                                '482913',
                              ),
                              autocorrect: false,
                              validator: (v) => validateCode(v ?? ''),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              key: const Key('name'),
                              controller: _name,
                              decoration: deco(
                                'Tu nombre (opcional)',
                                'Teléfono',
                              ),
                              maxLength: 24,
                              buildCounter: (
                                context, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) => null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const Key('connect'),
                        onPressed: _busy ? null : () => _connect(),
                        icon: const Icon(Icons.sports_esports),
                        label: Text(_busy ? 'Conectando…' : 'Conectar'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final pair = await Navigator.push<Pairing>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ScanScreen(),
                            ),
                          );
                          if (pair != null && mounted) {
                            setState(() {
                              _host.text = pair.host;
                              _port.text = '${pair.port}';
                              _code.text = pair.code;
                            });
                          }
                        },
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Escanear QR del Mac'),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          key: const Key('error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
