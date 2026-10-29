// Mando Wi-Fi: a phone as a controller for nxnative's Mac host over the local network (docs/wifi-controllers.md). Landscape only, the screen in full.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'connect_screen.dart';
import 'storage.dart';
import 'gamer_theme.dart';
import 'native.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  var demo = false;
  try {
    demo = await mandoNative.invokeMethod<bool>('demo') ?? false;
  } on Object {
    /* preview optional */
  }
  runApp(
    MandoApp(store: SettingsStore(SettingsStore.platformDir()), demo: demo),
  );
}

class MandoApp extends StatelessWidget {
  const MandoApp({
    super.key,
    required this.store,
    this.open = openUdp,
    this.haptics = true,
    this.demo = false,
  });
  final SettingsStore store;
  final TransportOpener open;
  final bool haptics;
  final bool demo;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mando NX',
    debugShowCheckedModeBanner: false,
    theme: gamerTheme(),
    home: ConnectScreen(store: store, open: open, haptics: haptics, demo: demo),
  );
}
