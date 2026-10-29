# Notes for agents

Mando NX makes phones into Wi-Fi controllers for Nintendo Switch games that [nxnative](https://github.com/seedds/nxnative) runs natively on a Mac. It has three parts:

- the phone app (`app/`, Flutter, iOS + Android, Spanish UI);
- a patch to nxnative's Mac host (`host/nxnative.patch`, made for the nxnative commit in `host/NXNATIVE_COMMIT`);
- the scripts that put it together (`scripts/`).

nxnative is not in this repository: `scripts/setup_nxnative.sh` clones it, applies the patch and links `app/` into it as `dm/remote_pad`. The user-facing docs are in Spanish (`README.md`, `docs/*.md`). Code, code comments, log lines and this file are in English.

## Map

| Where | What |
|---|---|
| `app/lib/protocol.dart` | Messages (hello, state, bye; welcome, ack, reject, kick, bye, rumble, info), validation, stick normalization, the connect screen's checks |
| `app/lib/client.dart` | The session: hello until welcome, a 17 ms heartbeat carrying the whole state with seq numbers, ack timeout, rejoin, pause/resume, rumble and info ordering. No timers of its own: tests drive it with a fake clock |
| `app/lib/pad_layout.dart` | Where each control is on a landscape screen, multi-touch routing (pure Dart) |
| `app/lib/pad_screen.dart` | The pad: touch layer, tilt steering (`tilt.dart`), settings sheet, status, the game card (`GameCard`, `useText`) |
| `app/lib/connect_screen.dart`, `scan_screen.dart`, `pairing.dart` | Connect form, QR scanner (mobile_scanner), the strict `nxmando://pair` URI parser |
| `app/lib/native.dart` + `app/ios/Runner/AppDelegate.swift`, `app/android/.../MainActivity.kt` | The `mando/native` method channel: Core Haptics / Vibrator for game rumble, `--demo` launch argument |
| `app/lib/demo.dart` | Offline demo transport (welcome, ack, info) |
| `app/test/` | Protocol, client (fake clock and real loopback UDP), layout on five screens, widgets, motion |
| `host/nxnative.patch`: `dm/host/remote_proto.h` | Pure protocol and sessions (no socket, no clock): parsing, codes and their rate limit, players over the shared slot table, release / timeout, rumble pacing, info |
| `dm/host/remote_mac.c` / `.h` | The UDP socket and its thread, env switches `DM_REMOTE*`, hooks into the front end, `hle_hid.c` and haptics |
| `dm/host/hle_hid.c`, `dm_input.h` | `dm_hid_player_use` / `dm_hid_seats` / `dm_hid_players`: what the game makes of each player (from `SetSupportedNpadIdType`), sent to phones as `info` |
| `dm/host/front_mac.m`, `pad_slots.h` | Player slots shared by the keyboard, physical controllers and phones; Controllers menu; QR window (⌘J) |
| `dm/host/kbd_map.h`, `controls_mac.m` | The configurable keyboard map and its window (⌘K) |
| `dm/host/haptics_apple.m` | `dm_haptics_apple_external`: a phone-owned player's rumble goes to the Wi-Fi receiver |
| `dm/host/tests/t_remote.c`, `t_remote_udp.c`, `t_kbd_map.c` | Host tests (`make -C dm/host/tests GAME=<id> remote`) |
| `dm/tools/remote_phone.py` | Fake phones for checking a host without one (used by `scripts/smoke_host.sh`) |
| `docs/wifi-controllers.md` (in the patch) = `docs/protocol.md` here | The protocol, the host switches and the limits. It is the source of truth. `export_patch.sh` copies it here |

## Rules

- **No game data, ever:** no NSP/XCI, keys, title keys, RomFS, NSO/NCA, shaders, saves or dumps in this repository or the patch. Logs, title IDs, build IDs and offsets are fine. `export_patch.sh` refuses non-source paths and files over 1 MB. Keep that check.
- **No personal signing data:** the Apple team ID lives only in `app/ios/Flutter/Signing.xcconfig`, which git ignores (`install_ios.sh` writes it). Never put `DEVELOPMENT_TEAM` back into `project.pbxproj`.
- **Never edit `host/nxnative.patch` by hand.** Change the code in a patched nxnative checkout (`scripts/setup_nxnative.sh`), build and test it there, then run `scripts/export_patch.sh` and commit the regenerated patch with `docs/protocol.md`.
- **Code inside the patch follows nxnative's rules** (its `AGENTS.md`). They include: English only; red log lines start with `[RED] `; fix root causes rather than working around them; prefer general mechanisms (Horizon / hid semantics) over per-game rules; never use fixed game addresses unless they are gated by build ID; new env switches go into `docs/env_switches.tsv`.
- **Protocol changes:** they are always backward compatible. The host ignores unknown keys and old apps ignore unknown message types. A new host → phone behaviour that an old app could misread is opt-in from the phone's hello (as `"rumble":1`). Change both sides, both test suites and `docs/wifi-controllers.md` in the same change. Keep every host reply within 200 bytes (`rp_reply.text`) and every datagram within 512.
- **The app's UI text is Spanish.** Run `dart format lib test` and keep `flutter analyze` clean.
- **Do not install on the user's devices, or start or stop their game, unless they ask.** `build_host.sh` and `smoke_host.sh` refuse to run while the game is open: never work around that.
- Commit only when asked. Commit messages say what changed and why, and what was checked.

## Checks

```bash
scripts/check.sh                 # flutter analyze + test; host tests; the patch applies to the pinned commit
scripts/smoke_host.sh            # needs the user's packed game (a <title ID>_build folder) and the game closed
```

Done means:
- `flutter analyze` is clean and `flutter test` passes;
- `t_remote`, `t_kbd_map` and `t_remote_udp` pass;
- after host changes, `build_host.sh` builds and `smoke_host.sh` passes on a real game;
- a fresh nxnative at `NXNATIVE_COMMIT` takes the patch (`check.sh` does this).

Simulators cannot check the camera, tilt feel or vibration: say so when it matters.

## Moving to a newer nxnative

The patch is pinned because it touches files that upstream keeps changing (`front_mac.m`, `README.md`, `docs/development.md`, `docs/env_switches.tsv` conflicted with upstream `880b45d`).

1. In an nxnative checkout without local changes, make a branch on the new upstream commit: `git switch -c mando-nx-new origin/main`.
2. Apply the patch: `git apply --3way /path/to/mando-nx/host/nxnative.patch`. Resolve the conflicts in favour of upstream's current code, then re-add our hunks. Check by reading the code that the hooks still fit: `pad_slots`, `dm_pad_players`, `SetSupportedNpadIdType`, haptics.
3. Run `make -C dm/host GAME=<id> dmhost` and `make -C dm/host/tests GAME=<id> remote`. Then copy the host into a build folder (`scripts/build_host.sh`) and run `scripts/smoke_host.sh`.
4. Run `scripts/export_patch.sh --nxnative <that checkout> --commit <new upstream commit>`. It rewrites both `host/nxnative.patch` and `host/NXNATIVE_COMMIT`.
5. Run `scripts/check.sh`, and in `README.md` (Estado) update which commit the patch is for.

## Open

- Character, kart, place or lap on the phone: these need the game's memory layout for each game and build ID (reverse engineering), gated by build ID as nxnative requires. `info` only carries what hid tells the host, which holds for every game.
- Android is built and unit-tested but has not been run on a phone.
- No automatic discovery (Bonjour) yet: QR or manual IP only. IPv4 only. Traffic is not encrypted: use it on a trusted network.
- The phone pad has no right stick and no stick presses.
