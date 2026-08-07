import Foundation

/// The real meteor calendar, in the `Season` pattern: pure date functions,
/// nothing stored, nothing scheduled.
///
/// Three windows a year — Lyrids in April, Perseids in August, Geminids in
/// December. During one, night skies shed slow meteors on breaks and idle,
/// and a night session finished under a shower is a night the star stories
/// remember differently. Missing a shower marks nothing anywhere; the next
/// window simply arrives, because that is what calendars do.
enum ShowerCalendar {

    static func isShowerNight(
        on date: Date = Date(), calendar: Calendar = .current
    ) -> Bool {
        if LaunchOptions.forceShower { return true }
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        switch month {
        case 4: return (19...24).contains(day)    // Lyrids
        case 8: return (9...15).contains(day)     // Perseids
        case 12: return (11...16).contains(day)   // Geminids
        default: return false
        }
    }

    /// Which shower, for the stories.
    static func name(
        on date: Date, calendar: Calendar = .current
    ) -> String? {
        guard isShowerNight(on: date, calendar: calendar) else { return nil }
        switch calendar.component(.month, from: date) {
        case 4: return "the Lyrids"
        case 8: return "the Perseids"
        case 12: return "the Geminids"
        default: return "a falling-star night"
        }
    }
}
