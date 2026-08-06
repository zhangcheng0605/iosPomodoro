import Foundation

/// Three things you can offer, and nobody is hungry.
///
/// Dragged to the buddy during a break or while idle. It takes the one it
/// likes, sniffs and politely nudges back the one it does not, and that is the
/// whole mechanic. There is no meter behind it.
///
/// ### The fences, and they are the feature
///
/// - **Free and infinite.** No cost in acorns, no cost in anything. Fence 6 of
///   the Hearth era says the memory is never the product; feeding your pet is
///   the same category. A treat with a price would turn the one gesture in
///   this app that is purely generous into a transaction.
/// - **No hunger, ever.** Nothing goes down. There is no bar to keep topped
///   up, no "last fed" date, nothing that is worse for having been away. A
///   Tamagotchi guilt loop is the single fastest way to ruin everything this
///   app is, and this is the feature closest to one.
/// - **No buff.** Offering a treat does not speed the timer, raise the bond,
///   drop an acorn or make a sighting likelier. If it did, it would stop being
///   a kindness and become a chore with a payout — and somebody would work out
///   the optimal feeding schedule within a week.
/// - **Nothing is refused unkindly.** A buddy that dislikes a treat nudges it
///   back; it never turns away, never sulks, and there is no wrong answer to
///   find. The point of preferences is personality, not a puzzle.
///
/// ### Why three and not thirty
///
/// A biscuit, a berry and a small fish cover the three things twelve animals
/// might plausibly want, and every buddy has one favourite and one it declines.
/// Thirty treats would make the favourite a needle in a haystack; three make it
/// something you find in an afternoon and remember for good.
enum Treat: String, CaseIterable, Identifiable, Codable {
    case biscuit
    case berry
    case fish

    var id: String { rawValue }

    var name: String {
        switch self {
        case .biscuit: "A biscuit"
        case .berry: "A berry"
        case .fish: "A small fish"
        }
    }

    var asset: String { "treat_\(rawValue)" }

    /// What the buddy does with the one it likes. Never the buddy's name —
    /// that has to come from `settings.displayName(for:)` at the call site.
    var takenLine: String {
        switch self {
        case .biscuit: "took it in both hands and turned it round twice."
        case .berry: "had it before you had let go."
        case .fish: "took it very carefully, which is somehow worse."
        }
    }

    /// What happens to the one it does not want. All three are a *decline*,
    /// not a rejection — the buddy is being polite about a thing it does not
    /// fancy, which is what a real animal does and what keeps this from
    /// having a wrong answer.
    var nudgedLine: String {
        switch self {
        case .biscuit: "sniffed it, and pushed it back towards you."
        case .berry: "looked at it, then at you, and did not take it."
        case .fish: "moved it politely to one side."
        }
    }

    /// The ordinary reception: taken, eaten, no fuss. What every buddy does
    /// with the one treat that is neither its favourite nor its refusal.
    var acceptedLine: String {
        switch self {
        case .biscuit: "ate it without comment."
        case .berry: "ate it, and checked whether there was another."
        case .fish: "ate it, and washed both hands afterwards."
        }
    }
}

extension Buddy {

    /// The one it is delighted by. Data, per the standing quirk rule — a
    /// preference is never a branch in a view.
    ///
    /// Chosen to be *guessable but not obvious*: the otter and the penguin
    /// want the fish, which anybody would predict, and the fox wants the berry,
    /// which almost nobody would. A table where every answer is predictable is
    /// a table nobody bothers to explore.
    var favouriteTreat: Treat {
        switch self {
        case .cat, .owl: .fish
        case .dog, .capybara, .hamster: .biscuit
        case .bunny, .fox, .redpanda, .hedgehog: .berry
        case .penguin, .otter: .fish
        // She has been eating out of bins for a fortnight. A biscuit is a
        // sure thing and she is not in a position to be interesting about it.
        case .stray: .biscuit
        }
    }

    /// The one it politely declines. Never the favourite — `check_greeting`'s
    /// sibling `check_treats.py` asserts that, because a buddy that both loves
    /// and refuses the same thing is a table that has been edited in one place.
    var declinedTreat: Treat {
        switch self {
        case .cat, .owl: .berry
        case .dog, .capybara, .hamster: .fish
        case .bunny, .fox, .redpanda, .hedgehog: .fish
        case .penguin, .otter: .biscuit
        case .stray: .berry
        }
    }

    /// How this one reacts to a given treat.
    func reception(of treat: Treat) -> Treat.Reception {
        if treat == favouriteTreat { return .favourite }
        if treat == declinedTreat { return .declined }
        return .accepted
    }
}

extension Treat {
    enum Reception: String, CaseIterable {
        case favourite, accepted, declined

        /// Whether the buddy bounces. Only the favourite does — a bounce for
        /// everything would make the favourite unfindable, which is the whole
        /// feature.
        var isDelighted: Bool { self == .favourite }
    }

    /// The caption, given how it went. The favourite's line is the only one
    /// that says anything is special about it, and it is said **once** — see
    /// `Pouch.hasFedFavourite`.
    func line(for reception: Reception, isFirstFavourite: Bool) -> String {
        switch reception {
        case .declined: nudgedLine
        case .accepted: acceptedLine
        case .favourite:
            isFirstFavourite
                ? "\(takenLine) That is the one, then."
                : takenLine
        }
    }
}
