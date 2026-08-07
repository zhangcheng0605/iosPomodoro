import SwiftUI

/// The moth two greeting vignettes are about. Loops around the buddy's head
/// at 8fps; in the rare variant it settles on the nose and everybody holds
/// still. Mounted only while its vignette plays, per the canvas rule.
struct HelloMothView: View {
    let lands: Bool
    let spriteSize: CGFloat

    @State private var born = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 8.0)) { context in
            let t = context.date.timeIntervalSince(born)
            let spot = position(at: t)
            Image("fx_moth_\(Int(t * 6) % 2)")
                .renderingMode(.template)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 15)
                .foregroundStyle(Theme.bark.opacity(0.7))
                .offset(x: spot.x, y: spot.y)
                .opacity(t > 5.2 ? max(0, 1 - (t - 5.2) / 0.8) : 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func position(at t: Double) -> CGPoint {
        let loop = CGPoint(
            x: sin(t * 1.9) * spriteSize * 0.55,
            y: -spriteSize * 0.35 + sin(t * 3.1) * spriteSize * 0.16
        )
        guard lands, t > 2.2 else { return loop }
        // Eases from wherever the loop was onto the nose, then stays put.
        let nose = CGPoint(x: -spriteSize * 0.02, y: -spriteSize * 0.12)
        let blend = min(1, (t - 2.2) / 0.5)
        let hold = CGPoint(
            x: sin(2.2 * 1.9) * spriteSize * 0.55,
            y: -spriteSize * 0.35 + sin(2.2 * 3.1) * spriteSize * 0.16
        )
        return CGPoint(
            x: hold.x + (nose.x - hold.x) * blend,
            y: hold.y + (nose.y - hold.y) * blend
        )
    }
}

/// The drawer: everything ever carried home, each with its provenance —
/// what, where, who, when. The plan's single collection surface.
struct KeepsakeDrawerView: View {
    @Environment(TimerEngine.self) private var engine

    private let columns = [GridItem(.adaptive(minimum: 48), spacing: 10)]

    var body: some View {
        let items = engine.drawer.items

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "archivebox.fill")
                Text("The drawer")
                Spacer()
                if !items.isEmpty {
                    Text("\(items.count) kept")
                        .foregroundStyle(Theme.bark.opacity(0.6))
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.blossom)

            if items.isEmpty {
                Text("Go live a little. \(engine.buddyName) finds things while you're away, and everything carried home lands here.")
                    .font(.caption)
                    .foregroundStyle(Theme.bark.opacity(0.65))
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(items.reversed()) { record in
                        cell(for: record)
                    }
                }
                if let newest = items.last {
                    Text(provenance(for: newest))
                        .font(.caption)
                        .foregroundStyle(Theme.bark.opacity(0.65))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface.opacity(0.75)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(drawerAccessibilityLabel(items: items))
    }

    @ViewBuilder
    private func cell(for record: KeepsakeRecord) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.cream.opacity(0.9))
            if let trinket = Trinket(rawValue: record.keepsake) {
                Image(trinket.assetName)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
            }
        }
        .frame(width: 48, height: 48)
    }

    /// "Sea glass — the sea made it soft. Harbor Isle, with Mochi, Aug 7."
    private func provenance(for record: KeepsakeRecord) -> String {
        guard let trinket = Trinket(rawValue: record.keepsake) else { return "" }
        // A finder that isn't a buddy is a night visitor who left it.
        let finder = Buddy(rawValue: record.finder).map {
            engine.settings.displayName(for: $0)
        } ?? "a visitor"
        let place = Place(rawValue: record.place)?.name ?? "somewhere out there"
        let day = record.date.formatted(.dateTime.month(.abbreviated).day())
        return "\(trinket.name) — \(trinket.note). \(place), with \(finder), \(day)."
    }

    private func drawerAccessibilityLabel(items: [KeepsakeRecord]) -> String {
        guard !items.isEmpty else {
            return "The drawer, empty. Keepsakes the buddy carries home land here."
        }
        guard let newest = items.last else { return "The drawer." }
        return "The drawer: \(items.count) keepsakes. Newest: \(provenance(for: newest))"
    }
}
