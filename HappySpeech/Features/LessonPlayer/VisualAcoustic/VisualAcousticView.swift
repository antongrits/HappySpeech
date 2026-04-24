import SwiftUI
import OSLog

// MARK: - VisualAcousticView
//
// «Визуально-акустическая связь» — экран-игра для ребёнка. Показывается
// крупный emoji-образ (например, 🐍) и вопрос «Как звучит змея? Найди слово
// со звуком «С»». Ребёнок жмёт «Слушать» — AVSpeechSynthesizer зачитывает
// вопрос и 4 варианта. После окончания речи варианты активируются.
// После выбора показывается feedback (зелёный/красный/золотой раскрыт),
// через 1.2–1.5 с — автопереход к следующему раунду. 6 раундов.
//
// Архитектура: Clean Swift VIP. `interactor`, `presenter`, `router`, `display`
// создаются ровно один раз в `bootstrap()` и удерживаются как `@State` —
// иначе SwiftUI пересоздаст их при каждом re-render и состояние игры рассыплется.

struct VisualAcousticView: View {

    // MARK: - Input

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var display = VisualAcousticDisplay()
    @State private var interactor: VisualAcousticInteractor?
    @State private var presenter: VisualAcousticPresenter?
    @State private var router: VisualAcousticRouter?
    @State private var bootstrapped = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "VisualAcousticView")

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
        .accessibilityLabel(String(localized: "Визуально-акустическая игра: найди слово с целевым звуком"))
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        switch display.phase {
        case .loading:
            loadingView
        case .presenting, .choosing, .feedback:
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
            Text(String(localized: "Готовим игру…"))
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
            questionBlock
            listenButton
            Spacer(minLength: 0)
            choicesGrid
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
                    String(localized: "Раунд \(display.roundIndex + 1) из \(display.totalRounds)")
                )
            Text("\(display.roundIndex + 1)/\(display.totalRounds)")
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
                .frame(height: 160)

            Text(display.imageEmoji)
                .font(.system(size: 96))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                .scaleEffect(reduceMotion ? 1.0 : (display.isPlaying ? 1.04 : 1.0))
                .animation(
                    reduceMotion
                        ? nil
                        : .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                    value: display.isPlaying
                )
                .accessibilityLabel(display.imageLabel)

            if display.isPlaying {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .padding(SpacingTokens.small)
                            .background(Circle().fill(ColorTokens.Kid.surfaceAlt))
                            .padding(SpacingTokens.small)
                            .accessibilityLabel(String(localized: "Звук играет"))
                    }
                    Spacer()
                }
            }
        }
    }

    private var questionBlock: some View {
        VStack(spacing: SpacingTokens.tiny) {
            Text(display.question)
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            Text(display.questionWithSound)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
    }

    private var listenButton: some View {
        HSButton(
            display.isPlaying
                ? String(localized: "Слушаю…")
                : String(localized: "Слушать"),
            style: .secondary,
            size: .medium,
            icon: "speaker.wave.2.fill",
            isLoading: display.isPlaying
        ) {
            handleListen()
        }
        .frame(maxWidth: 260)
        .disabled(display.phase == .feedback || display.phase == .completed)
    }

    // MARK: - Choices

    private var choicesGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: SpacingTokens.small),
                      GridItem(.flexible(), spacing: SpacingTokens.small)],
            spacing: SpacingTokens.small
        ) {
            ForEach(Array(display.choices.enumerated()), id: \.offset) { idx, word in
                ChoiceTile(
                    title: word,
                    ownIndex: idx,
                    result: result(at: idx),
                    reduceMotion: reduceMotion
                ) {
                    handleChoice(at: idx)
                }
                .disabled(!isChoiceEnabled)
                .accessibilityHint(accessibilityHint(for: idx))
            }
        }
        .overlay(alignment: .top) {
            if display.phase == .feedback, !display.feedbackText.isEmpty {
                feedbackBanner
                    .offset(y: -48)
                    .transition(.opacity)
            }
        }
        .animation(
            reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7),
            value: display.phase
        )
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
            Text(display.feedbackText)
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
    }

    private var isChoiceEnabled: Bool {
        display.phase == .choosing
    }

    private func result(at index: Int) -> ChoiceResult {
        guard display.choiceResults.indices.contains(index) else { return .none }
        return display.choiceResults[index]
    }

    private func accessibilityHint(for index: Int) -> String {
        switch result(at: index) {
        case .none:
            return isChoiceEnabled
                ? String(localized: "Нажми, чтобы выбрать это слово")
                : String(localized: "Сначала послушай вопрос")
        case .correct:
            return String(localized: "Правильно")
        case .wrong(let correctIndex):
            if correctIndex == index {
                return String(localized: "Правильный ответ")
            }
            return String(localized: "Неверно")
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

    private func handleListen() {
        guard display.phase == .presenting || display.phase == .choosing else { return }
        container.soundService.playUISound(.tap)
        interactor?.playAudio(.init())
    }

    private func handleChoice(at index: Int) {
        guard isChoiceEnabled else { return }
        guard display.choices.indices.contains(index) else { return }
        container.soundService.playUISound(.tap)
        container.hapticService.selection()
        interactor?.chooseWord(.init(choiceIndex: index))
        // Звук/вибро-feedback по итогу проверки.
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

        let interactor = VisualAcousticInteractor()
        let presenter = VisualAcousticPresenter()
        let router = VisualAcousticRouter()

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

        logger.info(
            "bootstrap activity=\(activity.id, privacy: .public) target=\(activity.soundTarget, privacy: .public)"
        )

        interactor.loadRound(VisualAcousticModels.LoadRound.Request(
            activity: activity,
            roundIndex: 0
        ))
    }
}

// MARK: - ChoiceTile

/// Один из 4 вариантов ответа. Стилизуется по `ChoiceResult`.
///
/// Правило рендеринга:
/// - `.none` — нейтральный outlined.
/// - `.correct` — зелёный фон, галочка (ребёнок сам выбрал правильно).
/// - `.wrong(correctIndex: ownIndex)` — «revealed» золотой фон со звездой
///   (Presenter помечает так правильный слот после ошибки).
/// - `.wrong(correctIndex: other)` — красный фон с крестиком (чужая ошибка).
private struct ChoiceTile: View {

    let title: String
    let ownIndex: Int
    let result: ChoiceResult
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
                    .minimumScaleFactor(0.65)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.vertical, SpacingTokens.small)
            .frame(maxWidth: .infinity, minHeight: 56)
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
                value: result
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }

    /// Признак «revealed»: ячейка сама является правильным ответом
    /// (Presenter подставил сюда `.wrong(correctIndex: ownIndex)`).
    private var isRevealed: Bool {
        if case .wrong(let correctIndex) = result, correctIndex == ownIndex {
            return true
        }
        return false
    }

    private var isPlainWrong: Bool {
        if case .wrong(let correctIndex) = result, correctIndex != ownIndex {
            return true
        }
        return false
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch result {
        case .none:
            EmptyView()
        case .correct:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        case .wrong:
            if isRevealed {
                Image(systemName: "star.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
        }
    }

    private var backgroundColor: Color {
        switch result {
        case .none:     return ColorTokens.Kid.surface
        case .correct:  return ColorTokens.Feedback.correct
        case .wrong:    return isRevealed
            ? ColorTokens.Brand.gold
            : ColorTokens.Feedback.incorrect
        }
    }

    private var foregroundColor: Color {
        switch result {
        case .none:     return ColorTokens.Kid.ink
        case .correct:  return .white
        case .wrong:    return .white
        }
    }

    private var borderColor: Color {
        switch result {
        case .none:     return ColorTokens.Brand.primary
        case .correct:  return ColorTokens.Feedback.correct
        case .wrong:    return isRevealed
            ? ColorTokens.Brand.gold
            : ColorTokens.Feedback.incorrect
        }
    }

    private var borderWidth: CGFloat {
        result == .none ? 1.5 : 2
    }

    private var scaleForState: CGFloat {
        guard !reduceMotion else { return 1 }
        switch result {
        case .correct:  return 1.04
        case .wrong:    return isRevealed ? 1.02 : 0.97
        case .none:     return 1.0
        }
    }
}

// MARK: - Preview

#Preview("Presenting") {
    VisualAcousticView(
        activity: SessionActivity(
            id: "preview",
            gameType: .visualAcoustic,
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
