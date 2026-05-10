import SwiftUI

struct ForYouView: View {
    @ObservedObject var viewModel: RecommendationViewModel
    let onSelectItem: (FeedItem) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header

                SectionHeader(title: "오늘의 메인 픽", actionTitle: "전체 보기 >") {}
                MainPickCard(item: viewModel.mainPick) {
                    onSelectItem(viewModel.mainPick)
                }

                Divider()
                    .padding(.top, 2)

                SectionHeader(title: "더 둘러보기")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(FeedCategory.allCases) { category in
                            Button {
                                viewModel.selectedCategory = category
                            } label: {
                                CategoryChip(title: category.chipTitle, isSelected: viewModel.selectedCategory == category)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }

                HStack(spacing: 17) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DooriStyle.softGray)
                        .frame(height: 131)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DooriStyle.softGray)
                        .frame(height: 131)
                }
                .padding(.top, -2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 70)
            .padding(.bottom, 0)
        }
        .background(DooriStyle.canvas)
        .navigationBarBackButtonHidden()
        .onAppear {
            if viewModel.selectedCategory == nil {
                viewModel.selectedCategory = .food
            }
        }
    }

    private var header: some View {
        HStack {
            Text("LOGO")
                .font(.system(size: 30, weight: .regular, design: .serif))
                .foregroundStyle(DooriStyle.ink)

            Spacer()

            Button {} label: {
                Image(systemName: "bell")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(DooriStyle.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
    }
}
