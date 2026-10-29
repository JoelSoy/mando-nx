# Mando NX (remote_pad)

A phone as a controller for nxnative's Mac host over Wi-Fi: a landscape touch gamepad (a floating left stick, A B X Y, L R ZL ZR, + −, D-pad, several fingers at once) that sends its state to the host 59 times a second. The interface is in Spanish. Protocol, host switches and security: [docs/protocol.md](../docs/protocol.md) (nxnative's `docs/wifi-controllers.md` with this repository's patch). Setup in Spanish: [docs/instalacion.md](../docs/instalacion.md).

Flutter, iOS and Android, mobile_scanner for camera QR scanning and sensors_plus for tilt steering (the settings are a small JSON file in the app's private storage, `lib/storage.dart`).

| Folder | What |
|---|---|
| `lib/protocol/` | the messages both ways, their checks, stick normalization (`protocol.dart` exports them) |
| `lib/net/` | the session (hello, heartbeat, rejoin, pause) and the game's feed: rumble, info, roster, keyboard, icon (`client.dart`) |
| `lib/pad/` | layouts and presets, where each control is on a screen, the touch router, the editor (`pad_layout.dart`) |
| `lib/pad/screen/` | the pad screen and its parts, the game card, the settings sheet, the keyboard prompt (`pad_screen.dart`) |
| `lib/motion/` | tilt steering: accelerometer and gyroscope |
| `lib/screens/`, `lib/storage/` | the connect screen and QR scanner; the kept settings and pad preferences |

Every file is under 200 lines.

Permissions: Android `INTERNET` (`android/app/src/main/AndroidManifest.xml`); iOS `NSLocalNetworkUsageDescription` (`ios/Runner/Info.plist`), which iOS asks the player about the first time. Both keep the screen on while the app is in front and lock it to landscape.

## Check

```
flutter pub get   # Flutter's own packages and flutter_lints, from the local pub cache
flutter analyze
flutter test
```

## Build and install

- **iOS:** `../scripts/install_ios.sh` signs with your team (kept in `ios/Flutter/Signing.xcconfig`, which git ignores; see `Signing.xcconfig.example`), builds a release, installs it on the connected iPhone and opens it. In Xcode, `ios/Runner.xcworkspace` takes the same `Signing.xcconfig`.
- **Android:** `flutter build apk --debug`, then install the APK (`flutter install` or `adb install`). The first build downloads Gradle and Android packages.

The gamer interface includes **Probar mando**, an offline demo; the tune icon opens tilt calibration/sensitivity and separate game-rumble/touch-feedback toggles. QR and protocol details are in the linked Wi-Fi guide. To open demo from the iOS simulator: `xcrun simctl launch booted org.nxnative.remotePad --demo`. Physical camera, motion and vibration require device validation.
