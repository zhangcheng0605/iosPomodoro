import Foundation
import Observation

/// One photograph a day, of whatever is true right now.
///
/// The Snap half: the timetable, sighting-window and moon knowledge you've
/// built is what makes a *good* shot possible. The Wordle half: one per
/// day, so the timing is a decision — and the develop-overnight beat means
/// tomorrow's first open always has a small parcel waiting.
///
/// A photo is a parameter record, not pixels: ~200 bytes of what was true,
/// re-rendered by the same views whenever it is looked at — the postcard
/// pipeline's philosophy, applied to a camera. An unspent shot vanishes
/// without record; the shelf shows photos taken, never blanks for days
/// skipped. No film count, no grades: the house voice captions everything
/// kindly because it doesn't know how to do otherwise.
struct PhotoRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    let place: String
    let dayPart: String
    let buddy: String
    /// Asleep under the blanket, or up and about — decides the sprite.
    let tucked: Bool
    /// The timetabled event that happened to be running, if one was.
    let event: String?
    let moonFull: Bool
    /// Composed at capture, so the words remember what the render might
    /// not draw.
    let caption: String
}

@Observable
final class PhotoAlbum {

    private(set) var photos: [PhotoRecord] = []

    @ObservationIgnored private var lastShotDay: Int?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar
    private static let keep = 60

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        load()
    }

    /// Whether today's one shot is still unspent.
    func shotAvailable(on date: Date = Date()) -> Bool {
        lastShotDay != Snack.dayNumber(for: date, calendar: calendar)
    }

    func snap(_ record: PhotoRecord) {
        photos.append(record)
        if photos.count > Self.keep {
            photos.removeFirst(photos.count - Self.keep)
        }
        lastShotDay = Snack.dayNumber(for: record.date, calendar: calendar)
        save()
    }

    /// Developed means slept on: a photo renders only from the day after
    /// it was taken.
    func isDeveloped(_ record: PhotoRecord, on date: Date = Date()) -> Bool {
        Snack.dayNumber(for: record.date, calendar: calendar)
            < Snack.dayNumber(for: date, calendar: calendar)
    }

    /// Today's shot, still in the bath.
    func developing(on date: Date = Date()) -> PhotoRecord? {
        photos.last { !isDeveloped($0, on: date) }
    }

    /// The caption, written at the moment of the click.
    static func caption(
        place: Place, part: DayPart, buddyName: String, tucked: Bool,
        event: ClockworkEvent?, moonFull: Bool
    ) -> String {
        let hour = switch part {
        case .dawn: "First light"
        case .day: "Midday"
        case .dusk: "Dusk"
        case .night: "Night"
        }
        var line = "\(hour) at \(place.name). "
        if let event {
            line += "\(event.name), mid-act. "
        }
        line += tucked
            ? "\(buddyName) slept through the click."
            : "\(buddyName) pretended not to pose."
        if moonFull {
            line += " Full moon presiding."
        }
        return line
    }

    // MARK: Debug

    /// `-PawmodoroPhoto` — the shot regranted regardless of the day.
    func regrantForDebug() {
        lastShotDay = nil
        save()
    }

    /// `-PawmodoroDevelop` — today's photo renders now: it is re-dated to
    /// yesterday, which is what "developed" means here.
    func developNowForDebug(on date: Date = Date()) {
        guard let last = photos.last,
              !isDeveloped(last, on: date),
              let yesterday = calendar.date(byAdding: .day, value: -1, to: last.date)
        else { return }
        photos[photos.count - 1] = PhotoRecord(
            id: last.id, date: yesterday, place: last.place,
            dayPart: last.dayPart, buddy: last.buddy, tucked: last.tucked,
            event: last.event, moonFull: last.moonFull, caption: last.caption
        )
        save()
    }

    // MARK: Persistence

    private struct State: Codable {
        var photos: [PhotoRecord]
        var lastShotDay: Int?
    }

    private func load() {
        guard let data = defaults.data(forKey: StorageKeys.photos),
              let state = try? JSONDecoder().decode(State.self, from: data)
        else { return }
        photos = state.photos
        lastShotDay = state.lastShotDay
    }

    private func save() {
        let state = State(photos: photos, lastShotDay: lastShotDay)
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: StorageKeys.photos)
    }
}
