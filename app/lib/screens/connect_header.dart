// Connection header and offline preview entry.
import 'package:flutter/material.dart';

import '../gamer_theme.dart';

class ConnectHeader extends StatelessWidget {
  const ConnectHeader({
    super.key,
    required this.onDemo,
    required this.style,
    required this.onStyle,
  });
  final VoidCallback onDemo;
  final VisualStyle style;
  final ValueChanged<VisualStyle> onStyle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(colors: [cyan, coral]),
            ),
            child: const Icon(Icons.sports_esports_rounded, color: ink),
          ),
          const SizedBox(width: 12),
          const Text(
            'MANDO',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const Text(
            ' NX',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: cyan,
            ),
          ),
          const Spacer(),
          PopupMenuButton<VisualStyle>(
            tooltip: 'Estilo visual',
            initialValue: style,
            onSelected: onStyle,
            itemBuilder: (_) => [
              for (final s in VisualStyle.values)
                PopupMenuItem(value: s, child: Text(visualStyleNames[s]!)),
            ],
            icon: const Icon(Icons.palette_outlined, size: 20),
          ),
          OutlinedButton.icon(
            onPressed: onDemo,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Probar mando'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Row(
        children: [
          Icon(Icons.wifi_rounded, size: 15, color: cyan),
          SizedBox(width: 6),
          Text(
            'CONEXIÓN LOCAL',
            style: TextStyle(
              color: cyan,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'SIN CABLES. A TU MANERA.',
            style: TextStyle(color: muted, fontSize: 10, letterSpacing: .8),
          ),
        ],
      ),
      const SizedBox(height: 6),
      const Text(
        'Tu próxima partida empieza aquí.',
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -.4,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Conecta con tu Mac en la misma red Wi-Fi. Escanea su QR o introduce los datos de conexión.',
        style: TextStyle(color: muted, fontSize: 12),
      ),
    ],
  );
}
