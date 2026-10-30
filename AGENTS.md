# Notes for agents

Mando NX makes phones into Wi-Fi controllers for Nintendo Switch games that [nxnative](https://github.com/seedds/nxnative) runs natively on a Mac. It has three parts:

- the phone app (`app/`, Flutter, iOS + Android, Spanish UI);
- a patch to nxnative's Mac host (`host/nxnative.patch`, made for the nxnative commit in `host/NXNATIVE_COMMIT`);
- the scripts that put it together (`scripts/`).

nxnative is not in this repository: `scripts/setup_nxnative.sh` clones it, applies the patch and links `app/` into it as `dm/remote_pad`. The user-facing docs are in Spanish (`README.md`, `docs/*.md`). Code, code comments, log lines and this file are in English.

## Map

| Where | What |
|---|---|
| `app/lib/protocol/` (`protocol.dart` exports it) | `pad_state.dart` buttons and sticks; `encode.dart` what the phone sends; `host_messages.dart` + `decode.dart` what the host sends; `validate.dart` the connect screen's checks, names, ids |
| `app/lib/net/` (`client.dart`) | `remote_client.dart` + `remote_client_rx.dart` the session (hello, 17 ms heartbeat with seq, ack timeout, rejoin, pause/resume; no timers of its own: tests use a fake clock); `game_feed.dart` rumble, info, roster, race, the game's keyboard, the icon pulled in pieces; `game_images.dart` the game's pictures by key (course, character, item), pulled in pieces one at a time; `transport.dart` UDP |
| `app/lib/pad/` (`pad_layout.dart`) | `config.dart` layouts and presets; `layout.dart` + `placement.dart` a layout on a real screen; `layout_edit.dart` + `editor.dart` the editor's logic; `controls.dart`, `touch_router.dart` fingers → buttons and stick (any number at once; the stick hands over to a resting finger). Pure Dart |
| `app/lib/pad/screen/` (`pad_screen.dart`) | `pad_screen.dart` the screen and its lifecycle, with parts `pad_input.dart`, `pad_motion.dart`, `pad_editing.dart`, `pad_view.dart`; `painter.dart` (repaints on touches only), `game_card.dart` + `reading_dot.dart` + `race_line.dart`, `telemetry_board.dart` + `telemetry_instrument.dart` + `telemetry_layout.dart` (the race's instruments in the gaps between controls), `game_art.dart` (the game's pictures on the pad: the course on the middle screen, the face on the stick's knob, the held item on L), `status.dart`, `edit_panel.dart`, `settings_sheet.dart`, `keyboard_prompt.dart`, `toast.dart` (messages that take no touches) |
| `app/lib/motion/` | `steering.dart` the wheel's angle: accelerometer, fused with the gyroscope's rate about the same axis when there is one; `sensors.dart` the sensor streams, the watchdog, pause/resume |
| `app/lib/screens/`, `app/lib/storage/` (`storage.dart`) | the connect screen (`connect_screen.dart`, `connect_form.dart`, `connect_header.dart`, `scan_screen.dart`); the kept settings (`settings.dart`) and pad preferences (`pad_prefs.dart`) |
| `app/lib/games/courses.dart`, `mk8_racers.dart`, `mk8_karts.dart` | Mario Kart 8 Deluxe's course folders → the Spanish names the game shows (from its EUes text), a retro course's console in front; its character, kart part and item ids → Spanish names (the game's own for characters and parts; usual ones for items, which the game shows only as icons) |
| `app/lib/pairing.dart`, `native.dart`, `demo.dart`, `gamer_theme.dart` | the QR's URI parser; the `mando/native` channel (Core Haptics / Vibrator, `--demo`); the offline demo; the theme |
| `app/ios/Runner/SceneDelegate.swift` | `PadViewController`: defers the system's edge gestures and hides the home indicator while playing |
| `app/test/` | One file per subject, each under 200 lines (`client_fakes.dart` is shared, not a test) |
| `host/nxnative.patch`: `dm/host/remote_proto.h` and its parts | Pure protocol and sessions (no socket, no clock): `remote_types.h`, `remote_json.h`, `remote_text.h`, `remote_session.h`, `remote_feed.h` (info, roster, race, keyboard, icon), `remote_parse.h`, `remote_packet.h`, `remote_tick.h` |
| `dm/host/remote_race.c`, `hle_fs.c` (`dm_fs_opened`), `hle_svc.c` (`dm_guest_heap`) | The `race` message's data: the course from the files the game opens; place, lap and coins from the racer objects, character and kart from the kart models, player 1's items from the item box on screen, for the main builds in `k_race` only (Mario Kart 8 Deluxe 4.0.1), found by vtable and checked on every read |
| `dm/host/remote_images.c`, `remote_img.c`, `remote_img_mac.m` | The `img` pictures: keys → the game's own files (RomFS, Yaz0, SARC, BNTX; block-linear RGBA8, BC7 on the GPU) → PNG / JPEG, made by a worker thread on request and kept; where they are is per build (`k_pics`). Nothing of the game is stored |
| `dm/host/hle_scan.c` (`DM_CTL scan …`) | The memory search used to find them: values, ranges, recorded columns matched against screenshots afterwards, 32- and 64-bit pointers, arrays of records by what they hold (`seq`). How: `docs/ingenieria_inversa.md` |
| `dm/host/remote_mac.c` / `.h`, `remote_front.c`, `remote_icon.c`, `remote_mac_int.h` | The UDP socket and its thread and the `DM_REMOTE*` switches; the hooks into the slots, `hle_hid.c`, haptics and the game's keyboard (`dm_remote_text_begin` / `_end`, called by `front_mac.m`); the icon's thumbnail |
| `dm/host/hle_hid.c`, `dm_input.h` | `dm_hid_player_use` / `dm_hid_seats` / `dm_hid_players` / `dm_hid_reads`: what the game makes of each player (from `SetSupportedNpadIdType`) and how often it reads each npad, sent to phones as `info` |
| `dm/host/front_mac.m`, `pad_slots.h` | Player slots shared by the keyboard, physical controllers and phones; Controllers menu; QR window (⌘J) |
| `dm/host/kbd_map.h`, `controls_mac.m` | The configurable keyboard map and its window (⌘K) |
| `dm/host/haptics_apple.m` | `dm_haptics_apple_external`: a phone-owned player's rumble goes to the Wi-Fi receiver |
| `dm/host/tests/t_remote.c`, `t_remote_feed.c` (harness `t_remote.h`), `t_remote_race.c`, `t_remote_img.c`, `t_remote_udp.c`, `t_kbd_map.c` | Host tests (`make -C dm/host/tests GAME=<id> remote`) |
| `dm/tools/remote_phone.py` | Fake phones for checking a host without one (used by `scripts/smoke_host.sh`) |
| `docs/wifi-controllers.md` (in the patch) = `docs/protocol.md` here | The protocol, the host switches and the limits. It is the source of truth. `export_patch.sh` copies it here |

## Rules

- **Every file this repository owns stays under 200 lines** (after `dart format`): the app's `lib/` and `test/`, the scripts, and the files the patch adds to nxnative (`remote_*.h`, `remote_*.c`, `t_remote*`). Split by subject when one grows: a part file or a mixin for one screen, one test file per subject. nxnative's own files that the patch touches (`front_mac.m`, `hle_hid.c`, Makefiles, docs) keep nxnative's style.
- **No game data, ever:** no NSP/XCI, keys, title keys, RomFS, NSO/NCA, shaders, saves or dumps in this repository or the patch. Logs, title IDs, build IDs and offsets are fine. `export_patch.sh` refuses non-source paths and files over 1 MB. Keep that check.
- **No personal signing data:** the Apple team ID lives only in `app/ios/Flutter/Signing.xcconfig`, which git ignores (`install_ios.sh` writes it). Never put `DEVELOPMENT_TEAM` back into `project.pbxproj`.
- **Never edit `host/nxnative.patch` by hand.** Change the code in a patched nxnative checkout (`scripts/setup_nxnative.sh`), build and test it there, then run `scripts/export_patch.sh` and commit the regenerated patch with `docs/protocol.md`.
- **Code inside the patch follows nxnative's rules** (its `AGENTS.md`). They include: English only; red log lines start with `[RED] `; fix root causes rather than working around them; prefer general mechanisms (Horizon / hid semantics) over per-game rules; never use fixed game addresses unless they are gated by build ID; new env switches go into `docs/env_switches.tsv`.
- **Protocol changes:** they are always backward compatible. The host ignores unknown keys and old apps ignore unknown message types. A new host → phone behaviour that an old app could misread is opt-in from the phone's hello (as `"rumble":1`). Change both sides, both test suites and `docs/wifi-controllers.md` in the same change. Keep every host reply within 200 bytes (`rp_reply.text`) and every datagram within 512.
- **The app's UI text is Spanish.** Run `dart format lib test` and keep `flutter analyze` clean.
- **Layouts:** every preset must pass `test/layout_test.dart` on all its screens. The tilt switch, Salir and the settings button take the touches on them, so a preset never puts them in the stick zone or on a button. New parts get a `PadPart`, a `baseSize`, a place in every preset and a name in `partNames`. Lifecycle changes only pause the sensor: never turn off a choice the player made.
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

- Race data (`race`) exists only for Mario Kart 8 Deluxe 4.0.1 (`remote_race.c` `k_race`). Not checked yet: that player n is racer n − 1 in split screen (place and kart). Items come from the item box on screen: player 1 alone only, since split screen has a box per player and which is whose is unknown (the racers' own item slots were not found). A new build or game needs its own row, found with `DM_CTL scan` (`docs/ingenieria_inversa.md`).
- Android is built and unit-tested but has not been run on a phone.
- No automatic discovery (Bonjour) yet: QR or manual IP only. IPv4 only. Traffic is not encrypted: use it on a trusted network.
- The phone pad has no right stick and no stick presses.
