import SwiftUI

/// One of the Cabinet's faces, at the current progress.
///
/// A frame out of a strip and nothing else — no timeline, no animation, no
/// state. The frame changes when `engine.progress` crosses a twelfth, which on
/// a 25-minute phase is about every two minutes, and that slowness is the
/// point: these are clocks you notice having moved rather than clocks you
/// watch moving.
struct ClockFaceView: View {
    let face: ClockFace
    let progress: Double

    var body: some View {
        Image(face.frame(at: progress))
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)   // the countdown beside it says the time
    }
}

/// The cabinet itself, in Settings.
///
/// Locked faces are shown with a padlock rather than hidden — the app's rule,
/// and the one that makes a collection feel like a place rather than a menu.
/// The line under a locked face says what earns it and never how close you
/// are: "after 20 sessions finished after dark" is a fact about the world,
/// "6 to go" is a target.
struct ClockFacePicker: View {
    @Environment(TimerEngine.self) private var engine

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(ClockFace.allCases) { face in
                tile(for: face)
            }
        }
        .padding(.vertical, 4)
    }

    private func tile(for face: ClockFace) -> some View {
        let earned = engine.hasEarned(face)
        let selected = engine.settings.clockFace == face

        return Button {
            guard earned else { return }
            engine.settings.clockFace = face
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    // Shown at two thirds through, which is where every face
                    // looks most like itself — a candle at 0 is a candle, and
                    // at 0.66 it is a candle *clock*.
                    if face.isDrawn {
                        Circle()
                            .trim(from: 0, to: 0.66)
                            .stroke(Theme.blossom,
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 34, height: 34)
                    } else {
                        ClockFaceView(face: face, progress: 0.66)
                            .frame(height: 44)
                    }
                }
                .frame(height: 46)
                .opacity(earned ? 1 : 0.3)

                Text(face.name)
                    .font(.caption2.weight(selected ? .semibold : .regular))
                    .foregroundStyle(Theme.bark.opacity(earned ? 0.9 : 0.45))
                    .lineLimit(1)

                Text(earned ? face.blurb : face.lockedLine)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.bark.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 22, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.surface.opacity(selected ? 0.95 : 0.5))
            )
            .overlay(alignment: .topTrailing) {
                if !earned {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.bark.opacity(0.4))
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            earned
                ? "\(face.name). \(face.blurb)"
                : "\(face.name), locked. \(face.lockedLine)"
        )
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
