import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'pairing.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanState();
}

class _ScanState extends State<ScanScreen> {
  final camera = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool done = false;
  String? error;
  @override
  void dispose() {
    camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escanear QR del Mac')),
    body: Stack(
      children: [
        MobileScanner(
          controller: camera,
          onDetect: (capture) {
            if (done) return;
            for (final b in capture.barcodes) {
              final pair = Pairing.parse(b.rawValue ?? '');
              if (pair != null) {
                done = true;
                Navigator.pop(context, pair);
                return;
              }
              setState(
                () => error = 'Este QR no es una conexión Mando NX válida',
              );
            }
          },
          errorBuilder: (context, error) => const Center(
            child: Text(
              'No se pudo abrir la cámara. Revisa el permiso o usa la conexión manual.',
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error ?? 'Abre el QR en el Mac con ⌘J',
              style: const TextStyle(
                backgroundColor: Colors.black,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
