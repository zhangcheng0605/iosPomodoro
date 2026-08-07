import Foundation
import Observation

/// A little journey: an off-duty buddy, away to a place you've unlocked,
/// home whenever it comes home.
///
/// The Travel Frog loop with its dark half amputated: the return time is
/// drawn once and displayed nowhere — an uncontrolled clock is the whole
/// pull — but there is no lateness, no hunger, no journey that can be
/// ruined. The trip proceeds identically whether the app opens or not, the
/// letter waits unread forever, and every outcome only adds: a note in the
/// mailbox, a souvenir in the drawer, and a tip about a species your
/// journal is missing, which quietly arms your next session there.
struct Journey: Codable, Equatable, Identifiable {
    /// One journey per buddy at a time — the buddy IS the key.
    var id: String { buddy }
    let buddy: String
    let destination: String
    let departedAt: Date
    /// What got knotted into the furoshiki, if the sill had anything.
    let snack: String?

    /// Six to thirty-six real hours, from the departure's own hash. Never
    /// shown anywhere; a hidden clock with a countdown is just an
    /// obligation with better art.
    var returnsAt: Date {
        let day = Snack.dayNumber(for: departedAt)
        let hours = 6 + Doorstep.stableHash("trip.\(buddy).\(day)") % 31
        return departedAt.addingTimeInterval(TimeInterval(hours) * 3600)
    }
}

/// What a homecoming leaves in the mailbox.
struct Letter: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    let buddy: String
    let place: String
    let text: String
    /// The souvenir that went into the drawer alongside it.
    let keepsake: String
    /// The journal gap the letter teases, if the journal has one there.
    let reportedSpecies: String?
}

/// Writes the letters home, in the house voice. Pure functions of the trip.
enum LetterPress {

    static func compose(
        buddyName: String, place: Place, season: Season?, snack: Snack?,
        snackReaction: SnackReaction?, gap: Species?
    ) -> String {
        var lines = [opener(for: place)]
        if let snack {
            lines.append(snackLine(snack, reaction: snackReaction))
        } else {
            lines.append("Traveled light. The horizon was enough.")
        }
        if let gap {
            lines.append("Something \(hint(for: gap)) kept me company at "
                + "\(place.name). You'd know its name — come and see.")
        } else {
            lines.append("Saw the regulars. They asked after you.")
        }
        lines.append("Back now. The sill looks the same. Good. — \(buddyName)")
        return lines.joined(separator: " ")
    }

    private static func opener(for place: Place) -> String {
        switch place {
        case .meadow: "The grass goes on further than it looks from home."
        case .woods: "Tall trees, good shadows. Slept in three of them."
        case .harbor: "The boats come back at dusk. So did I, eventually."
        case .blossom: "Petals in everything here. Acceptable."
        case .onsen: "Warm water. I understand the capybara now."
        case .keep: "Old stones, warm all afternoon. Sat on the best one."
        case .cloudspire: "It is very high up here. The birds are smug about it."
        case .peaks: "Cold. Bright. Entirely worth it."
        }
    }

    private static func snackLine(_ snack: Snack, reaction: SnackReaction?) -> String {
        switch reaction {
        case .bliss:
            "Ate \(snack.label) on the way — the good kind, as you knew."
        case .notMyThing:
            "Ate \(snack.label) out of politeness. We won't speak of it."
        default:
            "Ate \(snack.label) at the halfway rock. No regrets."
        }
    }

    /// How a letter gestures at a species without naming it. A few bespoke
    /// silhouettes; the rest get an honest generic.
    private static func hint(for species: Species) -> String {
        switch species {
        case .stag: "with antlers, standing very still"
        case .whale: "enormous, just offshore"
        case .heron: "that did not move once"
        case .kingfisher: "like a blue line over the water"
        case .badger: "striped, unhurried"
        case .peacock: "carrying far too many eyes"
        case .ibex: "on the far ridge, watching back"
        case .tanuki: "round, warming its paws"
        default: "the journal is still missing"
        }
    }
}

@Observable
final class Travels {

    /// Who is away right now.
    private(set) var away: [Journey] = []
    /// Every letter that ever came home, oldest first. Capped like the
    /// fortune box — a mailbox, not an archive wing.
    private(set) var mailbox: [Letter] = []

    @ObservationIgnored private let defaults: UserDefaults
    private static let keepLetters = 30

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func isAway(_ buddy: Buddy) -> Bool {
        away.contains { $0.buddy == buddy.rawValue }
    }

    func journey(for buddy: Buddy) -> Journey? {
        away.first { $0.buddy == buddy.rawValue }
    }

    func send(_ buddy: Buddy, to place: Place, packing snack: Snack?, on date: Date = Date()) {
        guard !isAway(buddy) else { return }
        away.append(Journey(
            buddy: buddy.rawValue, destination: place.rawValue,
            departedAt: date, snack: snack?.rawValue
        ))
        save()
    }

    /// Journeys whose hidden clock has run out — plus any whose buddy got
    /// picked for duty, who comes straight home when called.
    func due(now: Date = Date(), selected: Buddy) -> [Journey] {
        away.filter { $0.returnsAt <= now || $0.buddy == selected.rawValue }
    }

    /// File the homecoming: the journey ends, the letter keeps.
    func complete(_ journey: Journey, letter: Letter) {
        away.removeAll { $0.id == journey.id }
        mailbox.append(letter)
        if mailbox.count > Self.keepLetters {
            mailbox.removeFirst(mailbox.count - Self.keepLetters)
        }
        save()
    }

    /// `-PawmodoroJourney owl.peaks` — departed long enough ago to be due.
    func seedForDebug(buddy: Buddy, place: Place, on date: Date = Date()) {
        away.removeAll { $0.buddy == buddy.rawValue }
        away.append(Journey(
            buddy: buddy.rawValue, destination: place.rawValue,
            departedAt: date.addingTimeInterval(-40 * 3600), snack: Snack.sardine.rawValue
        ))
        save()
    }

    /// `-PawmodoroReturnNow` — everyone still out knocks at once.
    func hurryAllForDebug(on date: Date = Date()) {
        away = away.map {
            Journey(buddy: $0.buddy, destination: $0.destination,
                    departedAt: date.addingTimeInterval(-40 * 3600), snack: $0.snack)
        }
        save()
    }

    // MARK: Persistence

    private struct State: Codable {
        var away: [Journey]
        var mailbox: [Letter]
    }

    private func load() {
        guard let data = defaults.data(forKey: StorageKeys.travels),
              let state = try? JSONDecoder().decode(State.self, from: data)
        else { return }
        away = state.away
        mailbox = state.mailbox
    }

    private func save() {
        let state = State(away: away, mailbox: mailbox)
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: StorageKeys.travels)
    }
}
