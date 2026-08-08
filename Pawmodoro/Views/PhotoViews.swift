import SwiftUI

/// One developed photograph, re-rendered from its parameter record by the
/// same art that was on screen when the shutter clicked. The scene keeps
/// its captured hour forever; the caption keeps everything the little
/// render can't draw.
struct PhotoCard: View {
    let record: PhotoRecord

    private var place: Place? { Place(rawValue: record.place) }
    private var part: DayPart? { DayPart(rawValue: record.dayPart) }
    private var buddy: Buddy? { Buddy(rawValue: record.buddy) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                if let place, let part {
                    Image(place.assetName(for: part))
                        .interpolation(.none)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 96)
                        .clipped()
                }
                if let buddy {
                    ZStack {
                        BuddySprite(
                            buddy: buddy,
                            sleeping: record.tucked,
                            size: 34
                        )
                        if record.tucked {
                            Image("fx_blanket_over")
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 33)
                                .offset(y: 5)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
            .background(Theme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Theme.cream, lineWidth: 4)
            )
            .shadow(color: Theme.bark.opacity(0.18), radius: 4, y: 2)

            Text(record.caption)
                .font(.system(size: 9))
                .foregroundStyle(Theme.bark.opacity(0.65))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 126)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A photograph: \(record.caption)")
    }
}

/// The shelf on its own, for the main screen's developing chip to open.
///
/// The shelf's home is Stats, fourteen cards down a long scroll — fine for
/// somebody browsing, useless as the destination a one-shot points at. This
/// is the same view, one tap from the thing that made the photograph.
struct PhotoShelfSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                PhotoShelfView()
                    .padding()
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("Photographs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// The photo shelf: developed shots, and today's still in the bath.
/// Tapping a photo opens it large, with the share pass.
struct PhotoShelfView: View {
    @Environment(TimerEngine.self) private var engine
    @State private var openPhoto: PhotoRecord?

    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 14)]

    var body: some View {
        let developed = engine.photos.photos
            .filter { engine.photos.isDeveloped($0) }
            .suffix(8)
            .reversed()
        let developing = engine.photos.developing()

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "camera.fill")
                Text("Photographs")
                Spacer()
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.blossom)

            if developing == nil && developed.isEmpty {
                Text("One shot a day, of whatever is true when you take it. "
                     + "It develops overnight.")
                    .font(.caption)
                    .foregroundStyle(Theme.bark.opacity(0.65))
            } else {
                if developing != nil {
                    Text("One in the bath — it'll be ready in the morning.")
                        .font(.caption)
                        .foregroundStyle(Theme.bark.opacity(0.65))
                }
                LazyVGrid(columns: columns, spacing: 14) {
                    // The one in the bath holds its place in the grid. It
                    // shows nothing — the overnight gate is the whole point —
                    // but a sentence with no card under it reads as a shelf
                    // that lost the picture, which is exactly the doubt this
                    // shelf exists to settle.
                    if developing != nil {
                        developingCard
                    }
                    ForEach(Array(developed)) { record in
                        Button {
                            openPhoto = record
                        } label: {
                            PhotoCard(record: record)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface.opacity(0.75)))
        .sheet(item: $openPhoto) { record in
            ShareableCardSheet(title: "A photograph") {
                PhotoCard(record: record)
            }
        }
    }

    /// Today's shot, keeping its place on the shelf without showing itself.
    private var developingCard: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.bark.opacity(0.12))
                    .frame(width: 120, height: 96)
                Image(systemName: "hourglass")
                    .font(.title3)
                    .foregroundStyle(Theme.bark.opacity(0.35))
            }
            .background(Theme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Theme.cream, lineWidth: 4)
            )

            Text("Taken today. In the bath until morning.")
                .font(.system(size: 9))
                .foregroundStyle(Theme.bark.opacity(0.65))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 126)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's photograph, developing until morning")
    }
}
