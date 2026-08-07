import CoreGraphics
import Foundation
import Observation

/// Tricks, taught by drawing their motion and learned in the buddy's sleep.
///
/// Trace a circle on the scene and the buddy attempts a spin — badly, at
/// first, and the clumsiness is the endearing point, never a punishment.
/// Practicing today never levels a trick today: the tier rises overnight,
/// on the first open after a practiced day, because that is when animals
/// consolidate what they learned. The app is structurally un-bingeable and
/// tomorrow always holds a knowable, purely positive reveal.
///
/// Nothing decays. A trick half-learned in March is exactly as half-learned
/// in June, waiting patiently.
enum Trick: String, Codable, CaseIterable, Identifiable {
    /// Cued by a drawn circle.
    case spin
    /// Cued by a drawn arc — up and over.
    case leap

    var id: String { rawValue }

    var name: String {
        switch self {
        case .spin: "the spin"
        case .leap: "the leap"
        }
    }

    /// The bond level that opens the slot — the ladder finally pays out
    /// something concrete. The first trick is free from day one; a locked
    /// one simply doesn't answer yet, which is indistinguishable from not
    /// having found the cue, so nothing ever reads as refused.
    var requiredBond: Bond {
        switch self {
        case .spin: .justMet
        case .leap: .acquainted
        }
    }

    /// The caption for an attempt at a given tier. The joke at tier zero is
    /// always at physics, never at anyone.
    func remark(tier: Int, name: String) -> String {
        switch self {
        case .spin:
            switch tier {
            case 0: return "\(name) attempts the spin. It becomes a sit. A strong sit"
            case 1: return "the spin! Wobbly, but recognizably a spin"
            case 2: return "almost the whole spin — the landing needs work"
            default: return "the spin, nailed. \(name) makes it look easy now"
            }
        case .leap:
            switch tier {
            case 0: return "\(name) attempts the leap. The ground disagrees"
            case 1: return "a leap! Short, but definitely airborne"
            case 2: return "a real leap — nearly clears the imaginary bar"
            default: return "the leap, clean as anything"
            }
        }
    }
}

/// Reads a drawn stroke and decides whether it was a cue.
///
/// Cheap geometry, no models: a circle is a long path that turns through a
/// full revolution and comes home; an arc goes up, over, and down without
/// closing. Anything else is not a cue and nothing happens — the toys
/// underneath already made the stroke worthwhile.
enum StrokeReader {

    static func trick(from points: [CGPoint]) -> Trick? {
        guard points.count >= 8 else { return nil }

        let xs = points.map(\.x), ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max(),
              let first = points.first, let last = points.last
        else { return nil }

        let width = maxX - minX
        let height = maxY - minY
        let diagonal = hypot(width, height)
        guard diagonal > 60 else { return nil }   // too small to mean anything

        var pathLength: CGFloat = 0
        var turning: CGFloat = 0
        var previous = first
        var previousAngle: CGFloat?
        for point in points.dropFirst() {
            let dx = point.x - previous.x
            let dy = point.y - previous.y
            let step = hypot(dx, dy)
            guard step > 3 else { continue }   // jitter isn't intent
            pathLength += step
            let angle = atan2(dy, dx)
            if let previousAngle {
                var delta = angle - previousAngle
                while delta > .pi { delta -= 2 * .pi }
                while delta < -.pi { delta += 2 * .pi }
                turning += delta
            }
            previousAngle = angle
            previous = point
        }
        let closure = hypot(last.x - first.x, last.y - first.y)

        // A circle: turns through most of a revolution, path much longer
        // than the box, ends near where it began, not absurdly squashed.
        let aspect = width > 0 && height > 0
            ? max(width, height) / min(width, height) : 100
        if abs(turning) > 4.6,
           pathLength > diagonal * 2.0,
           closure < diagonal * 0.45,
           aspect < 2.6 {
            return .spin
        }

        // An arc: the apex sits well above both ends, the stroke travels
        // sideways, stays open, and bends through roughly half a turn.
        let apexY = minY
        let liftsOff = first.y - apexY > height * 0.55
            && last.y - apexY > height * 0.55
        if liftsOff,
           abs(last.x - first.x) > 50,
           closure > width * 0.5,
           abs(turning) > 1.2, abs(turning) < 4.2 {
            return .leap
        }

        return nil
    }
}

@Observable
final class Repertoire {

    /// One skill: how far along it is, and whether it was practiced on a
    /// day the buddy hasn't yet slept on.
    struct Skill: Codable, Equatable {
        var tier: Int
        var practicedOn: Date?
        /// Set when the overnight rise lands, so the next attempt's caption
        /// can say where the improvement came from.
        var grew: Bool
    }

    /// The performance on stage right now, for the view to animate.
    struct Attempt: Equatable, Identifiable {
        let id: UUID
        let trick: Trick
        let tier: Int
        /// Whether the caption opens with the practicing-in-dreams reveal.
        let announcedGrowth: Bool
    }

    static let masteredTier = 3

    private(set) var skills: [String: Skill] = [:]
    private(set) var attempt: Attempt?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        load()
    }

    func tier(_ buddy: Buddy, _ trick: Trick) -> Int {
        skills[key(buddy, trick)]?.tier ?? 0
    }

    func hasMastered(_ buddy: Buddy, _ trick: Trick) -> Bool {
        tier(buddy, trick) >= Self.masteredTier
    }

    /// Overnight consolidation: every skill practiced on an earlier day
    /// rises one tier, once, and remembers to say so. Called on launch and
    /// on foregrounding — the rise belongs to the night, not to the cue.
    func consolidate(on date: Date = Date()) {
        var changed = false
        for (key, skill) in skills {
            var skill = skill
            guard let practiced = skill.practicedOn,
                  !calendar.isDate(practiced, inSameDayAs: date),
                  skill.tier < Self.masteredTier
            else { continue }
            skill.tier += 1
            skill.practicedOn = nil
            skill.grew = true
            skills[key] = skill
            changed = true
        }
        if changed { save() }
    }

    /// A cue landed: perform at today's tier and mark the practice.
    /// Practicing never levels the trick today — that's the whole biology.
    func cue(_ trick: Trick, buddy: Buddy, on date: Date = Date()) {
        var skill = skills[key(buddy, trick)]
            ?? Skill(tier: 0, practicedOn: nil, grew: false)
        let announced = skill.grew
        skill.grew = false
        if skill.tier < Self.masteredTier {
            skill.practicedOn = date
        }
        skills[key(buddy, trick)] = skill
        save()
        attempt = Attempt(
            id: UUID(), trick: trick, tier: skill.tier, announcedGrowth: announced
        )
    }

    /// A performance with no practice bookkeeping — the celebration showing
    /// off a mastered trick, or a debug preview at a pinned tier.
    func showOff(_ trick: Trick, tier: Int) {
        attempt = Attempt(
            id: UUID(), trick: trick,
            tier: min(max(tier, 0), Self.masteredTier), announcedGrowth: false
        )
    }

    func clearAttempt() {
        attempt = nil
    }

    /// The mastered trick the celebration features today, if any — picked
    /// by date so it doesn't reroll within a day.
    func celebrationTrick(for buddy: Buddy, day: Int) -> Trick? {
        let mastered = Trick.allCases.filter { hasMastered(buddy, $0) }
        guard !mastered.isEmpty else { return nil }
        return mastered[abs(day) % mastered.count]
    }

    /// `-PawmodoroTrick spin.2` — pin a skill at a tier.
    func seedForDebug(_ trick: Trick, tier: Int, buddy: Buddy) {
        skills[key(buddy, trick)] = Skill(
            tier: min(max(tier, 0), Self.masteredTier), practicedOn: nil, grew: false
        )
        save()
    }

    private func key(_ buddy: Buddy, _ trick: Trick) -> String {
        "\(buddy.rawValue).\(trick.rawValue)"
    }

    // MARK: Persistence

    private func load() {
        guard let data = defaults.data(forKey: StorageKeys.repertoire),
              let decoded = try? JSONDecoder().decode([String: Skill].self, from: data)
        else { return }
        skills = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(skills) else { return }
        defaults.set(data, forKey: StorageKeys.repertoire)
    }
}
