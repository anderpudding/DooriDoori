import SwiftUI

enum DooriStyle {
    static let accent = Color(red: 1.0, green: 0.333, blue: 0.165)
    static let accentSoft = Color(red: 1.0, green: 0.478, blue: 0.349)
    static let ink = Color(red: 0.08, green: 0.075, blue: 0.07)
    static let muted = Color(red: 0.45, green: 0.45, blue: 0.45)
    static let canvas = Color(red: 0.988, green: 0.988, blue: 0.988)
    static let softGray = Color(red: 0.85, green: 0.85, blue: 0.85)
    static let line = Color(red: 0.89, green: 0.89, blue: 0.87)
    static let warm = Color(red: 1.0, green: 0.94, blue: 0.91)
}

extension View {
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}
