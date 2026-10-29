import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/client.dart';
import 'package:remote_pad/pad_screen.dart';
import 'package:remote_pad/pad_layout.dart';
import 'package:sensors_plus/sensors_plus.dart';

class Wire implements Transport {
  @override
  void send(List<int> d) {}
  @override
  void close() {}
}

void main() {
  RemoteClient client() => RemoteClient(
    transport: Wire(),
    code: '123456',
    clientId: 'phone12345678',
    name: 'Phone',
    clock: () => 0,
  );
  void size(WidgetTester t) {
    t.view.physicalSize = const Size(1704, 786);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
  }

  testWidgets(
    'visible accelerometer toggle defaults off, toggles and keeps joystick working',
    (t) async {
      size(t);
      final sensor = StreamController<AccelerometerEvent>.broadcast();
      final c = client();
      await t.pumpWidget(
        MaterialApp(
          home: PadScreen(
            client: c,
            haptics: false,
            accelerometer: () => sensor.stream,
          ),
        ),
      );
      final toggle = find.byKey(const Key('tilt-toggle'));
      expect(t.widget<Switch>(toggle).value, false);
      expect(find.text('Acelerómetro'), findsOneWidget);
      await t.tap(toggle);
      await t.pump();
      expect(t.widget<Switch>(toggle).value, true);
      final layout = PadLayout.compute(const Size(852, 393));
      final finger = await t.startGesture(layout.stickHome);
      await finger.moveBy(Offset(-layout.stickRadius, 0));
      expect(c.state.lx, -1);
      await finger.up();
      expect(c.state.lx, 0);
      await t.tap(toggle);
      await t.pump();
      expect(t.widget<Switch>(toggle).value, false);
      expect(c.state.lx, 0);
      await t.tap(find.byKey(const Key('settings')));
      await t.pumpAndSettle();
      expect(find.text('AJUSTES DE MANDO'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      unawaited(sensor.close());
    },
  );
  testWidgets(
    'accelerometer error and absent readings turn toggle off and release steering',
    (t) async {
      size(t);
      final sensor = StreamController<AccelerometerEvent>.broadcast();
      final c = client();
      await t.pumpWidget(
        MaterialApp(
          home: PadScreen(
            client: c,
            haptics: false,
            accelerometer: () => sensor.stream,
          ),
        ),
      );
      final toggle = find.byKey(const Key('tilt-toggle'));
      await t.tap(toggle);
      await t.pump();
      sensor.addError(StateError('unavailable'));
      await t.pump();
      expect(t.widget<Switch>(toggle).value, false);
      expect(c.state.lx, 0);
      expect(
        find.text('Acelerómetro no disponible. Usa el joystick.'),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
      unawaited(sensor.close());
      final silent = StreamController<AccelerometerEvent>.broadcast();
      await t.pumpWidget(
        MaterialApp(
          home: PadScreen(
            client: client(),
            haptics: false,
            accelerometer: () => silent.stream,
          ),
        ),
      );
      await t.tap(toggle);
      await t.pump(const Duration(seconds: 3));
      expect(t.widget<Switch>(toggle).value, false);
      await t.pumpWidget(const SizedBox());
      unawaited(silent.close());
    },
  );
}
