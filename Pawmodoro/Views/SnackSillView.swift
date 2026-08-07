import SwiftUI

/// How a dropped snack lands. Decided by pure functions before the chip
/// animates, so the flight can match the outcome instead of guessing.
enum SnackDropVerdict {
    /// Eaten — the chip flies in and vanishes.
    case taken
    /// Politely refused — the chip flies in and bounces back to the sill.
    case snubbed
    /// No room today — the chip never leaves; a caption explains.
    case full
}

/// One snack on a small themed backing beside the buddy. Drag it over and
/// let go: the snack flies the rest of the way and the buddy answers.
///
/// The chip owns only the travel. What the drop *means* is decided by the
/// caller through `verdictForDrop`, and everything that happens to the buddy
/// — the bounce, the purr, the caption — happens in `onLanded`, back in
/// `BuddyView`, where those effects already live.
struct SnackSillChip: View {
    let snack: Snack
    let verdictForDrop: () -> SnackDropVerdict
    let onLanded: (SnackDropVerdict) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var drag: CGSize = .zero
    @State private var eaten = false
    @State private var inFlight = false

    /// Where the buddy's mouth is, relative to the chip: across the spacing
    /// and half the sprite. Coarse on purpose — the flight is a gesture, not
    /// a docking maneuver.
    private static let flightTarget = CGSize(width: 82, height: -4)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.cream.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.bark.opacity(0.14), lineWidth: 1)
                )
            Image(snack.assetName)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
        }
        .frame(width: 44, height: 44)
        .scaleEffect(eaten ? 0.25 : 1)
        .opacity(eaten ? 0 : 1)
        .offset(drag)
        .zIndex(inFlight || drag != .zero ? 1 : 0)
        .gesture(dragGesture)
        .accessibilityHidden(true)   // the buddy cell carries the named action
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !inFlight else { return }
                drag = value.translation
            }
            .onEnded { value in
                guard !inFlight else { return }
                // Anywhere meaningfully toward the buddy counts. A drop
                // short of the mark springs home without comment.
                let toward = value.translation.width > 44
                    && abs(value.translation.height) < 90
                guard toward else {
                    withAnimation(.spring(duration: 0.4, bounce: 0.35)) { drag = .zero }
                    return
                }
                deliver()
            }
    }

    /// The same drop, for assistive tech and for anyone who'd rather tap.
    func deliver() {
        let verdict = verdictForDrop()
        if reduceMotion {
            // The travel goes, the outcome stays.
            onLanded(verdict)
            withAnimation(.easeOut(duration: 0.3)) {
                drag = .zero
                if verdict == .taken { eaten = true }
            }
            return
        }
        switch verdict {
        case .taken:
            inFlight = true
            withAnimation(.easeIn(duration: 0.24)) {
                drag = Self.flightTarget
                eaten = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 270_000_000)
                onLanded(.taken)
            }
        case .snubbed:
            inFlight = true
            withAnimation(.easeIn(duration: 0.22)) { drag = Self.flightTarget }
            Task {
                try? await Task.sleep(nanoseconds: 250_000_000)
                onLanded(.snubbed)
                withAnimation(.spring(duration: 0.5, bounce: 0.4)) { drag = .zero }
                inFlight = false
            }
        case .full:
            onLanded(.full)
            withAnimation(.spring(duration: 0.4, bounce: 0.35)) { drag = .zero }
        }
    }
}
