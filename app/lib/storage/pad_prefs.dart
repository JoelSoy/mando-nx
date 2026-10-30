// The pad's kept preferences (storage/settings.dart writes them with the rest).
import '../pad/config.dart';
import '../visual_style.dart';

/// The pad's preferences, kept between runs: the layout in use, the player's own saved layouts (at most maxSaved), tilt steering (its sensitivity, the gyroscope when
/// the phone has one), game rumble and touch feedback.
class PadPrefs {
  PadPrefs({
    this.tilt = false,
    this.style = VisualStyle.console,
    this.sensitivity = 1.6,
    this.gameRumble = true,
    this.touchFeedback = true,
    this.useGyro = true,
    PadConfig? layout,
    List<PadConfig>? saved,
  }) : layout = layout ?? PadConfig.classic,
       saved = saved ?? [];
  static const maxSaved = 6;
  VisualStyle style;
  bool tilt, gameRumble, touchFeedback, useGyro;
  double sensitivity;
  PadConfig layout;
  final List<PadConfig> saved;

  /// Every layout the player can pick: the presets, then their own.
  List<PadConfig> get choices => [...PadConfig.presets, ...saved];

  /// Keeps a layout of the player's under its name (replacing one of the same name; the oldest goes past maxSaved) and makes it the one in use.
  void keep(PadConfig c) {
    final mine = c.named(c.name);
    saved.removeWhere((s) => s.name == mine.name);
    saved.add(mine);
    while (saved.length > maxSaved) {
      saved.removeAt(0);
    }
    layout = mine;
  }

  void forget(String name) {
    saved.removeWhere((s) => s.name == name);
    if (!layout.builtIn && layout.name == name) layout = PadConfig.classic;
  }

  Map<String, Object> toJson() => {
    'style': style.name,
    'tilt': tilt,
    'sensitivity': sensitivity,
    'gameRumble': gameRumble,
    'touchFeedback': touchFeedback,
    'useGyro': useGyro,
    'layout': layout.builtIn ? layout.name : layout.toJson(),
    'saved': [for (final c in saved) c.toJson()],
  };

  factory PadPrefs.fromJson(Object? j) {
    if (j is! Map<String, dynamic>) return PadPrefs();
    bool flag(String k, bool d) => j[k] is bool ? j[k] as bool : d;
    final sens = j['sensitivity'];
    final saved = [
      if (j['saved'] is List)
        for (final e in j['saved'] as List) ?PadConfig.fromJson(e),
    ].take(maxSaved).toList();
    final l = j['layout'];
    PadConfig? layout;
    if (l is String) {
      layout = PadConfig.presets.where((p) => p.name == l).firstOrNull;
    } else {
      final c = PadConfig.fromJson(l);
      layout = c == null
          ? null
          : saved.where((s) => s.name == c.name).firstOrNull ?? c;
    }
    return PadPrefs(
      style: readVisualStyle(j['style']),
      tilt: flag('tilt', false),
      sensitivity: sens is num && sens.isFinite
          ? sens.toDouble().clamp(0.5, 3.0)
          : 1.6,
      gameRumble: flag('gameRumble', true),
      touchFeedback: flag('touchFeedback', true),
      useGyro: flag('useGyro', true),
      layout: layout,
      saved: saved,
    );
  }
}
