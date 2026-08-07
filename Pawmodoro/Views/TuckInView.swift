import SwiftUI

/// The folded blanket that waits beside the buddy after sunset. Drag it over
/// and the buddy is tucked in; the receipt is a timestamped caption tonight
/// and a guaranteed dream tomorrow.
///
/// Sits on the buddy's right, mirroring the sill on the left, and drags the
/// other way. Always accepted — there is no wrong way to tuck someone in.
struct TuckChip: View {
    /// Winter nights get the star-quilt.
    let starry: Bool
    let onTucked: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var drag: CGSize = .zero
    @State private var gone = false
    @State private var inFlight = false

    private static let flightTarget = CGSize(width: -82, height: -2)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.cream.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.bark.opacity(0.14), lineWidth: 1)
                )
            Image(starry ? "fx_blanket_folded_winter" : "fx_blanket_folded")
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 22)
        }
        .frame(width: 44, height: 44)
        .scaleEffect(gone ? 0.3 : 1)
        .opacity(gone ? 0 : 1)
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
                let toward = value.translation.width < -44
                    && abs(value.translation.height) < 90
                guard toward else {
                    withAnimation(.spring(duration: 0.4, bounce: 0.35)) { drag = .zero }
                    return
                }
                if reduceMotion {
                    onTucked()
                    return
                }
                inFlight = true
                withAnimation(.easeIn(duration: 0.26)) {
                    drag = Self.flightTarget
                    gone = true
                }
                Task {
                    try? await Task.sleep(nanoseconds: 290_000_000)
                    onTucked()
                }
            }
    }
}
