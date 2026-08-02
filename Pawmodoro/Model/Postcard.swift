import Foundation
import Observation

/// A keepsake from somewhere you got to.
///
/// Only the facts are stored, never an image: a postcard is re-drawn from the
/// current art every time it's shown, so it costs a few dozen bytes, survives
/// an art change, and can be exported at whatever size the share sheet wants.
struct Postcard: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    let place: String
    let dayPart: String
    let buddy: String
    /// What the card is about: an arrival, or a finished cycle.
    let occasion: Occasion
    /// Sessions completed that day, for the caption.
    let sessions: Int
    /// Set when something was seen the same day — the two keepsake systems
    /// feed each other.
    let sighting: String?

    enum Occasion: String, Codable {
        case arrival
        case cycle
    }

    var resolvedPlace: Place { Place(rawValue: place) ?? .meadow }
    var resolvedDayPart: DayPart { DayPart(rawValue: dayPart) ?? .day }
    var resolvedBuddy: Buddy { Buddy(rawValue: buddy) ?? .cat }
    var resolvedSighting: Species? { sighting.flatMap(Species.init(rawValue:)) }
}

/// Every postcard the buddy has sent.
@Observable
final class Album {
    private(set) var cards: [Postcard] = []

    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = StorageKeys.postcards
    /// Plenty for years of use, and a hard stop on unbounded growth.
    private static let limit = 200

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    /// Newest first — an album you scroll from the most recent trip.
    var newestFirst: [Postcard] { cards.sorted { $0.date > $1.date } }

    func add(_ card: Postcard) {
        cards.append(card)
        if cards.count > Self.limit {
            cards.removeFirst(cards.count - Self.limit)
        }
        save()
    }

    func clear() {
        cards = []
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([Postcard].self, from: data)
        else { return }
        cards = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(cards) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
