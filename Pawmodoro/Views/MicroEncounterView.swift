import SwiftUI

/// Three tiny moments that are never written down anywhere.
///
/// A butterfly that lands on a sleeping buddy's nose. A robin on the top of the
/// timer ring for a few seconds. A snowflake that settles on a nose in
/// December. No journal entry, no card, no count — they happen, and then
/// they've happened, and the only record is that you saw it.
///
/// That is the whole design. The field journal exists to be filled; this exists
/// to be *told about*, which is a different and rarer kind of pleasure and
/// would be ruined by a tick-box.
enum MicroEncounter: String, CaseIterable, Identifiable {
    case butterfly
    case robin
    case snowflake

    var id: String { rawValue }

    /// Reuses the wildlife sprites — no new art, and the butterfly on the nose
    /// is recognisably the same butterfly from the journal.
    var asset: String {
        switch self {
        case .butterfly: "wild_butterfly_0"
        case .robin: "wild_robin_0"
        // A snowflake is four strokes; drawing one would be sillier than
        // composing it out of the shape the Canvas already has.
        case .snowflake: ""
        }
    }

    var size: CGSize {
        switch self {
        case .butterfly: CGSize(width: 22, height: 18)
        case .robin: CGSize(width: 24, height: 21)
        case .snowflake: CGSize(width: 12, height: 12)
        }
    }

    /// Where it lands, as fractions of the screen.
    ///
    /// The nose ones sit just above the buddy, which lives under the ring; the
    /// robin perches on the ring's top edge. Both are eyeballed rather than
    /// measured, and both are decoration that overlaps nothing readable.
    var position: CGPoint {
        switch self {
        case .butterfly, .snowflake: CGPoint(x: 0.53, y: 0.545)
        case .robin: CGPoint(x: 0.62, y: 0.205)
        }
    }

    /// The slice of a focus phase it is present for. All well short of the
    /// chime: the last stretch belongs to the countdown, as ever.
    var window: ClosedRange<Double> {
        switch self {
        case .butterfly: 0.58...0.72
        case .robin: 0.30...0.40
        case .snowflake: 0.62...0.78
        }
    }

    /// Whether it can happen at all right now.
    ///
    /// Deliberately narrow. A butterfly on a nose in a snowstorm at midnight
    /// would be charming exactly once and wrong every time after.
    func isPossible(place: Place, dayPart: DayPart, season: Season?) -> Bool {
        switch self {
        case .butterfly:
            return (place == .meadow || place == .blossom)
                && (dayPart == .day || dayPart == .dawn)
        case .robin:
            return dayPart != .night
        case .snowflake:
            return season == .winter
        }
    }

    /// One in twelve, per eligible session. Rare enough that mentioning it to
    /// somebody is worth doing.
    static let chance = 1.0 / 12.0
}

/// Draws whatever tiny thing is visiting.
///
/// Mounted only inside its own window, like a sighting, and a pure function of
/// progress — no timer, and it is always gone before the chime.
struct MicroEncounterView: View {
    let encounter: MicroEncounter
    /// 0...1 across the visit.
    let phase: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = Date()

    var body: some View {
        GeometryReader { geometry in
            content
                .frame(width: encounter.size.width, height: encounter.size.height)
                .opacity(fade)
                .position(
                    x: geometry.size.width * encounter.position.x,
                    y: geometry.size.height * encounter.position.y
                )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch encounter {
        case .snowflake:
            // Six spokes, drawn rather than drawn *out*: at twelve points a
            // sprite would be four white pixels and a rumour.
            Canvas { canvas, size in
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                var path = Path()
                for spoke in 0..<6 {
                    let angle = Double(spoke) * .pi / 3
                    path.move(to: centre)
                    path.addLine(to: CGPoint(
                        x: centre.x + cos(angle) * size.width * 0.46,
                        y: centre.y + sin(angle) * size.height * 0.46
                    ))
                }
                canvas.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 1.4)
            }
        default:
            sprite
        }
    }

    @ViewBuilder
    private var sprite: some View {
        if reduceMotion {
            image
        } else {
            // A slow wing-flap while it sits there. Two frames would need a
            // second asset; a gentle squash costs nothing and reads the same.
            TimelineView(.periodic(from: .now, by: 1.0 / 6.0)) { context in
                let beat = context.date.timeIntervalSince(arrived) * 3
                image.scaleEffect(x: 0.86 + 0.14 * abs(sin(beat)), y: 1, anchor: .center)
            }
        }
    }

    private var image: some View {
        Image(encounter.asset)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
    }

    /// Lands and leaves. Slower at both ends than a sighting's, because it is
    /// settling onto something rather than passing through.
    private var fade: Double {
        let edge = 0.26
        if phase < edge { return max(0, phase / edge) }
        if phase > 1 - edge { return max(0, (1 - phase) / edge) }
        return 1
    }
}
