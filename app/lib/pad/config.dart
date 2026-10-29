// Where the player puts each part of the pad and how big it is: a PadConfig is the centre of every part as a fraction of the screen's safe area (0 left / top, 1 right /
// bottom) and its size relative to the part's normal size. Fractions keep a layout working on every screen; sizes follow the layout unit (pad_layout.dart). Built-in presets
// (Clásico is the default) and the player's own saved layouts are both PadConfigs, kept as JSON with the other pad preferences (storage.dart).

/// The parts the player can move and resize. Buttons that belong together move together: the D-pad, the four face buttons.
enum PadPart { stick, dpad, face, zl, l, zr, r, minus, plus, tilt, exit, menu }

const Map<PadPart, String> partNames = {
  PadPart.stick: 'Joystick',
  PadPart.dpad: 'Cruceta',
  PadPart.face: 'A B X Y',
  PadPart.zl: 'ZL',
  PadPart.l: 'L',
  PadPart.zr: 'ZR',
  PadPart.r: 'R',
  PadPart.minus: '−',
  PadPart.plus: '+',
  PadPart.tilt: 'Inclinación',
  PadPart.exit: 'Salir',
  PadPart.menu: 'Ajustes',
};

const double minScale = 0.5, maxScale = 2.0;

class PartPlace {
  const PartPlace(this.x, this.y, [this.scale = 1]);
  final double x, y, scale;
  PartPlace copyWith({double? x, double? y, double? scale}) => PartPlace(
    (x ?? this.x).clamp(0.0, 1.0),
    (y ?? this.y).clamp(0.0, 1.0),
    (scale ?? this.scale).clamp(minScale, maxScale),
  );
  List<double> toJson() => [_r(x), _r(y), _r(scale)];
  static double _r(double v) => (v * 1000).roundToDouble() / 1000;
  @override
  bool operator ==(Object other) =>
      other is PartPlace &&
      other.x == x &&
      other.y == y &&
      other.scale == scale;
  @override
  int get hashCode => Object.hash(x, y, scale);
}

class PadConfig {
  const PadConfig(this.name, this.parts, {this.builtIn = false});
  final String name;
  final Map<PadPart, PartPlace> parts;
  final bool builtIn;

  PartPlace operator [](PadPart p) => parts[p] ?? classic.parts[p]!;
  PadConfig withPart(PadPart p, PartPlace place) =>
      PadConfig(name, {...parts, p: place});
  PadConfig named(String n, {bool builtIn = false}) =>
      PadConfig(n, parts, builtIn: builtIn);
  bool samePlaces(PadConfig o) => PadPart.values.every((p) => this[p] == o[p]);

  Map<String, Object> toJson() => {
    'name': name,
    for (final p in PadPart.values) p.name: this[p].toJson(),
  };

  /// A layout from JSON; parts that are missing or wrong take their place in Clásico. Null when it is not a layout at all.
  static PadConfig? fromJson(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    final name = j['name'] is String && (j['name'] as String).trim().isNotEmpty
        ? (j['name'] as String).trim()
        : 'Personalizado';
    final parts = <PadPart, PartPlace>{};
    for (final p in PadPart.values) {
      final v = j[p.name];
      if (v is List &&
          v.length == 3 &&
          v.every((e) => e is num && e.isFinite)) {
        final n = v.cast<num>();
        parts[p] = PartPlace(
          n[0].toDouble().clamp(0.0, 1.0),
          n[1].toDouble().clamp(0.0, 1.0),
          n[2].toDouble().clamp(minScale, maxScale),
        );
      }
    }
    return PadConfig(name.length > 24 ? name.substring(0, 24) : name, parts);
  }

  /// The default: shoulders in the top corners, Salir and the settings beside them, − and + at the top, the stick bottom left, the D-pad beside it, A B X Y bottom
  /// right, the tilt switch alone in the middle at the bottom, out of the stick's way.
  static const classic = PadConfig('Clásico', {
    PadPart.zl: PartPlace(0.103, 0.106),
    PadPart.l: PartPlace(0.103, 0.254),
    PadPart.zr: PartPlace(0.897, 0.106),
    PadPart.r: PartPlace(0.897, 0.254),
    PadPart.minus: PartPlace(0.366, 0.106),
    PadPart.plus: PartPlace(0.634, 0.106),
    PadPart.stick: PartPlace(0.154, 0.683),
    PadPart.dpad: PartPlace(0.391, 0.660),
    PadPart.face: PartPlace(0.825, 0.641),
    PadPart.tilt: PartPlace(0.5, 0.935),
    PadPart.exit: PartPlace(0.262, 0.106),
    PadPart.menu: PartPlace(0.738, 0.106),
  }, builtIn: true);

  /// Mario Kart: a bigger stick, bigger A (accelerate) and B, a bigger R (drift) and L (item); a smaller D-pad and − +.
  static final marioKart = PadConfig('Mario Kart', {
    ...classic.parts,
    PadPart.stick: const PartPlace(0.155, 0.67, 1.15),
    PadPart.face: const PartPlace(0.81, 0.63, 1.15),
    PadPart.r: const PartPlace(0.88, 0.27, 1.2),
    PadPart.l: const PartPlace(0.12, 0.27, 1.2),
    PadPart.zr: const PartPlace(0.90, 0.10, 0.9),
    PadPart.zl: const PartPlace(0.10, 0.10, 0.9),
    PadPart.dpad: const PartPlace(0.40, 0.66, 0.8),
    PadPart.minus: const PartPlace(0.37, 0.10, 0.85),
    PadPart.plus: const PartPlace(0.63, 0.10, 0.85),
  }, builtIn: true);

  /// Zurdo (left-handed): the stick on the right, A B X Y and the D-pad on the left; the shoulders stay on their sides, as on the controller.
  static final leftHanded = PadConfig('Zurdo', {
    ...classic.parts,
    for (final p in const [PadPart.stick, PadPart.dpad, PadPart.face])
      p: PartPlace(1 - classic[p].x, classic[p].y, classic[p].scale),
  }, builtIn: true);

  /// Grande: everything a little bigger, for big thumbs or a tablet held far away.
  static final big = PadConfig('Grande', {
    ...classic.parts,
    PadPart.stick: const PartPlace(0.15, 0.67, 1.1),
    PadPart.face: const PartPlace(0.81, 0.64, 1.15),
    PadPart.dpad: const PartPlace(0.41, 0.66),
    PadPart.zl: const PartPlace(0.11, 0.11, 1.1),
    PadPart.l: const PartPlace(0.11, 0.26, 1.1),
    PadPart.zr: const PartPlace(0.89, 0.11, 1.1),
    PadPart.r: const PartPlace(0.89, 0.26, 1.1),
  }, builtIn: true);

  static final presets = [classic, marioKart, leftHanded, big];
}
