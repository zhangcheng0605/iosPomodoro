import Foundation
import Observation

/// A photograph of where you actually were.
///
/// The postcards remember where the *buddy* was — a drawing of Harbor Isle at
/// dusk. This remembers where **you** were: the desk, the café window, the
/// kitchen table at six in the morning. It is the app's two worlds shaking
/// hands, and the caption is what does the handshaking — a photo of your own
/// desk stamped *"Harbor Isle, in the mist — 50 minutes"*.
///
/// ### Everything it knows, it already knew
///
/// Nothing here is asked for. The date comes from `WorldCalendar`, the place
/// and the buddy from settings, the weather from the sky the world had that
/// day, the length from the session that just ended. There is no title field,
/// no tag, no note to write. A memory feature that opens a text box has
/// become a journal, and this app has one of those.
///
/// ### And it never leaves the device
///
/// The app makes no network calls and this does not change that. The JPEG
/// lives in Documents, the metadata beside it, and EXIF location is stripped
/// on import — always, not as an option. That is what lets the App Store page
/// say *your photos never leave your device* and mean it.
struct Snapshot: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    /// The file's name in the snapshots directory. Not a full path: the
    /// container's location changes between installs and an absolute path
    /// stored today is a broken image after the next restore.
    var file: String
    /// Everything the world knew at the moment it was kept. All optional-free
    /// because all of it was known — but stored as raw strings so that
    /// retiring a place or a weather can never make an album undecodable.
    var place: String
    var buddy: String
    var weather: String
    var minutes: Int
    /// The stock it is shown in. Changeable afterwards — the photograph is
    /// never modified, only displayed.
    var stock: String = FilmStock.asitwas.rawValue

    var filmStock: FilmStock { FilmStock(rawValue: stock) ?? .asitwas }

    /// The line under the photograph, in the world's voice.
    ///
    /// Deliberately about the *world*, not the photo: "Harbor Isle, in the
    /// mist — 50 minutes" says where the two of you were while you were at
    /// this desk, which is the whole joke and the whole point. Never names the
    /// buddy — that has to come from `settings.displayName(for:)` at the call
    /// site, and a model type cannot reach it.
    var caption: String {
        let where_ = Place(rawValue: place)?.name ?? place
        var line = where_
        if let sky = Weather(rawValue: weather), sky != .clear {
            line += ", in \(sky.hintPhrase)"
        }
        return "\(line) — \(minutes) minutes"
    }
}

/// The scrapbook itself: photographs on disk, their facts in defaults.
///
/// Split deliberately. The images are files because a few hundred kilobytes
/// each has no business in `UserDefaults`, and the metadata is in defaults
/// because it is tiny, needs no migration, and `-PawmodoroResetState` already
/// knows how to wipe a key. `prune()` is what keeps the two halves honest.
@Observable
final class Scrapbook {
    private(set) var snapshots: [Snapshot] = []

    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = StorageKeys.snapshots

    /// Generous, and a hard stop. At a capped long edge these are a few
    /// hundred kilobytes each, so two hundred is tens of megabytes — worth
    /// bounding, and far more than anybody will take.
    static let limit = 200

    /// The long edge every import is scaled to. Big enough to look right
    /// full-screen on any phone, small enough that a scrapbook is not the
    /// largest thing on the device.
    static let longEdge: CGFloat = 2000

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([Snapshot].self, from: data) {
            snapshots = decoded
        }
    }

    /// Newest first — a scrapbook you open at the most recent page.
    var newestFirst: [Snapshot] { snapshots.sorted { $0.date > $1.date } }

    var isEmpty: Bool { snapshots.isEmpty }

    // MARK: Where the files live

    /// `Documents/Snapshots`, created on demand.
    ///
    /// Documents rather than Caches: the system may empty Caches whenever it
    /// likes, and a memory the app quietly deleted to save space would be the
    /// worst bug this feature could have.
    static var directory: URL? {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return nil }
        let folder = documents.appendingPathComponent("Snapshots", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(
                at: folder, withIntermediateDirectories: true
            )
        }
        return folder
    }

    func url(for snapshot: Snapshot) -> URL? {
        Self.directory?.appendingPathComponent(snapshot.file)
    }

    // MARK: Keeping and letting go

    func add(_ snapshot: Snapshot) {
        snapshots.append(snapshot)
        if snapshots.count > Self.limit {
            let dropped = snapshots.prefix(snapshots.count - Self.limit)
            for old in dropped { removeFile(old) }
            snapshots.removeFirst(snapshots.count - Self.limit)
        }
        save()
    }

    /// The one destructive path in the feature, and it is the user's own hand.
    /// Nothing else in the app ever removes a snapshot.
    func remove(_ snapshot: Snapshot) {
        removeFile(snapshot)
        snapshots.removeAll { $0.id == snapshot.id }
        save()
    }

    func setStock(_ stock: FilmStock, on snapshot: Snapshot) {
        guard let index = snapshots.firstIndex(where: { $0.id == snapshot.id })
        else { return }
        snapshots[index].stock = stock.rawValue
        save()
    }

    /// Delete any file with no snapshot pointing at it.
    ///
    /// The two halves are stored separately, so they can come apart: a crash
    /// between writing the JPEG and saving the metadata leaves an orphan, and
    /// an orphan is invisible storage nobody can reach. Called at launch,
    /// where it costs one directory listing.
    func prune() {
        guard let directory = Self.directory,
              let files = try? FileManager.default.contentsOfDirectory(
                  atPath: directory.path
              ) else { return }
        let known = Set(snapshots.map(\.file))
        for file in files where !known.contains(file) {
            try? FileManager.default.removeItem(
                at: directory.appendingPathComponent(file)
            )
        }
    }

    func clear() {
        for snapshot in snapshots { removeFile(snapshot) }
        snapshots = []
        save()
    }

    private func removeFile(_ snapshot: Snapshot) {
        guard let url = url(for: snapshot) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
