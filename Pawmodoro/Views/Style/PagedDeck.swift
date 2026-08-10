import SwiftUI

/// A deck of full-size pages you move through one at a time.
///
/// Two screens in this app are decks — onboarding's three pages and the
/// anniversary card's five — and both were written the phone way, as a
/// `TabView` with `.tabViewStyle(.page)`. That is the whole reason this type
/// exists, and the reason is worth writing down because it was invisible for
/// months.
///
/// ### `.page` does not exist on macOS, and the fallback is not nothing
///
/// `Platform.swift` used to absorb the two iOS spellings the way it absorbs
/// `navigationBarTitleDisplayMode`: `.page` resolved to `DefaultTabViewStyle`
/// and `.indexViewStyle` resolved to `self`. Every other shim in that file is
/// genuinely a no-op — the Mac simply drops a decoration it has no place for.
/// This one was not. `DefaultTabViewStyle` on macOS is a **real AppKit tab
/// bar**, so the Mac build drew three unlabelled tab chips straddling the top
/// edge of the onboarding sheet, half-clipped by its rounded corner, in place
/// of three page dots at the bottom. The accessibility tree read
/// `AXTabGroup` with three empty-named radio buttons. It is the first screen
/// anybody sees, including App Review.
///
/// So the shims are gone and this is what replaced them. A paged deck is a
/// thing that has to be *built* differently on the two platforms rather than
/// dropped on one of them, which is exactly the line `Platform.swift` draws
/// around itself.
///
/// ### What each platform gets
///
/// - **iOS** — the `TabView` that shipped, with its swipe and its dots. Not
///   reimplemented, not wrapped in anything new: the same three modifiers in
///   the same order, so the phone screen is the one that was verified.
/// - **macOS** — the selected page, and a control row under it. There is no
///   swipe on a desk, so the row is the only way through the deck and it is
///   built as controls rather than decoration: two chevrons and a dot per
///   page, all of them clickable, all of them in the accessibility tree with
///   names. `YearKeptView` has no forward button of its own, so a deck whose
///   dots were merely drawn would strand a Mac reader on card one of five.
struct PagedDeck<Content: View>: View {
    @Binding var index: Int
    let count: Int
    @ViewBuilder let page: (Int) -> Content

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            ZStack {
                page(index)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(index)
            .transition(.opacity)

            pager
                .padding(.top, 10)
        }
        #else
        TabView(selection: $index) {
            ForEach(0..<count, id: \.self) { number in
                page(number).tag(number)
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        #endif
    }

    #if os(macOS)

    /// The Mac's way through the deck: back, the dots, forward.
    ///
    /// The dots are the iOS index view's shape and colours — this is meant to
    /// read as the same screen — but every one of them is a `Button`, because
    /// on the Mac they are the navigation rather than a report of where you
    /// are.
    private var pager: some View {
        HStack(spacing: 10) {
            step(-1, "chevron.left", "Previous page")

            ForEach(0..<count, id: \.self) { number in
                Button {
                    withAnimation { index = number }
                } label: {
                    Circle()
                        .fill(number == index
                              ? Theme.bark.opacity(0.55)
                              : Theme.bark.opacity(0.2))
                        .frame(width: 8, height: 8)
                        // The dot is eight points across and a pointer target
                        // should not be. The padding is transparent and
                        // hit-testable, which is the whole of the difference.
                        .padding(6)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Page \(number + 1) of \(count)")
            }

            step(1, "chevron.right", "Next page")
        }
        .padding(.bottom, 4)
    }

    private func step(_ delta: Int, _ glyph: String, _ label: String) -> some View {
        let target = index + delta
        let allowed = target >= 0 && target < count
        return Button {
            withAnimation { index = target }
        } label: {
            Image(systemName: glyph)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.bark.opacity(allowed ? 0.55 : 0.15))
                .pointerBacking(cornerRadius: 6, inset: -6)
                // A chevron glyph measures 6×9 points. Read back off the
                // accessibility tree, that is what the *control* measured too
                // until this padding was added — a target a pointer has to be
                // aimed at. Transparent, hit-testable, and outside the hover
                // backing so the backing stays snug on the glyph.
                .padding(8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!allowed)
        .accessibilityLabel(label)
        .tooltip(label)
    }

    #endif
}
