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

/// The blanket where it lands: draped over the sleeping buddy — and the way
/// back out from under it.
///
/// All twelve asleep poses fill the lower half of the same grid, so one
/// overlay drapes everyone. It went on by being dragged over the buddy; it
/// comes off by being dragged back the way it came, the same 44pt in the
/// other direction, towards the spot the folded blanket sits on. A blanket
/// you cannot lift is a trap, and the blanket is the one thing in this app
/// that covers the buddy up entirely.
///
/// Lifting it costs nothing: the night's guaranteed dream was earned when the
/// blanket went on and `TuckIn.lift(on:)` does not touch it. The folded chip
/// simply comes back, and the whole ritual can happen again.
///
/// ## Why it hands the still touches back
///
/// This sits *over* the sprite, and the sprite is where the buddy's own
/// stroking gesture lives. A view with a gesture on it takes the touch
/// whether or not that gesture ever recognises, so a plain `DragGesture` here
/// would have quietly stopped the buddy being touchable at all for the whole
/// of a night — trading one trap for a smaller one. Instead the drag starts
/// at zero distance and a touch that goes nowhere is reported back through
/// `onTouched`, which the buddy answers exactly as it answers a hand laid on
/// it. What is genuinely lost is *where* the hand was: there is a blanket in
/// the way, so a touch under one is a hand on the buddy rather than a hand on
/// its ear, and that is the honest reading rather than a shortfall.
struct BlanketOverlay: View {
    /// Winter nights get the star-quilt, matching the chip it came from.
    let starry: Bool
    /// The sprite's width; the blanket is drawn to the same proportion the
    /// tucked pose was drawn for.
    let spriteSize: CGFloat
    /// A hand that rested on the blanket without pulling it.
    let onTouched: () -> Void
    let onLifted: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var drag: CGSize = .zero
    @State private var gone = false
    @State private var inFlight = false

    var body: some View {
        Image(starry ? "fx_blanket_over_winter" : "fx_blanket_over")
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: spriteSize * 0.98)
            .offset(x: drag.width, y: spriteSize * 0.16 + drag.height * 0.3)
            .opacity(gone ? 0 : 1)
            .gesture(dragGesture)
            .accessibilityHidden(true)   // the buddy cell carries the named action
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !inFlight else { return }
                drag = value.translation
            }
            .onEnded { value in
                guard !inFlight else { return }
                let away = value.translation.width > 44
                    && abs(value.translation.height) < 90
                guard away else {
                    withAnimation(.spring(duration: 0.4, bounce: 0.35)) { drag = .zero }
                    // A touch that went nowhere was never reaching for the
                    // blanket; it was reaching for the buddy under it.
                    if abs(value.translation.width) < 10,
                       abs(value.translation.height) < 10 {
                        onTouched()
                    }
                    return
                }
                if reduceMotion {
                    onLifted()
                    return
                }
                inFlight = true
                withAnimation(.easeOut(duration: 0.26)) {
                    drag = CGSize(width: spriteSize * 0.9, height: 0)
                    gone = true
                }
                Task {
                    try? await Task.sleep(nanoseconds: 290_000_000)
                    onLifted()
                }
            }
    }
}
