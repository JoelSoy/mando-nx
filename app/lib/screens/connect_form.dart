// The connect screen's form (connect_screen.dart): the title and the demo, the Mac's IP and port, the pairing code, a name, Conectar, the QR scanner, the last error.
import 'package:flutter/material.dart';

import '../gamer_theme.dart';
import '../pairing.dart';
import '../protocol.dart';
import 'connect_header.dart';
import 'scan_screen.dart';

class ConnectForm extends StatelessWidget {
  const ConnectForm({
    super.key,
    required this.formKey,
    required this.host,
    required this.port,
    required this.code,
    required this.name,
    required this.busy,
    required this.error,
    required this.onConnect,
    required this.onDemo,
    required this.onScanned,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController host, port, code, name;
  final bool busy;
  final String? error;
  final VoidCallback onConnect, onDemo;
  final void Function(VoidCallback fill)
  onScanned; // the scanned pairing filled the fields: redraw

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
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ConnectHeader(onDemo: onDemo),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              key: const Key('host'),
                              controller: host,
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
                              controller: port,
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
                              controller: code,
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
                              controller: name,
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
                        onPressed: busy ? null : () => onConnect(),
                        icon: const Icon(Icons.sports_esports),
                        label: Text(busy ? 'Conectando…' : 'Conectar'),
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
                          if (pair != null && context.mounted) {
                            onScanned(() {
                              host.text = pair.host;
                              port.text = '${pair.port}';
                              code.text = pair.code;
                            });
                          }
                        },
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Escanear QR del Mac'),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          error!,
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
