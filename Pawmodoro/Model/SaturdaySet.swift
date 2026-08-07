import Foundation
import Observation

/// The weekend request.
///
/// K.K. Slider's Saturday concert, with the teeth pulled: on weekends the
/// buddy has a track in mind — deterministic from the ISO week, biased
/// toward tracks that have never been stamped, so the setlist quietly walks
/// the whole catalog in about a year. Accepting cues it for the next run
/// and stamps it forever: "requested by Mochi, first Saturday of spring."
/// Skip the weekend and the request simply waits for the next one; no
/// missed show is representable.
@Observable
final class SetlistBox {

    /// Track id -> the day it was first played by request.
    private(set) var stamped: [String: Date] = [:]

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func hasStamped(_ trackID: String) -> Bool {
        stamped[trackID] != nil
    }

    var count: Int { stamped.count }

    /// Newest stamps first, for the card.
    struct Stamp: Identifiable {
        let track: MusicTrack
        let date: Date
        var id: String { track.id }
    }

    var stamps: [Stamp] {
        stamped.compactMap { key, date in
            MusicCatalog.track(id: key).map { Stamp(track: $0, date: date) }
        }
        .sorted { $0.date > $1.date }
    }

    func stamp(_ trackID: String, on date: Date = Date()) {
        guard stamped[trackID] == nil else { return }
        stamped[trackID] = date
        save()
    }

    /// This week's request from the tracks the user can actually play —
    /// unstamped first, so the setlist explores before it repeats.
    func request(week: Int, from unlocked: [MusicTrack]) -> MusicTrack? {
        guard !unlocked.isEmpty else { return nil }
        let fresh = unlocked.filter { stamped[$0.id] == nil }
        let pool = fresh.isEmpty ? unlocked : fresh
        return pool[abs(week) % pool.count]
    }

    // MARK: Persistence

    private func load() {
        guard let data = defaults.data(forKey: StorageKeys.setlist),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data)
        else { return }
        stamped = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(stamped) else { return }
        defaults.set(data, forKey: StorageKeys.setlist)
    }
}
