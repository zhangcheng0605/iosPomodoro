import SwiftUI

/// The thought bubble for an anniversary: the same two-tone `fx_bubble`
/// shells the dream bubble uses, holding a journal sketch — or, for the
/// memories without a picture, a small glyph. Tap to acknowledge.
struct MemoryBubble: View {
    let memory: Memory

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var risen = false

    private let size: CGFloat = 62

    var body: some View {
        ZStack {
            ThoughtBubbleShell(size: size)
            content
                .frame(width: size * 0.42, height: size * 0.42)
                .offset(y: -size * 0.17)
        }
        .frame(width: size, height: size)
        .offset(y: reduceMotion ? 0 : (risen ? 0 : 8))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.9)) { risen = true }
        }
        .accessibilityElement()
        .accessibilityLabel("A memory, held up for you")
    }

    @ViewBuilder
    private var content: some View {
        if let sketch = memory.sketchAsset {
            Image(sketch)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: glyph)
                .font(.system(size: size * 0.28, weight: .semibold))
                .foregroundStyle(Theme.blossom)
        }
    }

    private var glyph: String {
        switch memory.subject {
        case .firstSession: "pawprint.fill"
        case .species: "sparkles"
        case .strayFirstSeen, .strayJoined: "heart.fill"
        }
    }
}
