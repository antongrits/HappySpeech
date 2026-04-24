import SwiftUI
import OSLog

// MARK: - StoryCompletionView
//
// «Заверши историю» — экран-игра для ребёнка. Маскот-логопед зачитывает
// короткую историю с пропуском (`___`); ребёнок выбирает правильное слово
// из трёх вариантов. Правильное всегда содержит целевой звук. 5 сцен подряд.
// После пятой — финал со звёздами.
//
// Архитектура: Clean Swift VIP. `interactor`, `presenter`, `router`, `display`
// создаются ровно один раз в `bootstrap()` и удерживаются как `@State` —
// иначе SwiftUI пересоздаст их при каждом re-render и состояние игры рассыплется.

struct StoryCompletionView: View {

    // MARK: - Input

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var display = StoryCompletionDisplay()
    @State private var interactor: StoryCompletionInteractor?
    @State private var presenter: StoryCompletionPresenter?
    @State private var router: StoryCompletionRouter?
    @State private var bootstrapped = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "StoryCompletionView")

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            content
        }
        .task { await bootstrap() }
        .onDisappear { interactor?.cancel() }
        .onChange(of: display.pendingFinalScore) { _, newValue in
            if let score = newValue {
                logger.info("onComplete score=\(score, privacy: .public)")
                onComplete(score)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Заверши историю: выбери пропущенное слово"))
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        switch display.phase {
        case .loading:
            loadingView
        case .reading, .choosing, .feedback:
            playingView
        case .completed:
            completedView
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(ColorTokens.Brand.primary)
                .scaleEffect(1.4)
            Text(String(localized: "Готовим историю…"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(String(localized: "Загрузка"))
    }

    // MARK: - Playing

    private var playingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            progressHeader
            emojiTile
            storyCard
            Spacer(minLength: 0)
            choicesSection
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.large)
        .padding(.bottom, SpacingTokens.large)
    }

    private var progressHeader: some View {
        HStack(spacing: SpacingTokens.small) {
            HSProgressBar(value: display.progressFraction)
                .frame(height: 10)
                .accessibilityLabel(
                    String(localized: "Сцена \(display.sceneIndex + 1) из \(display.totalScenes)")
                )
            Text("\(display.sceneIndex + 1)/\(display.totalScenes)")
                .font(TypographyTokens.mono(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .monospacedDigit()
                .accessibilityHidden(true)
        }
    }

    private var emojiTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Kid.surface)
                .frame(height: 140)

            Text(display.emoji)
                .font(.system(size: 84))
                .accessibilityHidden(true)

            // Иконка TTS — показываем только в фазе reading.
            if display.phase == .reading, display.isReading {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .padding(SpacingTokens.small)
                            .background(
                                Circle()
                                    .fill(ColorTokens.Kid.surfaceAlt)
                            )
                            .padding(SpacingTokens.small)
                            .scaleEffect(reduceMotion ? 1.0 : 1.08)
                            .animation(
                                reduceMotion
                                    ? nil
                                    : .easeInOut(duration: 0.45).repeatForever(autoreverses: true),
                                value: display.isReading
                            )
                            .accessibilityLabel(String(localized: "Маскот читает историю"))
                    }
                    Spacer()
                }
            }
        }
    }

    private var storyCard: some View {
        Text(display.displayText)
            .font(TypographyTokens.title(20))
            .foregroundStyle(ColorTokens.Kid.ink)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
            .padding(SpacingTokens.medium)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(ColorTokens.Kid.surfaceAlt)
            )
            .accessibilityLabel(display.storyText.replacingOccurrences(
                of: StoryPlaceholder.marker,
                with: String(localized: "пропуск")
            ))
    }

    // MARK: - Choices

    private var choicesSection: some View {
        VStack(spacing: SpacingTokens.small) {
            if display.phase == .feedback, !display.feedbackMessage.isEmpty {
                feedbackBanner
            }
            ForEach(Array(display.choices.enumerated()), id: \.offset) { idx, word in
                ChoiceButton(
                    title: word,
                    state: state(at: idx),
                    reduceMotion: reduceMotion
                ) {
                    handleChoice(at: idx)
                }
                .disabled(!isChoiceEnabled)
                .accessibilityHint(accessibilityHint(for: idx))
            }
        }
    }

    private var feedbackBanner: some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: display.feedbackCorrect
                  ? "checkmark.circle.fill"
                  : "lightbulb.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(
                    display.feedbackCorrect
                        ? ColorTokens.Feedback.correct
                        : ColorTokens.Brand.butter
                )
                .accessibilityHidden(true)
            Text(display.feedbackMessage)
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            Spacer()
        }
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.vertical, SpacingTokens.small)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(
                    display.feedbackCorrect
                        ? ColorTokens.Feedback.correct.opacity(0.15)
                        : ColorTokens.Brand.butter.opacity(0.18)
                )
        )
        .transition(.opacity)
    }

    private var isChoiceEnabled: Bool {
        display.phase == .reading || display.phase == .choosing
    }

    private func state(at index: Int) -> ChoiceState {
        guard display.choiceStates.indices.contains(index) else { return .idle }
        return display.choiceStates[index]
    }

    private func accessibilityHint(for index: Int) -> String {
        switch state(at: index) {
        case .idle:     return String(localized: "Нажми, чтобы выбрать это слово")
        case .correct:  return String(localized: "Правильно")
        case .wrong:    return String(localized: "Неверно")
        case .revealed: return String(localized: "Правильный ответ")
        }
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer()
            starsRow
            Text(display.scoreLabel)
                .font(TypographyTokens.title(28))
                .foregroundStyle(ColorTokens.Kid.ink)
                .monospacedDigit()
            Text(display.completionMessage)
                .font(TypographyTokens.body(17))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.xLarge)
            Spacer()
            HSButton(String(localized: "Завершить"), style: .primary) {
                finalize()
            }
            .frame(maxWidth: 320)
            .padding(.bottom, SpacingTokens.large)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Игра завершена"))
    }

    private var starsRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(0..<3, id: \.self) { idx in
                Image(systemName: idx < display.starsEarned ? "star.fill" : "star")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(
                        idx < display.starsEarned
                            ? ColorTokens.Brand.butter
                            : ColorTokens.Kid.line
                    )
                    .scaleEffect(idx < display.starsEarned ? 1.0 : 0.85)
                    .animation(
                        reduceMotion
                            ? nil
                            : .spring(response: 0.5, dampingFraction: 0.65)
                                .delay(Double(idx) * 0.12),
                        value: display.starsEarned
                    )
            }
        }
        .accessibilityLabel(
            String(localized: "Получено звёзд: \(display.starsEarned) из 3")
        )
    }

    // MARK: - Actions

    private func handleChoice(at index: Int) {
        guard isChoiceEnabled else { return }
        guard display.choices.indices.contains(index) else { return }
        container.soundService.playUISound(.tap)
        container.hapticService.selection()
        interactor?.chooseWord(.init(choiceIndex: index))
        // Звук/вибро-feedback — сразу после обновления display (правильно/нет).
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            if display.feedbackCorrect {
                container.soundService.playUISound(.correct)
                container.hapticService.notification(.success)
            } else {
                container.soundService.playUISound(.incorrect)
                container.hapticService.notification(.warning)
            }
        }
    }

    private func finalize() {
        guard display.pendingFinalScore == nil else { return }
        container.soundService.playUISound(.complete)
        container.hapticService.notification(.success)
        display.pendingFinalScore = display.lastScore
        router?.routeBack()
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let interactor = StoryCompletionInteractor()
        let presenter = StoryCompletionPresenter()
        let router = StoryCompletionRouter()

        interactor.presenter = presenter
        interactor.router = router
        presenter.display = display
        router.onDismiss = { [weak display] in
            // Запасной канал dismiss — если router.routeBack() вызовется
            // в обход finalize(), всё равно поднимем pendingFinalScore.
            guard let display else { return }
            if display.pendingFinalScore == nil {
                display.pendingFinalScore = display.lastScore
            }
        }

        self.interactor = interactor
        self.presenter = presenter
        self.router = router

        logger.info("bootstrap activity=\(activity.id, privacy: .public) target=\(activity.soundTarget, privacy: .public)")

        interactor.loadStory(StoryCompletionModels.LoadStory.Request(
            activity: activity,
            sceneIndex: 0
        ))
    }
}

// MARK: - ChoiceButton

/// Один вариант ответа. Стилизуется по `ChoiceState`.
private struct ChoiceButton: View {

    let title: String
    let state: ChoiceState
    let reduceMotion: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SpacingTokens.small) {
                stateIcon
                Text(title)
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
            }
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.vertical, SpacingTokens.small)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.button, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.button, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .scaleEffect(scaleForState)
            .animation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.35, dampingFraction: 0.7),
                value: state
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .idle:
            EmptyView()
        case .correct:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        case .wrong:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        case .revealed:
            Image(systemName: "star.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .idle:     return ColorTokens.Kid.surface
        case .correct:  return ColorTokens.Feedback.correct
        case .wrong:    return ColorTokens.Feedback.incorrect
        case .revealed: return ColorTokens.Brand.gold
        }
    }

    private var foregroundColor: Color {
        switch state {
        case .idle:     return ColorTokens.Kid.ink
        case .correct, .wrong, .revealed: return .white
        }
    }

    private var borderColor: Color {
        switch state {
        case .idle:     return ColorTokens.Brand.primary
        case .correct:  return ColorTokens.Feedback.correct
        case .wrong:    return ColorTokens.Feedback.incorrect
        case .revealed: return ColorTokens.Brand.gold
        }
    }

    private var borderWidth: CGFloat {
        state == .idle ? 1.5 : 2
    }

    private var scaleForState: CGFloat {
        guard !reduceMotion else { return 1 }
        switch state {
        case .correct:  return 1.04
        case .wrong:    return 0.97
        case .revealed: return 1.02
        case .idle:     return 1.0
        }
    }
}

// MARK: - Preview

#Preview("Reading") {
    StoryCompletionView(
        activity: SessionActivity(
            id: "preview",
            gameType: .storyCompletion,
            lessonId: "l1",
            soundTarget: "С",
            difficulty: 1,
            isCompleted: false,
            score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
