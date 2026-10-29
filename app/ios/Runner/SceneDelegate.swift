import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

}

/// The pad's view controller (Main.storyboard): a swipe from an edge (Notification Center, Control Center, the home indicator) needs a second swipe while playing, so
/// a thumb near an edge does not leave the game by accident; the home indicator fades out.
class PadViewController: FlutterViewController {
  override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }
  override var prefersHomeIndicatorAutoHidden: Bool { true }
}
