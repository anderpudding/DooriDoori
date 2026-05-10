import SwiftUI

struct OnboardingView: View {
    var initialPreference: UserPreference = .defaultValue
    let onComplete: (UserPreference) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .categories
    @State private var selectedCategories: Set<String>
    @State private var preferredDistricts: Set<String>
    @State private var budgetLevel: Int
    @State private var vibeTags: Set<String>

    private enum Step: Int, CaseIterable {
        case categories
        case districts
        case budget
        case vibes
        case done

        var progress: Double {
            Double(rawValue + 1) / Double(Self.allCases.count)
        }

        var title: String {
            switch self {
            case .categories: return "어떤 정보를 찾고 있나요?"
            case .districts: return "자주 가는 동네를 골라주세요"
            case .budget: return "예산은 어느정도를 생각하시나요?"
            case .vibes: return "좋아하는 분위기를 골라주세요"
            case .done: return "딱 맞는 픽을 준비할게요"
            }
        }

        var subtitle: String {
            switch self {
            case .categories, .districts, .vibes: return "여러 개를 선택할 수 있어요"
            case .budget: return "추천 가격대를 맞추는 데 사용돼요"
            case .done: return "밴쿠버의 로컬 픽을 취향에 맞춰 정렬했어요"
            }
        }
    }

    private let districts = [
        "Downtown", "Burnaby", "Richmond", "Coquitlam", "North Vancouver",
        "West Vancouver", "Kitsilano", "Yaletown", "UBC", "Mount Pleasant", "Gastown"
    ]

    private let vibes = [
        "korean-community", "newcomer-friendly", "study-friendly", "casual",
        "cozy", "trendy", "family-friendly", "date-night", "outdoor",
        "indoor", "learning-heavy", "career-focused", "group-friendly",
        "solo-friendly", "free-entry"
    ]

    init(initialPreference: UserPreference = .defaultValue, onComplete: @escaping (UserPreference) -> Void) {
        self.initialPreference = initialPreference
        self.onComplete = onComplete
        _selectedCategories = State(initialValue: Set(initialPreference.selectedCategories))
        _preferredDistricts = State(initialValue: Set(initialPreference.preferredDistricts))
        _budgetLevel = State(initialValue: initialPreference.budgetLevel)
        _vibeTags = State(initialValue: Set(initialPreference.vibeTags))
    }

    var body: some View {
        ZStack {
            DooriStyle.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 16)
                    .padding(.top, 65)

                topControl

                VStack(alignment: .leading, spacing: 10) {
                    Text(step.title)
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(DooriStyle.ink)
                    Text(step.subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.black.opacity(0.72))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 24)

                content
                    .padding(.horizontal, 16)
                    .padding(.top, 38)

                Spacer(minLength: 24)

                PrimaryButton(title: step == .done ? "시작하기" : "다음") {
                    advance()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 48)
                .disabled(!canAdvance)
                .opacity(canAdvance ? 1 : 0.45)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.16))
                Capsule()
                    .fill(DooriStyle.accent)
                    .frame(width: proxy.size.width * step.progress)
            }
        }
        .frame(height: 5)
    }

    private var topControl: some View {
        Button {
            if step.rawValue > 0 {
                step = Step(rawValue: step.rawValue - 1) ?? .categories
            } else {
                dismiss()
            }
        } label: {
            Image(systemName: "arrow.left")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(DooriStyle.ink)
                .frame(width: 44, height: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 22)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .categories:
            VStack(spacing: 20) {
                categoryCard(.food)
                categoryCard(.events)
                categoryCard(.lifestyle)
            }
        case .districts:
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(districts, id: \.self) { district in
                    chipButton(title: district, isSelected: preferredDistricts.contains(district)) {
                        toggle(district, in: &preferredDistricts)
                    }
                }
            }
        case .budget:
            VStack(spacing: 18) {
                budgetCard(title: "Free", level: 0)
                budgetCard(title: "$", level: 1)
                budgetCard(title: "$$", level: 2)
                budgetCard(title: "$$$", level: 3)
                budgetCard(title: "$$$$", level: 4)
            }
        case .vibes:
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(vibes, id: \.self) { vibe in
                        chipButton(title: vibe, isSelected: vibeTags.contains(vibe)) {
                            toggle(vibe, in: &vibeTags)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            .frame(maxHeight: 410)
        case .done:
            VStack(spacing: 18) {
                Image(systemName: "sparkle")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(DooriStyle.accent)
                    .padding(.top, 60)

                Text("선택하신 취향을 바탕으로\n밴쿠버의 딱 맞는 픽을 준비했어요.")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DooriStyle.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func categoryCard(_ category: ContentCategory) -> some View {
        Button {
            toggle(category.rawValue, in: &selectedCategories)
        } label: {
            PreferenceSelectionCard(
                title: category.titleKr,
                subtitle: category.titleEn,
                symbolName: category.symbolName,
                isSelected: selectedCategories.contains(category.rawValue)
            )
        }
        .buttonStyle(.plain)
    }

    private func budgetCard(title: String, level: Int) -> some View {
        Button {
            budgetLevel = level
        } label: {
            PreferenceSelectionCard(
                title: level == 0 ? "무료" : title,
                subtitle: level == 0 ? "Free entry" : "Budget level \(level)",
                symbolName: level == 0 ? "ticket" : "dollarsign",
                isSelected: budgetLevel == level
            )
        }
        .buttonStyle(.plain)
    }

    private func chipButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(isSelected ? .white : DooriStyle.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isSelected ? DooriStyle.accent : DooriStyle.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var canAdvance: Bool {
        switch step {
        case .categories: return !selectedCategories.isEmpty
        case .districts: return !preferredDistricts.isEmpty
        case .budget: return true
        case .vibes: return !vibeTags.isEmpty
        case .done: return true
        }
    }

    private func advance() {
        if step == .done {
            let preference = UserPreference(
                selectedCategories: Array(selectedCategories).sorted(),
                preferredDistricts: Array(preferredDistricts).sorted(),
                budgetLevel: budgetLevel,
                vibeTags: Array(vibeTags).sorted(),
                infoNeeds: [],
                languagePreference: .both,
                updatedAt: Date()
            )
            onComplete(preference)
        } else {
            step = Step(rawValue: step.rawValue + 1) ?? .done
        }
    }

    private func toggle(_ value: String, in set: inout Set<String>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }
}
