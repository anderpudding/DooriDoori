import SwiftUI

struct IconCircleButton: View {
    let symbolName: String
    var foreground: Color = DooriStyle.ink
    var background: Color = .white
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background(background, in: Circle())
                .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: background == .white ? 1 : 0))
        }
        .buttonStyle(.plain)
    }
}
