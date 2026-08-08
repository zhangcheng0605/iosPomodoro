import SwiftUI
import WidgetKit

/// The extension's single entry point.
///
/// Xcode's template vended three samples ("Time", "Favorite Emoji", a control
/// that starts a timer that does not exist). They are gone; this vends the two
/// real widgets Phase Z was written for. There is exactly one `@main` in the
/// extension, and it lives here rather than beside either widget.
@main
struct PawmodoroWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PawmodoroHomeWidget()
        PawmodoroLiveActivity()
    }
}
