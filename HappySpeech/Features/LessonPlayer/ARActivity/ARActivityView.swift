import SwiftUI

// MARK: - ARActivityView
//
// Диспетчер AR-игр внутри SessionShell.
// Фазы UI:
//   1. `loading`          — строим capability + permissions + cards.
//   2. `permissionDenied` — banner «Открыть Настройки».
//   3. `selection`        — grid с 7 карточками AR-игр.
//   4. `active`           — fullScreenCover с дочерним AR-экраном.
//   5. `completed`        — итог: звёзды, процент, сообщение.
// Контракт с родителем: `ARActivityView(activity:, onComplete:)`,
// где `onComplete(score: Float)` вызывается после «Завершить».

struct ARActivityView: View {

    // MARK: - Input

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var interactor: ARActivityInteractor?
    @State private var presenter: ARActivityPresenter?
    @State private var router: ARActivityRouter?
    @State private var display = ARActivityViewDisplay()

    // MARK: - Routing flags

    @State private var showARMirror = false
    @State private var showARStoryQuest = false
    @State private var bootstrapped = false

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            switch display.phase {
            case .loading:
                loadingView
            case .permissionDenied:
                permissionDeniedView
            case .selection:
                selectionContent
            case .active:
                activePlaceholder
            case .completed:
                completedContent
            }
        }
        .task { await bootstrap() }
        .fullScreenCover(isPresented: $showARMirror, onDismiss: handleMirrorDismiss) {
            ARMirrorView()
                .environment(container)
        }
        .fullScreenCover(isPresented: $showARStoryQuest, onDismiss: handleStoryQuestDismiss) {
            ARStoryQuestView()
                .environment(container)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ARActivityRoot")
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(ColorTokens.Brand.primary)
                .scaleEffect(1.4)
            Text(String(localized: "Проверяем AR-возможности…"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .accessibilityLabel(String(localized: "Загрузка"))
    }

    // MARK: - Permission Denied

    private var permissionDeniedView: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(TypographyTokens.kidDisplay(56))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
                .accessibilityHidden(true)

            Text(String(localized: "Нужна камера"))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)

            Text(String(localized: "AR-упражнения работают через камеру. Разреши доступ в Настройках."))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer()

            HSButton(
                String(localized: "Открыть Настройки"),
                style: .primary,
                icon: "gear"
            ) {
                interactor?.openSettings(.init())
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .accessibilityHint(String(localized: "Открыть системные настройки для разрешения камеры"))

            HSButton(
                String(localized: "Назад"),
                style: .ghost
            ) {
                onComplete(0)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.large)
        }
    }

    // MARK: - Selection Screen

    private var selectionContent: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.large) {
                headerSection

                if display.showPermissionBanner {
                    permissionBanner
                        .padding(.horizontal, SpacingTokens.screenEdge)
                }

                gameCardsGrid

                Spacer(minLength: SpacingTokens.large)
            }
            .padding(.vertical, SpacingTokens.medium)
        }
        .scrollIndicators(.hidden)
    }

    private var headerSection: some View {
        VStack(spacing: SpacingTokens.small) {
            Text(display.screenTitle)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
                .accessibilityAddTraits(.isHeader)

            Text(display.subtitle)
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    private var permissionBanner: some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ColorTokens.Semantic.warning)
                .accessibilityHidden(true)

            Text(display.permissionBannerMessage)
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)

            Button {
                interactor?.requestPermission(.init(kind: .camera))
            } label: {
                Text(String(localized: "Разрешить"))
                    .font(TypographyTokens.body(14))
                    .fontWeight(.semibold)
                    .foregroundStyle(ColorTokens.Brand.primary)
            }
            .accessibilityLabel(String(localized: "Разрешить доступ к камере"))
        }
        .padding(SpacingTokens.regular)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .fill(ColorTokens.Kid.surfaceAlt)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md)
                        .stroke(ColorTokens.Semantic.warning.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private var gameCardsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: SpacingTokens.small),
                GridItem(.flexible(), spacing: SpacingTokens.small)
            ],
            spacing: SpacingTokens.small
        ) {
            ForEach(display.gameCards) { card in
                ARActivityGameCardView(card: card) {
                    guard card.isAvailable else { return }
                    interactor?.selectGame(.init(kind: card.kind))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(gameCardAccessibilityLabel(for: card))
                .accessibilityHint(card.isAvailable ? String(localized: "Начать игру") : card.unavailableReason)
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    private func gameCardAccessibilityLabel(for card: ARActivityGameCard) -> String {
        var label = card.title
        if card.isRecommended {
            label += ", " + String(localized: "рекомендуется")
        }
        if card.playedToday {
            label += ", " + String(localized: "уже играли сегодня")
        }
        if !card.isAvailable {
            label += ", " + String(localized: "недоступно")
        }
        return label
    }

    // MARK: - Active (placeholder shown while fullScreenCover transitions)

    private var activePlaceholder: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(ColorTokens.Brand.primary)
                .scaleEffect(1.2)
            Text(String(localized: "Открываем AR…"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    // MARK: - Completed

    private var completedContent: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer(minLength: SpacingTokens.medium)

            starsRow
                .accessibilityLabel(String(localized: "Получено звёзд: \(display.starsEarned) из 3"))

            Text(display.scoreLabel)
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)

            Text(display.completionMessage)
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer(minLength: SpacingTokens.medium)

            HSButton(
                String(localized: "Завершить"),
                style: .primary,
                icon: "checkmark.circle.fill"
            ) {
                onComplete(display.lastScore)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.large)
            .accessibilityHint(String(localized: "Вернуться к занятию"))
        }
    }

    private var starsRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < display.starsEarned ? "star.fill" : "star")
                    .font(TypographyTokens.kidDisplay(44))
                    .foregroundStyle(
                        index < display.starsEarned
                            ? ColorTokens.Brand.gold
                            : ColorTokens.Kid.line
                    )
                    .scaleEffect(index < display.starsEarned ? 1.0 : 0.88)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6)
                            .delay(Double(index) * 0.1),
                        value: display.starsEarned
                    )
            }
        }
        .accessibilityElement(children: .ignore)
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let interactor = ARActivityInteractor(
            adaptivePlanner: container.adaptivePlannerService,
            sessionRepository: nil,
            hapticService: container.hapticService
        )
        let presenter = ARActivityPresenter()
        let router = ARActivityRouter()

        interactor.presenter = presenter
        interactor.router = router
        presenter.viewModel = display

        router.onRouteToMirror = { showARMirror = true }
        router.onRouteToStoryQuest = { showARStoryQuest = true }
        router.onRouteToButterflyCatch = { showARStoryQuest = true }
        router.onRouteToBreathingAR = { showARStoryQuest = true }
        router.onRouteToMimicLyalya = { showARMirror = true }
        router.onRouteToHoldThePose = { showARMirror = true }
        router.onRouteToPoseSequence = { showARMirror = true }
        router.onRouteToSoundAndFace = { showARMirror = true }
        router.onDismiss = { onComplete(display.lastScore) }

        self.interactor = interactor
        self.presenter = presenter
        self.router = router

        let soundGroup = Self.resolveSoundGroup(for: activity.soundTarget)
        let stage = Self.resolveStage(for: activity.difficulty)

        interactor.loadActivity(.init(
            contentUnitId: activity.id,
            soundGroup: soundGroup,
            targetSound: activity.soundTarget,
            stage: stage,
            childName: "",
            childId: "",
            childAge: 6
        ))
    }

    // MARK: - Dismiss handlers

    private func handleMirrorDismiss() {
        interactor?.completeActivity(.init(
            activityType: .mirror,
            gameKind: display.activeGameKind,
            score: 0.8,
            attempts: 1,
            durationSec: 0
        ))
    }

    private func handleStoryQuestDismiss() {
        interactor?.completeActivity(.init(
            activityType: .storyQuest,
            gameKind: display.activeGameKind,
            score: 0.8,
            attempts: 1,
            durationSec: 0
        ))
    }

    // MARK: - Helpers

    static func resolveSoundGroup(for targetSound: String) -> String {
        let firstLetter = targetSound.uppercased().prefix(1)
        switch firstLetter {
        case "С", "З", "Ц":    return "whistling"
        case "Ш", "Ж", "Ч", "Щ": return "hissing"
        case "Р", "Л":          return "sonants"
        case "К", "Г", "Х":    return "velar"
        default:                return ""
        }
    }

    static func resolveStage(for difficulty: Int) -> String {
        switch difficulty {
        case ..<2:  return "isolated"
        case 2:     return "syllable"
        case 3:     return "wordInit"
        case 4:     return "wordMed"
        default:    return "phrase"
        }
    }
}

// MARK: - ARActivityGameCardView

private struct ARActivityGameCardView: View {

    let card: ARActivityGameCard
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                HStack {
                    Image(systemName: card.iconSystemName)
                        .font(TypographyTokens.title(24))
                        .foregroundStyle(iconColor)
                        .accessibilityHidden(true)

                    Spacer(minLength: 0)

                    if card.isRecommended {
                        Image(systemName: "star.fill")
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Brand.gold)
                            .accessibilityHidden(true)
                    }

                    if card.playedToday {
                        Image(systemName: "checkmark.circle.fill")
                            .font(TypographyTokens.caption(14))
                            .foregroundStyle(ColorTokens.Brand.primary.opacity(0.6))
                            .accessibilityHidden(true)
                    }
                }

                Text(card.title)
                    .font(TypographyTokens.body(15))
                    .fontWeight(.semibold)
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(card.description)
                    .font(TypographyTokens.body(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)

                HStack {
                    Image(systemName: "clock")
                        .font(TypographyTokens.caption(10))
                        .accessibilityHidden(true)
                    Text(card.estimatedLabel)
                        .font(TypographyTokens.body(11))
                }
                .foregroundStyle(ColorTokens.Kid.inkSoft)

                if !card.isAvailable && !card.unavailableReason.isEmpty {
                    Text(card.unavailableReason)
                        .font(TypographyTokens.body(11))
                        .foregroundStyle(ColorTokens.Semantic.warning)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(SpacingTokens.regular)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md))
            .overlay(recommendedBorder)
            .opacity(card.isAvailable ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!card.isAvailable)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: card.isAvailable)
    }

    private var iconColor: Color {
        card.isAvailable ? ColorTokens.Brand.primary : ColorTokens.Kid.inkSoft
    }

    private var titleColor: Color {
        card.isAvailable ? ColorTokens.Kid.ink : ColorTokens.Kid.inkMuted
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: RadiusTokens.md)
            .fill(card.isRecommended
                  ? ColorTokens.Brand.lilac.opacity(0.12)
                  : ColorTokens.Kid.surface)
    }

    private var recommendedBorder: some View {
        RoundedRectangle(cornerRadius: RadiusTokens.md)
            .stroke(
                card.isRecommended ? ColorTokens.Brand.primary.opacity(0.5) : Color.clear,
                lineWidth: 1.5
            )
    }
}

// MARK: - Preview

#Preview("Selection screen") {
    ARActivityView(
        activity: SessionActivity(
            id: "ar-demo",
            gameType: .arActivity,
            lessonId: "Р-syllable",
            soundTarget: "Р",
            difficulty: 2,
            isCompleted: false,
            score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
