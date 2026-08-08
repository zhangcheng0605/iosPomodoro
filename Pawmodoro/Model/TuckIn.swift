import Foundation
import Observation

/// The bedtime ritual: after sunset a blanket waits, and dragging it over
/// the buddy plants a reveal that can only arrive tomorrow.
///
/// Nothing here can be owed. An untucked buddy sleeps identically well and
/// dreams at the ordinary rate; no caption ever mentions a night without a
/// blanket, and a missed window simply reappears the next evening. The whole
/// mechanic is additive: a tucked night *guarantees* the next day's dream
/// roll, where an ordinary night leaves it at its usual odds.
///
/// ## A tuck belongs to a night, not to a calendar day
///
/// The bedtime window runs from dusk *across* midnight — `DayPart` calls
/// 21:00–04:59 night — so half of every bedtime falls on the following
/// calendar date. A lifetime of "the same calendar day" therefore lifted a
/// blanket laid at 23:00 two hours later and one laid at 03:27 **twenty and
/// a half hours** later, over the whole of the waking day, with no way to
/// take it off. Both of those are one sleep, and both end at the same
/// morning: the lifetime is the next waking hour after the tuck, decided
/// once when the blanket goes on and stored, so nothing has to recompute it
/// and nothing can drift.
///
/// ## And it can always be taken off
///
/// `lift(on:)` is the hand on the blanket. It is not an undo in the sense of
/// erasing anything — what the night earned is earned the moment the blanket
/// goes on, and lifting it keeps every bit of that. All it does is end the
/// nap early, put the folded blanket back beside the buddy, and let the whole
/// ritual happen again if you want it to.
@Observable
final class TuckIn {

    /// When the blanket went on, if it has. The caption's whole receipt.
    private(set) var tuckedOn: Date?
    /// When this blanket comes off by itself — the next waking hour after
    /// `tuckedOn`, decided once so that it is a fact rather than a rule
    /// being re-derived on every read.
    private(set) var liftsAt: Date?
    /// When a hand took it off early, if one did. Only counts when it lands
    /// after the tuck it belongs to; an older lift is last night's.
    private(set) var liftedOn: Date?

    /// The lift moments a tuck has earned, each of which blesses the rest of
    /// its own day. Append-only within the two days anything can read: the
    /// blessing survives the blanket being taken off by hand, because it was
    /// earned by the tucking rather than by the sleeping.
    @ObservationIgnored private var blessedLifts: [Date] = []
    /// The day whose morning caption has already been said, so the reveal
    /// lands once, not on every foregrounding.
    @ObservationIgnored private var revealedOn: Date?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar

    /// The hour an ordinary blanket comes off: sunrise-ish, and deliberately
    /// *after* `DayPart`'s night ends at 05:00 rather than at midnight —
    /// midnight is the middle of a bedtime window, not the end of one.
    static let wakingHour = 6
    /// A nocturnal buddy goes to bed at dawn and gets up at dusk, which is
    /// `DayPart`'s own 17:00 boundary. Luna's blanket is a daytime blanket.
    static let nocturnalWakingHour = 17

    init(defaults: UserDefaults = .standard,
         calendar: Calendar = WorldCalendar.calendar) {
        self.defaults = defaults
        self.calendar = calendar
        load()
    }

    // MARK: The evening

    /// When the blanket is offered: the evening for everyone, daybreak for a
    /// nocturnal buddy — Luna's bedtime is sunrise, per the quirks-are-data
    /// rule, and her upgraded dream then rolls on her daytime nap, so the owl
    /// rule (no dreams at night) is never touched.
    static func windowIsOpen(for buddy: Buddy, at part: DayPart) -> Bool {
        buddy.isNocturnal ? part == .dawn : (part == .dusk || part == .night)
    }

    /// When a blanket laid at `tucked` comes off by itself.
    ///
    /// The hour of the tuck says which sleep it is: a blanket laid at dawn is
    /// a nocturnal buddy's, and runs to dusk; everything else is an ordinary
    /// night's and runs to the next morning. Note that this is a function of
    /// the *tuck's* hour and not of the buddy — a model type has no business
    /// knowing who is under the blanket, and the window that offered it has
    /// already made that decision.
    func liftTime(after tucked: Date) -> Date {
        let hour = calendar.component(.hour, from: tucked)
        let waking = DayPart.from(hour: hour) == .dawn
            ? Self.nocturnalWakingHour
            : Self.wakingHour
        return nextTime(hour: waking, after: tucked)
    }

    /// The next time the clock reads `hour:00`, strictly after `date`.
    /// `nextDate(after:matching:)` rather than arithmetic, so the morning a
    /// clock goes forward is still a morning.
    private func nextTime(hour: Int, after date: Date) -> Date {
        calendar.nextDate(
            after: date,
            matching: DateComponents(hour: hour, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? date.addingTimeInterval(24 * 60 * 60)
    }

    /// Whether the buddy is under the blanket right now — laid this sleep,
    /// not yet lifted, and the waking hour not yet come round.
    func isTuckedNow(on date: Date = WorldCalendar.now) -> Bool {
        guard let tuckedOn, let liftsAt else { return false }
        if let liftedOn, liftedOn >= tuckedOn { return false }
        return date >= tuckedOn && date < liftsAt
    }

    /// "11:04", for the caption that is the whole receipt.
    var tuckClock: String? {
        guard let tuckedOn else { return nil }
        return tuckedOn.formatted(date: .omitted, time: .shortened)
    }

    func tuck(on date: Date = WorldCalendar.now) {
        guard !isTuckedNow(on: date) else { return }
        let lift = liftTime(after: date)
        tuckedOn = date
        liftsAt = lift
        liftedOn = nil
        record(blessing: lift)
        save()
    }

    /// The blanket comes off, by hand, before its morning.
    ///
    /// Nothing is given back. `blessedLifts` is untouched, so the guaranteed
    /// dream this tuck earned still arrives on its own morning — the blanket
    /// is a thing you did, and taking it off again does not undo having done
    /// it. Returns whether there was in fact a blanket to lift.
    @discardableResult
    func lift(on date: Date = WorldCalendar.now) -> Bool {
        guard isTuckedNow(on: date) else { return false }
        liftedOn = date
        save()
        return true
    }

    // MARK: The morning

    /// Whether this is a blessed day: a tucked sleep has ended today. While
    /// this is true the dream roll skips its odds and simply happens.
    ///
    /// It begins at the lift rather than at midnight, because midnight falls
    /// inside the bedtime window and a blessing that arrived while the buddy
    /// was still under the blanket would be a morning line said in the dark.
    func blessing(on date: Date = WorldCalendar.now) -> Bool {
        blessedLifts.contains {
            $0 <= date && calendar.isDate($0, inSameDayAs: date)
        }
    }

    /// The one-shot morning line. True exactly once per blessed day.
    func claimMorningReveal(on date: Date = WorldCalendar.now) -> Bool {
        guard blessing(on: date) else { return false }
        if let revealedOn, calendar.isDate(revealedOn, inSameDayAs: date) { return false }
        revealedOn = date
        save()
        return true
    }

    /// Remember a lift as a blessing. Two is all anything can read — the
    /// morning that has just happened and the one coming — so a third tuck
    /// in the same stretch never displaces a blessing still in play.
    private func record(blessing lift: Date) {
        guard !blessedLifts.contains(lift) else { return }
        blessedLifts = Array((blessedLifts + [lift]).sorted().suffix(2))
    }

    // MARK: Debug

    /// `-PawmodoroTucked` — pretend the blanket went on last night, so the
    /// blessing and the morning line are today's without waiting a day.
    ///
    /// It lands at **03:27** whenever that hour has already been and gone,
    /// because the small hours are exactly the case a calendar day got wrong;
    /// before 03:27 there is no such night yet and it lands at 23:00 the
    /// evening before instead. Either way the blanket lifts at this morning's
    /// waking hour and today is the blessed day — so from 06:00 onward this
    /// flag shows the thank-you, and before 06:00 it shows the blanket, which
    /// is the honest answer at that hour.
    func seedYesterdayForDebug(on date: Date = WorldCalendar.now) {
        let midnight = calendar.startOfDay(for: date)
        let smallHours = calendar.date(
            bySettingHour: 3, minute: 27, second: 0, of: midnight, direction: .forward
        )
        let lastEvening = calendar.date(byAdding: .hour, value: -1, to: midnight)
        let planted: Date?
        if let smallHours, smallHours <= date {
            planted = smallHours
        } else {
            planted = lastEvening
        }
        guard let planted else { return }
        let lift = liftTime(after: planted)
        tuckedOn = planted
        liftsAt = lift
        liftedOn = nil
        blessedLifts = [lift]
        revealedOn = nil
        save()
    }

    // MARK: Persistence

    /// Every field optional, so a world saved by the shipped version — which
    /// stored only the two dates — still decodes. `load()` fills the rest in.
    private struct State: Codable {
        var tuckedOn: Date?
        var revealedOn: Date?
        var liftsAt: Date?
        var liftedOn: Date?
        var blessedLifts: [Date]?
    }

    private func load() {
        guard let data = defaults.data(forKey: StorageKeys.tuckIn),
              let state = try? JSONDecoder().decode(State.self, from: data)
        else { return }
        tuckedOn = state.tuckedOn
        revealedOn = state.revealedOn
        liftedOn = state.liftedOn
        liftsAt = state.liftsAt ?? tuckedOn.map { liftTime(after: $0) }
        // A world written before the blanket had a waking hour carries one
        // date and nothing else. Its pending blessing is whatever that tuck
        // would earn now, which is the reading that loses nobody a dream.
        if let stored = state.blessedLifts {
            blessedLifts = stored
        } else if let lift = liftsAt {
            blessedLifts = [lift]
        }
    }

    private func save() {
        let state = State(
            tuckedOn: tuckedOn, revealedOn: revealedOn,
            liftsAt: liftsAt, liftedOn: liftedOn, blessedLifts: blessedLifts
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: StorageKeys.tuckIn)
    }
}
