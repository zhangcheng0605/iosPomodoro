import SwiftUI

/// Home, on two clocks.
///
/// A tree per completed focus **hour**, and a neighbour at quiet milestones of
/// the **session** count — the wood measures how long you sat, the residents
/// measure how often you came back. Neither is a target: there is no
/// percentage, no next milestone and no "12 trees to go". The only number
/// anywhere near it is how long until the next tree, and that is phrased as an
/// observation about a wood rather than a countdown.
///
/// Nothing here can be lost. That is the era's law and this is the surface it
/// was written for: a plant that could wilt, or a pond that could dry up,
/// would make the app a thing you owe something to.
///
/// The wood is drawn first and the neighbours over the top of it, each half
/// depth-sorted within itself. That ordering is load-bearing: the first
/// version interleaved them, which looks better at twenty trees and at a
/// hundred and twenty leaves the pond entirely behind an oak.
/// `tools/check_residents.py` measured it — 80 to 100 % of every resident
/// gone — and the residents moved to the near band in front. A thing this app
/// says can never be lost has to still be *there* after four months.
struct HomesteadView: View {
    @Environment(TimerEngine.self) private var engine

    private var minutes: Int { engine.log.totalMinutes }

    private var trees: [Grove.Tree] { Grove.trees(forMinutes: minutes) }

    private var residents: [Resident] {
        Resident.settled(sessions: engine.log.totalSessions)
    }

    /// The current buddy's house, if it has been traded for. One at a time —
    /// twelve dens in one yard would be a housing estate.
    private var den: Den? { engine.visibleDen }

    private var dayPart: DayPart { LaunchOptions.forcedDayPart ?? DayPart.current() }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The homestead")
                .font(.headline)
                .foregroundStyle(Theme.bark)

            Text(caption)
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.6))

            wood

            if let line = residentLine {
                Text(line)
                    .font(.footnote)
                    .foregroundStyle(Theme.bark.opacity(0.6))
            }
        }
    }

    private var caption: String {
        guard !trees.isEmpty else {
            return "An hour of focus plants a tree back here. They never come "
                + "down."
        }
        let count = trees.count
        return count == 1
            ? "One tree, from your first hour."
            : "\(count) trees, one for each hour you have sat."
    }

    /// Who lives here, listed rather than counted. "3 of 8" would turn a
    /// garden into a set to complete, and the whole point of a resident is
    /// that it arrives without ever having been on offer.
    private var residentLine: String? {
        var names = residents.map(\.settledLine)
        if let den { names.append(den.settledLine) }
        switch names.count {
        case 0: return nil
        case 1: return "There is \(names[0])."
        default:
            let head = names.dropLast().joined(separator: ", ")
            return "There is \(head) and \(names[names.count - 1])."
        }
    }

    // MARK: The scene

    private var wood: some View {
        HomesteadScene(trees: trees, residents: residents, den: den,
                       dayPart: dayPart, buddy: engine.settings.buddy)
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.surface.opacity(0.55))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .bottomTrailing) {
            if let line = nextLine {
                Text(line)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.bark.opacity(0.45))
                    .padding(8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Deliberately an observation rather than a countdown. "38 minutes to
    /// your next tree" is a target; "the next one is about 38 minutes away" is
    /// a fact about a wood.
    private var nextLine: String? {
        guard !trees.isEmpty,
              let remaining = Grove.minutesToNextTree(from: minutes)
        else { return nil }
        return "the next is about \(remaining) minutes away"
    }

    private var accessibilityLabel: String {
        guard !trees.isEmpty || !residents.isEmpty else {
            return "The homestead, with nothing in it yet. An hour of focus "
                + "plants a tree."
        }
        var line = "The homestead"
        if !trees.isEmpty {
            let full = trees.filter { $0.stage == .full }.count
            line += ": \(trees.count) trees"
            if full > 0 { line += ", \(full) of them fully grown" }
        }
        if let residentLine { return line + ". " + residentLine }
        return line + "."
    }
}
