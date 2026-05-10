import SwiftUI

struct FeedDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let item: FeedItem

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                topImage

                VStack(alignment: .leading, spacing: 18) {
                    Text(item.category.title)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(DooriStyle.accent)

                    Text(item.name)
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundStyle(DooriStyle.ink)

                    Label(item.address, systemImage: "location")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DooriStyle.muted)

                    Label(item.budgetLabel, systemImage: "wallet.pass")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DooriStyle.ink)

                    Divider()
                        .padding(.vertical, 6)

                    Text("Reviews")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(DooriStyle.ink)

                    HStack(spacing: 10) {
                        reviewChip("all", selected: true)
                        reviewChip("korean", selected: false)
                        reviewChip("local", selected: false)
                    }

                    reviewPlaceholder

                    PrimaryButton(title: "Visit website", symbolName: "safari") {}
                        .padding(.top, 8)
                }
                .padding(22)
            }
        }
        .background(Color.white)
        .navigationBarBackButtonHidden()
        .ignoresSafeArea(edges: .top)
    }

    private var topImage: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 0)
                .fill(
                    LinearGradient(
                        colors: [DooriStyle.warm, Color(red: 0.97, green: 0.72, blue: 0.62)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 360)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(.white.opacity(0.8))
                }

            IconCircleButton(symbolName: "chevron.left", background: .white.opacity(0.92), size: 46) {
                dismiss()
            }
            .padding(.top, 58)
            .padding(.leading, 20)

            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index == 0 ? .white : .white.opacity(0.45))
                        .frame(width: index == 0 ? 18 : 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 20)
        }
    }

    private func reviewChip(_ title: String, selected: Bool) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(selected ? .white : DooriStyle.ink)
            .padding(.horizontal, 17)
            .frame(height: 36)
            .background(selected ? DooriStyle.accent : DooriStyle.softGray, in: Capsule())
    }

    private var reviewPlaceholder: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Circle()
                    .fill(DooriStyle.softGray)
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 5) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(DooriStyle.line)
                        .frame(width: 112, height: 10)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(DooriStyle.line.opacity(0.7))
                        .frame(width: 72, height: 8)
                }
                Spacer()
            }

            Text("한국인 방문자와 로컬 리뷰를 비교해볼 수 있는 리뷰 카드 영역입니다.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DooriStyle.muted)
                .lineSpacing(4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(DooriStyle.line, lineWidth: 1)
        )
    }
}
