import Foundation

/// What time of year it is, if it is any particular time of year at all.
///
/// A pomodoro app that quietly knows it's autumn is a pomodoro app people
/// screenshot. Nothing is unlocked, nothing is earned, nothing is announced —
/// you open it one morning in late October and there are leaves.
///
/// Date-driven and derived, so there is no state: `Season.current()` is a
/// function of the calendar and nothing else — and of `WorldCalendar`'s
/// calendar specifically, so `-PawmodoroDate` moves the season along with
/// everything else the date decides. The windows are northern; that policy
/// lives in `WorldCalendar.hemisphere`, with its reasoning.
enum Season: String, CaseIterable, Identifiable {
    case sakura
    case fireflies
    case autumn
    case winter
    case lanterns

    var id: String { rawValue }

    var name: String {
        switch self {
        case .sakura: "Blossom season"
        case .fireflies: "Firefly nights"
        case .autumn: "Leaf fall"
        case .winter: "Snow"
        case .lanterns: "Lantern days"
        }
    }

    /// Month and day the window opens and closes, inclusive at both ends.
    ///
    /// The lantern window is a deliberate approximation. Lunar New Year moves
    /// between 21 January and 20 February, and computing it properly means
    /// shipping a lunisolar calendar to hang some paper lanterns — so the
    /// window is simply the whole span it can fall in. Better slightly early
    /// than absent.
    var window: (from: (month: Int, day: Int), to: (month: Int, day: Int)) {
        switch self {
        case .lanterns: ((1, 21), (2, 20))
        case .sakura: ((3, 20), (4, 15))
        case .fireflies: ((7, 1), (8, 31))
        case .autumn: ((10, 10), (10, 31))
        case .winter: ((12, 1), (12, 31))
        }
    }

    /// How many particles the layer draws. Kept small on purpose: this is
    /// dressing that runs whenever the app is open, and the anti-goals say no
    /// battery tax.
    var particleCount: Int {
        switch self {
        case .sakura: 14
        case .fireflies: 9
        case .autumn: 12
        case .winter: 16
        case .lanterns: 7
        }
    }

    /// Whether this one only shows after dark. Fireflies in daylight would be
    /// a bug, and lanterns are only worth lighting at night.
    var nightOnly: Bool {
        switch self {
        case .fireflies, .lanterns: true
        case .sakura, .autumn, .winter: false
        }
    }

    /// The last week of October gets bats. This is the only thing in the app
    /// that is a joke, and it is a small one.
    static func hasBats(on date: Date = WorldCalendar.now,
                        calendar: Calendar = WorldCalendar.calendar) -> Bool {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return month == 10 && (24...31).contains(day)
    }

    /// The season today falls in, or nil for most of the year — which is the
    /// point. If it were always some season, none of them would register.
    static func current(on date: Date = WorldCalendar.now,
                        calendar: Calendar = WorldCalendar.calendar) -> Season? {
        if let forced = LaunchOptions.forcedSeason { return forced }
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let today = month * 100 + day
        return allCases.first { season in
            let window = season.window
            let from = window.from.month * 100 + window.from.day
            let to = window.to.month * 100 + window.to.day
            return today >= from && today <= to
        }
    }
}
