import Foundation

/// The one opinion about what "today" is.
///
/// Nine features in the Deep Time plan are functions of the date — weather,
/// tides, migrations, the snail, anniversaries, the rain ledger. Each one is a
/// chance to invent a *slightly* different answer to "which day is it", and
/// the day those answers disagree is the day the sky says Tuesday and the
/// tide says Monday. So they all come here instead.
///
/// Three things live in this file and nowhere else:
///
/// 1. **What day it is** — `now` and `today`, both honouring
///    `-PawmodoroDate`, so one flag moves the whole world at once.
/// 2. **Which hemisphere the world is in** — northern, always. See
///    `hemisphere` for why that is a design decision rather than an oversight.
/// 3. **`seed(day:place:)`** — the deterministic day-to-noise function every
///    rolled-per-day feature draws from.
///
/// A note on `seed`: it deliberately does not use Swift's `Hasher`, whose
/// output is randomised per process — a weather that changed every time you
/// reopened the app would be the exact opposite of the point. This is a plain
/// FNV-1a, written out, and it is a **compatibility contract**: changing it
/// silently rewrites everybody's past and future weather, so don't.
enum WorldCalendar {

    /// One calendar, so nobody quietly uses a different one.
    static var calendar: Calendar { Calendar.current }

    /// The current moment, in the world's terms.
    ///
    /// With `-PawmodoroDate` set, the *day* moves but the clock keeps
    /// ticking: the pinned day's start plus however far through today we
    /// actually are. That keeps `DayPart` honest — pinning the date to a
    /// solstice shouldn't also freeze the sun at midnight — and leaves
    /// `-PawmodoroClock` as the only thing that pins the hour.
    static var now: Date {
        guard let pinned = LaunchOptions.pinnedDay else { return Date() }
        let real = Date()
        let sinceMidnight = real.timeIntervalSince(calendar.startOfDay(for: real))
        return pinned.addingTimeInterval(sinceMidnight)
    }

    /// Midnight at the start of the current world day, in the local time zone.
    ///
    /// Local, not UTC, and deliberately: a session finished at 11pm belongs to
    /// the day you felt you were in, and every screen that groups by day —
    /// the streak, the stats chart, the year ring — already agrees with that.
    /// The cost is that flying across the date line can give you a short day
    /// or a long one. The sky has always had this property; so does this.
    static var today: Date { startOfDay(now) }

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Whole days between two dates, counted by calendar day rather than by
    /// 86,400-second blocks — so a day that lost an hour to daylight saving is
    /// still one day.
    static func days(from: Date, to: Date) -> Int {
        calendar.dateComponents(
            [.day], from: startOfDay(from), to: startOfDay(to)
        ).day ?? 0
    }

    /// Days since a fixed epoch, which is what `seed` actually hashes.
    /// 2020-01-01 local. Any stable origin would do; this one keeps the
    /// numbers small and readable in a debugger.
    static func dayNumber(_ date: Date = now) -> Int {
        days(from: Date(timeIntervalSince1970: 1_577_836_800), to: date)
    }

    // MARK: Hemisphere

    /// The world is northern, everywhere, for everybody.
    ///
    /// This is a decision, not a bug. The seasons were written as northern
    /// windows — blossom in April, leaf fall in October — and the scenery,
    /// the music and half the journal's species were drawn to match. Flipping
    /// them for southern users would put the app's whole visual identity six
    /// months out of step with itself for the sake of literalism, and the
    /// world is explicitly *not* a mirror of the reader's own (there is no
    /// location permission here and never will be).
    ///
    /// It lives here as a named constant so that the day somebody wants to
    /// revisit it, there is exactly one place to look — and so that no
    /// feature quietly invents a second policy.
    static let hemisphere: Hemisphere = .northern

    enum Hemisphere { case northern, southern }

    // MARK: The seed

    /// A stable 64-bit seed for one day in one place.
    ///
    /// `salt` separates features that would otherwise agree by accident: the
    /// weather and the tide both asking for (today, harbor) should not get
    /// the same number and move together.
    static func seed(day: Date = today, place: Place, salt: String = "") -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325          // FNV-1a offset basis
        func feed(_ bytes: some Sequence<UInt8>) {
            for byte in bytes {
                hash ^= UInt64(byte)
                hash = hash &* 0x1000_0000_01b3            // FNV prime
            }
        }
        feed(String(dayNumber(day)).utf8)
        feed([0x7c])                                       // "|"
        feed(place.rawValue.utf8)
        feed([0x7c])
        feed(salt.utf8)
        return mix(hash)
    }

    /// A uniform value in 0..<1 from the same inputs — what most callers
    /// actually want.
    static func roll(day: Date = today, place: Place, salt: String = "") -> Double {
        // Top 53 bits: exactly the mantissa a Double can hold without
        // rounding, so the distribution stays flat.
        Double(seed(day: day, place: place, salt: salt) >> 11) / Double(1 << 53)
    }

    /// Picks one element deterministically for a day and place.
    static func pick<T>(
        _ options: [T], day: Date = today, place: Place, salt: String = ""
    ) -> T? {
        guard !options.isEmpty else { return nil }
        let index = Int(seed(day: day, place: place, salt: salt) % UInt64(options.count))
        return options[index]
    }

    /// splitmix64's finaliser. FNV-1a alone leaves neighbouring inputs
    /// correlated in the low bits, which would make consecutive days look
    /// suspiciously alike — this scatters them.
    private static func mix(_ value: UInt64) -> UInt64 {
        var z = value &+ 0x9e37_79b9_7f4a_7c15
        z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
        z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
        return z ^ (z >> 31)
    }
}
