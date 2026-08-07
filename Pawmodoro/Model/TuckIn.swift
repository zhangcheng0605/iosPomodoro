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
@Observable
final class TuckIn {

    /// When the blanket went on, if it has. The only stored fact.
    private(set) var tuckedOn: Date?
    /// The day whose morning caption has already been said, so the reveal
    /// lands once, not on every foregrounding.
    @ObservationIgnored private var revealedOn: Date?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
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

    /// Whether the buddy is under the blanket right now — tucked earlier
    /// this same calendar day.
    func isTuckedNow(on date: Date = Date()) -> Bool {
        guard let tuckedOn else { return false }
        return calendar.isDate(tuckedOn, inSameDayAs: date)
    }

    /// "11:04", for the caption that is the whole receipt.
    var tuckClock: String? {
        guard let tuckedOn else { return nil }
        return tuckedOn.formatted(date: .omitted, time: .shortened)
    }

    func tuck(on date: Date = Date()) {
        if let tuckedOn, calendar.isDate(tuckedOn, inSameDayAs: date) { return }
        tuckedOn = date
        save()
    }

    // MARK: The morning

    /// Whether today is the day after a tucked night. While this is true the
    /// dream roll skips its odds and simply happens.
    func blessing(on date: Date = Date()) -> Bool {
        guard let tuckedOn,
              let next = calendar.date(byAdding: .day, value: 1, to: tuckedOn)
        else { return false }
        return calendar.isDate(next, inSameDayAs: date)
    }

    /// The one-shot morning line. True exactly once per blessed day.
    func claimMorningReveal(on date: Date = Date()) -> Bool {
        guard blessing(on: date) else { return false }
        if let revealedOn, calendar.isDate(revealedOn, inSameDayAs: date) { return false }
        revealedOn = date
        save()
        return true
    }

    // MARK: Debug

    /// `-PawmodoroTucked` — pretend the blanket went on last night, so the
    /// blessing and the morning line are today's without waiting a day.
    func seedYesterdayForDebug(on date: Date = Date()) {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date)
        else { return }
        tuckedOn = yesterday
        revealedOn = nil
        save()
    }

    // MARK: Persistence

    private struct State: Codable {
        var tuckedOn: Date?
        var revealedOn: Date?
    }

    private func load() {
        guard let data = defaults.data(forKey: StorageKeys.tuckIn),
              let state = try? JSONDecoder().decode(State.self, from: data)
        else { return }
        tuckedOn = state.tuckedOn
        revealedOn = state.revealedOn
    }

    private func save() {
        let state = State(tuckedOn: tuckedOn, revealedOn: revealedOn)
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: StorageKeys.tuckIn)
    }
}
