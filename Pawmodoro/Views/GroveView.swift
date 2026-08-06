import SwiftUI

/// The wood behind the house.
///
/// One tree per completed focus hour, growing through three stages and then
/// staying a tree. A hundred hours is a small forest that exists because you
/// sat still, and there is nothing else to say about it — no percentage, no
/// next milestone, no "12 trees to go". The only number anywhere near it is
/// how long until the next one, and that is phrased as an observation.
///
/// Nothing here can be lost. That is the era's law and this is the surface it
/// was written for: a plant that could wilt would make the app a thing you owe
/// something to.
struct GroveView: View {
    @Environment(TimerEngine.self) private var engine

    private var minutes: Int {
        engine.log.records.reduce(0) { $0 + $1.minutes }
    }

    private var trees: [Grove.Tree] { Grove.trees(forMinutes: minutes) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The grove")
                .font(.headline)
                .foregroundStyle(Theme.bark)

            Text(caption)
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.6))

            wood
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

    /// A `Canvas` would be cheaper, but each tree is a pixel-art sprite and
    /// `Canvas` cannot draw `Image` with `.interpolation(.none)` — the trees
    /// would come out smoothed, which in this art style reads as a bug.
    private var wood: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(trees) { tree in
                    Image(tree.stage.asset)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: tree.stage.size.width,
                               height: tree.stage.size.height)
                        // Positioned by its *base*, like the stray and the
                        // snail: anchoring a centre puts a tall tree's roots
                        // lower than a short one's, and the error grows with
                        // the art, which is the hardest kind to see.
                        .position(
                            x: geometry.size.width * tree.x,
                            y: geometry.size.height * tree.y
                                - tree.stage.size.height / 2
                        )
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
        guard !trees.isEmpty else {
            return "The grove, with nothing in it yet. An hour of focus plants "
                + "a tree."
        }
        let full = trees.filter { $0.stage == .full }.count
        var line = "The grove: \(trees.count) trees"
        if full > 0 { line += ", \(full) of them fully grown" }
        return line + "."
    }
}
