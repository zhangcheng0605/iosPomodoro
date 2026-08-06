import Foundation

/// Twenty-four candles, one for each hour of the clock.
///
/// A candle lights the first time a session ever *ends* in that hour, and then
/// it stays lit. Not "how often", not "how recently" — once. The shelf is a
/// record of the hours you have ever been here for, and after a year of
/// ordinary use most people will have a cluster of lit ones around their own
/// working day and a dark rim of hours they have never met.
///
/// **Nothing counts anything.** No "14 of 24", no list of the ones you are
/// missing, no prompt to go and light 4 a.m. The dark end of the shelf is
/// visible only by looking at the shelf, which is the anti-goal about hidden
/// counts applied to the one collection where it matters most: the unlit hours
/// are unlit because you were asleep, and being asleep is not a gap in
/// somebody's practice.
///
/// Like the year ring, it **backfills**. Sessions have always carried a full
/// `endedAt: Date`, so the shelf is right the moment it arrives — somebody who
/// has been using the app for a year opens it to a year's worth of candles.
enum ShelfOfHours {

    /// One hour of the clock.
    struct Candle: Identifiable, Equatable {
        /// 0...23.
        let hour: Int
        /// The first session that ever ended in this hour, or nil.
        let firstLit: Date?

        var id: Int { hour }
        var isLit: Bool { firstLit != nil }

        /// "3 a.m." — the shelf's own label, in twelve-hour form because that
        /// is how people talk about the strange ones. Nobody says "the 03:00
        /// candle".
        var label: String {
            switch hour {
            case 0: "12a"
            case 1...11: "\(hour)a"
            case 12: "12p"
            default: "\(hour - 12)p"
            }
        }

        /// What this hour is like, or nil.
        ///
        /// Every one of these has to pass the **strange, not proud** test: it
        /// may say what an hour is *like*, and it may not congratulate anybody
        /// for being awake in it. "Still going at 3 a.m." is the copy this app
        /// does not write — it turns a candle into a dare, and it is exactly
        /// the sentence a productivity app would put here. Most hours get
        /// nothing at all, which is also the right amount to say about 2 p.m.
        var caption: String? {
            switch hour {
            case 0: "the day changing over"
            case 1: nil
            case 2: nil
            case 3: "the hour with nobody else in it"
            case 4: "the last of the dark"
            case 5: "before the birds, and then the birds"
            case 6: nil
            case 7: nil
            case 8: nil
            case 9: nil
            case 10: nil
            case 11: nil
            case 12: "the sun straight overhead"
            case 13: nil
            case 14: nil
            case 15: nil
            case 16: nil
            case 17: "the light going amber"
            case 18: nil
            case 19: nil
            case 20: nil
            case 21: "the house gone quiet"
            case 22: nil
            case 23: nil
            default: nil
            }
        }
    }

    /// The whole shelf, midnight first.
    ///
    /// `LaunchOptions.forcedDayPart` is deliberately *not* honoured here,
    /// unlike `SessionLog.nightSessions` and the year ring. Those two are
    /// about which part of the day a session belongs to, which is a judgement
    /// the clock flag is allowed to make. A candle is about a specific hour of
    /// a specific day, and pretending a lunchtime session ended at 3 a.m.
    /// would light a candle that is a lie — and candles never go out.
    static func build(from records: [SessionRecord]) -> [Candle] {
        let calendar = WorldCalendar.calendar
        var earliest: [Int: Date] = [:]

        for record in records {
            let hour = calendar.component(.hour, from: record.endedAt)
            if let existing = earliest[hour], existing <= record.endedAt { continue }
            earliest[hour] = record.endedAt
        }
        return (0...23).map { Candle(hour: $0, firstLit: earliest[$0]) }
    }

    /// The two hours the dream pool cares about, so `Dream` and the shelf
    /// cannot drift apart about which candle is which.
    static let smallHours = 3
    static let firstLight = 5

    static func isLit(_ hour: Int, in candles: [Candle]) -> Bool {
        candles.first { $0.hour == hour }?.isLit ?? false
    }
}
