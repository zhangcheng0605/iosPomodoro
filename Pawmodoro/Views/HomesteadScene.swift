import SwiftUI

/// The wood and the yard, drawn from facts rather than from the engine.
///
/// Pulled out of `HomesteadView` when the hundred-hour panorama needed the
/// same picture. A postcard is re-drawn from its stored facts every time it is
/// shown — that is the whole postcard contract — so it cannot ask an
/// `@Observable` engine what today's tree count is. Everything this needs is
/// therefore a parameter, and the two callers pass different sources for the
/// same five things.
///
/// It also means the panorama and the stats card can never disagree about what
/// the wood looks like, which they would have within a week of one of them
/// being edited.
struct HomesteadScene: View {
    let trees: [Grove.Tree]
    let residents: [Resident]
    let den: Den?
    let dayPart: DayPart
    let buddy: Buddy

    /// Still pictures only. The postcard passes false: a card being exported
    /// to a share sheet has no business running a timeline, and a frame of
    /// animation caught mid-blink is not the frame anybody wants to send.
    var animated: Bool = true

    /// One thing standing in the homestead — a tree or a neighbour.
    ///
    /// Both go through the same struct so the draw order can be a single
    /// sort. A tree has one asset and a resident has two; `asset(frame:)`
    /// wraps, so a tree simply ignores the clock.
    private struct Piece: Identifiable {
        let id: String
        let x: Double
        let y: Double
        let size: CGSize
        let assets: [String]

        func asset(frame: Int) -> String { assets[frame % assets.count] }
    }

    /// The wood, then the yard. Within each, far things first, so nearer ones
    /// overlap them rather than being hidden behind — that is the whole of the
    /// depth illusion. Across the two, the yard always wins, which is what
    /// keeps a neighbour from being swallowed by a full canopy.
    private var pieces: [Piece] {
        let wood = trees
            .sorted { $0.y < $1.y }
            .map { tree in
                Piece(id: "tree-\(tree.index)", x: tree.x, y: tree.y,
                      size: tree.stage.size, assets: [tree.stage.asset])
            }
        var yard = residents
            .sorted { $0.position.y < $1.position.y }
            .map { resident in
                Piece(id: "resident-\(resident.rawValue)",
                      x: resident.position.x, y: resident.position.y,
                      size: resident.size, assets: resident.frames)
            }
        if let den {
            // Not animated: its two frames are empty and occupied, chosen by
            // the world's clock rather than by a timer. A house that blinks
            // between somebody being in and out twice a second would be a
            // haunting.
            let occupied = den.isOccupied(at: dayPart, buddy: buddy)
            yard.append(Piece(
                id: "den-\(den.rawValue)",
                x: Den.position.x, y: Den.position.y,
                size: den.size, assets: [den.frames[occupied ? 1 : 0]]
            ))
            yard.sort { $0.y < $1.y }
        }
        return wood + yard
    }

    /// A `Canvas` would be cheaper, but every piece is a pixel-art sprite and
    /// `Canvas` cannot draw `Image` with `.interpolation(.none)` — the trees
    /// would come out smoothed, which in this art style reads as a bug.
    var body: some View {
        GeometryReader { geometry in
            // The timeline is only mounted once somebody lives here: an empty
            // homestead, and a wood with no residents in it, are both still
            // pictures and should cost nothing to leave on screen.
            if residents.isEmpty || !animated {
                scene(in: geometry.size, frame: 0)
            } else {
                TimelineView(.periodic(from: .now, by: Resident.frameSeconds)) { context in
                    scene(in: geometry.size, frame: Self.frame(at: context.date))
                }
            }
        }
        // Y4's four time-of-day grades, and no new art for them.
        //
        // The plan asked for the homestead to be exported four times like
        // every place is. It is graded at draw time instead, by
        // `FilmStock.of(_:)` — which holds the scene generator's own three
        // numbers per hour, with `tools/check_film.py` failing if they ever
        // drift apart. Seventy-six imagesets, or one modifier reading the
        // table that already had to exist.
        //
        // Applied here rather than by the callers, so the card and the
        // postcard cannot be lit at different hours — and inside whatever clip
        // and under whatever caption they add, because grading a text row
        // would put its contrast somewhere `check_contrast.py` never looks.
        .filmStock(FilmStock.of(dayPart))
    }

    /// Derived from the wall clock rather than counted, for the same reason
    /// the countdown is: a view that scrolls off screen stops getting ticks,
    /// and a counter would come back out of step with itself.
    private static func frame(at date: Date) -> Int {
        let elapsed = date.timeIntervalSinceReferenceDate / Resident.frameSeconds
        return Int(elapsed.rounded(.down)) % 2
    }

    private func scene(in size: CGSize, frame: Int) -> some View {
        ZStack(alignment: .topLeading) {
            // The ground the wood stands on, drawn here rather than left to
            // the callers. The stats card supplied its own and the panorama
            // postcard did not, so a hundred trees came out floating on black
            // — the one place in the app with no background behind the art.
            // Keeping it inside the shared view is the same argument the rest
            // of this file makes: the two callers cannot disagree about what
            // the wood looks like if neither of them draws it.
            Theme.surface

            ForEach(pieces) { piece in
                Image(piece.asset(frame: frame))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: piece.size.width, height: piece.size.height)
                    // Positioned by its *base*, like the stray and the snail:
                    // anchoring a centre puts a tall tree's roots lower than a
                    // short one's, and the error grows with the art, which is
                    // the hardest kind to see.
                    .position(x: size.width * piece.x,
                              y: size.height * piece.y - piece.size.height / 2)
            }
        }
    }
}
