import SwiftUI

struct AccountView: View {
    @ObservedObject var viewModel: RecommendationViewModel
    let onEditProfile: () -> Void
    let onResetAIPreferences: () -> Void
    let onShowRecentlyViewed: () -> Void
    let onShowSavedPlaces: () -> Void

    private var nickname: String {
        "김"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 45)

                profileHeader
                    .padding(.bottom, 42)

                ProfileMenuRow(
                    title: "AI 취향 재설정",
                    iconName: "sparkle",
                    style: .primary,
                    trailingText: nil,
                    action: onResetAIPreferences
                )
                .padding(.bottom, 30)

                recentPlacesCard
                    .padding(.bottom, 13)

                ProfileMenuRow(
                    title: "저장한 장소",
                    iconName: "bookmark",
                    style: .normal,
                    trailingText: "\(viewModel.savedItems.count)",
                    action: onShowSavedPlaces
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 74)
            .padding(.bottom, 40)
        }
        .background(DooriStyle.canvas)
    }

    private var header: some View {
        HStack {
            Text("Profile")
                .dooriText(.subheading, english: true)
                .foregroundStyle(DooriStyle.ink)

            Spacer()

            Image(systemName: "gearshape")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(DooriStyle.ink)
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 14) {
            ProfileAvatarView(initial: String(nickname.prefix(1)))

            Button(action: onEditProfile) {
                HStack(spacing: 9) {
                    Text(nickname)
                        .dooriText(.subheading)
                        .foregroundStyle(DooriStyle.ink)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DooriStyle.ink)
                }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var recentPlacesCard: some View {
        Button(action: onShowRecentlyViewed) {
            VStack(spacing: 18) {
                ProfileMenuRowContent(
                    title: "최근 본 장소",
                    iconName: "clock.arrow.circlepath",
                    style: .normal,
                    trailingText: nil
                )

                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
                        .frame(height: 132)

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
                        .frame(height: 132)
                }
                .padding(.horizontal, 15)
            }
            .padding(.top, 16)
            .padding(.bottom, 22)
            .profileCardBorder(color: Color.black.opacity(0.09))
        }
        .buttonStyle(.plain)
    }
}

struct ProfileAvatarView: View {
    let initial: String

    var body: some View {
        Circle()
            .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
            .frame(width: 123, height: 123)
            .overlay {
                Circle()
                    .stroke(Color.white, lineWidth: 3)
            }
            .overlay {
                Text(initial)
                    .dooriText(.h1)
                    .foregroundStyle(DooriStyle.accent)
            }
            .clipShape(Circle())
    }
}

struct ProfileMenuRow: View {
    let title: String
    let iconName: String
    let style: ProfileMenuRowStyle
    let trailingText: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ProfileMenuRowContent(
                title: title,
                iconName: iconName,
                style: style,
                trailingText: trailingText
            )
            .frame(height: 63)
            .profileCardBorder(color: style.borderColor)
        }
        .buttonStyle(.plain)
    }
}

struct ProfileMenuRowContent: View {
    let title: String
    let iconName: String
    let style: ProfileMenuRowStyle
    let trailingText: String?

    var body: some View {
        HStack {
            HStack(spacing: style == .primary ? 22 : 21) {
                Image(systemName: iconName)
                    .font(.system(size: style.iconSize, weight: .medium))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(style.tint)

                Text(title)
                    .dooriText(.caption)
                    .foregroundStyle(style.titleColor)
            }

            Spacer()

            if let trailingText {
                Text(trailingText)
                    .dooriText(.captionSmall)
                    .foregroundStyle(DooriStyle.secondaryText)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DooriStyle.ink)
        }
        .padding(.horizontal, 16)
    }
}

enum ProfileMenuRowStyle {
    case primary
    case normal

    var tint: Color {
        switch self {
        case .primary: return DooriStyle.secondaryText
        case .normal: return DooriStyle.muted
        }
    }

    var titleColor: Color {
        switch self {
        case .primary: return DooriStyle.secondaryText
        case .normal: return DooriStyle.ink
        }
    }

    var borderColor: Color {
        switch self {
        case .primary: return DooriStyle.accent
        case .normal: return Color.black.opacity(0.12)
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .primary: return 19
        case .normal: return 23
        }
    }
}

private extension View {
    func profileCardBorder(color: Color) -> some View {
        background(DooriStyle.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(color, lineWidth: 1)
            )
    }
}

struct ProfilePlaceholderScreen: View {
    let title: String

    var body: some View {
        VStack {
            Spacer()

            Text(title)
                .dooriText(.subheading)
                .foregroundStyle(DooriStyle.ink)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DooriStyle.canvas)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ProfileEditPlaceholderView: View {
    var body: some View {
        // TODO: Add nickname and profile image editing when the profile edit design is finalized.
        ProfilePlaceholderScreen(title: "프로필 변경")
    }
}

struct AIPreferenceResetPlaceholderView: View {
    var body: some View {
        // TODO: Add onboarding preference editing when the AI preference reset design is finalized.
        ProfilePlaceholderScreen(title: "AI 취향 재설정")
    }
}

struct RecentlyViewedPlacesPlaceholderView: View {
    var body: some View {
        // TODO: Show recently viewed places when the recent-history design and data flow are finalized.
        ProfilePlaceholderScreen(title: "최근 본 장소")
    }
}

struct SavedPlacesPlaceholderView: View {
    var body: some View {
        // TODO: Show saved places when the saved-place list design is finalized.
        ProfilePlaceholderScreen(title: "저장한 장소")
    }
}
