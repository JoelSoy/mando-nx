import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/client.dart';
import 'package:remote_pad/pad_layout.dart';
import 'package:remote_pad/pad_screen.dart';
import 'package:remote_pad/protocol.dart';
import 'package:remote_pad/storage.dart';

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

  testWidgets(
    'edit: drag A B X Y somewhere else, Listo keeps it as Personalizado and saves',
    (t) async {
      size(t);
      final prefs = PadPrefs();
      var saves = 0;
      final c = client();
      await t.pumpWidget(
        MaterialApp(
          home: PadScreen(
            client: c,
            haptics: false,
            prefs: prefs,
            onPrefsChanged: () => saves++,
          ),
        ),
      );
      await t.tap(find.byKey(const Key('settings')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('edit-layout')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('edit-panel')), findsOneWidget);
      final face = PadLayout.compute(screen).parts[PadPart.face]!.center;
      final g = await t.startGesture(face);
      await t.pump();
      expect(find.text('Editando: A B X Y'), findsOneWidget);
      await g.moveBy(const Offset(-120, -60));
      await t.pump();
      await g.up();
      expect(
        c.state,
        PadState.neutral,
        reason: 'editing sends nothing to the game',
      );
      await t.tap(find.byKey(const Key('edit-done')));
      await t.pump();
      expect(find.byKey(const Key('edit-panel')), findsNothing);
      expect(prefs.layout.name, 'Personalizado');
      expect(prefs.saved.single.name, 'Personalizado');
      expect(saves, greaterThan(0));
      final moved = PadLayout.compute(
        screen,
        config: prefs.layout,
      ).parts[PadPart.face]!.center;
      expect((moved - (face + const Offset(-120, -60))).distance, lessThan(1));
      // and the buttons are pressed where they are drawn now
      final a = PadLayout.compute(
        screen,
        config: prefs.layout,
      ).buttons.firstWhere((b) => b.control == Control.a).center;
      final press = await t.startGesture(a);
      await t.pump();
      expect(c.state.buttons, Btn.a);
      await press.up();
    },
  );

  testWidgets('edit: Cancelar leaves the layout as it was', (t) async {
    size(t);
    final prefs = PadPrefs();
    await t.pumpWidget(
      MaterialApp(
        home: PadScreen(client: client(), haptics: false, prefs: prefs),
      ),
    );
    await t.tap(find.byKey(const Key('settings')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('edit-layout')));
    await t.pumpAndSettle();
    final g = await t.startGesture(
      PadLayout.compute(screen).parts[PadPart.dpad]!.center,
    );
    await g.moveBy(const Offset(80, -80));
    await g.up();
    await t.tap(find.byKey(const Key('edit-cancel')));
    await t.pump();
    expect(identical(prefs.layout, PadConfig.classic), isTrue);
    expect(prefs.saved, isEmpty);
  });

  testWidgets('a preset from the settings sheet is used at once and kept', (
    t,
  ) async {
    size(t);
    final prefs = PadPrefs();
    var saves = 0;
    await t.pumpWidget(
      MaterialApp(
        home: PadScreen(
          client: client(),
          haptics: false,
          prefs: prefs,
          onPrefsChanged: () => saves++,
        ),
      ),
    );
    await t.tap(find.byKey(const Key('settings')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('layout-Zurdo')));
    await t.pump();
    expect(prefs.layout.name, 'Zurdo');
    expect(saves, 1);
  });
}
