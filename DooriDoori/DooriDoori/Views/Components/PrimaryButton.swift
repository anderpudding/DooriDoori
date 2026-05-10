import SwiftUI

struct PrimaryButton: View {
    let title: String
    var symbolName: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: 16, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(DooriStyle.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
