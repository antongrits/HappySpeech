import SwiftUI

// MARK: - ChildHomeView (Clean Swift: View)

struct ChildHomeView: View {
    let childId: String

    @State private var interactor: ChildHomeInteractor
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    init(childId: String) {
        self.childId = childId
        self._interactor = State(initialValue: ChildHomeInteractor())
    }

    var body: some View {
        ZStack {
            // Background
            kidBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Top greeting + streak
                    greetingSection

                    // Mascot Lyalya
                    mascotSection

                    // Daily mission card
                    dailyMissionSection

                    // Quick actions
                    quickActionsSection

                    // Recent progress
                    progressSection

                    Spacer(minLength: SpacingTokens.sp16)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            }

            // Parent button (top-right)
            parentButton
        }
        .onAppear {
            Task { await interactor.fetchChildData(id: childId) }
        }
        .environment(\.circuitContext, .kid)
        .loadingOverlay(interactor.viewModel.isLoading)
    }

    // MARK: - Sections

    private var kidBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#FFF4EC"),
                    Color(hex: "#FFF0E8")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Decorative clouds
            CloudDecoration()
        }
    }

    private var greetingSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Привет,"))
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)

                Text(interactor.viewModel.childName)
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
            }

            Spacer()

            // Streak indicator
            if interactor.viewModel.currentStreak > 0 {
                StreakBadge(streak: interactor.viewModel.currentStreak)
            }
        }
        .padding(.top, SpacingTokens.pageTop)
        .padding(.bottom, SpacingTokens.sp3)
    }

    private var mascotSection: some View {
        VStack(spacing: SpacingTokens.sp2) {
            HSMascotView(
                mood: interactor.viewModel.mascotMood,
                size: 140
            )

            if let phrase = interactor.viewModel.mascotPhrase {
                Text(phrase)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.sp8)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, SpacingTokens.sp4)
    }

    private var dailyMissionSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text(String(localized: "Задание на сегодня"))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .textCase(.uppercase)
                .tracking(1)

            DailyMissionCard(
                mission: interactor.viewModel.dailyMission,
                onTap: {
                    coordinator.navigate(to: .childHome(childId: childId))
                }
            )
        }
        .padding(.top, SpacingTokens.sp2)
    }

    private var quickActionsSection: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: SpacingTokens.sp3
        ) {
            QuickActionTile(
                title: String(localized: "Карта звуков"),
                icon: "map.fill",
                color: ColorTokens.Brand.sky
            ) {
                // Navigate to WorldMap
            }

            QuickActionTile(
                title: String(localized: "AR-зеркало"),
                icon: "camera.fill",
                color: ColorTokens.Brand.lilac
            ) {
                // Navigate to AR
            }

            QuickActionTile(
                title: String(localized: "Наклейки"),
                icon: "star.fill",
                color: ColorTokens.Brand.butter
            ) {
                // Navigate to Rewards
            }

            QuickActionTile(
                title: String(localized: "Достижения"),
                icon: "trophy.fill",
                color: ColorTokens.Brand.mint
            ) {
                // Navigate to Achievements
            }
        }
        .padding(.top, SpacingTokens.sp5)
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text(String(localized: "Прогресс по звукам"))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .textCase(.uppercase)
                .tracking(1)
                .padding(.top, SpacingTokens.sp5)

            ForEach(interactor.viewModel.soundProgress, id: \.sound) { item in
                SoundProgressRow(item: item)
            }
        }
    }

    private var parentButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    coordinator.navigate(to: .parentHome)
                } label: {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .padding(SpacingTokens.sp3)
                        .background(
                            Circle().fill(ColorTokens.Kid.surface)
                                .kidTileShadow()
                        )
                }
                .accessibilityLabel(String(localized: "Профиль родителя"))
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp2)
            Spacer()
        }
    }
}

// MARK: - Supporting Views

private struct CloudDecoration: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.white.opacity(0.6))
                .frame(width: 120, height: 60)
                .blur(radius: 20)
                .offset(x: -80, y: 60)

            Ellipse()
                .fill(Color.white.opacity(0.5))
                .frame(width: 90, height: 45)
                .blur(radius: 16)
                .offset(x: 100, y: 90)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct DailyMissionCard: View {
    let mission: ChildHomeViewModel.DailyMission
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SpacingTokens.sp4) {
                // Sound icon
                ZStack {
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(ColorTokens.Brand.primary.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Text(mission.targetSound)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(ColorTokens.Brand.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(mission.title)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)

                    Text(mission.subtitle)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)

                    HSProgressBar(value: mission.progress, style: .kid, tint: ColorTokens.Brand.primary)
                        .frame(height: 10)
                        .padding(.top, 2)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(ColorTokens.Brand.primary)
            }
            .padding(SpacingTokens.sp4)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .kidCardShadow()
            )
        }
        .buttonStyle(.plain)
        .tapFeedback()
        .accessibilityLabel("\(mission.title). \(mission.subtitle). Нажмите для начала.")
    }
}

private struct QuickActionTile: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.sp2) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(color)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle().fill(color.opacity(0.12))
                    )

                Text(title)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .ctaTextStyle()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp4)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .kidCardShadow()
            )
        }
        .buttonStyle(.plain)
        .tapFeedback()
        .accessibilityLabel(title)
    }
}

private struct StreakBadge: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.orange)
            Text("\(streak)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.orange)
        }
        .padding(.horizontal, SpacingTokens.sp3)
        .padding(.vertical, SpacingTokens.sp2)
        .background(
            Capsule().fill(Color.orange.opacity(0.12))
        )
        .accessibilityLabel("\(streak) дней подряд")
    }
}

private struct SoundProgressRow: View {
    let item: ChildHomeViewModel.SoundProgress

    var body: some View {
        HStack(spacing: SpacingTokens.sp3) {
            Text(item.sound)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(item.color)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.stageName)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.ink)
                    Spacer()
                    Text("\(Int(item.rate * 100))%")
                        .font(TypographyTokens.mono(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                HSProgressBar(value: item.rate, style: .kid, tint: item.color)
                    .frame(height: 8)
            }
        }
        .padding(.vertical, SpacingTokens.sp2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Звук \(item.sound). \(item.stageName). \(Int(item.rate * 100)) процентов.")
    }
}

// MARK: - ViewModel

struct ChildHomeViewModel {
    var childName: String = "Ребёнок"
    var currentStreak: Int = 0
    var mascotMood: MascotMood = .idle
    var mascotPhrase: String? = nil
    var isLoading: Bool = false
    var dailyMission: DailyMission = .placeholder
    var soundProgress: [SoundProgress] = []

    struct DailyMission {
        let targetSound: String
        let title: String
        let subtitle: String
        let progress: Double

        static let placeholder = DailyMission(
            targetSound: "Р",
            title: "Звук Р в словах",
            subtitle: "Этап 3 из 10 · Слова с Р в начале",
            progress: 0.45
        )
    }

    struct SoundProgress: Identifiable {
        var id: String { sound }
        let sound: String
        let stageName: String
        let rate: Double
        let color: Color
    }
}

// MARK: - Interactor

@Observable
@MainActor
final class ChildHomeInteractor {
    var viewModel = ChildHomeViewModel()

    func fetchChildData(id: String) async {
        viewModel.isLoading = true
        defer { viewModel.isLoading = false }

        // In production: fetch from ChildRepository
        viewModel.childName = "Миша"
        viewModel.currentStreak = 5
        viewModel.mascotMood = .happy
        viewModel.mascotPhrase = "Отличная работа, Миша! Сегодня мы тренируем звук Р 🎉"
        viewModel.dailyMission = ChildHomeViewModel.DailyMission(
            targetSound: "Р",
            title: "Звук Р в словах",
            subtitle: "Этап 4 · Слова с Р в начале",
            progress: 0.45
        )
        viewModel.soundProgress = [
            .init(sound: "Р", stageName: "Слова", rate: 0.45, color: ColorTokens.Brand.primary),
            .init(sound: "Ш", stageName: "Слоги", rate: 0.70, color: ColorTokens.Brand.lilac),
        ]
    }
}

// MARK: - Preview

#Preview("Child Home") {
    ChildHomeView(childId: "preview-child-1")
        .environment(AppCoordinator())
        
}
