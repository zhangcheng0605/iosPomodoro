// The gesture, on the one platform that has the sensor for it.
//
// There is no accelerometer in a Mac, so there is nothing to detect and no
// sensible fallback — a snow globe you shake by pressing a key is not a snow
// globe. macOS gets a menu item instead; see `PawmodoroApp`. Both call
// `SceneShake.shared.shake()`: one feature, two ways in.
//
// The *name* survives on macOS as an empty view, so the scene that plants one
// in its background does not have to know which platform it is on. That is
// the same rule as `FeedbackStyle` — the vocabulary is shared, only the
// mechanism compiles out.
#if canImport(UIKit)
import SwiftUI
import UIKit

/// Catches a shake and hands it to `SceneShake`.
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
            // The one signal, shared with the Mac's menu item. This used to
            // post its own notification, which made the menu item a button
            // wired to nothing — `SceneShake` existed and only one of the two
            // ways in reached it.
            SceneShake.shared.shake()
        }
    }
}

#else
import SwiftUI

/// Nothing to detect, and nothing drawn. See the note at the top of the file.
struct ShakeDetector: View {
    var body: some View { EmptyView() }
}

#endif
