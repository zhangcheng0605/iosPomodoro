import PhotosUI
import SwiftUI

/// Where you actually were.
///
/// A grid of photographs of your own desks, stamped with what the world was
/// doing while you sat at them. The one screen in the app that contains
/// something the app did not draw.
///
/// The picker is `PhotosPicker`, which needs **no permission dialog at all** —
/// the system shows its own sheet and hands back only what was chosen. That is
/// the whole reason it is the primary path: a memory feature whose first act is
/// an access prompt has asked for something before giving anything.
struct ScrapbookView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var picking: PhotosPickerItem?
    @State private var opened: Snapshot?
    @State private var importing = false
    @State private var failed: String?
    @State private var showCamera = false

    private var scrapbook: Scrapbook { engine.scrapbook }

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if scrapbook.isEmpty {
                    empty
                } else {
                    LazyVGrid(columns: columns, spacing: 8) {
                        // The way in comes first, in the grid itself rather
                        // than the toolbar — see `keepPicker`.
                        addTile
                        ForEach(scrapbook.newestFirst) { snapshot in
                            tile(snapshot)
                        }
                    }
                    .padding()
                }
            }
            // The same bound every other sheet in the app now carries. A
            // scrapbook is the one collection here with no ceiling on it, so
            // it is the one most certain to grow a Mac sheet past the bottom
            // of the display and take Done with it. See `sheetSize()`.
            .sheetSize()
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("Where you were")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                // Hidden, not disabled, where there is no camera — a control
                // for hardware the simulator does not have is only clutter.
                #if canImport(UIKit)
                if CameraPicker.isAvailable {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showCamera = true
                        } label: {
                            Image(systemName: "camera")
                        }
                        .disabled(importing)
                        .accessibilityLabel("Photograph where you are sitting")
                    }
                }
                #endif
            }
            .sheet(item: $opened) { SnapshotView(snapshot: $0) }
            #if canImport(UIKit)
            // Full screen, because that is what a viewfinder is.
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    keep(image)
                }
                .ignoresSafeArea()
            }
            #endif
            .onChange(of: picking) { _, item in
                guard let item else { return }
                Task { await keep(item) }
            }
            .alert("That picture could not be kept",
                   isPresented: Binding(get: { failed != nil },
                                        set: { if !$0 { failed = nil } })) {
                Button("All right", role: .cancel) {}
            } message: {
                Text(failed ?? "")
            }
        }
    }

    // MARK: The way in

    /// The photo picker, written once and worn twice — as the first cell of
    /// the grid, and as the button in the empty state.
    ///
    /// It lives in the *content* rather than the toolbar, and that is the
    /// whole of the Mac fix. A sheet on macOS has no window toolbar to put
    /// items in: SwiftUI keeps `.confirmationAction` (and its neighbours) and
    /// silently drops `.navigation` / `.primaryAction`, so the "+" that a
    /// phone shows in the navigation bar rendered *nothing* on a Mac and the
    /// Scrapbook had no way in at all. A control in the content is drawn by
    /// the same code on both platforms — one way in, not a Mac variant — and
    /// it is more findable on the phone too, which is the other half of why
    /// this is the fix rather than a workaround.
    private func keepPicker<Label: View>(
        @ViewBuilder label: () -> Label
    ) -> some View {
        PhotosPicker(selection: $picking, matching: .images, label: label)
            .buttonStyle(.squishy)
            .disabled(importing)
            .accessibilityLabel("Keep a picture of where you are")
    }

    /// The first cell of the grid, the same size as a photograph.
    private var addTile: some View {
        keepPicker {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                Text("Keep one")
                    .font(.caption2)
            }
            .foregroundStyle(Theme.bark.opacity(0.65))
            .frame(maxWidth: .infinity)
            .frame(height: 104)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.surface.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Theme.bark.opacity(0.25),
                                  style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
        }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 38))
                .foregroundStyle(Theme.bark.opacity(0.3))
            Text("Nothing kept yet.")
                .font(.headline)
                .foregroundStyle(Theme.bark.opacity(0.8))
            Text("Keep a picture of wherever you are sitting. It gets stamped "
                 + "with where the two of you were at the time.")
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.6))
                .multilineTextAlignment(.center)
            // An empty Scrapbook is exactly where somebody gets stuck, so the
            // empty state carries its own way in rather than pointing at a
            // control somewhere else.
            keepPicker {
                // `blossom` rather than any other green or brown on hand:
                // `Theme.onAccent` is only *measured* against the three
                // accents (`check_contrast.py` walks blossom/sage/sunshine),
                // so a capsule in any other colour would be a contrast claim
                // nothing in the toolchain checks.
                Label("Keep a picture", systemImage: "photo.badge.plus")
                    .font(.headline)
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Theme.blossom))
            }
            .padding(.top, 8)
        }
        .padding(40)
    }

    private func tile(_ snapshot: Snapshot) -> some View {
        Button {
            opened = snapshot
        } label: {
            SnapshotImage(snapshot: snapshot, in: scrapbook)
                .aspectRatio(1, contentMode: .fill)
                .frame(height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(snapshot.caption)
    }

    // MARK: Keeping one

    /// Load, strip, scale, write, record — in that order, and the order is the
    /// point. The metadata row is written *last*, so a failure anywhere leaves
    /// a file with nothing pointing at it rather than a row pointing at
    /// nothing; `Scrapbook.prune()` sweeps the first at the next launch and
    /// there is no repair for the second.
    private func keep(_ item: PhotosPickerItem) async {
        importing = true
        defer { importing = false; picking = nil }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            failed = "It could not be read."
            return
        }
        guard let prepared = SnapshotImport.prepare(data) else {
            failed = "It was not an image this app could open."
            return
        }
        write(prepared)
    }

    /// The camera's path in. Same pipeline from `prepare` onward — the shot
    /// gets the same strip, scale and upright rendering an imported photograph
    /// does, so there is exactly one definition of what a kept picture is.
    private func keep(_ image: PlatformImage) {
        guard let prepared = SnapshotImport.prepare(image) else {
            failed = "It was not an image this app could open."
            return
        }
        write(prepared)
    }

    private func write(_ prepared: Data) {
        guard let directory = Scrapbook.directory else {
            failed = "There is nowhere to keep it."
            return
        }
        let file = "\(UUID().uuidString).jpg"
        do {
            try prepared.write(to: directory.appendingPathComponent(file))
        } catch {
            failed = "There was no room to keep it."
            return
        }
        engine.keepSnapshot(file: file)
    }
}

/// One photograph, at whatever size it is asked for, in its own stock.
struct SnapshotImage: View {
    let snapshot: Snapshot
    let scrapbook: Scrapbook

    init(snapshot: Snapshot, in scrapbook: Scrapbook) {
        self.snapshot = snapshot
        self.scrapbook = scrapbook
    }

    var body: some View {
        if let url = scrapbook.url(for: snapshot),
           let image = PlatformImage.file(url.path) {
            Image(platform: image)
                .resizable()
                .scaledToFill()
                // The grade is applied at draw time, never to the file. The
                // photograph on disk is always exactly what was imported, so
                // changing stock is free and reversible forever — and the one
                // thing this feature must never do is modify somebody's
                // picture.
                .filmStock(snapshot.filmStock)
        } else {
            // A file that has gone missing shows as a gap rather than a crash
            // or an error: the row is real, the picture is not, and there is
            // nothing useful to say about it.
            Rectangle()
                .fill(Theme.surface.opacity(0.5))
                .overlay(
                    Image(systemName: "photo")
                        .foregroundStyle(Theme.bark.opacity(0.25))
                )
        }
    }
}
