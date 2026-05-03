import OSLog
import SwiftUI

// MARK: - MinimalPairsView
//
// «Минимальные пары» — экран из четырёх фаз:
//   1. loading   — подготовка раундов
//   2. round     — prompt + speaker + две emoji-карточки (target vs foil)
//   3. feedback  — зелёный/красный баннер + автодисмисс через 1.5 с
//   4. completed — звёзды + счёт + per-pair accuracy + кнопка «Завершить»
//
// Доступность: touch targets ≥56pt, VoiceOver labels, Dynamic Type, Reduce Motion.
// View не содержит бизнес-логики.

struct MinimalPairsView: View {

    // MARK: Inputs

    let soundContrast: String
    let childName: String
    let onComplete: (Float) -> Void

    // MARK: Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: State

    @State private var display: MinimalPairsDisplay
    @State private var interactor: MinimalPairsInteractor
    @State private var presenter: MinimalPairsPresenter

    private let logger = Logger(subsystem: "ru.happyspeech", category: "MinimalPairsView")

    // MARK: - Init

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
            if let toast = display.toastMessage {
                toastBanner(toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(
            reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85),
            value: display.toastMessage
        )
        .task {
            presenter.viewModel = display
            await interactor.loadSession(.init(
                soundContrast: soundContrast,
                childName: childName,
                childId: "",
                childAge: 6
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

    // MARK: - Content routing

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

    // MARK: Loading

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
            lyalyaMascotHeader
            progressHeader
            promptBlock
            optionsRow
            hintReplayRow
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

    private var lyalyaMascotHeader: some View {
        LyalyaRealityKitView(state: display.isAnswered ? .happy : .idle, mood: 0.7)
            .frame(width: 60, height: 60)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)
    }

    private var progressHeader: some View {
        VStack(spacing: SpacingTokens.tiny) {
            Text(display.progressLabel)
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .monospacedDigit()
            ProgressView(value: roundProgress, total: 1.0)
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
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(ColorTokens.Brand.primary))
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(display.replaysRemaining == 0 && !display.isAnswered)
            .accessibilityLabel(String(localized: "Повторить слово"))
            .accessibilityHint(String(localized: "Нажмите, чтобы услышать слово ещё раз"))
            .accessibilityValue(
                display.replaysRemaining > 0
                    ? String(localized: "Доступно повторов: \(display.replaysRemaining)")
                    : String(localized: "Повторы закончились")
            )

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
                    optionCard(word: pair.targetWord, emoji: pair.targetEmoji, isTarget: true)
                    optionCard(word: pair.foilWord, emoji: pair.foilEmoji, isTarget: false)
                } else {
                    optionCard(word: pair.foilWord, emoji: pair.foilEmoji, isTarget: false)
                    optionCard(word: pair.targetWord, emoji: pair.targetEmoji, isTarget: true)
                }
            }
        }
    }

    private func optionCard(word: String, emoji: String, isTarget: Bool) -> some View {
        let shouldHighlight = display.showHintHighlight && isTarget
        let glassStyle: HSLiquidGlassStyle = shouldHighlight
            ? .tinted(ColorTokens.Brand.primary)
            : .primary
        return Button {
            selectOption(isTarget: isTarget)
        } label: {
            HSLiquidGlassCard(style: glassStyle, padding: SpacingTokens.small) {
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
                .frame(minHeight: 160)
            }
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(cardStroke(isTarget: isTarget, hintHighlight: shouldHighlight), lineWidth: 3)
            )
            .scaleEffect(shouldHighlight ? 1.04 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
                value: shouldHighlight
            )
        }
        .buttonStyle(.plain)
        .disabled(display.isAnswered)
        .accessibilityLabel(word)
        .accessibilityHint(String(localized: "Нажмите, если это правильная картинка"))
        .accessibilityAddTraits(shouldHighlight ? .isSelected : [])
    }

    // MARK: Hint & Replay row

    private var hintReplayRow: some View {
        HStack(spacing: SpacingTokens.medium) {
            // Кнопка подсказки
            Button {
                requestHint()
            } label: {
                Label(
                    String(localized: "Подсказка (\(display.hintsAvailable))"),
                    systemImage: "lightbulb.fill"
                )
                .font(TypographyTokens.caption(13))
                .foregroundStyle(display.hintsAvailable > 0
                    ? ColorTokens.Brand.primary
                    : ColorTokens.Kid.inkMuted)
                .padding(.horizontal, SpacingTokens.small)
                .padding(.vertical, SpacingTokens.tiny)
                .background(
                    Capsule().fill(
                        display.hintsAvailable > 0
                            ? ColorTokens.Brand.primary.opacity(0.12)
                            : ColorTokens.Kid.line.opacity(0.3)
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(display.isAnswered || display.hintsAvailable == 0)
            .accessibilityLabel(
                String(localized: "Подсказка. Доступно: \(display.hintsAvailable)")
            )

            Spacer()

            // Индикатор повторов
            if display.replaysRemaining < 3 {
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { idx in
                        Circle()
                            .fill(idx < display.replaysRemaining
                                  ? ColorTokens.Brand.primary
                                  : ColorTokens.Kid.line)
                            .frame(width: 8, height: 8)
                    }
                }
                .accessibilityLabel(
                    String(localized: "Повторов осталось: \(display.replaysRemaining)")
                )
            }
        }
        .padding(.horizontal, SpacingTokens.small)
        .opacity(display.isAnswered ? 0.4 : 1.0)
    }

    // MARK: Feedback overlay

    private var feedbackOverlay: some View {
        VStack(spacing: SpacingTokens.tiny) {
            HStack(spacing: SpacingTokens.small) {
                Image(systemName: display.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                Text(display.feedbackText)
                    .font(TypographyTokens.headline(17))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            if let streak = display.streakLabel {
                Text(streak)
                    .font(TypographyTokens.caption(12))
                    .opacity(0.9)
            }
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
        ScrollView {
            VStack(spacing: SpacingTokens.large) {
                starsRow
                    .padding(.top, SpacingTokens.xLarge)
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

                if !display.pairSummary.isEmpty {
                    pairAccuracySection
                }

                HSButton(
                    String(localized: "Завершить"),
                    style: .primary,
                    icon: "checkmark.circle.fill"
                ) {
                    finalize()
                }
                .frame(maxWidth: 320)
                .padding(.bottom, SpacingTokens.large)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
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
                        reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.65)
                            .delay(Double(idx) * 0.12),
                        value: display.starsEarned
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(localized: "Получено звёзд: \(display.starsEarned) из 3")
        )
    }

    private var pairAccuracySection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text(String(localized: "Точность по звукам"))
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .padding(.horizontal, SpacingTokens.small)

            ForEach(display.pairSummary) { item in
                HStack {
                    Text(item.contrast)
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .frame(width: 60, alignment: .leading)
                    ProgressView(value: Double(item.accuracyPercent), total: 100)
                        .progressViewStyle(.linear)
                        .tint(accuracyColor(item.accuracyPercent))
                    Text(item.accuracyLabel)
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .frame(width: 40, alignment: .trailing)
                        .monospacedDigit()
                }
                .padding(.horizontal, SpacingTokens.small)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    String(localized: "Звуки \(item.contrast): \(item.accuracyLabel)")
                )
            }
        }
        .padding(SpacingTokens.cardPad)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
    }

    // MARK: Toast

    private func toastBanner(_ message: String) -> some View {
        Text(message)
            .font(TypographyTokens.caption(14))
            .foregroundStyle(.white)
            .padding(.horizontal, SpacingTokens.medium)
            .padding(.vertical, SpacingTokens.small)
            .background(Capsule().fill(Color.black.opacity(0.75)))
            .padding(.top, SpacingTokens.medium)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(message)
    }

    // MARK: - Styling helpers

    private func cardFill(isTarget: Bool, hintHighlight: Bool) -> Color {
        if hintHighlight { return ColorTokens.Brand.primary.opacity(0.15) }
        guard display.isAnswered,
              let selected = display.selectedIsTarget else { return ColorTokens.Kid.surface }
        let cardIsSelected = (selected == isTarget)
        if !cardIsSelected { return ColorTokens.Kid.surface }
        return display.correct
            ? ColorTokens.Feedback.correct.opacity(0.18)
            : ColorTokens.Feedback.incorrect.opacity(0.18)
    }

    private func cardStroke(isTarget: Bool, hintHighlight: Bool) -> Color {
        if hintHighlight { return ColorTokens.Brand.primary }
        guard display.isAnswered,
              let selected = display.selectedIsTarget else { return .clear }
        let cardIsSelected = (selected == isTarget)
        if !cardIsSelected { return .clear }
        return display.correct
            ? ColorTokens.Feedback.correct
            : ColorTokens.Feedback.incorrect
    }

    private func accuracyColor(_ percent: Int) -> Color {
        switch percent {
        case 80...:  return ColorTokens.Feedback.correct
        case 60..<80: return ColorTokens.Brand.butter
        default:     return ColorTokens.Feedback.incorrect
        }
    }

    // MARK: - Actions

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

    private func requestHint() {
        guard display.hintsAvailable > 0, !display.isAnswered else { return }
        container.soundService.playUISound(.tap)
        Task { await interactor.requestHint(.init()) }
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

    private var roundProgress: Double {
        guard display.totalRounds > 0 else { return 0 }
        let parts = display.progressLabel.split(separator: "/")
        guard let first = parts.first,
              let current = Int(first.trimmingCharacters(in: .whitespaces))
        else { return 0 }
        return Double(current) / Double(display.totalRounds)
    }

    private static func contrast(for sound: String) -> String {
        switch sound.uppercased() {
        case "С", "С/Ш":    return "С-Ш"
        case "Ш":            return "С-Ш"
        case "Р", "Р/Л":    return "Р-Л"
        case "Л":            return "Р-Л"
        case "К", "К/Г":    return "К-Г"
        case "Г":            return "К-Г"
        case "З", "З/Ж":    return "З-Ж"
        case "Ж":            return "З-Ж"
        case "Б", "Б/П":    return "Б-П"
        case "П":            return "Б-П"
        case "Д", "Д/Т":    return "Д-Т"
        case "Т":            return "Д-Т"
        case "В", "В/Ф":    return "В-Ф"
        case "Ф":            return "В-Ф"
        default:             return ""
        }
    }
}

// MARK: - MinimalPairsDisplay: DisplayLogic adapter

extension MinimalPairsDisplay: MinimalPairsDisplayLogic {

    func displayLoadSession(_ viewModel: MinimalPairsModels.LoadSession.ViewModel) {
        totalRounds = viewModel.totalRounds
        greeting = viewModel.greeting
    }

    func displayStartRound(_ viewModel: MinimalPairsModels.StartRound.ViewModel) {
        currentPair = viewModel.pair
        progressLabel = viewModel.progressLabel
        promptText = viewModel.promptText
        hintsAvailable = viewModel.hintsAvailable
        isAnswered = false
        selectedIsTarget = nil
        feedbackText = ""
        streakLabel = nil
        isStreakBonus = false
        showHintHighlight = false
        replaysRemaining = 3
        toastMessage = nil
        phase = .round
    }

    func displaySelectOption(_ viewModel: MinimalPairsModels.SelectOption.ViewModel) {
        correct = viewModel.correct
        feedbackText = viewModel.feedbackText
        correctAnswer = viewModel.correctAnswer
        isStreakBonus = viewModel.isStreakBonus
        streakLabel = viewModel.streakLabel
        isAnswered = true
        showHintHighlight = false
        phase = .feedback
        answeredCount += 1
        if viewModel.correct { correctCount += 1 }
    }

    func displayReplayWord(_ viewModel: MinimalPairsModels.ReplayWord.ViewModel) {
        replaysRemaining = viewModel.replaysRemaining
        if let msg = viewModel.toastMessage {
            showToast(msg)
        }
    }

    func displayHint(_ viewModel: MinimalPairsModels.RequestHint.ViewModel) {
        hintsAvailable = viewModel.hintsRemaining
        showToast(viewModel.toastMessage)
        if viewModel.level == .highlight && !viewModel.capReached {
            showHintHighlight = true
            hintHighlightDuration = viewModel.highlightDuration
            Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .seconds(viewModel.highlightDuration))
                self.showHintHighlight = false
            }
        }
    }

    func displayBonusRoundAdded(_ viewModel: MinimalPairsModels.BonusRoundAdded.ViewModel) {
        totalRounds = viewModel.totalRounds
        showToast(viewModel.toastMessage)
    }

    func displayCompleteSession(_ viewModel: MinimalPairsModels.CompleteSession.ViewModel) {
        starsEarned = viewModel.starsEarned
        scoreLabel = viewModel.scoreLabel
        completionMessage = viewModel.message
        pairSummary = viewModel.pairSummary
        phase = .completed
    }

    // MARK: - Toast helper

    private func showToast(_ message: String) {
        toastMessage = message
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(2.5))
            self.toastMessage = nil
        }
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
