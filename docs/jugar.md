# Jugar

## Abrir el juego

Doble clic en `scripts/play_wifi.command`, o desde Terminal:

```bash
scripts/play_wifi.command                  # el juego que guardó build_host.sh
scripts/play_wifi.command --lang es-419    # en español (si el juego lo tiene)
scripts/play_wifi.command --players 2      # como mucho 2 jugadores con teléfono
scripts/play_wifi.command --keyboard-own   # el teclado es el Jugador 1 y los teléfonos van del 2 en adelante
scripts/play_wifi.command --new-code       # un código de emparejamiento nuevo
scripts/play_wifi.command --no-wifi        # sin red: solo teclado y mandos físicos
```

En la Terminal aparecen la IP del Mac, el puerto (47800) y el código. Con el juego se abre la ventana del **QR** (también en el menú **Controllers → Phone Pairing QR…**, ⌘J). Para que el juego vuelva a recibir los controles, **cierra la ventana del QR**. El código no cambia entre partidas, así que los teléfonos se reconectan solos.

## Conectar un teléfono

1. El teléfono y el Mac tienen que estar en la **misma red**.
2. Abre **Mando NX** → **Escanear QR del Mac** → apunta al QR → **Conectar**. También puedes escribir a mano la IP, el puerto y el código. La IP lleva puntos, no comas.
3. Arriba sale tu jugador (**Jugador 1**, **Jugador 2**…) y la latencia, por ejemplo `Conectado · 12 ms`.
4. **Salir** libera tu jugador al momento. Si el teléfono se bloquea o pierde la red, sus botones se sueltan en medio segundo y pierde el jugador a los 5 segundos. Al volver se reconecta solo y recupera el mismo jugador si sigue libre.

**Probar mando** abre el mando sin conexión (dice DEMO), para ver los botones.

## Jugadores

- El **primer teléfono es el Jugador 1** y el teclado del Mac también controla al Jugador 1. Los siguientes teléfonos son los jugadores 2, 3 y 4. Con `--keyboard-own`, el teclado tiene el Jugador 1 para él solo.
- Los teléfonos y los mandos físicos (Xbox, PlayStation, Pro Controller) comparten la misma lista de jugadores y nunca se pisan.
- Mientras la ventana del juego no está al frente (otra app, la ventana del QR, la de teclas), los mandos se sueltan. Al volver, siguen.

## La tarjeta del juego

En el centro del mando, el host muestra lo que sabe del juego:

| Dice | Significa |
|---|---|
| **El juego lee tu mando como Jugador N** (verde) | El juego usa tu mando como su jugador N |
| **Pantalla de 1 jugador: tu mando también mueve al Jugador 1** | El juego está en una pantalla de un solo jugador: todos los mandos mueven al Jugador 1 |
| **El juego acepta N jugadores ahora: tu mando espera** | Hay más mandos que jugadores en esta pantalla |
| **En pausa: pon la ventana del juego al frente en el Mac** | La ventana del juego no está al frente |

Las luces son los jugadores que acepta la partida: la tuya, de tu color; las rellenas, jugadores con mando. El teléfono vibra cuando el juego toma tu mando.

El nombre del personaje, el kart o la posición en la carrera **no** salen: están dentro de la memoria del juego y habría que estudiarla para cada juego y cada versión.

## Controles (Mario Kart 8 Deluxe)

| Acción | Botón |
|---|---|
| Acelerar | **A** |
| Frenar / marcha atrás | **B** |
| Saltar / derrapar | **R** |
| Usar objeto | **L** o **ZL** |
| Mirar atrás | **X** |
| Pausa | **+** |
| Dirección | joystick (aparece donde pones el dedo, en la mitad izquierda) |

Para jugar a varios en Mario Kart: en el menú principal elige el modo multijugador (2 a 4 jugadores). El Jugador 1 maneja los menús.

## Volante por inclinación

- Activa **Inclinación** (abajo a la izquierda) y sostén el teléfono apaisado como un volante.
- En los ajustes (el icono abajo a la derecha) están la **Sensibilidad** y **Centrar volante**: tócalo con el teléfono en posición neutra.
- Si tocas el joystick, manda el joystick.
- Si sales de la app o el sensor falla, la inclinación se apaga y vuelve el joystick. Solo usa el acelerómetro: no hace falta giroscopio.

## Vibración

**Vibración del juego** (en los ajustes) hace vibrar el teléfono con la vibración real del juego para tu jugador. **Respuesta al tocar** es otra cosa: un toque corto al pulsar los botones. Se activan por separado.

## Teclado del Mac

- Teclas por defecto: WASD mueve el joystick, las flechas son la cruceta, J A, K B, U X, I Y, Q L, E R, Z ZL, C ZR, Return +, Tab −, Espacio sacude el mando.
- Para cambiarlas: **Controllers → Keyboard Controls…** (⌘K) en la ventana del juego. Haz clic en una casilla y pulsa la tecla. Se guarda al momento, y **Restore Defaults** vuelve a las teclas de fábrica.
