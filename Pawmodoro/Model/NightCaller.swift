import Foundation
import Observation

/// Someone came in the night.
///
/// A snack still on the sill at the end of a day is not a waste — it is an
/// invitation. The morning sweep already takes it away; now it leaves
/// evidence: a line about who came, sometimes a memento, and a species
/// known by its visits rather than by sight. Absence as mechanic, with the
/// Atsume ledger kept and the bought bait amputated: the snack was free,
/// the visit is free, and nothing was ever waiting on you.
enum NightCaller {

    /// Who a snack tempts after dark. Data in the taste-table spirit:
    /// creatures that genuinely forage at night, one per flavor.
    static func visitor(for snack: Snack, moonIsFull: Bool) -> Species {
        // The moon rabbit takes the mochi, but only under a full moon —
        // the one visitor the calendar gates, like its sightings.
        if snack == .mochi, moonIsFull { return .moonrabbit }
        switch snack {
        case .acorn: return .badger
        case .sardine: return .tanuki
        case .yuzu: return .macaque
        case .cracker: return .hedgehog
        case .cloudberry: return .mountainhare
        case .honeycomb: return .badger
        case .minnow: return .tawnyowl
        case .mochi: return .tanuki
        case .chestnut: return .squirrel
        case .snowcookie: return .ptarmigan
        }
    }

    /// The evidence line, per visitor. Written for the morning after.
    static func evidence(for species: Species, snack: Snack) -> String {
        switch species {
        case .badger: return "heavy prints, no manners — the badger took "
            + "\(snack.label) and left the sill tidier than expected"
        case .tanuki: return "small hand-shaped prints. The tanuki has "
            + "\(snack.label) now, and no regrets anywhere"
        case .macaque: return "the macaque came down from the spring for "
            + "\(snack.label). Steam on the glass"
        case .hedgehog: return "a rustle-shaped gap in the night — the "
            + "hedgehog managed \(snack.label) somehow"
        case .mountainhare: return "long prints, long gone. The mountain "
            + "hare, and \(snack.label) with it"
        case .tawnyowl: return "one feather, no sound at all. The tawny "
            + "owl considered \(snack.label) acceptable"
        case .squirrel: return "the squirrel relocated \(snack.label). "
            + "Officially it was never here"
        case .ptarmigan: return "snow prints in a neat line — the "
            + "ptarmigan, for \(snack.label)"
        case .moonrabbit: return "under the full moon, \(snack.label) "
            + "simply gone. The prints stop mid-sill"
        default: return "something came for \(snack.label) in the night, "
            + "and was polite about it"
        }
    }

    /// One visit, resolved. Rolled deterministically from the night itself —
    /// the close date, never your bedtime — so staying up late can't miss
    /// one and checking early can't hurry one.
    struct Visit {
        let species: Species
        let snack: Snack
        /// The rare thank-you, straight into the drawer.
        let memento: Keepsake?
    }

    /// Roughly two nights in three, the snack tempts someone; one visit in
    /// six leaves a memento. Both decided by the date's own hash.
    static func visit(
        snack: Snack, sweptFrom date: Date, moonIsFull: Bool,
        calendar: Calendar = .current
    ) -> Visit? {
        let night = Snack.dayNumber(for: date, calendar: calendar)
        let seed = Doorstep.stableHash("night.\(night).\(snack.rawValue)")
        guard seed % 3 != 0 else { return nil }
        let species = visitor(for: snack, moonIsFull: moonIsFull)
        let memento: Keepsake? = seed % 6 == 1 ? mementoLeft(by: species) : nil
        return Visit(species: species, snack: snack, memento: memento)
    }

    /// What a visitor leaves, when one does.
    private static func mementoLeft(by species: Species) -> Keepsake {
        switch species {
        case .tawnyowl: .feather
        case .tanuki: .bottlecap
        case .macaque: .stone
        case .mountainhare, .ptarmigan: .sprig
        case .squirrel: .pinecone
        default: .stone
        }
    }
}
