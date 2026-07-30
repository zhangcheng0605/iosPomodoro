import SwiftUI

/// Cozy pastel palette — warm cream, blossom pink, and sage, echoing
/// cozy pixel-art games. Swap these when real art direction lands.
enum Theme {
    static let cream = Color(red: 0.99, green: 0.96, blue: 0.89)
    static let blush = Color(red: 0.98, green: 0.80, blue: 0.82)
    static let blossom = Color(red: 0.93, green: 0.55, blue: 0.66)
    static let sage = Color(red: 0.68, green: 0.79, blue: 0.63)
    static let forest = Color(red: 0.29, green: 0.42, blue: 0.34)
    static let bark = Color(red: 0.45, green: 0.32, blue: 0.24)
    static let sunshine = Color(red: 0.97, green: 0.82, blue: 0.45)

    static func background(for phase: TimerEngine.Phase) -> LinearGradient {
        let colors: [Color] = switch phase {
        case .focus: [blush.opacity(0.6), cream]
        case .shortBreak: [sage.opacity(0.5), cream]
        case .longBreak: [sunshine.opacity(0.45), cream]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    static func accent(for phase: TimerEngine.Phase) -> Color {
        switch phase {
        case .focus: blossom
        case .shortBreak: sage
        case .longBreak: sunshine
        }
    }
}
