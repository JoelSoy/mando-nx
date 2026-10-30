// What the pad says in words: the link's status, what the game makes of this player, a player's name as the roster gives it.
import 'package:flutter/material.dart';

import '../../client.dart';
import '../../protocol.dart';

const playerColors = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFFFDD835),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
  Color(0xFF00ACC1),
  Color(0xFFD81B60),
];

Color playerColor(int p) => playerColors[(p - 1) % playerColors.length];

String statusText(RemoteClient c) {
  if (c.isDemo) return "DEMO · Sin conexión real";
  switch (c.status) {
    case LinkStatus.joining:
      return c.sinceStartMs > 4000
          ? 'Sin respuesta del Mac. Revisa la IP, el puerto y que ambos estén en la misma red Wi-Fi.'
          : 'Conectando…';
    case LinkStatus.connected:
      return c.rttMs == null ? 'Conectado' : 'Conectado · ${c.rttMs} ms';
    case LinkStatus.reconnecting:
      return 'Reconectando…';
    case LinkStatus.waiting:
      if (c.hostQuit) {
        return 'El juego se cerró en el Mac. Se volverá a conectar cuando lo abras de nuevo.';
      }
      return c.reason == 'busy'
          ? 'Demasiados intentos con un código incorrecto. Espera un minuto…'
          : 'Todos los jugadores están ocupados. Esperando un lugar libre…';
    case LinkStatus.rejected:
      return c.reason == 'code'
          ? 'Código incorrecto. Revisa el código que muestra el Mac.'
          : 'Esta versión de la app no es compatible con el juego del Mac.';
    case LinkStatus.closed:
      return 'Desconectado';
  }
}

/// What the host's info says about this player, as a line under the game's name.
String useText(GameInfo i) {
  switch (i.use) {
    case PlayerUse.own:
      return 'El juego lee tu mando como Jugador ${i.player}';
    case PlayerUse.p1:
      return 'Pantalla de 1 jugador: tu mando también mueve al Jugador 1';
    case PlayerUse.off:
      return i.seats == 1
          ? 'El juego acepta 1 jugador ahora: tu mando espera'
          : 'El juego acepta ${i.seats} jugadores ahora: tu mando espera';
    case PlayerUse.pause:
      return 'En pausa: pon la ventana del juego al frente en el Mac';
  }
}

/// A roster name for people: the Mac's keyboard and an unknown phone in Spanish, the rest as the host gives it.
String playerName(String n) => switch (n) {
  'keyboard' => 'Teclado',
  'phone' => 'Teléfono',
  _ => n,
};

/// The player's number at the top of the pad, in the player's colour.
class PlayerPill extends StatelessWidget {
  const PlayerPill({super.key, required this.player, required this.color});
  final int? player;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('player'),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF2B323C),
      border: Border.all(
        color: player != null ? color.withValues(alpha: .85) : Colors.white24,
      ),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
      ],
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      player != null ? 'Jugador $player' : 'Sin jugador',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    ),
  );
}
