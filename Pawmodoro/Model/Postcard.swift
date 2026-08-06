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
    /// Focus minutes at the moment the card was made. Only the panorama uses
    /// it, and it uses it to redraw the exact wood that stood there.
    ///
    /// Optional so that every card written before the panorama existed still
    /// decodes — Swift's synthesised `Decodable` calls `decodeIfPresent` for
    /// an Optional and leaves it nil, which is the same argument
    /// `SightingRecord.weather` made when the weather arrived.
    let minutes: Int?

    enum Occasion: String, Codable {
        case arrival
        case cycle
        /// A hundred hours of focus, and a picture of the whole wood it grew.
        ///
        /// The only card in the album that is not about a *place* — it is
        /// about the homestead, which is nowhere, and it is the one thing in
        /// this app that takes four months of daily use to reach. `place` is
        /// still filled in with wherever you happened to be sitting, because
        /// a postcard with a blank field is a bug waiting to be found by
        /// somebody's decoder.
        case panorama
        /// Every hour on the dial, at least once. The one card that is about
        /// a *time* rather than a place — `place` still records where you
        /// happened to be when the last hour landed, because a postcard with
        /// a blank field is a bug waiting for somebody's decoder.
        ///
        /// Minted once and never again: the ring cannot un-fill, so a second
        /// one could only ever be a duplicate.
        case belltower
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
