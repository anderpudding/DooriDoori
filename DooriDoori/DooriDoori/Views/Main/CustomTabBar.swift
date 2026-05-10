import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        HStack {
            tabButton(.all)
            Spacer()
            centerButton
            Spacer()
            tabButton(.account)
        }
        .padding(.horizontal, 42)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(
            Rectangle()
                .fill(.white)
                .overlay(alignment: .top) { Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1) }
        )
    }

    private var centerButton: some View {
        Button {
            selectedTab = .forYou
        } label: {
            VStack(spacing: 7) {
                Image(systemName: MainTab.forYou.symbolName)
                    .font(.system(size: 29, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 53, height: 53)
                    .background(DooriStyle.accent, in: Circle())

                Text(MainTab.forYou.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(selectedTab == .forYou ? DooriStyle.accent : DooriStyle.muted)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("For you")
    }

    private func tabButton(_ tab: MainTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 7) {
                Image(systemName: tab.symbolName)
                    .font(.system(size: 22, weight: .semibold))
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(selectedTab == tab ? DooriStyle.accent : DooriStyle.muted)
            .frame(width: 72, height: 58)
        }
        .buttonStyle(.plain)
    }
}
