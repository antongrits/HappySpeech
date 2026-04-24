import SwiftUI
import OSLog

// MARK: - MinimalPairsView
//
// «Минимальные пары» — экран из трёх фаз:
//   1. loading   — прогресс-индикатор при подготовке раундов
//   2. round     — prompt + speaker + две emoji-карточки (target vs foil)
//   3. feedback  — зелёный/красный overlay с текстом, auto-dismiss через 1.5 c
//   4. completed — звёзды + счёт + кнопка «Завершить»
//
// View не содержит бизнес-логики. Через @State хранит триаду
// interactor/presenter/display (Display — @Observable store). Все действия
// проксируются в Interactor.

struct MinimalPairsView: View {

    // MARK: Inputs

    /// Целевой фонетический контраст ("Р-Л", "С-Ш", ""). Пустая строка — любой.
    let soundContrast: String
    /// Имя ребёнка для приветствия в completed-фазе.
    let childName: String
    /// Коллбек в SessionShell со итоговым скором 0…1.
    let onComplete: (Float) -> Void

    // MARK: Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: State

    @State private var display: MinimalPairsDisplay
    @State private var interactor: MinimalPairsInteractor
    @State private var presenter: MinimalPairsPresenter

    private let logger = Logger(subsystem: "ru.happyspeech", category: "MinimalPairsView")

    // MARK: - Convenience init

    @MainActor
    init(
        soundContrast: String,
        childName: String,
        onComplete: @escaping (Float) -> Void
    ) {
        self.soundContrast = soundContrast
        self.childName = childName
        self.onComplete = onComplete

        let interactor = MinimalPairsInteractor()
        let presenter = MinimalPairsPresenter()
        interactor.presenter = presenter
        _interactor = State(initialValue: interactor)
        _presenter = State(initialValue: presenter)
        _display = State(initialValue: MinimalPairsDisplay())
    }

    /// SessionShell-совместимый init — принимает `SessionActivity`.
    @MainActor
    init(activity: SessionActivity, onComplete: @escaping (Float) -> Void) {
        let contrast = Self.contrast(for: activity.soundTarget)
        self.init(soundContrast: contrast, childName: "", onComplete: onComplete)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            content
        }
        .task {
            bindPresenter()
            await interactor.loadSession(.init(
                soundContrast: soundContrast,
                childName: childName
            ))
            await interactor.startRound(.init(roundIndex: 0))
        }
        .onChange(of: display.pendingFinalScore) { _, newValue in
            if let score = newValue {
                logger.info("onComplete score=\(score, privacy: .public)")
                onComplete(score)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            String(localized: "Минимальные пары. Слушай слово и выбирай правильную картинку.")
        )
    }

    // MARK: - Subviews

    @ViewBuilder
    private var content: some View {
        switch display.phase {
        case .loading:
            loadingView
        case .round, .feedback:
            roundView
        case .completed:
            completedView
        }
    }

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(ColorTokens.Brand.primary)
            Text(String(localized: "Готовим игру…"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .accessibilityLabel(String(localized: "Загрузка"))
    }

    // MARK: Round

    private var roundView: some View {
        VStack(spacing: SpacingTokens.large) {
            progressHeader
            promptBlock
            optionsRow
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.large)
        .overlay(alignment: .bottom) {
            if display.phase == .feedback {
                feedbackOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, SpacingTokens.xLarge)
            }
        }
        .animation(
            reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85),
            value: display.phase
        )
    }

    private var progressHeader: some View {
        VStack(spacing: SpacingTokens.tiny) {
            Text(display.progressLabel)
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .monospacedDigit()
            ProgressView(
                value: roundProgress,
                total: 1.0
            )
            .progressViewStyle(.linear)
            .tint(ColorTokens.Brand.primary)
            .frame(maxWidth: 260)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Прогресс сессии"))
        .accessibilityValue(display.progressLabel)
    }

    private var promptBlock: some View {
        HStack(spacing: SpacingTokens.small) {
            Button(action: replayWord) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle().fill(ColorTokens.Brand.primary)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Повторить слово"))
            .accessibilityHint(String(localized: "Нажмите, чтобы услышать слово ещё раз"))

            Text(display.promptText)
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(SpacingTokens.cardPad)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
    }

    private var optionsRow: some View {
        HStack(spacing: SpacingTokens.medium) {
            if let pair = display.currentPair {
                if pair.targetIsLeft {
                    optionCard(
                        word: pair.targetWord,
                        emoji: pair.targetEmoji,
                        isTarget: true
                    )
                    optionCard(
                        word: pair.foilWord,
                        emoji: pair.foilEmoji,
                        isTarget: false
                    )
                } else {
                    optionCard(
                        word: pair.foilWord,
                        emoji: pair.foilEmoji,
                        isTarget: false
                    )
                    optionCard(
                        word: pair.targetWord,
                        emoji: pair.targetEmoji,
                        isTarget: true
                    )
                }
            }
        }
    }

    private func optionCard(word: String, emoji: String, isTarget: Bool) -> some View {
        Button {
            selectOption(isTarget: isTarget)
        } label: {
            VStack(spacing: SpacingTokens.small) {
                Text(emoji)
                    .font(.system(size: 72))
                    .accessibilityHidden(true)
                Text(word)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(cardFill(isTarget: isTarget))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(cardStroke(isTarget: isTarget), lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
        .disabled(display.isAnswered)
        .accessibilityLabel(word)
        .accessibilityHint(String(localized: "Нажмите, если это правильная картинка"))
    }

    // MARK: Feedback

    private var feedbackOverlay: some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: display.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 24, weight: .bold))
            Text(display.feedbackText)
                .font(TypographyTokens.headline(17))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, SpacingTokens.large)
        .padding(.vertical, SpacingTokens.medium)
        .foregroundStyle(.white)
        .background(
            Capsule().fill(
                display.correct
                    ? ColorTokens.Feedback.correct
                    : ColorTokens.Feedback.incorrect
            )
        )
        .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
        .accessibilityLabel(display.feedbackText)
    }

    // MARK: Completed

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
            HSButton(
                String(localized: "Завершить"),
                style: .primary
            ) {
                finalize()
            }
            .frame(maxWidth: 320)
            .padding(.bottom, SpacingTokens.large)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Раунд завершён"))
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
                        reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.65).delay(Double(idx) * 0.12),
                        value: display.starsEarned
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(localized: "Получено звёзд: \(display.starsEarned) из 3")
        )
    }

    // MARK: - Styling helpers

    private func cardFill(isTarget: Bool) -> Color {
        guard display.isAnswered,
              let selected = display.selectedIsTarget
        else { return ColorTokens.Kid.surface }
        let cardIsSelected = (selected == isTarget)
        if !cardIsSelected { return ColorTokens.Kid.surface }
        return display.correct
            ? ColorTokens.Feedback.correct.opacity(0.18)
            : ColorTokens.Feedback.incorrect.opacity(0.18)
    }

    private func cardStroke(isTarget: Bool) -> Color {
        guard display.isAnswered,
              let selected = display.selectedIsTarget
        else { return .clear }
        let cardIsSelected = (selected == isTarget)
        if !cardIsSelected { return .clear }
        return display.correct
            ? ColorTokens.Feedback.correct
            : ColorTokens.Feedback.incorrect
    }

    // MARK: - Actions

    private func bindPresenter() {
        presenter.viewModel = display
    }

    private func selectOption(isTarget: Bool) {
        guard !display.isAnswered else { return }
        display.selectedIsTarget = isTarget
        container.soundService.playUISound(.tap)
        Task {
            await interactor.selectOption(.init(selectedIsTarget: isTarget))
        }
    }

    private func replayWord() {
        container.soundService.playUISound(.tap)
        Task { await interactor.replayCurrentWord() }
    }

    private func finalize() {
        guard display.pendingFinalScore == nil else { return }
        let correct = Float(display.correctCount)
        let total = Float(max(display.answeredCount, 1))
        let score = correct / total
        container.soundService.playUISound(.complete)
        display.pendingFinalScore = score
    }

    // MARK: - Helpers

    /// Визуальный прогресс раунда для линейного ProgressView.
    private var roundProgress: Double {
        guard display.totalRounds > 0 else { return 0 }
        let parts = display.progressLabel.split(separator: "/")
        guard let first = parts.first,
              let current = Int(first.trimmingCharacters(in: .whitespaces))
        else { return 0 }
        return Double(current) / Double(display.totalRounds)
    }

    // MARK: - Contrast inference

    /// Преобразует `soundTarget` из SessionActivity в фонетический контраст.
    private static func contrast(for sound: String) -> String {
        switch sound.uppercased() {
        case "С", "С/Ш":   return "С-Ш"
        case "Ш":           return "С-Ш"
        case "Р", "Р/Л":   return "Р-Л"
        case "Л":           return "Р-Л"
        case "К", "К/Г":   return "К-Г"
        case "Г":           return "К-Г"
        case "З", "З/Ж":   return "З-Ж"
        case "Ж":           return "З-Ж"
        default:            return ""
        }
    }
}

// MARK: - Display: DisplayLogic adapter

extension MinimalPairsDisplay: MinimalPairsDisplayLogic {

    func displayLoadSession(_ viewModel: MinimalPairsModels.LoadSession.ViewModel) {
        totalRounds = viewModel.totalRounds
        greeting = viewModel.greeting
    }

    func displayStartRound(_ viewModel: MinimalPairsModels.StartRound.ViewModel) {
        currentPair = viewModel.pair
        progressLabel = viewModel.progressLabel
        promptText = viewModel.promptText
        isAnswered = false
        selectedIsTarget = nil
        feedbackText = ""
        phase = .round
    }

    func displaySelectOption(_ viewModel: MinimalPairsModels.SelectOption.ViewModel) {
        correct = viewModel.correct
        feedbackText = viewModel.feedbackText
        correctAnswer = viewModel.correctAnswer
        isAnswered = true
        phase = .feedback
        answeredCount += 1
        if viewModel.correct { correctCount += 1 }
    }

    func displayCompleteSession(_ viewModel: MinimalPairsModels.CompleteSession.ViewModel) {
        starsEarned = viewModel.starsEarned
        scoreLabel = viewModel.scoreLabel
        completionMessage = viewModel.message
        phase = .completed
    }
}

// MARK: - Preview

#Preview("Round") {
    MinimalPairsView(
        soundContrast: "Р-Л",
        childName: "Саша",
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
