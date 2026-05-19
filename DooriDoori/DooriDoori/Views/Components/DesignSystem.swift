import SwiftUI
import UIKit

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

}

enum AppFont {
    private enum NotoSansKR {
        static let black = "NotoSansKR-Black"
        static let bold = "NotoSansKR-Bold"
        static let extraBold = "NotoSansKR-ExtraBold"
        static let extraLight = "NotoSansKR-ExtraLight"
        static let light = "NotoSansKR-Light"
        static let medium = "NotoSansKR-Medium"
        static let regular = "NotoSansKR-Regular"
        static let semiBold = "NotoSansKR-SemiBold"
        static let thin = "NotoSansKR-Thin"

        static let registeredNames = [
            black,
            bold,
            extraBold,
            extraLight,
            light,
            medium,
            regular,
            semiBold,
            thin
        ]
    }

    static func font(_ style: DooriTextStyle) -> Font {
        Font.custom(fontName(for: style), size: style.size)
    }

    #if DEBUG
    static func validateRegisteredFonts() {
        for fontName in NotoSansKR.registeredNames where UIFont(name: fontName, size: 12) == nil {
            print("Missing app font registration: \(fontName). Check UIAppFonts and target membership.")
        }
    }
    #endif

    private static func fontName(for style: DooriTextStyle) -> String {
        switch style {
        case .h1:
            return NotoSansKR.black
        case .h2, .subheading:
            return NotoSansKR.bold
        case .caption, .navBar:
            return NotoSansKR.medium
        case .body, .bodySmall, .captionSmall:
            return NotoSansKR.regular
        }
    }
}

extension View {
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)
    }

    func dooriText(_ style: DooriTextStyle, english: Bool = false) -> some View {
        font(AppFont.font(style))
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
