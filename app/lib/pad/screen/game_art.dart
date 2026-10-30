// The game's pictures on the pad itself (net/game_images.dart): the course's picture on the screen between the controls (RaceScreen), the character's face on
// the stick's knob (it moves with it) and the held item on L, the button that uses it, in place of its letter (the pad painters leave that label out: hidden).
// Face and item are decoded once into images (artImages) and drawn by a foreground painter that repaints with the touches, over either skin.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../client.dart';
import '../../pad_layout.dart';
import '../../protocol.dart';

/// The race's pictures the pad shows, once here: the course's (the screen), the character's face, the item held in the first slot
(Uint8List?, Uint8List?, Uint8List?) raceArt(GameImages client, RaceInfo? r) =>
    r == null
    ? (null, null, null)
    : (
        client.picture(r.coursePicture),
        client.picture(r.driverPicture),
        client.picture(r.itemPicture(r.item)),
      );

/// Pictures decoded for painting, by their bytes (the client keeps one list per picture); it notifies when one is ready
class ArtImages extends ChangeNotifier {
  final Map<Uint8List, ui.Image> _done = {};
  final Set<Uint8List> _busy = {};

  ui.Image? of(Uint8List? bytes) {
    if (bytes == null) return null;
    final image = _done[bytes];
    if (image == null && _busy.add(bytes)) _decode(bytes);
    return image;
  }

  Future<void> _decode(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      _done[bytes] = (await codec.getNextFrame()).image;
      notifyListeners();
    } catch (_) {
      // not a picture: it stays out
    }
  }
}

final artImages = ArtImages();

class GameArtPainter extends CustomPainter {
  GameArtPainter(
    this.layout,
    this.router, {
    this.face,
    this.item,
    super.repaint,
  });
  final PadLayout layout;
  final TouchRouter router;
  final Uint8List? face, item; // pictures, painted once artImages has them

  static void draw(Canvas c, ui.Image image, Rect to) => c.drawImageRect(
    image,
    Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
    to,
    Paint()..filterQuality = FilterQuality.medium,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final f = artImages.of(face);
    if (f != null) {
      final r = layout.stickRadius * .4, knob = router.stickKnob;
      canvas.save();
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: knob, radius: r)),
      );
      canvas.drawCircle(knob, r, Paint()..color = const Color(0xFFE9EEF3));
      draw(canvas, f, Rect.fromCircle(center: knob, radius: r * 1.05));
      canvas.restore();
      canvas.drawCircle(
        knob,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: .7),
      );
    }
    final i = artImages.of(item);
    final l = layout.buttons.where((b) => b.control == Control.l).firstOrNull;
    if (i != null && l != null) {
      final side = l.rect.shortestSide * .86,
          down = router.pressed.contains(Control.l) ? 1.0 : 0.0;
      draw(
        canvas,
        i,
        Rect.fromCenter(
          center: l.center.translate(0, down),
          width: side,
          height: side,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(GameArtPainter old) =>
      old.face != face ||
      old.item != item ||
      old.layout != layout ||
      old.router != router;
}

/// The screen between the controls (the console skin's middle panel; the same place in the classic one) showing the course's picture, darker at the top and the
/// bottom so what is over it stays readable
class RaceScreen extends StatelessWidget {
  const RaceScreen({super.key, required this.picture});
  final Uint8List picture;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Stack(
      children: [
        Positioned.fromRect(
          rect: Rect.fromLTWH(
            box.maxWidth * .3,
            10,
            box.maxWidth * .4,
            box.maxHeight - 20,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: .6,
                  child: Image.memory(
                    picture,
                    key: const Key('race-screen'),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xF0171A20),
                        Color(0x40171A20),
                        Color(0x40171A20),
                        Color(0xF0171A20),
                      ],
                      stops: [0, .32, .68, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
