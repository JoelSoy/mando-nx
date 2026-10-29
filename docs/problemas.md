# Problemas y soluciones

Primero mira el registro del juego. Para ver los teléfonos que se conectaron, los códigos erróneos y los paquetes ignorados:

```bash
grep -E "Wi-Fi|hid supported|\[RED\]" <build>/run/gameplay_wifi.log | tail -30
```

## "Sin respuesta del Mac. Revisa la IP, el puerto…"

El teléfono manda mensajes pero no le llega respuesta. Si en el registro **no aparece nada del teléfono** (ni siquiera `wrong pairing code`), sus mensajes no llegan al Mac. Revisa en este orden:

1. **El permiso de Red local de iOS.** Ve a **Ajustes → Privacidad y seguridad → Red local → Mando NX** y actívalo. Sin ese permiso iOS bloquea los mensajes en silencio. Después toca **Salir** y vuelve a **Conectar**.
2. **La misma red.** El Mac y el teléfono tienen que estar en la misma Wi‑Fi. Si la IP del Mac es `172.20.10.x`, el Mac está usando el **hotspot de un iPhone**: funciona incluso desde el mismo iPhone que hace de hotspot (probado), pero si falla, usa una Wi‑Fi normal.
3. **La IP.** Usa la que muestra el juego (o el QR) y escríbela con puntos: `172.20.10.2`, no `172.20,10.2`. Si el Mac cambia de red, cambia su IP: vuelve a escanear el QR.
4. **Una VPN en el teléfono** puede mandar el tráfico fuera de tu red: apágala.
5. **El firewall del Mac:** si macOS pregunta si `dmhost-wifi` puede aceptar conexiones, elige **Permitir**. Con "Bloquear todas las conexiones entrantes" activado, ningún teléfono puede entrar (**Ajustes del Sistema → Red → Firewall**).
6. **El juego abierto con Wi‑Fi:** en el registro tiene que aparecer `Wi-Fi controllers on`. Si no aparece, abre el juego con `play_wifi.command` (no con otro lanzador).

Para probar el Mac sin teléfono (con el juego cerrado): `scripts/smoke_host.sh`.

## La inclinación "se desactiva sola"

En versiones anteriores de la app pasaba por tres causas, ya corregidas:

- **El interruptor estaba encima de la zona del joystick** (abajo a la izquierda) y el pulgar lo tocaba sin querer. Ahora está en el centro de abajo, y ningún diseño incluido lo pone donde llega el joystick.
- **Los gestos del sistema la apagaban** (Centro de Control, notificaciones, alertas). Ahora solo pausan el sensor, y los bordes piden un segundo deslizamiento.
- **Iba al revés** con el teléfono girado hacia el otro lado. Ahora gira igual en las dos posiciones horizontales.

Si en un diseño tuyo pusiste el interruptor donde cae el pulgar del joystick, muévelo en **Ajustes → Personalizar botones**.

## "Al estar presionando deja de funcionar"

En versiones anteriores pasaba por cuatro causas, ya corregidas:

- **Un gesto del sistema soltaba todos los dedos para siempre.** Al rozar un borde (la barra de inicio abajo, el Centro de Control arriba), iOS ponía la app en "inactiva" y la app olvidaba los dedos apoyados. Esos dedos ya no funcionaban hasta levantarlos. Ahora un dedo apoyado sigue contando (iOS solo cancela los que toma él), y los bordes piden un segundo deslizamiento.
- **El aviso "Acelerómetro no disponible" tapaba la parte de abajo** (joystick, cruceta, B) durante 4 segundos. Ahora sale en el centro y no recibe toques.
- **Al levantar el pulgar del joystick con otro dedo apoyado en su zona**, el joystick no respondía hasta soltarlo todo. Ahora ese dedo toma el joystick.
- **Los botones Salir, Ajustes e Inclinación estaban donde caen los pulgares.** Ahora están arriba y en el centro de abajo.

El mando acepta todos los dedos a la vez que el teléfono reconozca (iPhone: 5): por ejemplo joystick, A, R, ZL y B juntos.

## Otros mensajes de la app

| La app dice | Qué hacer |
|---|---|
| **Código incorrecto** | Usa el código que muestra el juego (o escanea el QR). `--new-code` cambia el código, y entonces hay que volver a escanearlo |
| **Demasiados intentos con un código incorrecto. Espera un minuto…** | Más de 5 códigos erróneos en un minuto: espera un minuto |
| **Todos los jugadores están ocupados** | Ya hay tantos jugadores como `--players` (4 por defecto): espera o sube `--players` |
| **El juego se cerró en el Mac** | Vuelve a abrir el juego: el teléfono se reconecta solo |
| **Esta versión de la app no es compatible** | La app y el host usan versiones distintas del protocolo: actualiza los dos |

## Instalación en el iPhone

| Problema | Solución |
|---|---|
| La app dejó de abrir pasados unos días | La firma con cuenta gratuita dura 7 días: `scripts/install_ios.sh` otra vez |
| "Desarrollador no confiable" | **Ajustes → General → VPN y gestión de dispositivos** → confía en tu cuenta |
| `no paired iPhone or iPad` | Conecta el cable, desbloquea el iPhone, toca **Confiar** y activa el **Modo de desarrollador** |
| `no Apple team found` | Inicia sesión en **Xcode → Settings → Accounts**, o pasa `--team <ID>` |
| El bundle ID ya está registrado por otro equipo | `scripts/install_ios.sh --bundle-id com.tunombre.mandonx` |
| Con cuenta gratuita, error por límite de apps | Una cuenta gratuita tiene como mucho 3 apps propias a la vez en el dispositivo: borra una |

## Host y juego

| Problema | Solución |
|---|---|
| `the game is running … close it first` | Cierra el juego (⌘Q) y vuelve a correr el script |
| `the patch does not apply` | Tu nxnative está en otro commit: `git -C ../nxnative switch -c mando-nx $(cat host/NXNATIVE_COMMIT)` (con el árbol limpio), o porta el parche ([AGENTS.md](../AGENTS.md#moving-to-a-newer-nxnative)) |
| `cannot listen on UDP port 47800` | Ya hay otro juego abierto: ciérralo |
| Los mandos no responden con el QR abierto | Cierra la ventana del QR: con ella al frente, el juego no recibe los controles |
| `[RED] audren: no DeviceSink` en pruebas sin ventana | Ya existía antes de este parche (también pasa con el host original). Con ventana y sonido no aparece |
