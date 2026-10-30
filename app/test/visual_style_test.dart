import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/storage.dart';
import 'package:remote_pad/pad_layout.dart';
import 'package:remote_pad/visual_style.dart';

void main() {
  test(
    'fresh preferences use console; saved pre-skin preferences keep gamer',
    () {
      expect(PadPrefs().style, VisualStyle.console);
      expect(PadPrefs.fromJson({'tilt': true}).style, VisualStyle.gamer);
      expect(PadPrefs.fromJson({'style': 'unknown'}).style, VisualStyle.gamer);
    },
  );
  test(
    'skin round trips without changing control layout or motion choices',
    () {
      final p = PadPrefs(
        layout: PadConfig.presets.last,
        tilt: true,
        sensitivity: 2.1,
        useGyro: false,
      );
      for (final skin in VisualStyle.values) {
        p.style = skin;
        final restored = PadPrefs.fromJson(p.toJson());
        expect(restored.style, skin);
        expect(restored.layout.toJson(), p.layout.toJson());
        expect(restored.tilt, true);
        expect(restored.sensitivity, 2.1);
        expect(restored.useGyro, false);
      }
    },
  );
}
