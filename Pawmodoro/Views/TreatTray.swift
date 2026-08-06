import SwiftUI

/// Three things on the desk, to hand up to the buddy.
///
/// Only while nothing is counting down — during a break or while idle. A treat
/// offered mid-focus would be a reason to touch the screen during the one
/// stretch of time this app exists to leave alone.
///
/// ### The gesture, and why it is two gestures
///
/// The drag is the relationship: lift a treat and the buddy's eyes follow it
/// across the screen; carry it close and the buddy sits up; let go within
/// reach and it is handed over, the sprite shrinking into the buddy with a
/// scatter of crumbs. Let go anywhere else and the treat glides back to the
/// desk — nothing lost, nothing scored.
///
/// A **tap** does the same offering. That is not a hedge: a drag target is
/// unreachable by VoiceOver and by anybody using Switch Control, and this is a
/// gesture of affection — the last feature in the app that should be
/// sight-and-dexterity gated. The tap is the accessible path and it happens to
/// also be the path for anybody who never discovers the drag.
///
/// ### The drop test, now that it can be honest
///
/// The first release accepted any upward toss (`translation.height < -30`),
/// because on Linux no geometry could be checked and the tray sits directly
/// beneath the buddy. That rule survives — a hesitant lift is still an offer —
/// but the real question is now asked too: `BuddyView` publishes its sprite's
/// frame through `TouchTracker`, so "did it land on the buddy" is a distance
/// to the actual animal on the actual screen, not a guess about layout.
struct TreatTray: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far up counts as handing it over. Generous — a hesitant lift is
    /// still an offer, and the failure mode of a too-small number is a treat
    /// that snaps back for no reason anybody can see.
    private static let toss: CGFloat = 30

    /// How close to the sprite's centre counts as within reach. The sprite is
    /// 104pt across, so this is the animal plus a whisker — near enough that
    /// perking up reads as *about the treat*, not about the room.
    private static let reach: CGFloat = 80

    @State private var dragging: Treat?
    @State private var offset: CGSize = .zero
    /// The tray's own place on screen, for converting the global points the
    /// drag reports into local ones the eat overlay can be drawn at.
    @State private var trayFrame: CGRect = .zero
    @State private var eating: EatMoment?
    @State private var eatSeed = 0

    var body: some View {
        HStack(spacing: 18) {
            ForEach(Treat.allCases) { treat in
                treatButton(treat)
            }
        }
        .padding(.vertical, 4)
        .background(GeometryReader { proxy in
            Color.clear
                .onAppear { trayFrame = proxy.frame(in: .global) }
                .onChange(of: proxy.frame(in: .global)) { _, frame in
                    trayFrame = frame
                }
        })
        // The treat mid-flight and its crumbs. An overlay on the tray rather
        // than a child of any chip, so it can draw above the tray's bounds —
        // the buddy is a hundred points up.
        .overlay(alignment: .topLeading) {
            if let eating {
                EatFX(moment: eating)
                    .id(eating.id)
            }
        }
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
            // While its ghost is being eaten the chip on the desk stays
            // hidden, then fades back in — the desk restocking itself.
            .opacity(eating?.treat == treat ? 0 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25),
                       value: dragging)
            .animation(.easeIn(duration: 0.2), value: eating)
            .contentShape(Rectangle())
            .gesture(
                // Global coordinates, because the question this drag answers —
                // is the treat at the buddy — is a question about the screen,
                // not about this chip.
                DragGesture(minimumDistance: 4, coordinateSpace: .global)
                    .onChanged { value in
                        dragging = treat
                        offset = value.translation
                        // The buddy watches the treat travel, through the same
                        // channel its eyes already follow a finger on the
                        // scenery — and notices when it comes within reach.
                        TouchTracker.shared.x =
                            Double(value.location.x / max(screenWidth, 1))
                        TouchTracker.shared.treatNear = withinReach(value.location)
                    }
                    .onEnded { value in
                        let handedOver = withinReach(value.location)
                            || value.translation.height < -Self.toss
                        TouchTracker.shared.x = nil
                        TouchTracker.shared.treatNear = false
                        if handedOver {
                            playEat(treat, from: value.location)
                            offer(treat)
                        }
                        // Not handed over: clearing the offset under the
                        // spring above is the glide home.
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

    // MARK: Geometry

    /// The screen's width, recovered from the tray's own frame: the tray is a
    /// centred `HStack`, so its margins are symmetric and the sum is the
    /// window. Only ever used as a denominator for "left or right of centre".
    private var screenWidth: CGFloat {
        trayFrame.width + trayFrame.minX * 2
    }

    private func withinReach(_ point: CGPoint) -> Bool {
        guard let frame = TouchTracker.shared.buddyFrame else { return false }
        return hypot(point.x - frame.midX, point.y - frame.midY) < Self.reach
    }

    // MARK: The eat moment

    /// The treat shrinks into the buddy, and a few crumbs fall. Purely
    /// cosmetic — the offer itself already happened — and it clears itself so
    /// the 30fps crumb canvas is only mounted while there is anything to draw.
    private func playEat(_ treat: Treat, from global: CGPoint) {
        guard let buddyFrame = TouchTracker.shared.buddyFrame else { return }
        eatSeed += 1
        let id = eatSeed
        eating = EatMoment(
            id: id,
            treat: treat,
            from: CGPoint(x: global.x - trayFrame.minX,
                          y: global.y - trayFrame.minY),
            to: CGPoint(x: buddyFrame.midX - trayFrame.minX,
                        y: buddyFrame.midY - trayFrame.minY)
        )
        Task {
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            if eating?.id == id { eating = nil }
        }
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

/// One hand-over: which treat, where it was let go, and where the buddy is.
/// Points are in the tray's local space.
private struct EatMoment: Equatable {
    let id: Int
    let treat: Treat
    let from: CGPoint
    let to: CGPoint
}

/// The treat's last moment: it shrinks into the buddy and leaves three crumbs.
///
/// Under Reduce Motion nothing travels and nothing falls — the treat simply
/// fades where it was released, which keeps the acknowledgement and drops the
/// motion, same trade the hearts make.
private struct EatFX: View {
    let moment: EatMoment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false
    /// Set when the treat reaches the buddy; the crumbs' own clock.
    @State private var landedAt: Date?

    /// How long the treat takes to reach the buddy's mouth.
    private static let flight: TimeInterval = 0.3

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(moment.treat.asset)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .scaleEffect(arrived && !reduceMotion ? 0.15 : 1)
                .opacity(arrived ? 0 : 1)
                .position(reduceMotion || !arrived ? moment.from : moment.to)

            // Mounted only while there are crumbs to draw, like every other
            // canvas in the app. Three particles, well under the budget.
            if let landedAt, !reduceMotion {
                crumbs(since: landedAt)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeIn(duration: reduceMotion ? 0.45 : Self.flight)) {
                arrived = true
            }
            guard !reduceMotion else { return }
            Task {
                try? await Task.sleep(
                    nanoseconds: UInt64(Self.flight * 1_000_000_000))
                landedAt = Date()
            }
        }
    }

    private func crumbs(since landedAt: Date) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { canvas, _ in
                let age: Double = context.date.timeIntervalSince(landedAt)
                let t: CGFloat = CGFloat(min(1.0, max(0.0, age / 0.6)))
                let fade: Double = Double(1 - t) * 0.7
                for index in 0..<3 {
                    let spread: CGFloat = CGFloat(index - 1)
                    let drift: CGFloat = spread * 10 * t
                    let fall: CGFloat = t * t * 20 + abs(spread) * 3
                    let x: CGFloat = moment.to.x + drift
                    let y: CGFloat = moment.to.y + 8 + fall
                    let dot = CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)
                    canvas.fill(
                        Path(ellipseIn: dot),
                        with: .color(Theme.bark.opacity(fade))
                    )
                }
            }
        }
    }
}
