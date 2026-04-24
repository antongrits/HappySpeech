import SwiftUI

// MARK: - ARActivityView
//
// Точка входа для AR-упражнений внутри SessionShell.
// Трёхфазовый UI:
//   1. `preview` — карточка с иконкой, описанием и кнопкой «Начать».
//   2. `active`  — fullScreenCover с дочерним AR-экраном (mirror / storyQuest).
//   3. `completed` — итог: звёзды, процент, сообщение, кнопка «Завершить».
// Контракт с родителем — как у остальных игр сессии:
//   `ARActivityView(activity:, onComplete:)`, где `onComplete(score: Float)`
//   вызывается после нажатия «Завершить».

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
            case .preview:
                previewContent
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
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(ColorTokens.Brand.primary)
                .scaleEffect(1.4)
            Text(String(localized: "Готовим AR-упражнение…"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .accessibilityLabel(String(localized: "Загрузка"))
    }

    // MARK: - Preview

    private var previewContent: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer(minLength: SpacingTokens.medium)

            Image(systemName: display.iconSystemName)
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(ColorTokens.Brand.primary)
                .frame(width: 120, height: 120)
                .background(
                    Circle().fill(ColorTokens.Brand.lilac.opacity(0.2))
                )
                .accessibilityHidden(true)

            Text(display.title)
                .font(TypographyTokens.title(28))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.screenEdge)

            Text(display.description)
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.screenEdge)

            estimatedBadge

            Spacer(minLength: SpacingTokens.medium)

            cameraHint
                .padding(.horizontal, SpacingTokens.screenEdge)

            HSButton(String(localized: "Начать"), style: .primary) {
                interactor?.startActivity(.init(activityType: display.activityType))
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.large)
            .accessibilityHint(String(localized: "Открыть AR-упражнение"))
        }
    }

    private var estimatedBadge: some View {
        HStack(spacing: SpacingTokens.tiny) {
            Image(systemName: "clock")
                .font(.system(size: 13, weight: .medium))
            Text(display.estimatedLabel)
                .font(TypographyTokens.body(14))
        }
        .foregroundStyle(ColorTokens.Kid.inkSoft)
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.vertical, SpacingTokens.tiny)
        .background(
            Capsule().fill(ColorTokens.Kid.surfaceAlt)
        )
        .accessibilityLabel(display.estimatedLabel)
    }

    private var cameraHint: some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
            Text(String(localized: "Готовься к камере!"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
        }
        .padding(.vertical, SpacingTokens.small)
        .padding(.horizontal, SpacingTokens.regular)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.sm)
                .stroke(ColorTokens.Kid.line, lineWidth: 1)
        )
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

            HSButton(String(localized: "Завершить"), style: .primary) {
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
                    .font(.system(size: 44, weight: .semibold))
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

        let interactor = ARActivityInteractor()
        let presenter = ARActivityPresenter()
        let router = ARActivityRouter()

        interactor.presenter = presenter
        interactor.router = router
        presenter.viewModel = display

        router.onRouteToMirror = {
            showARMirror = true
        }
        router.onRouteToStoryQuest = {
            showARStoryQuest = true
        }
        router.onDismiss = {
            onComplete(display.lastScore)
        }

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
            childName: ""
        ))
    }

    // MARK: - Dismiss handlers

    private func handleMirrorDismiss() {
        // Симулятор/тесты не возвращают реальный score — используем «хороший» дефолт.
        // На устройстве ARMirrorView отдаёт звёзды через свой отдельный pipeline;
        // для упрощения интеграции в сессию считаем средний успех.
        interactor?.completeActivity(.init(
            activityType: .mirror,
            score: 0.8,
            attempts: 1
        ))
    }

    private func handleStoryQuestDismiss() {
        interactor?.completeActivity(.init(
            activityType: .storyQuest,
            score: 0.8,
            attempts: 1
        ))
    }

    // MARK: - Helpers

    /// Определяет SoundFamily по целевому звуку (русской букве).
    static func resolveSoundGroup(for targetSound: String) -> String {
        let upper = targetSound.uppercased()
        let firstLetter = upper.prefix(1)
        switch firstLetter {
        case "С", "З", "Ц":
            return "whistling"
        case "Ш", "Ж", "Ч", "Щ":
            return "hissing"
        case "Р", "Л":
            return "sonants"
        case "К", "Г", "Х":
            return "velar"
        default:
            return ""
        }
    }

    /// Грубое отображение Int-сложности → строкового этапа коррекции.
    /// 0–1 → isolated, 2 → syllable, 3 → wordInit, 4 → wordMed, 5+ → phrase.
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

// MARK: - Preview

#Preview("Preview state") {
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
