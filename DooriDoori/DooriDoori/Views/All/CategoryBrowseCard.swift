import SwiftUI

struct CategoryBrowseCard: View {
    let title: String
    let subtitle: String
    let symbolName: String
    var buttonTitle: String?
    var buttonAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DooriStyle.ink)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DooriStyle.muted)
                }
            }
            Spacer()

            if let buttonTitle, let buttonAction {
                Button(action: buttonAction) {
                    HStack(spacing: 7) {
                        Image(systemName: "map")
                        Text(buttonTitle)
                    }
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(width: 113, height: 41)
                    .background(DooriStyle.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 106)
        .padding(.horizontal, 30)
        .background(DooriStyle.softGray, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
