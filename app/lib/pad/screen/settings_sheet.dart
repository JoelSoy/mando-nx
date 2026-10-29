// The pad's settings sheet: the layouts (presets and the player's own, used at once; the player's can be deleted), the editor, tilt steering (sensitivity, centre,
// the gyroscope), game rumble and touch feedback. Each change is kept (PadPrefs) through the pad screen (PadSettingsHost).
import 'package:flutter/material.dart';

import '../../client.dart';
import '../../motion/steering.dart';
import '../../pad_layout.dart';
import '../../storage.dart';

abstract interface class PadSettingsHost {
  PadPrefs get prefs;
  RemoteClient get client;
  Steering get steering;
  bool get steeringOn; // the player chose tilt steering
  bool get gyroActive; // the gyroscope is steering now
  void setTilt(bool on);
  void setUseGyro(bool on);
  void useLayout(PadConfig c);
  void forgetLayout(String name);
  void startEditing();
  void saved(); // a preference changed: keep it
}

void showPadSettings(BuildContext context, PadSettingsHost h) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  "AJUSTES DE MANDO",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Diseño de los botones",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final c in h.prefs.choices)
                    InputChip(
                      key: Key('layout-${c.name}'),
                      label: Text(c.name),
                      selected:
                          h.prefs.layout.name == c.name &&
                          h.prefs.layout.builtIn == c.builtIn,
                      onPressed: () => update(() => h.useLayout(c)),
                      onDeleted: c.builtIn
                          ? null
                          : () => update(() => h.forgetLayout(c.name)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                key: const Key('edit-layout'),
                onPressed: () {
                  Navigator.pop(context);
                  h.startEditing();
                },
                icon: const Icon(Icons.open_with_rounded),
                label: const Text("Personalizar botones (posición y tamaño)"),
              ),
              const Divider(height: 28),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Volante por inclinación"),
                subtitle: Text(
                  h.steeringOn
                      ? "${h.gyroActive ? "Con giroscopio (más preciso)." : "Con acelerómetro."} El joystick tiene prioridad."
                      : "Gira el teléfono como un volante. El joystick tiene prioridad.",
                ),
                value: h.steeringOn,
                onChanged: (v) => update(() => h.setTilt(v)),
              ),
              SwitchListTile(
                key: const Key('use-gyro'),
                contentPadding: EdgeInsets.zero,
                title: const Text("Usar el giroscopio si el teléfono lo tiene"),
                subtitle: const Text(
                  "Más preciso y estable; sin él, solo el acelerómetro.",
                ),
                value: h.prefs.useGyro,
                onChanged: (v) => update(() => h.setUseGyro(v)),
              ),
              Row(
                children: [
                  const Text("Sensibilidad"),
                  Expanded(
                    child: Slider(
                      value: h.steering.sensitivity,
                      min: .5,
                      max: 3,
                      onChanged: (v) =>
                          update(() => h.steering.sensitivity = v),
                      onChangeEnd: (v) {
                        h.prefs.sensitivity = v;
                        h.saved();
                      },
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: h.steering.calibrate,
                icon: const Icon(Icons.center_focus_strong),
                label: const Text("Centrar volante"),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Vibración del juego"),
                value: h.client.gameRumbleEnabled,
                onChanged: (v) => update(() {
                  h.client.setGameRumble(v);
                  h.prefs.gameRumble = v;
                  h.saved();
                }),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Respuesta al tocar"),
                value: h.prefs.touchFeedback,
                onChanged: (v) => update(() {
                  h.prefs.touchFeedback = v;
                  h.saved();
                }),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
