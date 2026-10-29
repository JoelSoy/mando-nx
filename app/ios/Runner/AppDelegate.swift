import Flutter
import UIKit
import CoreHaptics

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var rumbleEngine: CHHapticEngine?
  private var rumblePlayer: CHHapticPatternPlayer?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // A controller: the screen must not dim or lock while playing
    application.isIdleTimerDisabled = true
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "mando/native", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      if call.method == "demo" { result(ProcessInfo.processInfo.arguments.contains("--demo") || ProcessInfo.processInfo.environment["MANDO_DEMO"] == "1"); return }
      guard call.method == "rumble", let a = call.arguments as? [String: Any] else { result(FlutterMethodNotImplemented); return }
      guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { result(nil); return }
      do {
        try self.rumblePlayer?.stop(atTime: 0)
        let i = min(1, max(0, (a["i"] as? NSNumber)?.floatValue ?? 0))
        let s = min(1, max(0, (a["s"] as? NSNumber)?.floatValue ?? 0))
        let ms = min(1000, max(0, (a["ms"] as? NSNumber)?.doubleValue ?? 0))
        if i > 0 && ms > 0 {
          if self.rumbleEngine == nil { self.rumbleEngine = try CHHapticEngine() }
          try self.rumbleEngine?.start()
          let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [CHHapticEventParameter(parameterID: .hapticIntensity,value:i), CHHapticEventParameter(parameterID: .hapticSharpness,value:s)],relativeTime:0,duration:ms/1000)
          self.rumblePlayer = try self.rumbleEngine?.makePlayer(with: CHHapticPattern(events:[event],parameters:[]))
          try self.rumblePlayer?.start(atTime:0)
        }
        result(nil)
      } catch { self.rumbleEngine=nil; result(FlutterError(code:"haptics",message:"Haptics unavailable",details:nil)) }
    }
  }
}
