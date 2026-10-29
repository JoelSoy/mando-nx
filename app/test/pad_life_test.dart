import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/client.dart';
import 'package:remote_pad/pad_layout.dart';
import 'package:remote_pad/pad_screen.dart';
import 'package:remote_pad/protocol.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'client_fakes.dart';

const png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

void main() {
  late FakeTransport t;
  late RemoteClient c;
  Future<void> pad(
    WidgetTester w, {
    Stream<AccelerometerEvent> Function()? acc,
  }) async {
    w.view.physicalSize = const Size(1704, 786);
    w.view.devicePixelRatio = 2;
    addTearDown(w.view.reset);
    t = FakeTransport();
    c = RemoteClient(
      transport: t,
      code: '482913',
      clientId: 'phoneid123456789',
      name: 'Ana',
      clock: () => 0,
    )..start();
    await w.pumpWidget(
      MaterialApp(
        home: PadScreen(
          client: c,
          haptics: false,
          accelerometer: acc,
          gyroscope: () => const Stream.empty(),
        ),
      ),
    );
    c.receive(j({'v': 1, 't': 'welcome', 'sid': sid, 'player': 2}));
    await w.pump();
  }

  testWidgets(
    'a held button stays pressed through the Control Center; the background lets it go',
    (w) async {
      await pad(w);
      final a = PadLayout.compute(const Size(852, 393)).buttons
          .firstWhere((b) => b.control == Control.a)
          .center;
      final g = await w.startGesture(a);
      await w.pump();
      expect(c.state.buttons, Btn.a);
      w.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await w.pump();
      expect(c.state.buttons, Btn.a, reason: 'the finger is still down');
      w.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await g.moveBy(const Offset(1, 0));
      await w.pump();
      expect(c.state.buttons, Btn.a);
      w.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      w.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await w.pump();
      expect(c.state.buttons, 0);
      w.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await g.up();
      await w.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a sensor that stops says so without covering the buttons', (
    w,
  ) async {
    await pad(
      w,
      acc: () => StreamController<AccelerometerEvent>.broadcast().stream,
    );
    await w.tap(find.byKey(const Key('tilt-toggle')));
    await w.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('toast')), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    final b = PadLayout.compute(const Size(852, 393)).buttons
        .firstWhere((b) => b.control == Control.b)
        .center;
    final g = await w.startGesture(b);
    await w.pump();
    expect(
      c.state.buttons,
      Btn.b,
      reason: 'the bottom buttons still take presses',
    );
    await g.up();
    await w.pump(const Duration(seconds: 4));
    await w.pumpWidget(const SizedBox());
  });
}
