import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_pad/main.dart';
import 'package:remote_pad/storage.dart';
import 'package:remote_pad/visual_style.dart';
import 'package:remote_pad/pad/screen/classic_painter.dart';
import 'package:remote_pad/pad/screen/console_shell.dart';

void main() {
  testWidgets(
    'stored gamer skin opens the actual classic painter and changes independently of layouts',
    (t) async {
      t.view.physicalSize = const Size(1704, 786);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final dir = Directory.systemTemp.createTempSync('skin-widget');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = SettingsStore(dir);
      File('${dir.path}/${SettingsStore.fileName}')
          .writeAsStringSync('{"pad":{"style":"gamer"}}');
      expect(store.load().pad.style, VisualStyle.gamer);
      await t.pumpWidget(MandoApp(store: store, demo: true, haptics: false));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is ClassicPadPainter,
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('settings')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 350));
      await t.tap(find.byKey(const Key('skin-console')));
      await t.pump();
      expect(store.load().pad.style, VisualStyle.console);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is ConsoleShell,
        ),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
}
