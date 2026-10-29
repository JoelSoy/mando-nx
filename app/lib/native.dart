import 'package:flutter/services.dart';

const mandoNative = MethodChannel('mando/native');
Future<void> gameRumble(double intensity, double sharpness, int ms) async {
  try {
    await mandoNative.invokeMethod<void>('rumble', {
      'i': intensity,
      's': sharpness,
      'ms': ms,
    });
  } on MissingPluginException {
    /* simulator / tests without haptics */
  } on PlatformException {
    /* hardware not available */
  }
}
