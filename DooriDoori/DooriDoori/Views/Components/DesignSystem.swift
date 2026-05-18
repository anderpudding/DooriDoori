import SwiftUI

enum DooriStyle {
    static let accent = Color(red: 0.357, green: 0.267, blue: 0.773)
    static let accentSoft = Color(red: 0.459, green: 0.459, blue: 0.702)
    static let ink = Color(red: 0.067, green: 0.067, blue: 0.067)
    static let muted = Color(red: 0.45, green: 0.45, blue: 0.45)
    static let canvas = Color(red: 0.976, green: 0.976, blue: 0.976)
    static let surface = Color(red: 0.988, green: 0.988, blue: 0.988)
    static let secondaryText = Color(red: 0.404, green: 0.404, blue: 0.698)
    static let longText = Color(red: 0.302, green: 0.302, blue: 0.302)
    static let softGray = Color(red: 0.85, green: 0.85, blue: 0.85)
    static let line = Color.black.opacity(0.9)
    static let warm = Color(red: 0.93, green: 0.94, blue: 1.0)
}

enum DooriTextStyle {
    case h1
    case h2
    case subheading
    case body
    case bodySmall
    case caption
    case captionSmall
    case navBar

    var size: CGFloat {
        switch self {
        case .h1: return 30
        case .h2: return 26
        case .subheading: return 20
        case .body: return 15
        case .bodySmall: return 13
        case .caption: return 15
        case .captionSmall: return 13
        case .navBar: return 11
        }
    }

    var weight: Font.Weight {
        switch self {
        case .h1: return .black
        case .h2, .subheading: return .bold
        case .caption, .navBar: return .medium
        case .body, .bodySmall, .captionSmall: return .regular
        }
    }
}

extension View {
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)
    }

    func dooriText(_ style: DooriTextStyle, english: Bool = false) -> some View {
        let fontName = english ? "Roboto Flex" : "Noto Sans KR"
        return font(.custom(fontName, size: style.size).weight(style.weight))
            .tracking(english ? style.size * 0.03 : 0)
    }
}

extension String {
    var containsKoreanText: Bool {
        unicodeScalars.contains { scalar in
            (0xAC00...0xD7A3).contains(Int(scalar.value))
                || (0x1100...0x11FF).contains(Int(scalar.value))
                || (0x3130...0x318F).contains(Int(scalar.value))
        }
    }
}
