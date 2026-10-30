# Wi-Fi controllers and the Mac keyboard map

On the Mac host, phones can be controllers over the local network, each one a player of its own, beside the keyboard and physical controllers: local multiplayer such as Mario Kart 8 Deluxe's four-player split screen with the keyboard as player 1 and three phones. The phone app is [dm/remote_pad](../dm/remote_pad/README.md) (Flutter, iOS and Android, Spanish interface). The keyboard's keys can be changed in a window of the game and are kept between runs.

- [Playing](#playing)
- [Host switches](#host-switches)
- [Players](#players)
- [Protocol](#protocol)
- [Security](#security)
- [The keyboard map](#the-keyboard-map)
- [Tests](#tests)
- [Limits](#limits)

## Playing

1. Start the game on the Mac with `DM_REMOTE=1` (and, for keyboard + phones, `DM_KBD_PLAYER=own`, so the keyboard keeps player 1 for itself). The log, the window title and the **Controllers** menu show the Mac's address, the port and the pairing code: `Wi-Fi: 192.168.1.23:47800, code 482913`. If macOS asks whether the host may accept incoming network connections, allow it.
2. On each phone, open **Mando NX**, type the Mac's IP address, the port and the code, and tap **Conectar**. The phone shows its player (**Jugador 2**), the link and its round-trip time. The phone and the Mac must be on the same network. iOS asks once for local network access; the app needs it.
3. **Salir** on the phone frees its player at once. A phone that goes quiet (locked, out of range) has its buttons released after 0.5 s and loses its player after 5 s; when it comes back it joins again by itself and gets the same player, unless another phone or controller took it meanwhile.

`dm/tools/remote_phone.py --code <code> --phones 3` stands in for phones, to check a host without one.

## Host switches

Off unless `DM_REMOTE=1`: without it the host opens no socket and behaves as before.

| Switch | Meaning |
|---|---|
| `DM_REMOTE=1` | Starts the receiver (`dm/host/remote_mac.c`): one IPv4 UDP socket, one thread |
| `DM_REMOTE_PORT` | UDP port, default 47800 (`0`: any free port, for tests) |
| `DM_REMOTE_BIND` | The IPv4 address to listen on, default every address of the Mac (`127.0.0.1` keeps it to this Mac) |
| `DM_REMOTE_CODE` | The pairing code, 4 to 32 letters and digits. Unset: a random 6-digit code for this start, printed in the log |
| `DM_REMOTE_PLAYERS` | The highest player a phone may be, 1 to 8 (default 8). With `4`, a fourth phone beside the keyboard waits for a free player |
| `DM_REMOTE_TIMEOUT_MS` | How long a silent phone keeps its player, 200 to 60000 ms (default 5000); its buttons are released after half of that, at most 500 ms |

## Players

Phones take players from the same slot table as physical controllers (`dm/host/pad_slots.h`, under a lock in `front_mac.m`), so a phone and a controller are never one player, and each player keeps its own npad (`hle_hid.c`: player n is npad No n). A phone takes, as a controller does, the free player its id last held, then player 1 if free, then the lowest player nobody has held yet, then the lowest free one, all within `DM_REMOTE_PLAYERS`. Its slot name is `wifi:<client id>`, so a rejoining phone finds its player again. A controller connecting while phones play takes a player no phone holds. Eight players at most.

While the game window is not key (another app in front, the Keyboard Controls window), phones are released, as the keyboard and controllers are; back in focus they play again. Without a window (`DM_WINDOW` unset, tests) phones play and the keyboard does not.

## Protocol

Version 1. One JSON object per UDP datagram, UTF-8, at most 512 bytes; `v` is the version in every message. Unknown keys are ignored, so later versions can add fields. The host's parser takes a flat object of strings, numbers, `true`, `false` and `null` only (nothing nested), at most 32 members and strings of at most 64 bytes; anything else is dropped and counted (the log sums them up every 10 s).

Phone to host:

| `t` | Fields | When |
|---|---|---|
| `hello` | `code` (the pairing code), `id` (8–32 of `A-Z a-z 0-9 _ -`, random per installation and kept), `name` (optional, shown in the log and the menu, cut to 32 bytes) | every 500 ms until a `welcome` or `reject`; again after a `kick` |
| `state` | `sid`, `seq` (0–2³²−1, one more per datagram), `b` (buttons, 0–65535), `lx` `ly` `rx` `ry` (−1 to 1, y up; optional, 0), `ms` (optional: the phone's clock, echoed in acks) | 50–60 times a second, the whole state each time, changed or not: it is also the heartbeat |
| `bye` | `sid` | leaving |
| `text` | `sid`, `ks` (the keyboard request it answers), `text` (at most 128 bytes, UTF-8), `ok` (1 typed, 0 cancelled) | the player answered the game's keyboard (`kbd`) |
| `icon` | `sid`, `off` (a multiple of 300) | asking for a piece of the game's icon (`info.isz` bytes, CRC `info.ih`): a few at a time, again after 400 ms without the piece |

`b` has NpadButton's bits (`dm/host/dm_input.h`): A 1, B 2, X 4, Y 8, left stick press 16, right stick press 32, L 64, R 128, ZL 256, ZR 512, + 1024, − 2048, D-pad left 4096, up 8192, right 16384, down 32768.

Host to phone:

| `t` | Fields | When |
|---|---|---|
| `welcome` | `sid` (16 hex digits), `player` (1–8), `hz` (60), `timeout_ms` | a `hello` with the right code. A repeated `hello` from the same address gets the same session; from another address (the app restarted, the phone changed network) a new `sid` on the same player |
| `reject` | `reason`: `code` (wrong code), `full` (no free player), `busy` (too many wrong codes, try again in a minute), `version` | a `hello` that cannot join |
| `ack` | `sid`, `seq` (the newest taken), `player`, `ms` (the last one received) | the first state at once, then every 250 ms |
| `kick` | `reason`: `session` (a `sid` the host does not know: it restarted or the session ended), `timeout` | the phone joins again with `hello` |
| `bye` | `reason`: `left` (answering the phone's `bye`), `host` (the host quits) | |
| `info` | `sid`, `is` (0–2³²−1, one more per info; the phone drops older ones), `player`, `game` (the game profile's name, at most 48 bytes), `use`, `seats` (1–8), `taken` (bit n: player n + 1 has a controller, phone or not), `rd` (1: the game read this player's npad in the last half second), `ih` (the icon's CRC-32, 8 hex digits; `00000000` none), `isz` (its size in bytes) | once the phone streams, then on a change and every 2 s |
| `roster` | `sid`, `rs` (ordered like `is`), `n1`…`n8` (who holds each player, only those held: `keyboard`, a controller's name, a phone's own name; at most 24 bytes) | once the phone streams, then on a change and every 3 s |
| `kbd` | `sid`, `ks` (the request), `max` (characters), `title`, `init` (the text it starts with); or `sid`, `ks`, `done` (1) | the game's keyboard is up on the Mac (every second until a phone answers); `done` when it was answered (by any phone or on the Mac) or closed, twice |
| `iconpart` | `sid`, `ih`, `off`, `d` (base64 of up to 300 bytes from `off`) | the answer to `icon` |
| `race` | `sid`, `cs` (ordered like `is`), `crs` (the course as the game files it, as `Gu_WaterPark`; empty in the menus or when unknown), and when known `pos` (place, 1 first), `lap` (1 first), `coin`; `drv`, `body`, `tire`, `wing` (the game's ids for the character and the kart's body, tires and glider, 0–63); `itm`, `itm2` (the item in each of the two slots, the game's item id, −1 empty) | on a game build with race data (below): once the phone streams, then on a change (at most every 100 ms) and every 2 s |

`info.use` is what the game makes of the phone's player, from the npads it supports (`SetSupportedNpadIdType`, `hle_hid.c` `dm_hid_player_use`): `own` (the game reads that player's npad itself), `p1` (a one-player screen: the controller feeds player 1, as every controller does there), `off` (the game takes fewer players now: not used), `pause` (the game window is not key: released). `seats` is how many players the game takes now (Mario Kart 8 Deluxe: 4 for local play). These are general: nothing is read from a game's memory, so they hold for every game. `race` is the exception, and only on a game build listed in `remote_race.c`'s `k_race` (gated by main's build ID): the course is the folder of the course files the game opens (`hle_fs.c` `dm_fs_opened`), and place, lap and coins are read from the racer the player drives, the character and kart from that racer's kart model, found by their classes' vtables and checked on every read (Mario Kart 8 Deluxe 4.0.1: player n is racer n − 1; a phone a one-player screen merges into player 1 races as player 1). The items come from the item box on the screen, so only player 1 gets them, and only while the game shows one box (one player on the Mac); a slot whose roulette still turns counts as empty. The ids are the game's own: the order of its character and part lists (`drv` 0 Mario … 40 King Boo … 52; `body` 0 Standard Kart, 14 Standard Bike, 15 Comet…; `tire` 20 Leaf; `wing` 0 Super Glider) and of its item ids (0 banana, 1 green shell, 2 red shell, 3 mushroom … 15 coin … 22 Boo; the table from an id to the item box's icon is at main+0xf21e7c). The phone has the names. Other builds send no `race`. `rd` counts the game's own `GetNpadStates` / `GetNpadState` calls on that player's npad (`hle_hid.c` `dm_hid_reads`; player 1's for a phone a one-player screen merges into it). The icon is a JPEG thumbnail, at most 128 pixels a side (`remote_icon.c`, ImageIO), of `icon.jpg` beside the RomFS image (`DM_ROMFS`) or of `DM_REMOTE_ICON`. The game's keyboard (`hle_swkbd.c` → `front_text_input` in `front_mac.m`) asks every phone while its box is up; the first answer, from a phone or typed on the Mac, wins, and a phone's fills the box and closes it.

Ordering: the host takes a state only when its `seq` is newer than the last one taken (serial number arithmetic, so 0 follows 2³²−1); a late or repeated datagram is dropped, and a lost one is replaced by the next, which carries the whole state. The first state of a session is taken whatever its `seq`. Sticks: each axis is clamped to −1..1, then the pair to the unit circle, then scaled to ±32767; the app applies a 12 % dead zone before sending. The phone counts the host as gone after 2 s without an ack (it keeps sending and says hello again every second); after a `bye` with reason `host` it keeps trying every 2 s, so it joins again when the game is started again.

Host side: `dm/host/remote_proto.h` and its parts (`remote_types.h`, `remote_json.h`, `remote_text.h`, `remote_session.h`, `remote_feed.h`, `remote_parse.h`, `remote_packet.h`, `remote_tick.h`: parsing, validation, sessions, the game's feed; no socket), `dm/host/remote_mac.c` (socket and thread), `remote_front.c` (the hooks into the slots, hid, haptics and the game's keyboard), `remote_icon.c` (the icon's thumbnail), `remote_race.c` (the course, place, lap, coins, character, kart and items). Phone side: `dm/remote_pad/lib/protocol/` and `lib/net/`.

## Security

- Opt-in: no socket without `DM_REMOTE=1`; `DM_REMOTE_BIND` can keep it to one network.
- Joining needs the pairing code. Wrong codes are limited before any code is compared: 5 a minute from one address, 30 a minute from all; past that, `busy`. Codes are compared in constant time.
- A session id is 64 random bits (`arc4random_buf`) and works only from the address and port that joined; a datagram from anywhere else is dropped. At most 8 sessions, 250 datagrams a second per phone, 20 `kick` replies a second; no reply to a datagram from an unknown address is larger than that datagram. An `iconpart` is larger than its `icon` request, but it only goes to the address and port a session joined from.
- Not encrypted: someone who can capture the Wi-Fi's traffic can read the code and the session ids. Use it on a network you trust, and a longer `DM_REMOTE_CODE` on a shared one.
- The pairing code is not printed in the log when it comes from `DM_REMOTE_CODE` (only a code the host makes itself is, since there is nowhere else to read it).

## The keyboard map

`dm/host/kbd_map.h`. Without a map file the keys are the ones the Mac always had: WASD left stick, arrow keys D-pad, J A, K B, U X, I Y, Q L, E R, Z ZL, C ZR, F / G stick presses, Return +, Tab −, Space shakes the controller; the right stick has no keys.

**Controllers > Keyboard Controls…** (⌘K) in the game window opens a window with a row per action and two key boxes. Click a box and press a key: that key now does that action (a key used by another action moves here). Esc cancels, Delete clears the box, a ⌘ shortcut still goes to the menus. Shift, Control and Option, left and right, can be keys; Command, Caps Lock and Fn cannot. Each change applies at once and is saved at once; **Restore Defaults** goes back to the built-in keys and removes the file.

The file is `~/Library/Application Support/nxnative/keyboard.txt` (`DM_KBD_MAP=<path>` names another), one map for every game. It can be edited by hand: a line per action, `<action>=<key>[,<key>…]`, keys by their US-keyboard name (the key's position, whatever the layout prints on it), `#` for comments:

```
A=Space
B=K,LeftShift
LStickUp=UpArrow
DpadUp=
```

The actions are `A B X Y L R ZL ZR Plus Minus LS RS DpadUp DpadDown DpadLeft DpadRight LStickUp LStickDown LStickLeft LStickRight RStickUp RStickDown RStickLeft RStickRight Shake`. The keys are the letters, digits, `Minus Equal LeftBracket RightBracket Backslash Semicolon Quote Comma Period Slash Grave Section Return Tab Space Delete Escape ForwardDelete Help Home End PageUp PageDown LeftArrow RightArrow UpArrow DownArrow LeftShift RightShift LeftControl RightControl LeftOption RightOption`, `F1` to `F20`, `Keypad0` to `Keypad9` and `KeypadDecimal KeypadMultiply KeypadPlus KeypadClear KeypadDivide KeypadEnter KeypadMinus KeypadEquals`. An action the file names gets exactly the keys listed (none after the `=`: no key); the others keep the built-in ones. A line that names an unknown action or key is logged as `[RED]` and changes nothing.

## Tests

- `make -C dm/host/tests GAME=<id> remote` (also part of `run`): `t_remote` (parsing, validation, sticks, seq, sessions over a slot table shared with controllers: codes and their limit, players, release, timeout, rejoin, focus, bye, eight players), `t_remote_feed` (info with reading and the icon, roster, the game's keyboard asked and answered, icon pieces, base64 and CRC, race and its pace), `t_remote_race` (the course from the files opened, the racers, kart models and item boxes found by vtable on a fake heap, every check that turns data off), `t_kbd_map` (the built-in map is the old fixed one, files, round trip, modifiers), `t_remote_udp` (real datagrams on loopback through `remote_mac.c`'s thread to the npads `hle_hid.c` reports: three phones beside the keyboard in a four-player game; the feed: reading, roster, the icon made from a PNG, race, the keyboard answered by a phone).
- `cd dm/remote_pad && flutter analyze && flutter test`: the protocol, the client's join / heartbeat / seq / rejoin / pause on a fake clock and over a loopback socket, the layout on five screen sizes, multi-touch routing, the screens.

## Limits

- IPv4 only; QR or manual address entry; automatic discovery is not implemented.
- `info` says what the game's controller setup makes of a player, not what happens inside the game. Only `race` comes from inside a game, for the builds `remote_race.c` knows: Mario Kart 8 Deluxe 4.0.1, whose racer order was checked with one player only (that player 2 is racer 1 in split screen is assumed). Items only for player 1 playing alone: with two or more players on the Mac the game draws an item box each, and which is whose is not known.
- The phone gamepad has no right stick or stick presses; `rx`/`ry` stay 0. Tilt steering changes the left stick. Physical sensor and haptic feel need device testing.
- The app is not tested on phones here; installing it needs the developer's own signing (iOS) or a debug build (Android): see [dm/remote_pad](../dm/remote_pad/README.md).

## Gamer interface, QR, tilt and game rumble

Use **Probar mando** to explore the controls offline (marked DEMO). In the Mac game, **Controllers → Phone Pairing QR… (⌘J)** shows a QR; the phone's **Escanear QR del Mac** fills the address, port and pairing code after validation. Press **Conectar** to join. The camera is only opened by the scan action, and manual entry remains available. `DM_REMOTE_QR=1` opens the pairing window at launch. Close that window to return input focus to the game.

The URI is `nxmando://pair?v=1&host=<IPv4>&port=<port>&code=<code>`. Only those four single parameters, protocol 1, valid IPv4, valid port and code are accepted. The QR contains the pairing secret: show it only to intended players.

The phone's tune button opens separate controls for **Volante por inclinación**, sensitivity, centering, game vibration and touch feedback. Hold the phone in landscape as a wheel, enable tilt and tap **Centrar volante** in the neutral position. Touching the joystick overrides tilt. Sensor errors fall back to the joystick; backgrounding releases controls. Tilt is accelerometer/gravity based steering, not game six-axis motion injection.

Phones advertise `rumble:1` in hello. Legacy phones omit it and receive no rumble. The host routes that player's real game vibration to UDP messages with `t:rumble`, session `sid`, uint32 sequence `rs`, intensity `i`, sharpness `s` (both 0–1), and duration `ms` (0–1000). Changes are limited to 30/s, renewed every 100 ms, with 150 ms pulses that expire if connectivity stops. Phone checks session and sequence before native Core Haptics (iOS) or Vibrator (Android). The Mac's rumble gain applies before transport; touch feedback is independent.

Dependencies: [mobile_scanner](https://pub.dev/packages/mobile_scanner), [sensors_plus](https://pub.dev/packages/sensors_plus). Simulator checks verify presentation and protocol but cannot verify physical camera scanning, motion direction or vibration feel. Character selection, minimap and automatic Bonjour discovery remain unimplemented. Tilt steering uses the gyroscope when the phone has one (fused with the accelerometer) and the player allows it.

### Game card

From the host's `info`, the pad shows a card in its middle: the game's name, a light per player the game takes (the phone's own in its player colour, glowing while the game reads it; other players with a controller filled), and a line saying what the game makes of the phone: **El juego lee tu mando como Jugador N**, a one-player screen where it also moves player 1, a game taking fewer players (the phone waits), or a pause while the game window on the Mac is not in front. The phone gives a short vibration when the game takes its controller. In a race (`race`), the card also shows the course by its Spanish name, the place, the lap and the coins, and below them the character, the kart (body, tires, glider) and the items held, by the names the game shows in Spanish (the items, which the game shows only as icons, by their usual Spanish names). The offline demo shows the card with a demo game.

### Visible motion switch

The pad has an **Inclinación / Acelerómetro** switch, off by default. It uses the accelerometer only: no gyroscope is required. The joystick remains available and overrides tilt while touched. Turning motion off, leaving the app, sensor errors, stream closure or two seconds without valid readings cancels sensor input and releases steering back to the joystick. Tune/settings is drawn above the touch-input layer so it remains tappable. Minimap is not implemented; it would need game telemetry.
