import SwiftUI

struct OnboardingView: View {
    var initialPreference: UserPreference = .defaultValue
    let onComplete: (UserPreference) -> Void

    @State private var step: OnboardingStep = .splash
    @State private var permissionStates: [OnboardingPermission: PermissionSelectionState] = [
        .location: .idle,
        .camera: .idle,
        .notifications: .idle
    ]
    @State private var nickname = ""
    @State private var hasLocalProfilePhoto = false
    @State private var selectedStatus: PreferenceOption?
    @State private var selectedDistrict: PreferenceOption?
    @State private var selectedVibe: PreferenceOption?
    @State private var selectedCategories: Set<PreferenceOption> = []

    private let statusOptions = [
        PreferenceOption(title: "학생", value: "status:student"),
        PreferenceOption(title: "워킹홀리데이", value: "status:working-holiday"),
        PreferenceOption(title: "직장인", value: "status:worker"),
        PreferenceOption(title: "영주권자/시민권자", value: "status:resident-citizen"),
        PreferenceOption(title: "기타", value: "status:other")
    ]

    private let districtOptions = [
        PreferenceOption(title: "Downtown", value: "Downtown"),
        PreferenceOption(title: "Burnaby", value: "Burnaby"),
        PreferenceOption(title: "Richmond", value: "Richmond"),
        PreferenceOption(title: "Coquitlam", value: "Coquitlam"),
        PreferenceOption(title: "North Vancouver", value: "North Vancouver")
    ]

    private let vibeOptions = [
        PreferenceOption(title: "아늑하고 여유로운", value: "cozy"),
        PreferenceOption(title: "활기차고 트렌디한", value: "trendy"),
        PreferenceOption(title: "조용하고 차분한", value: "calm"),
        PreferenceOption(title: "사람들과 어울리기 좋은", value: "group-friendly")
    ]

    private let categoryOptions = [
        PreferenceOption(title: "맛집 탐방", value: ContentCategory.food.rawValue),
        PreferenceOption(title: "이벤트", value: ContentCategory.events.rawValue),
        PreferenceOption(title: "라이프스타일", value: ContentCategory.lifestyle.rawValue)
    ]

    var body: some View {
        ZStack {
            DooriStyle.canvas.ignoresSafeArea()

            switch step {
            case .splash:
                OnboardingSplashView(
                    onSignUp: { step = .permissions },
                    onLogin: { step = .permissions }
                )
            case .permissions:
                PermissionRequestView(
                    states: $permissionStates,
                    onBack: { step = .splash },
                    onContinue: { step = .profileSetup }
                )
            case .profileSetup:
                OnboardingProfileSetupView(
                    nickname: $nickname,
                    hasLocalProfilePhoto: $hasLocalProfilePhoto,
                    onBack: { step = .permissions },
                    onNext: { step = .status }
                )
            case .status:
                PreferenceQuestionView(
                    title: "캐나다 현재 신분",
                    subtitle: "항목을 골라주세요",
                    progress: 0.25,
                    options: statusOptions,
                    selectedOptions: singleSelectionSet(selectedStatus),
                    buttonTitle: "다음",
                    onBack: { step = .profileSetup },
                    onSelect: { selectedStatus = $0 },
                    onNext: { step = .district }
                )
            case .district:
                PreferenceQuestionView(
                    title: "주로 어디에서 찾으시나요?",
                    subtitle: "항목을 골라주세요",
                    progress: 0.5,
                    options: districtOptions,
                    selectedOptions: singleSelectionSet(selectedDistrict),
                    buttonTitle: "다음",
                    onBack: { step = .status },
                    onSelect: { selectedDistrict = $0 },
                    onNext: { step = .vibe }
                )
            case .vibe:
                PreferenceQuestionView(
                    title: "어떤 분위기를 선호하시나요?",
                    subtitle: "관심 있는 항목을 골라주세요",
                    progress: 0.75,
                    options: vibeOptions,
                    selectedOptions: singleSelectionSet(selectedVibe),
                    buttonTitle: "다음",
                    onBack: { step = .district },
                    onSelect: { selectedVibe = $0 },
                    onNext: { step = .categories }
                )
            case .categories:
                PreferenceQuestionView(
                    title: "관심있는 분야는 무엇인가요?",
                    subtitle: "관심 있는 항목을 골라주세요",
                    progress: 1,
                    options: categoryOptions,
                    selectedOptions: selectedCategories,
                    buttonTitle: "완료",
                    rowHeight: 89,
                    rowSpacing: 22,
                    onBack: { step = .vibe },
                    onSelect: { option in
                        if selectedCategories.contains(option) {
                            selectedCategories.remove(option)
                        } else {
                            selectedCategories.insert(option)
                        }
                    },
                    onNext: { step = .finalLoading }
                )
            case .finalLoading:
                FinalOnboardingLoadingView(
                    nickname: normalizedNickname,
                    onComplete: {
                        onComplete(makePreference())
                    }
                )
            }
        }
        .tint(DooriStyle.accent)
    }

    private var normalizedNickname: String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "김지은" : trimmed
    }

    private func singleSelectionSet(_ option: PreferenceOption?) -> Set<PreferenceOption> {
        guard let option else { return [] }
        return [option]
    }

    private func makePreference() -> UserPreference {
        let categories = selectedCategories.isEmpty
            ? initialPreference.selectedCategories
            : selectedCategories.map(\.value).sorted()
        let districts = selectedDistrict.map { [$0.value] } ?? initialPreference.preferredDistricts
        let vibes = selectedVibe.map { [$0.value] } ?? initialPreference.vibeTags
        let infoNeeds = selectedStatus.map { [$0.value] } ?? initialPreference.infoNeeds

        return UserPreference(
            selectedCategories: categories,
            preferredDistricts: districts,
            budgetLevel: initialPreference.budgetLevel,
            vibeTags: vibes,
            infoNeeds: infoNeeds,
            languagePreference: initialPreference.languagePreference,
            updatedAt: Date()
        )
    }
}

private enum OnboardingStep {
    case splash
    case permissions
    case profileSetup
    case status
    case district
    case vibe
    case categories
    case finalLoading
}

struct InitialLoadingView: View {
    var body: some View {
        ZStack {
            DooriStyle.accent.ignoresSafeArea()

            VanoriSmileMark(size: 191, color: DooriStyle.accent)
        }
    }
}

private struct OnboardingSplashView: View {
    let onSignUp: () -> Void
    let onLogin: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 26) {
                VanoriSmileMark(size: 146, color: DooriStyle.accent)

                Text("어디서든, 나답게")
                    .dooriText(.h2)
                    .foregroundStyle(DooriStyle.ink)
            }
            .padding(.top, 123)

            Spacer()

            VStack(spacing: 18) {
                OnboardingNextButton(title: "회원가입", isEnabled: true, action: onSignUp)

                Button(action: onLogin) {
                    HStack(spacing: 10) {
                        Text("이미 계정이 있나요?")
                            .dooriText(.captionSmall)
                            .foregroundStyle(Color.black.opacity(0.5))
                        Text("로그인")
                            .dooriText(.captionSmall)
                            .foregroundStyle(DooriStyle.accent)
                    }
                }
                .buttonStyle(.plain)
                // TODO: Route to real login once the login/signup screen designs are finalized.
            }
            .padding(.horizontal, 17)
            .padding(.bottom, 38)
        }
        .background(DooriStyle.canvas)
    }
}

private struct PermissionRequestView: View {
    @Binding var states: [OnboardingPermission: PermissionSelectionState]
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackArrowButton(action: onBack)
                .padding(.top, 37)

            Text("DOORI 앱 이용을 위해 권한 요청")
                .dooriText(.h2)
                .foregroundStyle(DooriStyle.ink)
                .frame(width: 253, alignment: .leading)
                .padding(.top, 73)

            Text("더 나은 경험을 위해 아래 권한이 필요해요")
                .dooriText(.body, english: true)
                .foregroundStyle(Color.black.opacity(0.51))
                .padding(.top, 11)

            Text("선택")
                .dooriText(.body, english: true)
                .foregroundStyle(DooriStyle.ink)
                .padding(.top, 36)
                .padding(.bottom, 13)

            Divider()
                .overlay(Color.black.opacity(0.18))
                .padding(.horizontal, -24)

            VStack(spacing: 34) {
                PermissionOptionRow(permission: .location, state: state(for: .location)) {
                    select(.location)
                }
                PermissionOptionRow(permission: .camera, state: state(for: .camera)) {
                    select(.camera)
                }
                PermissionOptionRow(permission: .notifications, state: state(for: .notifications)) {
                    select(.notifications)
                }
            }
            .padding(.top, 29)

            Spacer()

            OnboardingNextButton(title: "확인", isEnabled: true, action: onContinue)

            Text("권한은 설정에서 언제든지 변경할 수 있어요")
                .dooriText(.captionSmall)
                .foregroundStyle(Color.black.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.top, 11)
                .padding(.bottom, 14)
        }
        .padding(.horizontal, 16)
        .background(DooriStyle.canvas)
    }

    private func state(for permission: OnboardingPermission) -> PermissionSelectionState {
        states[permission] ?? .idle
    }

    private func select(_ permission: OnboardingPermission) {
        // TODO: Integrate CoreLocation, AVFoundation camera, and UNUserNotificationCenter permission requests.
        states[permission] = .selected
    }
}

private struct PermissionOptionRow: View {
    let permission: OnboardingPermission
    let state: PermissionSelectionState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.913, green: 0.916, blue: 1))
                        .frame(width: 36, height: 36)

                    Image(systemName: permission.symbolName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(DooriStyle.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(permission.title)
                            .dooriText(.body, english: true)
                            .foregroundStyle(DooriStyle.ink)

                        if permission.isRequired {
                            Text("필수")
                                .dooriText(.navBar)
                                .foregroundStyle(DooriStyle.secondaryText)
                                .padding(.horizontal, 8)
                                .frame(height: 19)
                                .background(Color(red: 0.898, green: 0.902, blue: 1), in: RoundedRectangle(cornerRadius: 3))
                        }
                    }

                    Text(permission.subtitle)
                        .dooriText(.captionSmall)
                        .foregroundStyle(Color(red: 0.451, green: 0.451, blue: 0.451))
                }

                Spacer()

                Image(systemName: state == .selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(state == .selected ? DooriStyle.accent : Color.black.opacity(0.22))
            }
        }
        .buttonStyle(.plain)
    }
}

private enum OnboardingPermission: CaseIterable, Hashable {
    case location
    case camera
    case notifications

    var title: String {
        switch self {
        case .location: return "위치"
        case .camera: return "카메라"
        case .notifications: return "알림 메세지"
        }
    }

    var subtitle: String {
        switch self {
        case .location: return "위치 기준 정보 안내"
        case .camera: return "리뷰 사진 업로드"
        case .notifications: return "새로운 이벤트와 특별 소식을 알려드려요"
        }
    }

    var symbolName: String {
        switch self {
        case .location: return "location"
        case .camera: return "camera"
        case .notifications: return "bell"
        }
    }

    var isRequired: Bool {
        self == .location
    }
}

private enum PermissionSelectionState {
    case idle
    case selected
}

private struct OnboardingProfileSetupView: View {
    @Binding var nickname: String
    @Binding var hasLocalProfilePhoto: Bool
    let onBack: () -> Void
    let onNext: () -> Void

    private var canAdvance: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackArrowButton(action: onBack)
                .padding(.top, 37)

            Text("프로필을 설정해주세요")
                .dooriText(.h2)
                .foregroundStyle(DooriStyle.ink)
                .padding(.top, 73)

            Button {
                hasLocalProfilePhoto.toggle()
                // TODO: Persist profile photo after profile storage is designed.
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(hasLocalProfilePhoto ? DooriStyle.warm : Color(red: 0.85, green: 0.85, blue: 0.85))
                        .frame(width: 119, height: 119)
                        .overlay {
                            if hasLocalProfilePhoto {
                                VanoriSmileMark(size: 78, color: DooriStyle.accent)
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 56, weight: .regular))
                                    .foregroundStyle(.white)
                            }
                        }

                    ZStack {
                        Circle()
                            .fill(DooriStyle.accent)
                            .frame(width: 40, height: 40)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 2, y: 3)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)

            TextField("닉네임", text: $nickname)
                .dooriText(.body)
                .foregroundStyle(DooriStyle.ink)
                .padding(.horizontal, 20)
                .frame(height: 54)
                .background(DooriStyle.canvas, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.black.opacity(0.5), lineWidth: 1)
                )
                .padding(.top, 41)
                // TODO: Persist nickname after profile storage is designed.

            Spacer()

            OnboardingNextButton(title: "다음", isEnabled: canAdvance, action: onNext)
                .padding(.bottom, 48)
        }
        .padding(.horizontal, 16)
        .background(DooriStyle.canvas)
    }
}

private struct PreferenceQuestionView: View {
    let title: String
    let subtitle: String
    let progress: CGFloat
    let options: [PreferenceOption]
    let selectedOptions: Set<PreferenceOption>
    let buttonTitle: String
    var rowHeight: CGFloat = 68
    var rowSpacing: CGFloat = 24
    let onBack: () -> Void
    let onSelect: (PreferenceOption) -> Void
    let onNext: () -> Void

    private var canAdvance: Bool {
        !selectedOptions.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgressBar(progress: progress)
                .padding(.top, 65)

            BackArrowButton(action: onBack)
                .padding(.top, 21)

            Text(title)
                .dooriText(.h2)
                .foregroundStyle(DooriStyle.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .padding(.top, 13)

            Text(subtitle)
                .dooriText(.bodySmall, english: true)
                .foregroundStyle(Color(red: 0.302, green: 0.302, blue: 0.302))
                .padding(.top, 7)

            VStack(spacing: rowSpacing) {
                ForEach(options) { option in
                    PreferenceOptionButton(
                        option: option,
                        isSelected: selectedOptions.contains(option),
                        height: rowHeight,
                        action: { onSelect(option) }
                    )
                }
            }
            .padding(.top, 39)

            Spacer()

            OnboardingNextButton(title: buttonTitle, isEnabled: canAdvance, action: onNext)
                .padding(.bottom, 48)
        }
        .padding(.horizontal, 16)
        .background(DooriStyle.canvas)
    }
}

private struct PreferenceOption: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let value: String

    static func == (lhs: PreferenceOption, rhs: PreferenceOption) -> Bool {
        lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

private struct PreferenceOptionButton: View {
    let option: PreferenceOption
    let isSelected: Bool
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(option.title)
                .dooriText(.body, english: true)
                .foregroundStyle(DooriStyle.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, 43)
                .background(DooriStyle.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? DooriStyle.accent : Color.black.opacity(0.09), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .frame(height: height)
    }
}

private struct OnboardingProgressBar: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
                Capsule()
                    .fill(DooriStyle.accent)
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 5)
    }
}

private struct OnboardingNextButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            if isEnabled {
                action()
            }
        }) {
            Text(title)
                .dooriText(.body, english: true)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(isEnabled ? DooriStyle.accent : Color(red: 0.729, green: 0.729, blue: 0.867), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct BackArrowButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("←")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(DooriStyle.ink)
                .frame(width: 24, height: 24, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

private struct FinalOnboardingLoadingView: View {
    let nickname: String
    let onComplete: () -> Void

    @State private var didStart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackArrowButton(action: {})
                .opacity(0)
                .padding(.top, 96)

            Group {
                Text("딱 맞는 ")
                    .foregroundStyle(DooriStyle.ink)
                + Text("픽")
                    .foregroundStyle(DooriStyle.accent)
                + Text("을 찾아드릴게요...")
                    .foregroundStyle(DooriStyle.ink)
            }
            .dooriText(.h2)
            .padding(.top, 21)

            Group {
                Text("밴쿠버에서 ")
                + Text("\(nickname)님")
                    .underline()
                + Text("의 취향에 꼭 맞는 장소와 모임을 찾아드릴게요")
            }
            .dooriText(.bodySmall, english: true)
            .foregroundStyle(Color(red: 0.302, green: 0.302, blue: 0.302))
            .frame(width: 296, alignment: .leading)
            .padding(.top, 10)

            Spacer()

            OrbitingStarLoadingView()
                .frame(maxWidth: .infinity)
                .padding(.bottom, 287)
        }
        .padding(.horizontal, 16)
        .background(DooriStyle.canvas)
        .task {
            guard !didStart else { return }
            didStart = true
            try? await Task.sleep(nanoseconds: 750_000_000)
            onComplete()
        }
    }
}

private struct OrbitingStarLoadingView: View {
    @State private var isOrbiting = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(DooriStyle.accent, lineWidth: 5)
                .frame(width: 99, height: 99)
                .overlay {
                    VStack(spacing: 5) {
                        HStack(spacing: 16) {
                            Circle().fill(DooriStyle.accent).frame(width: 6, height: 6)
                            Circle().fill(DooriStyle.accent).frame(width: 6, height: 6)
                        }
                        ArcSmile()
                            .stroke(DooriStyle.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 31, height: 18)
                    }
                    .padding(.top, 8)
                }

            StarShape()
                .fill(DooriStyle.accent)
                .frame(width: 24, height: 24)
                .offset(y: -72)
                .rotationEffect(.degrees(-20))
                .rotationEffect(.degrees(isOrbiting ? 360 : 0), anchor: .bottom)
        }
        .frame(width: 180, height: 180)
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                isOrbiting = true
            }
        }
    }
}

private struct VanoriSmileMark: View {
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(.white)
                .frame(width: size * 0.67, height: size * 0.67)
                .overlay {
                    VStack(spacing: size * 0.01) {
                        Text("VAN")
                            .font(.system(size: size * 0.16, weight: .bold, design: .rounded))
                            .foregroundStyle(color)
                        ArcSmile()
                            .stroke(color, style: StrokeStyle(lineWidth: size * 0.03, lineCap: .round))
                            .frame(width: size * 0.48, height: size * 0.24)
                    }
                    .padding(.top, size * 0.05)
                }

            Circle()
                .fill(.white)
                .frame(width: size * 0.31, height: size * 0.31)
                .overlay {
                    VStack(spacing: size * 0.015) {
                        HStack(spacing: size * 0.035) {
                            Circle().fill(color).frame(width: size * 0.012, height: size * 0.012)
                            Circle().fill(color).frame(width: size * 0.012, height: size * 0.012)
                        }
                        ArcSmile()
                            .stroke(color, style: StrokeStyle(lineWidth: size * 0.013, lineCap: .round))
                            .frame(width: size * 0.07, height: size * 0.045)
                    }
                    .padding(.top, size * 0.02)
                }
                .offset(x: size * 0.02, y: size * 0.01)
        }
        .frame(width: size, height: size)
    }
}

private struct ArcSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY),
            radius: rect.width / 2,
            startAngle: .degrees(25),
            endAngle: .degrees(155),
            clockwise: false
        )
        return path
    }
}

private struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let points = [
            CGPoint(x: center.x, y: rect.minY),
            CGPoint(x: center.x + rect.width * 0.12, y: center.y - rect.height * 0.12),
            CGPoint(x: rect.maxX, y: center.y),
            CGPoint(x: center.x + rect.width * 0.12, y: center.y + rect.height * 0.12),
            CGPoint(x: center.x, y: rect.maxY),
            CGPoint(x: center.x - rect.width * 0.12, y: center.y + rect.height * 0.12),
            CGPoint(x: rect.minX, y: center.y),
            CGPoint(x: center.x - rect.width * 0.12, y: center.y - rect.height * 0.12)
        ]

        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}
