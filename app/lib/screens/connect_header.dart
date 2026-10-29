// The connect screen's top (connect_form.dart): Mando NX, Probar mando (the offline demo), the motto and what to do.
import 'package:flutter/material.dart';

import '../gamer_theme.dart';

class ConnectHeader extends StatelessWidget {
  const ConnectHeader({super.key, required this.onDemo});
  final VoidCallback onDemo;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Icon(Icons.sports_esports_rounded, color: cyan, size: 32),
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
            onPressed: () => onDemo(),
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
    ],
  );
}
