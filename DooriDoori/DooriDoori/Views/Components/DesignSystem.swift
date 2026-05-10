import SwiftUI

enum DooriStyle {
    static let accent = Color(red: 0.204, green: 0.204, blue: 0.451)
    static let accentSoft = Color(red: 0.459, green: 0.459, blue: 0.702)
    static let ink = Color(red: 0.059, green: 0.055, blue: 0.278)
    static let muted = Color(red: 0.45, green: 0.45, blue: 0.45)
    static let canvas = Color(red: 0.976, green: 0.976, blue: 0.976)
    static let surface = Color(red: 0.988, green: 0.988, blue: 0.988)
    static let softGray = Color(red: 0.85, green: 0.85, blue: 0.85)
    static let line = Color.black.opacity(0.9)
    static let warm = Color(red: 0.93, green: 0.94, blue: 1.0)
}

extension View {
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}
