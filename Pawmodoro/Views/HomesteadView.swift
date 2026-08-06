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

    /// One thing standing in the homestead — a tree or a neighbour.
    ///
    /// Both go through the same struct so the draw order can be a single
    /// sort. A tree has one asset and a resident has two; `asset(frame:)`
    /// wraps, so a tree simply ignores the clock.
    private struct Piece: Identifiable {
        let id: String
        let x: Double
        let y: Double
        let size: CGSize
        let assets: [String]

        func asset(frame: Int) -> String { assets[frame % assets.count] }
    }

    /// The wood, then the yard. Within each, far things first, so nearer ones
    /// overlap them rather than being hidden behind — that is the whole of the
    /// depth illusion. Across the two, the yard always wins, which is what
    /// keeps a neighbour from being swallowed by a full canopy.
    private var pieces: [Piece] {
        let wood = trees
            .sorted { $0.y < $1.y }
            .map { tree in
                Piece(id: "tree-\(tree.index)", x: tree.x, y: tree.y,
                      size: tree.stage.size, assets: [tree.stage.asset])
            }
        var yard = residents
            .sorted { $0.position.y < $1.position.y }
            .map { resident in
                Piece(id: "resident-\(resident.rawValue)",
                      x: resident.position.x, y: resident.position.y,
                      size: resident.size, assets: resident.frames)
            }
        if let den {
            // Not animated: its two frames are empty and occupied, chosen by
            // the world's clock rather than by a timer. A house that blinks
            // between somebody being in and out twice a second would be a
            // haunting.
            let occupied = den.isOccupied(at: dayPart, buddy: engine.settings.buddy)
            yard.append(Piece(
                id: "den-\(den.rawValue)",
                x: Den.position.x, y: Den.position.y,
                size: den.size, assets: [den.frames[occupied ? 1 : 0]]
            ))
            yard.sort { $0.y < $1.y }
        }
        return wood + yard
    }

    /// A `Canvas` would be cheaper, but every piece is a pixel-art sprite and
    /// `Canvas` cannot draw `Image` with `.interpolation(.none)` — the trees
    /// would come out smoothed, which in this art style reads as a bug.
    private var wood: some View {
        GeometryReader { geometry in
            // The timeline is only mounted once somebody lives here: an empty
            // homestead, and a wood with no residents in it, are both still
            // pictures and should cost nothing to leave on screen.
            if residents.isEmpty {
                scene(in: geometry.size, frame: 0)
            } else {
                TimelineView(.periodic(from: .now, by: Resident.frameSeconds)) { context in
                    scene(in: geometry.size, frame: Self.frame(at: context.date))
                }
            }
        }
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

    /// Derived from the wall clock rather than counted, for the same reason
    /// the countdown is: a view that scrolls off screen stops getting ticks,
    /// and a counter would come back out of step with itself.
    private static func frame(at date: Date) -> Int {
        let elapsed = date.timeIntervalSinceReferenceDate / Resident.frameSeconds
        return Int(elapsed.rounded(.down)) % 2
    }

    private func scene(in size: CGSize, frame: Int) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(pieces) { piece in
                Image(piece.asset(frame: frame))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: piece.size.width, height: piece.size.height)
                    // Positioned by its *base*, like the stray and the snail:
                    // anchoring a centre puts a tall tree's roots lower than a
                    // short one's, and the error grows with the art, which is
                    // the hardest kind to see.
                    .position(x: size.width * piece.x,
                              y: size.height * piece.y - piece.size.height / 2)
            }
        }
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
