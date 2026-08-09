import SwiftUI
import UIKit
import WidgetKit

/// The buddy on the home screen (Duolingo's lever, Widgetable's proof —
/// minus the guilt half of both).
///
/// v1 is deliberately zero-plumbing: what the widget shows is a pure
/// function of the wall clock and the calendar — asleep at night, up at
/// dawn, Luna keeping her watch after dark, a night-cap in December —
/// exactly like the app's skies. No countdown, no paw counts, **no
/// numbers at all**: nothing on the home screen can ever disappoint.
/// The only shared state is the buddy's identity, read from the App
/// Group suite when it exists and falling back to the cat when it
/// doesn't, so the widget works before the App Group is ever configured.
///
/// Colours are literals here for the same reason they are in the Live
/// Activity: a widget runs in a separate process with no ThemeManager,
/// and these four sky tints are the widget's whole palette.
struct HomeBuddyEntry: TimelineEntry {
    let date: Date
    let buddy: String
}

struct HomeBuddyProvider: TimelineProvider {

    func placeholder(in context: Context) -> HomeBuddyEntry {
        // The gallery and the redacted loading state get the real buddy too,
        // so adding the widget never shows a stranger's cat for a beat.
        entry(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (HomeBuddyEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HomeBuddyEntry>) -> Void) {
        // One entry now, then one at each day-part boundary a couple of
        // days out. The system redraws at each; `.atEnd` asks for a new
        // timeline when they run dry. Nothing here ever needs a refresh
        // faster than the sky changes.
        let now = Date()
        let entries = [entry(at: now)]
            + Self.boundaries(after: now).prefix(8).map { entry(at: $0) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// The App Group suite the app mirrors into. The names are duplicated
    /// from `WidgetMirror` in the app target — the extension is a separate
    /// target and cannot see it without a shared file, which would mean
    /// editing `project.pbxproj`. `WidgetMirror`'s doc comment is the other
    /// half of this pair; change one and change the other.
    private static let suiteName = "group.com.pawmodoro"
    private static let buddyKey = "widget.buddy"

    /// Read at timeline-build time, not at draw time. That is only fresh
    /// because the app calls `WidgetCenter.shared.reloadAllTimelines()` when
    /// the buddy actually moves — without that this went stale until the next
    /// day-part boundary, which is up to nine hours overnight.
    private func entry(at date: Date) -> HomeBuddyEntry {
        let buddy = UserDefaults(suiteName: Self.suiteName)?
            .string(forKey: Self.buddyKey) ?? "cat"
        return HomeBuddyEntry(date: date, buddy: buddy)
    }

    /// The next few day-part boundaries — 5, 8, 17 and 21 o'clock, the
    /// same hours the app's `DayPart` uses. Duplicated rather than shared
    /// because the extension has its own target, and four integers are
    /// not worth a cross-target dependency.
    static func boundaries(after date: Date, calendar: Calendar = .current) -> [Date] {
        var out: [Date] = []
        var day = calendar.startOfDay(for: date)
        while out.count < 8 {
            for hour in [5, 8, 17, 21] {
                if let boundary = calendar.date(
                    bySettingHour: hour, minute: 0, second: 0, of: day
                ), boundary > date {
                    out.append(boundary)
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day)
            else { break }
            day = next
        }
        return out
    }
}

struct HomeBuddyView: View {
    let entry: HomeBuddyEntry

    private var hour: Int {
        Calendar.current.component(.hour, from: entry.date)
    }

    private var isNight: Bool { hour >= 21 || hour < 5 }

    private var isDecember: Bool {
        Calendar.current.component(.month, from: entry.date) == 12
    }

    /// Asleep at night — except Luna, who keeps the watch she keeps in
    /// the app — and up the rest of the day. `WidgetSprite` holds both that
    /// rule and the degrade-to-the-cat fallback, because the Live Activity
    /// needs exactly the same two and a second copy would be a second
    /// answer to the same question.
    private var assetName: String {
        WidgetSprite.buddy(entry.buddy, asleep: isNight)
    }

    var body: some View {
        ZStack {
            Image(assetName)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
            // Seasonal dressing: a night-cap for December nights. Luna
            // is on watch, not in bed, so she never wears it.
            if isDecember, isNight, entry.buddy != "owl",
               UIImage(named: "widget_nightcap") != nil {
                Image("widget_nightcap")
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36)
                    .offset(x: 4, y: -28)
            }
        }
        .containerBackground(for: .widget) { sky }
        .accessibilityLabel(accessibilityLine)
    }

    /// The sky behind the buddy follows the same clock the buddy does.
    private var sky: Color {
        switch hour {
        case 5..<8: Color(red: 0.99, green: 0.90, blue: 0.83)   // dawn
        case 8..<17: Color(red: 0.99, green: 0.96, blue: 0.89)  // day
        case 17..<21: Color(red: 0.95, green: 0.85, blue: 0.80) // dusk
        default: Color(red: 0.16, green: 0.19, blue: 0.31)      // night
        }
    }

    private var accessibilityLine: String {
        if isNight {
            return entry.buddy == "owl"
                ? "Your buddy, keeping the night watch"
                : "Your buddy, asleep for the night"
        }
        return "Your buddy, up and about"
    }
}

struct PawmodoroHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "PawmodoroHomeBuddy",
            provider: HomeBuddyProvider()
        ) { entry in
            HomeBuddyView(entry: entry)
        }
        .configurationDisplayName("Your buddy")
        .description("Asleep at night, up with the sun. No numbers, no nagging.")
        .supportedFamilies([.systemSmall])
    }
}
