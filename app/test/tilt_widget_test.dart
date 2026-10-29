import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/client.dart';
import 'package:remote_pad/pad_layout.dart';
import 'package:remote_pad/pad_screen.dart';
import 'package:remote_pad/storage.dart';
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

  const screen = Size(852, 393);
  AccelerometerEvent ev(double x, double y) =>
      AccelerometerEvent(x, y, 0, DateTime(2026));

  testWidgets(
    'tilt stays chosen through the Control Center and comes back on; the choice is kept for next time',
    (t) async {
      size(t);
      final prefs = PadPrefs();
      var listens = 0;
      final sensor = StreamController<AccelerometerEvent>.broadcast(
        onListen: () => listens++,
      );
      final c = client();
      await t.pumpWidget(
        MaterialApp(
          home: PadScreen(
            client: c,
            haptics: false,
            prefs: prefs,
            accelerometer: () => sensor.stream,
          ),
        ),
      );
      final toggle = find.byKey(const Key('tilt-toggle'));
      await t.tap(toggle);
      await t.pump();
      expect(prefs.tilt, isTrue);
      expect(listens, 1);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      expect(t.widget<Switch>(toggle).value, isTrue, reason: 'not turned off');
      expect(sensor.hasListener, isFalse, reason: 'the sensor rests meanwhile');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(sensor.hasListener, isTrue);
      expect(listens, 2);
      sensor.add(ev(9.8, 0));
      for (var i = 0; i < 20; i++) {
        sensor.add(ev(9.2, 3.3));
      }
      await t.pump();
      expect(c.state.lx, isNot(0));
      await t.pumpWidget(const SizedBox());
      // the next pad starts with tilt on
      final sensor2 = StreamController<AccelerometerEvent>.broadcast();
      await t.pumpWidget(
        MaterialApp(
          home: PadScreen(
            client: client(),
            haptics: false,
            prefs: prefs,
            accelerometer: () => sensor2.stream,
          ),
        ),
      );
      await t.pump();
      expect(
        t.widget<Switch>(find.byKey(const Key('tilt-toggle'))).value,
        isTrue,
      );
      expect(sensor2.hasListener, isTrue);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a stick thumb near the bottom does not reach the tilt switch', (
    t,
  ) async {
    size(t);
    final prefs = PadPrefs();
    final c = client();
    await t.pumpWidget(
      MaterialApp(
        home: PadScreen(client: c, haptics: false, prefs: prefs),
      ),
    );
    final l = PadLayout.compute(screen);
    final g = await t.startGesture(l.stickHome);
    await g.moveTo(
      Offset(l.stickHome.dx, screen.height - 4),
    ); // all the way down to the edge
    await t.pump();
    await g.up();
    await t.tapAt(
      Offset(l.stickZone.left + 10, screen.height - 8),
    ); // a tap low in the stick's corner
    await t.pump();
    expect(prefs.tilt, isFalse);
    expect(
      t.widget<Switch>(find.byKey(const Key('tilt-toggle'))).value,
      isFalse,
    );
  });
}
