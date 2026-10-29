// A layout (config.dart) on a real landscape screen: every button, the floating stick's home, radius and zone, and each part's outline, inside the safe area (the notch,
// the home indicator). Positions go through placement.dart; sizes follow the layout unit. partAt / placeAt are for the editor (editor.dart).
import 'dart:math' as math;
import 'dart:ui';

import 'config.dart';
import 'controls.dart';
import 'placement.dart';

class PadLayout {
  PadLayout._(
    this.size,
    this.buttons,
    this.stickZone,
    this.stickHome,
    this.stickRadius,
    this.parts,
    this.safe,
    this.config,
  );
  final Size size;
  final List<PadButton> buttons;
  final Rect stickZone;
  final Offset stickHome;
  final double stickRadius;

  /// Each part's outline (the stick: its circle at home; the tilt switch, Salir and the settings button: where their widgets go)
  final Map<PadPart, Rect> parts;

  /// The safe area the fractions of the config are of
  final Rect safe;
  final PadConfig config;

  /// The layout's unit: a tenth of the height, or an eighteenth of the width on a wide screen.
  double get unit => math.min(size.height / 10, size.width / 18);

  /// The normal size of each part in units, before its scale
  static const Map<PadPart, Size> baseSize = {
    PadPart.zl: Size(3.2, 1.2),
    PadPart.l: Size(3.2, 1.2),
    PadPart.zr: Size(3.2, 1.2),
    PadPart.r: Size(3.2, 1.2),
    PadPart.minus: Size(1.1, 1.1),
    PadPart.plus: Size(1.1, 1.1),
    PadPart.dpad: Size(3.15, 3.15),
    PadPart.face: Size(4.5, 4.5),
    PadPart.stick: Size(4.0, 4.0),
    PadPart.tilt: Size(3.4, 1.0),
    PadPart.exit: Size(2.0, 1.0),
    PadPart.menu: Size(1.1, 1.1),
  };

  /// The layout for a landscape screen of this size, inside its safe area (the notch, the home indicator), with the parts where config puts them.
  factory PadLayout.compute(
    Size size, {
    double safeLeft = 0,
    double safeRight = 0,
    double safeBottom = 0,
    PadConfig config = PadConfig.classic,
  }) {
    final w = size.width, h = size.height;
    final u = math.min(h / 10, w / 18); // = unit
    final safe = Rect.fromLTRB(safeLeft, 0, w - safeRight, h - safeBottom);
    double k(PadPart p) => config[p].scale * u;
    Size sizeOf(PadPart p) =>
        Size(baseSize[p]!.width * k(p), baseSize[p]!.height * k(p));
    // each part's centre, kept so that the whole part is inside the safe area
    Offset at(PadPart p) {
      final half = sizeOf(p) / 2;
      return Offset(
        keepInside(
          toPixels(config[p].x, safe.left, safe.right, refWidth * u, 3 * u),
          safe.left,
          safe.right,
          half.width,
        ),
        keepInside(
          toPixels(config[p].y, safe.top, safe.bottom, refHeight * u, 2 * u),
          safe.top,
          safe.bottom,
          half.height,
        ),
      );
    }

    Rect circle(Offset c, double r) => Rect.fromCircle(center: c, radius: r);
    final parts = <PadPart, Rect>{
      for (final p in PadPart.values)
        p: Rect.fromCenter(
          center: at(p),
          width: sizeOf(p).width,
          height: sizeOf(p).height,
        ),
    };
    final b = <PadButton>[
      // shoulders: ZL / ZR on top, L / R under them by default
      PadButton(Control.zl, 'ZL', parts[PadPart.zl]!),
      PadButton(Control.l, 'L', parts[PadPart.l]!),
      PadButton(Control.zr, 'ZR', parts[PadPart.zr]!),
      PadButton(Control.r, 'R', parts[PadPart.r]!),
      // − and + at the top, either side of the status in the middle
      PadButton(
        Control.minus,
        '−',
        circle(at(PadPart.minus), 0.55 * k(PadPart.minus)),
        round: true,
      ),
      PadButton(
        Control.plus,
        '+',
        circle(at(PadPart.plus), 0.55 * k(PadPart.plus)),
        round: true,
      ),
    ];
    // the D-pad
    final dc = at(PadPart.dpad), ds = 1.05 * k(PadPart.dpad);
    Rect cell(double dx, double dy) =>
        Rect.fromCenter(center: dc.translate(dx, dy), width: ds, height: ds);
    b
      ..add(PadButton(Control.up, '▲', cell(0, -ds)))
      ..add(PadButton(Control.down, '▼', cell(0, ds)))
      ..add(PadButton(Control.left, '◀', cell(-ds, 0)))
      ..add(PadButton(Control.right, '▶', cell(ds, 0)));
    // A B X Y as on the Switch: A right, B bottom, X top, Y left
    final fc = at(PadPart.face),
        off = 1.4 * k(PadPart.face),
        br = 0.85 * k(PadPart.face);
    b
      ..add(
        PadButton(
          Control.a,
          'A',
          circle(fc.translate(off, 0), br),
          round: true,
        ),
      )
      ..add(
        PadButton(
          Control.b,
          'B',
          circle(fc.translate(0, off), br),
          round: true,
        ),
      )
      ..add(
        PadButton(
          Control.x,
          'X',
          circle(fc.translate(0, -off), br),
          round: true,
        ),
      )
      ..add(
        PadButton(
          Control.y,
          'Y',
          circle(fc.translate(-off, 0), br),
          round: true,
        ),
      );
    // the stick: floating inside a zone around its home, as big as the stick allows a full tilt from anywhere in it
    final stickRadius = 2.0 * k(PadPart.stick);
    final stickHome = at(PadPart.stick);
    // (a bigger stick does not widen the zone until it needs to, so it does not reach the parts around it)
    final zs = math.min(config[PadPart.stick].scale, 1.0) * u;
    final stickZone = Rect.fromCenter(
      center: stickHome,
      width: math.max(5.9 * zs, 2.4 * stickRadius),
      height: math.max(6.6 * zs, 2.7 * stickRadius),
    ).intersect(Offset.zero & size);
    return PadLayout._(
      size,
      b,
      stickZone,
      stickHome,
      stickRadius,
      parts,
      safe,
      config,
    );
  }

  /// The button under p: of those whose touch area holds it, the one with the nearest centre.
  PadButton? buttonAt(Offset p) {
    PadButton? best;
    var bd = double.infinity;
    for (final b in buttons) {
      if (!b.hits(p)) continue;
      final d = (p - b.center).distance;
      if (d < bd) {
        bd = d;
        best = b;
      }
    }
    return best;
  }
}
