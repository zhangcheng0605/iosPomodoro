// iOS only, in the strongest sense: the whole file compiles out.
//
// There is no accelerometer in a Mac, so there is nothing to detect and no
// sensible fallback — a snow globe you shake by pressing a key is not a snow
// globe. macOS gets a menu item instead; see `PawmodoroApp`.
#if canImport(UIKit)
import SwiftUI
import UIKit

extension Notification.Name {
    /// Posted when the phone is shaken. One notification rather than a binding
    /// because several layers may want to react and none of them owns the
    /// gesture.
    static let pawmodoroShake = Notification.Name("pawmodoro.shake")
}

/// Catches a shake and turns it into a notification.
///
/// A first-responder view controller rather than the usual trick of overriding
/// `motionEnded` in an extension on `UIWindow`: Swift does not properly allow
/// overriding a method in an extension, and the version of that hack which
/// compiles today is the kind that stops compiling later.
///
/// Zero size, no drawing, no hit testing — it exists only to be in the
/// responder chain.
struct ShakeDetector: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ShakeViewController {
        ShakeViewController()
    }

    func updateUIViewController(_ controller: ShakeViewController, context: Context) {}

    final class ShakeViewController: UIViewController {
        override var canBecomeFirstResponder: Bool { true }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            becomeFirstResponder()
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            resignFirstResponder()
        }

        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            guard motion == .motionShake else { return }
            NotificationCenter.default.post(name: .pawmodoroShake, object: nil)
        }
    }
}

#endif
