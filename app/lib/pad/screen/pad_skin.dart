import 'package:flutter/material.dart';

import '../../gamer_theme.dart';
import '../../pad_layout.dart';
import 'painter.dart';
import 'classic_painter.dart';

CustomPainter paintPad(
  VisualStyle style,
  PadLayout l,
  TouchRouter r,
  Color color, {
  bool editing = false,
  PadPart? selected,
  Set<Control> hidden = const {},
  Listenable? repaint,
}) => style == VisualStyle.gamer
    ? ClassicPadPainter(
        l,
        r,
        color,
        editing: editing,
        selected: selected,
        hidden: hidden,
        repaint: repaint,
      )
    : PadPainter(
        l,
        r,
        color,
        editing: editing,
        selected: selected,
        hidden: hidden,
        repaint: repaint,
      );
