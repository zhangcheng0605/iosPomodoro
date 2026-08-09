import SwiftUI

/// What this app says back to a pointer.
///
/// On a phone a control is a thing you put your finger on and it either
/// happens or it doesn't; there is no *before*. On a Mac there is, and a
/// control that stays completely still while the cursor sits on it reads as
/// disabled or as decoration. The Mac walk (`docs/MAC_WALK.md` § 9) found
/// `.onHover` and `.help()` appearing **zero** times in the whole app, which
/// is the difference between "an iPad app in a window" and a Mac app more
/// than any single missing feature is.
///
/// ### Three answers, and why they are not one
///
/// The controls on this screen are three different shapes of thing and a
/// single hover treatment cannot fit them:
///
/// - `pointerRing` — a control that already carries a **backing**: the mode
///   chips, the ambience chips, the transport circles, a cart row. They have
///   a shape of their own, so the hover is a quiet themed ring drawn in that
///   shape. Nothing is drawn *over* the label, which is deliberate: every
///   text/background pair in this app clears 4.5:1 and a wash over a glyph
///   would quietly spend some of that (see `tools/check_contrast.py`).
/// - `pointerBacking` — a **bare glyph** with nothing behind it: the five
///   toolbar buttons. A light themed rounded rect appears under the cursor,
///   which is what every Mac toolbar does, and it *raises* the glyph's
///   contrast rather than lowering it.
/// - `pointerGlow` — **art**, which has no shape to ring: the buddy. A soft
///   themed glow around the silhouette. Pointedly *not* a scale, which was the
///   first thing tried: every sprite in this app is nearest-neighbour pixel
///   art drawn with `.interpolation(.none)`, and scaling it by three percent
///   makes some pixels a row taller than their neighbours. A shadow blurs the
///   alpha channel and leaves every pixel where the artist put it.
///
/// ### It compiles out
///
/// Every one of these is `self` on iOS — not a no-op modifier, not a wrapper
/// view, `self` — so the phone build has no hover state to store, no tracking
/// area, no extra layer and not one changed pixel. `.help()` in particular is
/// *not* free on iOS: it sets the accessibility hint there, and several of
/// these controls already have hints that say something better.
///
/// The colours go through `Theme` like everything else, so a hover looks like
/// it belongs in whichever of the four themes is on.
///
/// ### How to look at it, since you cannot hover
///
/// `-PawmodoroHover` holds all three of these on at once. It exists because a
/// hover state is the one appearance in this app that cannot be reached by
/// driving the app — `.onHover` is fed by the window server from the *real*
/// cursor, and a posted mouse-move never touches it. So:
///
///     tools/mac_probe.py --app <build>/Pawmodoro.app \
///         --flags -PawmodoroDemo -PawmodoroHover -- --shot hovered.png
///
/// and compare against the same run without the flag. What that proves is the
/// appearance and nothing else; the wiring — that `.onHover` is attached to
/// the right subview, and that the subview is a thing a pointer can land on —
/// is read here, not seen. Keep those two claims apart when reporting.
extension View {

    /// A quiet themed ring under the pointer, in the control's own shape.
    ///
    /// The shape is passed in rather than guessed because these controls are
    /// capsules, rounded rects and circles, and a ring that doesn't follow the
    /// backing looks like a rendering fault.
    func pointerRing<S: InsettableShape>(_ shape: S) -> some View {
        #if os(macOS)
        modifier(PointerRing(shape: shape))
        #else
        self
        #endif
    }

    /// A themed backing that fades in under a bare glyph — the toolbar idiom.
    func pointerBacking(cornerRadius: CGFloat = 7, inset: CGFloat = -5) -> some View {
        #if os(macOS)
        modifier(PointerBacking(cornerRadius: cornerRadius, inset: inset))
        #else
        self
        #endif
    }

    /// A soft themed glow around a silhouette, for art with no edge to ring.
    func pointerGlow(radius: CGFloat = 9) -> some View {
        #if os(macOS)
        modifier(PointerGlow(radius: radius))
        #else
        self
        #endif
    }

    /// A right-click menu, on a Mac only — and only when there is genuinely
    /// something on it.
    ///
    /// The condition is the whole reason this exists rather than a bare
    /// `.contextMenu`: every action this app offers by hand is conditional on
    /// the hour, the weather or what the buddy happens to have brought you, so
    /// most of the time the honest menu is *no menu*. An empty grey rectangle
    /// on right-click is worse than a right-click that does nothing, because
    /// it looks like the app is broken rather than quiet.
    @ViewBuilder
    func pointerMenu<M: View>(
        when available: Bool, @ViewBuilder items: () -> M
    ) -> some View {
        #if os(macOS)
        if available {
            contextMenu(menuItems: items)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// `.help()` on a Mac, and nothing whatsoever on a phone.
    ///
    /// Named for what it is rather than shadowing `.help` so that reading a
    /// call site tells you which platform is being talked to. Keep the text
    /// short and in the app's voice — a tooltip is the app speaking directly
    /// to the reader, which is the register `tools/check_post.py` fences on
    /// the one other surface that does it.
    func tooltip(_ text: String) -> some View {
        #if os(macOS)
        help(text)
        #else
        self
        #endif
    }
}

#if os(macOS)

/// How long the answer takes. Short enough to feel like the control noticed,
/// slow enough that dragging the cursor across the ambience row does not
/// strobe nineteen chips.
private enum PointerTiming {
    static let animation: Animation = .easeOut(duration: 0.12)
}

/// Whether an affordance should be drawn, given whether the cursor is actually
/// on it.
///
/// The `||` is `-PawmodoroHover`, and it is the only way anything in this file
/// can be *seen* by a process that is not allowed to move the cursor. A posted
/// `mouseMoved` does not drive `.onHover` — the window server synthesizes
/// enter and exit from the real pointer against the window's tracking areas,
/// and an event injected into the app's own queue never goes past it. So the
/// choice is to move the owner's mouse out from under his hand or to render
/// the hovered state and photograph that, and this is that.
///
/// One function rather than three copies of the expression, so that the flag
/// cannot end up wired to two of the three modifiers — which is a bug whose
/// only symptom is a screenshot that looks fine.
private func pointerShows(_ hovering: Bool) -> Bool {
    hovering || LaunchOptions.pinHover
}

private struct PointerRing<S: InsettableShape>: ViewModifier {
    let shape: S
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            // `strokeBorder` rather than `stroke`, which is why the shape is
            // constrained to `InsettableShape`: a centred stroke puts half its
            // width outside the backing and reads as a halo.
            // 0.45 rather than the third it started at, decided off a
            // screenshot rather than in the editor: on the pink of a selected
            // mode chip a third read fine, and on the cream of an ambience
            // chip — the row with nineteen of them, and the row a pointer
            // sweeps along — it was there in the pixel diff and not there to
            // the eye. The weaker value is the one that flatters the code and
            // fails the person using it.
            .overlay(
                shape.strokeBorder(
                    Theme.bark.opacity(pointerShows(hovering) ? 0.45 : 0),
                    lineWidth: 1.5
                )
                .allowsHitTesting(false)
            )
            .onHover { hovering = $0 }
            .animation(PointerTiming.animation, value: hovering)
    }
}

private struct PointerBacking: ViewModifier {
    let cornerRadius: CGFloat
    let inset: CGFloat
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.surface.opacity(pointerShows(hovering) ? 0.85 : 0))
                    // Negative padding, so the backing is a little larger than
                    // the glyph it sits behind rather than clipped to it.
                    .padding(inset)
            }
            .onHover { hovering = $0 }
            .animation(PointerTiming.animation, value: hovering)
    }
}

private struct PointerGlow: ViewModifier {
    let radius: CGFloat
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .shadow(
                color: Theme.blossom.opacity(pointerShows(hovering) ? 0.75 : 0),
                radius: radius
            )
            .onHover { hovering = $0 }
            .animation(PointerTiming.animation, value: hovering)
    }
}

#endif
