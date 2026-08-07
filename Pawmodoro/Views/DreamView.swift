import SwiftUI

/// The thought bubble that rises over a sleeping buddy, with what it's dreaming
/// about inside it.
///
/// One asset does the whole bubble: `fx_bubble` is a flat silhouette rendered
/// as a template, drawn twice — once a little larger in `Theme.bark` for a rim,
/// once in `Theme.cream` for the fill. That is what keeps it two-tone and
/// theme-correct without a second sprite or a raw colour.
struct DreamBubble: View {
    let dream: Dream
    /// 0...1 across the appearance, for the fade in and out.
    let phase: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var risen = false

    private let size: CGFloat = 62

    var body: some View {
        ZStack {
            bubble
            sketch
                // Sits in the round part of the bubble, which is its upper
                // two-thirds — the tail below is the two trailing dots.
                .frame(width: size * 0.42, height: size * 0.42)
                .offset(y: -size * 0.17)
        }
        .frame(width: size, height: size)
        .opacity(fade)
        // Under Reduce Motion the bubble simply fades in where it belongs
        // rather than drifting up into place.
        .offset(y: reduceMotion ? 0 : (risen ? 0 : 8))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.9)) { risen = true }
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("Dreaming of \(dream.subject)")
    }

    private var bubble: some View {
        ThoughtBubbleShell(size: size)
    }

    @ViewBuilder
    private var sketch: some View {
        if dream.isSilhouette {
            // Vignettes are drawn in full colour for the sky; in a dream they
            // are a sketch like everything else here.
            Image(dream.asset)
                .renderingMode(.template)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Theme.bark.opacity(0.75))
        } else {
            Image(dream.asset)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        }
    }

    /// Never pops, at either end.
    private var fade: Double {
        guard !reduceMotion else { return 1 }
        let edge = 0.18
        if phase < edge { return max(0, phase / edge) }
        if phase > 1 - edge { return max(0, (1 - phase) / edge) }
        return 1
    }
}

/// The two-tone thought bubble the dream and the memory both ride in: one
/// template asset drawn twice — a bark rim under a cream fill — with the
/// trailing dots shifting a pixel every beat. Extracted here because two
/// views were carrying identical copies of it.
struct ThoughtBubbleShell: View {
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = Date()

    var body: some View {
        if reduceMotion {
            shell(frame: 0)
        } else {
            // Two frames, slowly: the trailing dots shift by a pixel, which is
            // the whole shimmer. Anything faster reads as a glitch.
            TimelineView(.periodic(from: .now, by: 0.9)) { context in
                let tick = Int(context.date.timeIntervalSince(appeared) / 0.9)
                shell(frame: tick % 2)
            }
        }
    }

    private func shell(frame: Int) -> some View {
        let name = "fx_bubble_\(frame)"
        return ZStack {
            image(name)
                .foregroundStyle(Theme.bark.opacity(0.55))
                .frame(width: size + 3, height: size + 3)
            image(name)
                .foregroundStyle(Theme.cream)
                .frame(width: size, height: size)
        }
    }

    private func image(_ name: String) -> some View {
        Image(name)
            .renderingMode(.template)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
    }
}

/// The dream diary: what your buddy has dreamed, and what it hasn't yet.
///
/// Sits beside the field journal and works the same way — the unseen half is
/// shown as faint empty bubbles, because the point is that a fuller journal
/// makes a fuller dream life.
struct DreamDiaryView: View {
    @Environment(TimerEngine.self) private var engine

    private var diary: DreamDiary { engine.dreams }

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: 12)]

    /// Memories first, then travel, then the surreal — the same order they are
    /// weighted in, so the page reads as "mostly your journey".
    private var dreamed: [Dream] {
        Dream.everything.filter(diary.hasDreamed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Dream diary")
                    .font(.headline)
                    .foregroundStyle(Theme.bark)
                Spacer()
                Text("\(diary.dreamedCount)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.bark.opacity(0.6))
                    .monospacedDigit()
            }

            Text(dreamed.isEmpty
                 ? emptyCaption
                 : "What \(engine.buddyName) dreams about is where you've been "
                   + "together.")
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.6))

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(dreamed) { dream in
                    tile(for: dream)
                }
                // A few empty bubbles so the page says "there are more of
                // these" without listing forty-one things you haven't dreamed.
                ForEach(0..<emptySlots, id: \.self) { _ in
                    emptyTile
                }
            }
        }
    }

    /// Nocturnal buddies keep watch after dark and never dream at night, so
    /// "sleeps through every session" would be a lie for them.
    private var emptyCaption: String {
        if engine.settings.buddy.isNocturnal {
            return "\(engine.buddyName) keeps watch at night and dozes through "
                + "the daylight sessions. Finish one of those to find out "
                + "what the dreams are about."
        }
        return "\(engine.buddyName) sleeps through every session. Stay to the "
            + "end of one and you'll find out what about."
    }

    /// Enough to fill the row out and hint at more, never the whole catalogue.
    private var emptySlots: Int {
        max(0, min(4, Dream.everything.count - dreamed.count))
    }

    private func tile(for dream: Dream) -> some View {
        let record = diary.record(for: dream)

        return VStack(spacing: 5) {
            DreamBubble(dream: dream, phase: 0.5)
                .frame(width: 62, height: 62)

            Text(dream.subject.capitalizedFirstLetter)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.bark.opacity(0.9))
                .lineLimit(1)

            Text(caption(for: dream, record: record))
                .font(.system(size: 9))
                .foregroundStyle(Theme.bark.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 22, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.9))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Dreamed of \(dream.subject). \(dream.line) "
                + caption(for: dream, record: record)
        )
    }

    private var emptyTile: some View {
        VStack(spacing: 5) {
            Text("…")
                .font(.title2)
                .foregroundStyle(Theme.bark.opacity(0.35))
                .frame(width: 62, height: 62)
                .background(Circle().fill(Theme.bark.opacity(0.06)))
            Text(" ").font(.caption2)
            Text(" ").font(.system(size: 9)).frame(height: 22)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.35))
        )
        .accessibilityHidden(true)
    }

    /// Writes the relationship where it can — "three days after you met it" is
    /// the whole difference between a collection and a diary.
    private func caption(for dream: Dream, record: DreamRecord?) -> String {
        guard let record else { return dream.line }
        if let days = record.daysAfter, days > 0 {
            return days == 1
                ? "The day after you met it"
                : "\(days) days after you met it"
        }
        return record.firstDreamed.formatted(.dateTime.day().month(.abbreviated))
    }
}

private extension String {
    var capitalizedFirstLetter: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
