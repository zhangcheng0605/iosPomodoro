import Foundation

/// The companion who keeps you company through a session.
/// Emoji stand in for real sprite art until illustrated assets land.
enum Buddy: String, Codable, CaseIterable, Identifiable {
    case cat
    case dog

    var id: String { rawValue }

    var name: String {
        switch self {
        case .cat: "Mochi"
        case .dog: "Biscuit"
        }
    }

    var species: String {
        switch self {
        case .cat: "cat"
        case .dog: "dog"
        }
    }

    var pickerLabel: String {
        switch self {
        case .cat: "🐱  Mochi the cat"
        case .dog: "🐶  Biscuit the dog"
        }
    }

    /// Resting, waiting for you to begin.
    var idleEmoji: String {
        switch self {
        case .cat: "🐱"
        case .dog: "🐶"
        }
    }

    /// Curled up asleep while you focus.
    var nappingEmoji: String {
        switch self {
        case .cat: "😴"
        case .dog: "😴"
        }
    }

    /// Up and about during a break.
    var playingEmoji: String {
        switch self {
        case .cat: "😸"
        case .dog: "🐕"
        }
    }
}
