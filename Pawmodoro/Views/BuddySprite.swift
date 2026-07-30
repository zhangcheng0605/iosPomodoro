import SwiftUI
import UIKit

/// The buddy's pixel-art sprite at a given size.
///
/// Falls back to emoji if the image can't be loaded, so the buddy is never
/// missing even if the asset catalog entry is renamed or dropped.
struct BuddySprite: View {
    let buddy: Buddy
    let sleeping: Bool
    let size: CGFloat

    private var assetName: String {
        sleeping ? buddy.asleepAssetName : buddy.awakeAssetName
    }

    var body: some View {
        if let image = UIImage(named: assetName) {
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
    HStack(spacing: 16) {
        BuddySprite(buddy: .cat, sleeping: false, size: 104)
        BuddySprite(buddy: .cat, sleeping: true, size: 104)
        BuddySprite(buddy: .dog, sleeping: false, size: 104)
        BuddySprite(buddy: .dog, sleeping: true, size: 104)
    }
    .padding()
    .background(Theme.cream)
}
