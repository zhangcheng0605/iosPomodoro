import SwiftUI

/// Three things on the desk, to hand up to the buddy.
///
/// Only while nothing is counting down — during a break or while idle. A treat
/// offered mid-focus would be a reason to touch the screen during the one
/// stretch of time this app exists to leave alone.
///
/// ### The gesture, and why it is two gestures
///
/// The plan asked for a **drag** to the buddy, and that is the one that makes
/// it feel like handing something over rather than picking from a menu. So a
/// treat lifts under the finger and an upward toss offers it.
///
/// A **tap** does the same thing. That is not a hedge: a drag target is
/// unreachable by VoiceOver and by anybody using Switch Control, and this is a
/// gesture of affection — the last feature in the app that should be
/// sight-and-dexterity gated. The tap is the accessible path and it happens to
/// also be the path for anybody who never discovers the drag.
///
/// ### The drop test is deliberately naive
///
/// "Did it land on the buddy" would need the buddy's frame in this view's
/// coordinate space, which is a thing that breaks quietly on a different
/// screen size. The tray sits directly beneath the buddy, so *upward, far
/// enough* is the same question and cannot be got wrong: `translation.height <
/// -Self.toss`. Written on Linux, where no geometry could have been checked.
struct TreatTray: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far up counts as handing it over. Generous — a hesitant lift is
    /// still an offer, and the failure mode of a too-small number is a treat
    /// that snaps back for no reason anybody can see.
    private static let toss: CGFloat = 30

    @State private var dragging: Treat?
    @State private var offset: CGSize = .zero

    var body: some View {
        HStack(spacing: 18) {
            ForEach(Treat.allCases) { treat in
                treatButton(treat)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Treats")
    }

    private func treatButton(_ treat: Treat) -> some View {
        Image(treat.asset)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: 30, height: 30)
            .offset(dragging == treat ? offset : .zero)
            .scaleEffect(dragging == treat ? 1.15 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25),
                       value: dragging)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        dragging = treat
                        offset = value.translation
                    }
                    .onEnded { value in
                        if value.translation.height < -Self.toss {
                            offer(treat)
                        }
                        dragging = nil
                        offset = .zero
                    }
            )
            // Alongside the drag rather than instead of it. `simultaneously`
            // is wrong here — a tap and a drag are two answers to the same
            // question and only one of them happened.
            .onTapGesture { offer(treat) }
            .accessibilityLabel(treat.name)
            .accessibilityHint("Offers it")
            .accessibilityAddTraits(.isButton)
    }

    /// Hand it over, and take the caption away again a few seconds later.
    ///
    /// The engine holds the result for exactly as long as somebody needs to
    /// read one sentence. Nothing is stored, nothing is spent, and the only
    /// thing that survives is `Pouch.hasFedFavourite`, which exists so the
    /// "that is the one, then" line is said once per buddy in a lifetime.
    private func offer(_ treat: Treat) {
        engine.offer(treat)
        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            engine.clearOffer()
        }
    }
}
