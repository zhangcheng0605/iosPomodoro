import SwiftUI
import UIKit

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

    init(buddy: Buddy, assetName: String, size: CGFloat, sleeping: Bool = false) {
        self.buddy = buddy
        self.assetName = assetName
        self.size = size
        self.sleeping = sleeping
    }

    /// The two resting poses, for the pickers and anywhere not animating.
    init(buddy: Buddy, sleeping: Bool, size: CGFloat) {
        self.init(
            buddy: buddy,
            assetName: sleeping ? buddy.asleepAssetName : buddy.awakeAssetName,
            size: size,
            sleeping: sleeping
        )
    }

    private var image: UIImage? {
        UIImage(named: assetName)
            ?? UIImage(named: sleeping ? buddy.asleepAssetName : buddy.awakeAssetName)
    }

    var body: some View {
        if let image {
            Image(uiImage: image)
                .interpolation(.none)      // keep the pixel edges crisp
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Text(sleeping ? buddy.nappingEmoji : buddy.idleEmoji)
                .font(.system(size: size * 0.72))
                .frame(width: size, height: size)
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
