import Foundation

/// The word for *the thing in front of you, now*.
///
/// A phone is tapped and a Mac is clicked, and there is exactly one sentence in
/// this app where getting that wrong actually costs something: the paywall
/// says "fifty lo-fi tracks the moment you tap", which on a Mac describes a
/// gesture the reader does not have. The Mac walk found five more — the
/// settle-in screen, a Settings footer, and three lines in the dream garden.
///
/// ### Why this is one noun and not `Platform.isDesktop` in the copy
///
/// The alternative was a conditional at each of the six call sites, and the
/// alternative to *that* was two of every string. Both scale with the number
/// of sentences, and this app writes new copy constantly — a rule that has to
/// be remembered once per sentence is a rule that will be forgotten. A word
/// that knows what it is is remembered by being *used*: the next person
/// writing a line reaches for `Pointing.tap` because that is what the
/// neighbouring line does, and it comes out right on both platforms without
/// anybody thinking about platforms.
///
/// ### What does *not* belong here
///
/// Only the words with no meaning on the other platform. "Drag the ring to set
/// your focus", "press and hold to cast off", "slide it over" all survive the
/// port untouched, because a pointer drags, holds and slides exactly as a
/// finger does. Adding them here would be churn dressed up as portability.
enum Pointing {

    /// "tap" in a pocket, "click" on a desk. Mid-sentence.
    static var tap: String { Platform.isDesktop ? "click" : "tap" }

    /// The same word starting a sentence.
    ///
    /// Spelled out rather than `.capitalized`, which is locale-dependent and
    /// would be a surprising thing to discover inside a two-word string.
    static var Tap: String { Platform.isDesktop ? "Click" : "Tap" }
}
