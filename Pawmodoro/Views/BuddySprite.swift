import SwiftUI

/// The buddy's pixel-art sprite at a given size.
///
/// Takes an explicit asset name so animation frames and the two resting poses
/// go through the same view. Falls back down a chain — requested frame, then
/// the buddy's base pose, then emoji — so a missing or renamed asset degrades
/// to the right animal rather than to a blank square.
struct BuddySprite: View {
    let buddy: Buddy
    let assetName: String
    let size: CGFloat
    /// Only used if every image lookup fails.
    private let sleeping: Bool

    /// What this buddy has on. Empty by default so every existing call site —
    /// pickers, previews, the celebration card — keeps working untouched and
    /// simply draws the buddy bare.
    var outfit: [Accessory] = []

    init(buddy: Buddy, assetName: String, size: CGFloat, sleeping: Bool = false,
         outfit: [Accessory] = []) {
        self.buddy = buddy
        self.assetName = assetName
        self.size = size
        self.sleeping = sleeping
        self.outfit = outfit
    }

    /// The two resting poses, for the pickers and anywhere not animating.
    init(buddy: Buddy, sleeping: Bool, size: CGFloat, outfit: [Accessory] = []) {
        self.init(
            buddy: buddy,
            assetName: sleeping ? buddy.asleepAssetName : buddy.awakeAssetName,
            size: size,
            sleeping: sleeping,
            outfit: outfit
        )
    }

    private var image: PlatformImage? {
        PlatformImage.asset(assetName)
            ?? PlatformImage.asset(
                sleeping ? buddy.asleepAssetName : buddy.awakeAssetName)
    }

    var body: some View {
        if let image {
            ZStack(alignment: .topLeading) {
                Image(platform: image)
                    .interpolation(.none)      // keep the pixel edges crisp
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                ForEach(outfit) { accessory in
                    worn(accessory)
                }
            }
            .frame(width: size, height: size)
            // Clipped, with headroom, and both halves are load-bearing.
            //
            // *Clipped*, because a long scarf hangs past the bottom of the
            // buddy's own square by design and unclipped would draw over the
            // caption underneath. *With headroom*, because the happy-bounce
            // frame shifts the whole buddy up two rows, and a hat that fits on
            // the resting pose loses its bobble on the bounce — every one of
            // the five head pieces did. Solving it by shrinking the hats
            // instead would have taken the knitted cap down to 0.43 of a
            // head, which is a dot.
            //
            // Padding out, clipping, then padding back leaves the layout
            // exactly where it was. `check_accessories.py` models the same
            // asymmetry: overhang above is allowed up to `headroom`, overhang
            // below is allowed and clipped, and the sides are not.
            .padding(.top, Self.headroom * size)
            .clipped()
            .padding(.top, -Self.headroom * size)
        } else {
            Text(sleeping ? buddy.nappingEmoji : buddy.idleEmoji)
                .font(.system(size: size * 0.72))
                .frame(width: size, height: size)
        }
    }

    /// How far above its own square a head piece may rise, as a fraction of
    /// the sprite size. Mirrored by `check_accessories.py`.
    static let headroom: CGFloat = 0.30

    /// One piece, placed by the anchors measured for *this exact frame*.
    ///
    /// The placement is in the drawing grid's units, so it scales with the
    /// sprite: at 54pt in a picker and 120pt in the unlock sheet the hat sits
    /// in the same place on the head. A frame with no anchors draws nothing,
    /// which is the right answer rather than a guess — the sleeping poses of
    /// a couple of buddies genuinely have no findable crown.
    @ViewBuilder
    private func worn(_ accessory: Accessory) -> some View {
        if let box = accessory.placement(on: assetName) {
            let unit = size / BuddyAnchors.canvas
            Image(accessory.asset)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: box.width * unit, height: box.height * unit)
                .offset(x: box.minX * unit, y: box.minY * unit)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            BuddySprite(buddy: .cat, sleeping: false, size: 92)
            BuddySprite(buddy: .cat, assetName: Buddy.cat.frame("awake_blink"), size: 92)
            BuddySprite(buddy: .cat, assetName: Buddy.cat.frame("happy_0"), size: 92)
            BuddySprite(buddy: .cat, assetName: Buddy.cat.frame("stretch"), size: 92)
        }
        HStack(spacing: 12) {
            BuddySprite(buddy: .dog, sleeping: true, size: 92)
            BuddySprite(buddy: .dog, assetName: Buddy.dog.frame("asleep_breathe"), size: 92)
            BuddySprite(buddy: .dog, assetName: Buddy.dog.frame("wake"), size: 92)
            BuddySprite(buddy: .dog, assetName: Buddy.dog.frame("stretch"), size: 92)
        }
    }
    .padding()
    .background(Theme.cream)
}
