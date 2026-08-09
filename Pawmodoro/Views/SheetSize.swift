import SwiftUI

extension View {

    /// How big a sheet is, on a desk — stated once, for every sheet in the app.
    ///
    /// A phone decides this for you and always has: a sheet is the width of the
    /// phone, no taller than the screen, and whatever is inside it scrolls
    /// because it has to. **A Mac sheet has no such opinion.** It is sized from
    /// its content's *ideal* size, and both of the containers this app builds
    /// sheets out of — `Form` and `ScrollView` — report an ideal size equal to
    /// everything they contain. Nothing clamps it to the display.
    ///
    /// Measured on the Mac walk of 9 Aug 2026, on a screen 2160 points tall:
    ///
    /// | Sheet | Size | Done button |
    /// |---|---|---|
    /// | Settings | 547 × **2972** | y = 3005 — 845 points below the screen |
    /// | The Magpie's Cart | 470 × **2307** | y = 2344 — off the bottom |
    ///
    /// No scroll bar in either, because neither was ever asked to fit anywhere:
    /// a `ScrollView` given all the room it wants does not scroll. On a 13-inch
    /// laptop that costs Settings everything below the Durations steppers, and
    /// a reviewer who opens it finds a sheet with no visible way out.
    ///
    /// Stating the frame is the whole fix — it is what gives the scroll view
    /// something to scroll *inside*. It is one `#if` in one file rather than a
    /// Mac spelling of five screens, for the reason `Platform.swift` gives: a
    /// second implementation of a screen is a second thing to keep in step.
    ///
    /// ### The numbers, and why they are these numbers
    ///
    /// 540 points wide is enough for the widest thing any of these sheets
    /// contains — the Settings `Form`, whose footers were being truncated
    /// mid-word at 547 before the rows themselves were taught to wrap. 620 tall
    /// clears the shortest screen Apple has ever shipped a Mac laptop with
    /// (1280 × 800 points): 620 plus the sheet's own action row still leaves
    /// room under the menu bar, so this does not have to ask the display how
    /// big it is. Do not raise it without checking that arithmetic again.
    ///
    /// ### What 620 actually costs, measured
    ///
    /// The number here is the *content*; what a screen has to fit is the
    /// window around it, and the two differ by enough to matter on the small
    /// laptop this was sized for. Measured on 10 Aug 2026 by reading the
    /// window frames out of the running app:
    ///
    /// | Door | Window |
    /// |---|---|
    /// | `Settings` scene (⌘,) | 540 × **700** |
    /// | Settings sheet (toolbar gear) | 540 × **719** |
    ///
    /// So the real ask is 719, against 800 minus a 25-point menu bar = 775.
    /// Fifty-six points of headroom, not the hundred and fifty this comment
    /// used to imply. Raising 620 by more than that overflows the shortest
    /// Mac laptop screen — which is the arithmetic the paragraph above tells
    /// you to redo, now with the constant it needs.
    func sheetSize(width: CGFloat = 540, height: CGFloat = 620) -> some View {
        #if os(macOS)
        return frame(width: width, height: height)
        #else
        return self
        #endif
    }
}
