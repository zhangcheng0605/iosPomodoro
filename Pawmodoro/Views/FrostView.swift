import SwiftUI

/// Frost mornings (PowerWash Simulator, one stroke of it).
///
/// On winter and late-autumn mornings the pane wakes lightly frosted: a
/// soft veil with crystal specks, drawn over the scene and under the UI.
/// Wipe with a finger and the stroke clears a crisp path — one soft
/// haptic per stroke, the buddy's eyes following your hand. Wipe most of
/// it and the rest lets go. Unwiped, it melts on its own by mid-morning,
/// and no record is kept of whether you touched it: the pleasure is the
/// feature, and there is nothing here to owe.
///
/// During a running focus the frost is already gone — it melted while
/// you worked. The fiction holds and the focus-is-sacred rule holds,
/// which is why a started focus melts it for the day rather than merely
/// hiding it.
///
/// Reduce Motion: the frost renders pre-cleared in a soft edge vignette,
/// takes no gestures, and nothing needs wiping to see the scene.
struct FrostView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Finished wipes, plus the one under the finger.
    @State private var strokes: [[CGPoint]] = []
    @State private var current: [CGPoint] = []
    /// Rough cleared area so far, in points squared — overlap is counted
    /// twice, deliberately: close-enough is the generous direction.
    @State private var wiped: CGFloat = 0
    @State private var veilOpacity: Double = 1
    @State private var melted = false

    /// A thumb's width of clearing.
    private static let wipeWidth: CGFloat = 46
    /// Past this fraction of the pane, the rest lets go on its own.
    private static let clearance: CGFloat = 0.6
    /// The hour the sun takes over the job.
    private static let meltHour = 10

    var body: some View {
        Group {
            if standing {
                GeometryReader { geometry in
                    pane(in: geometry.size)
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .task { await meltByMidMorning() }
            }
        }
        // A focus start melts the frost for good, not just for the phase:
        // "it was gone when you looked up" only works if it stays gone.
        .onChange(of: engine.isRunning) { _, running in
            if running, engine.phase == .focus {
                melted = true
            }
        }
    }

    /// Whether frost belongs on the pane right now.
    private var standing: Bool {
        guard !melted else { return false }
        if engine.isRunning, engine.phase == .focus { return false }
        if LaunchOptions.frostNow { return true }
        guard let season = Season.current(),
              season == .winter || season == .autumn
        else { return false }
        let hour = LaunchOptions.forcedClockHour
            ?? Calendar.current.component(.hour, from: Date())
        return hour < Self.meltHour
    }

    // MARK: The pane

    private func pane(in size: CGSize) -> some View {
        Canvas { canvas, _ in
            canvas.drawLayer { layer in
                // The veil, and its crystals.
                layer.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Theme.cream.opacity(0.58))
                )
                for index in 0..<48 {
                    layer.fill(
                        Path(ellipseIn: speckRect(index, in: size)),
                        with: .color(Theme.cream.opacity(0.85))
                    )
                }
                // What the finger cleared, punched out of the layer only.
                layer.blendMode = .destinationOut
                if reduceMotion {
                    // Pre-cleared: the middle of the pane is already open,
                    // leaving frost as a soft border vignette.
                    let inset = min(size.width, size.height) * 0.14
                    layer.fill(
                        Path(ellipseIn: CGRect(
                            x: inset, y: inset,
                            width: size.width - inset * 2,
                            height: size.height - inset * 2
                        )),
                        with: .color(Theme.cream)
                    )
                } else {
                    for stroke in strokes + [current] where stroke.count > 1 {
                        var path = Path()
                        path.move(to: stroke[0])
                        path.addLines(stroke)
                        layer.stroke(
                            path,
                            with: .color(Theme.cream),
                            style: StrokeStyle(
                                lineWidth: Self.wipeWidth,
                                lineCap: .round, lineJoin: .round
                            )
                        )
                    }
                }
            }
        }
        .opacity(veilOpacity)
        .contentShape(Rectangle())
        .gesture(reduceMotion ? nil : wipe(in: size))
        .onDisappear { TouchTracker.shared.x = nil }
    }

    /// Crystal specks, deterministic so the same morning draws the same
    /// frost — redraws must not make it shimmer.
    private func speckRect(_ index: Int, in size: CGSize) -> CGRect {
        let x = Double(Doorstep.stableHash("frost.x.\(index)") % 1000) / 1000
        let y = Double(Doorstep.stableHash("frost.y.\(index)") % 1000) / 1000
        let radius = 1.2 + Double(Doorstep.stableHash("frost.r.\(index)") % 22) / 10
        return CGRect(
            x: x * size.width - radius, y: y * size.height - radius,
            width: radius * 2, height: radius * 2
        )
    }

    // MARK: The finger

    private func wipe(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // The eyes follow the wipe, same as they follow a toy.
                TouchTracker.shared.x = value.location.x / max(size.width, 1)
                if current.count < 600 {
                    current.append(value.location)
                }
            }
            .onEnded { _ in
                TouchTracker.shared.x = nil
                guard current.count > 1 else {
                    current = []
                    return
                }
                let length = zip(current, current.dropFirst()).reduce(0) { sum, pair in
                    sum + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
                }
                wiped += (length + Self.wipeWidth) * Self.wipeWidth
                strokes.append(current)
                current = []
                HapticsDirector.shared.detent()
                let pane = max(size.width * size.height, 1)
                if wiped / pane > Self.clearance || strokes.count > 50 {
                    letGo()
                }
            }
    }

    /// The finish PowerWash sells: past the threshold, the remainder
    /// releases in one slow breath.
    private func letGo() {
        withAnimation(.easeInOut(duration: 1.4)) {
            veilOpacity = 0
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            melted = true
        }
    }

    /// Unwiped frost is the sun's problem, not yours: it goes on its own
    /// at mid-morning. Sleeping to a wall-clock date matches the idle-life
    /// loop's precedent; a backgrounded app resumes and catches up.
    private func meltByMidMorning() async {
        guard !LaunchOptions.frostNow else { return }
        let calendar = Calendar.current
        guard let target = calendar.date(
            bySettingHour: Self.meltHour, minute: 0, second: 0, of: Date()
        ) else { return }
        let wait = target.timeIntervalSinceNow
        if wait > 0 {
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        }
        guard !Task.isCancelled, !melted else { return }
        withAnimation(.easeInOut(duration: 2.5)) {
            veilOpacity = 0
        }
        try? await Task.sleep(nanoseconds: 2_600_000_000)
        melted = true
    }
}
