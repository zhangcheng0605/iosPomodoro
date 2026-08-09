import SwiftUI

/// The window-box card: three pockets, the seed on offer, and what each
/// plant is up to. Growth reads straight off the session log — the card
/// stores nothing, per the Stray's derived-state rule.
struct GardenView: View {
    @Environment(TimerEngine.self) private var engine

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                Text("The window-box")
                Spacer()
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.blossom)

            HStack(spacing: 14) {
                ForEach(0..<Garden.pocketCount, id: \.self) { slot in
                    pocketTile(slot)
                }
            }
            .frame(maxWidth: .infinity)

            Text(footline)
                .font(.caption)
                .foregroundStyle(Theme.bark.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface.opacity(0.75)))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func pocketTile(_ slot: Int) -> some View {
        let pocket = engine.garden.pockets[slot]
        Button {
            tap(slot)
        } label: {
            VStack(spacing: 4) {
                Image(assetName(for: pocket))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 55)
                Text(label(for: pocket))
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.bark.opacity(0.55))
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.cream.opacity(0.6))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLine(for: pocket, slot: slot))
    }

    private func tap(_ slot: Int) {
        let pocket = engine.garden.pockets[slot]
        if pocket == nil, engine.garden.seedOnOffer != nil {
            engine.plantSeed(in: slot)
            HapticsDirector.shared.stamp()
        } else if let pocket, engine.garden.isBloomed(pocket, log: engine.log) {
            engine.pickBloom(at: slot)
            HapticsDirector.shared.detent()
        }
    }

    private func assetName(for pocket: GardenPocket?) -> String {
        guard let pocket, let kind = PlantKind(rawValue: pocket.kind) else {
            return "plant_soil"
        }
        return kind.stageAsset(engine.garden.stage(of: pocket, log: engine.log))
    }

    private func label(for pocket: GardenPocket?) -> String {
        guard let pocket, let kind = PlantKind(rawValue: pocket.kind) else {
            return engine.garden.seedOnOffer != nil ? "\(Pointing.tap) to plant" : "soil"
        }
        let stage = engine.garden.stage(of: pocket, log: engine.log)
        if stage >= Garden.bloomStage { return "\(Pointing.tap) to pick" }
        return "day \(stage + 1)"
    }

    private var footline: String {
        if let seed = engine.garden.seedOnOffer,
           let kind = PlantKind(rawValue: seed.kind) {
            return "A seed fell out of a dream — \(kind.name). "
                + "Every day with a finished session waters the pockets."
        }
        if let bloom = engine.garden.blooms(log: engine.log).first,
           let kind = PlantKind(rawValue: bloom.pocket.kind) {
            return kind.bloomRemark(
                species: bloom.pocket.species.flatMap(Species.init(rawValue:))
            )
        }
        if engine.garden.pockets.contains(where: { $0 != nil }) {
            return "Growing at its own pace. Days without a session just "
                + "pause it — nothing here knows how to wilt."
        }
        return "Dreams drop seeds. Keep one to the end of a session and "
            + "check the sill."
    }

    private func accessibilityLine(for pocket: GardenPocket?, slot: Int) -> String {
        guard let pocket, let kind = PlantKind(rawValue: pocket.kind) else {
            return engine.garden.seedOnOffer != nil
                ? "Empty pocket. \(Pointing.Tap) to plant the offered seed."
                : "Empty pocket."
        }
        let stage = engine.garden.stage(of: pocket, log: engine.log)
        return stage >= Garden.bloomStage
            ? "\(kind.name), in bloom. \(Pointing.Tap) to pick."
            : "\(kind.name), day \(stage + 1) of growing."
    }
}
