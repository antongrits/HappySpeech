import OSLog
import SwiftUI

// MARK: - MemoryView
//
// «Найди пару» — сетка карточек. Ребёнок переворачивает по две;
// если совпали — остаются открытыми, если нет — закрываются через 1.5 с.
// 3 раунда: easy→medium→hard. Таймер на каждый раунд. Подсказки (3 штуки).
// Стрик: 3 подряд → badge, 5 подряд → мегабейдж.
// Reduce Motion: instant flip вместо 3D анимации.

struct MemoryView: View {

    // MARK: Inputs

    let soundGroup: String
    let childName: String
    let onComplete: (Float) -> Void

    // MARK: Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: State

    @State private var display: MemoryDisplay
    @State private var interactor: MemoryInteractor
    @State private var presenter: MemoryPresenter

    private let logger = Logger(subsystem: "ru.happyspeech", category: "MemoryView")

    // MARK: - Init

    @MainActor
    init(
        soundGroup: String,
        childName: String,
        onComplete: @escaping (Float) -> Void
    ) {
        self.soundGroup = soundGroup
        self.childName = childName
        self.onComplete = onComplete

        let haptic: any HapticService = LiveHapticService()
        let interactor = MemoryInteractor(hapticService: haptic)
        let presenter = MemoryPresenter()
        interactor.presenter = presenter
        _interactor = State(initialValue: interactor)
        _presenter = State(initialValue: presenter)
        _display = State(initialValue: MemoryDisplay())
    }

    @MainActor
    init(activity: SessionActivity, onComplete: @escaping (Float) -> Void) {
        self.init(
            soundGroup: Self.groupKey(for: activity.soundTarget),
            childName: "",
            onComplete: onComplete
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            content
        }
        .task {
            presenter.viewModel = display
            await interactor.loadSession(.init(
                soundGroup: soundGroup,
                childName: childName,
                startDifficulty: .easy
            ))
        }
        .onDisappear {
            interactor.cancel()
        }
        .onChange(of: display.pendingFinalScore) { _, newValue in
            if let score = newValue {
                logger.info("onComplete score=\(score, privacy: .public)")
                onComplete(score)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Найди все пары"))
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        switch display.phase {
        case .loading:
            loadingView
        case .playing:
            playingView
        case .roundCompleted:
            roundCompletedView
        case .completed:
            completedView
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(ColorTokens.Brand.primary)
            Text(String(localized: "Готовим игру…"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    // MARK: - Playing

    private var playingView: some View {
        VStack(spacing: SpacingTokens.small) {
            header
            grid
            Spacer(minLength: 0)
            bottomBar
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.large)
        .padding(.bottom, SpacingTokens.medium)
    }

    private var header: some View {
        VStack(spacing: SpacingTokens.small) {
            HStack(alignment: .firstTextBaseline) {
                LyalyaMascotView(state: display.streakCount >= 3 ? .celebrating : .idle, size: 52)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(display.greeting.isEmpty
                         ? String(localized: "Найди все пары")
                         : display.greeting)
                        .font(TypographyTokens.title(18))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(display.roundLabel)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                Spacer()
                timerBadge
            }
            HStack {
                Text(String(localized: "Найдено пар: \(display.matchedPairs) из \(display.totalPairs)"))
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .monospacedDigit()
                Spacer()
                if display.streakCount >= 3 {
                    streakBadge
                }
            }
            HSProgressBar(value: matchedProgress)
                .frame(height: 8)
        }
        .frame(maxWidth: .infinity)
    }

    private var timerBadge: some View {
        HStack(spacing: SpacingTokens.tiny) {
            Image(systemName: "timer")
                .font(TypographyTokens.caption(13).weight(.semibold))
                .accessibilityHidden(true)
            Text(display.timerLabel)
                .font(TypographyTokens.mono(14))
                .monospacedDigit()
        }
        .padding(.horizontal, SpacingTokens.small)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(ColorTokens.Kid.surfaceAlt)
        )
        .foregroundStyle(timerColor(for: display.timerColor))
        .accessibilityLabel(String(localized: "Осталось времени: \(display.timerLabel)"))
    }

    private var streakBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: display.megaStreak ? "flame.fill" : "bolt.fill")
                .font(TypographyTokens.caption(12))
                .accessibilityHidden(true)
            Text(display.megaStreak
                 ? String(localized: "Невероятно!")
                 : String(localized: "Серия: \(display.streakCount)"))
                .font(TypographyTokens.caption(12).weight(.semibold))
        }
        .padding(.horizontal, SpacingTokens.small)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(display.megaStreak
                      ? ColorTokens.Brand.butter.opacity(0.25)
                      : ColorTokens.Brand.primary.opacity(0.15))
        )
        .foregroundStyle(display.megaStreak ? ColorTokens.Brand.butter : ColorTokens.Brand.primary)
        .accessibilityLabel(display.megaStreak
                            ? String(localized: "Невероятная серия!")
                            : String(localized: "Серия: \(display.streakCount) подряд"))
    }

    // MARK: - Grid

    private var grid: some View {
        let cols = Array(
            repeating: GridItem(.flexible(), spacing: SpacingTokens.small),
            count: display.columns
        )
        return LazyVGrid(columns: cols, spacing: SpacingTokens.small) {
            ForEach(display.cards) { card in
                cardTile(card)
            }
        }
    }

    private func cardTile(_ card: MemoryCard) -> some View {
        let faceUp = card.isFaceUp || card.isMatched
        let isHinted = display.highlightedCardIds.contains(card.id)

        return Button {
            handleFlip(cardId: card.id)
        } label: {
            ZStack {
                if card.isMatched {
                    // Matched карточки получают glass-эффект вместо plain surface
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(ColorTokens.Feedback.correct.opacity(0.18))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(faceUp
                              ? ColorTokens.Kid.surface
                              : ColorTokens.Brand.primary.opacity(0.85))
                }
                if faceUp {
                    cardFaceContent(card: card)
                } else {
                    cardBackContent
                }
            }
            .frame(height: cardHeight)
            .overlay(cardOverlay(card: card, isHinted: isHinted))
            .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
            .scaleEffect(card.isMatched && !reduceMotion ? 1.02 : 1.0)
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : (faceUp ? 0 : 180)),
                axis: (0, 1, 0)
            )
            .animation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.35, dampingFraction: 0.7),
                value: faceUp
            )
            .animation(
                reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7),
                value: card.isMatched
            )
        }
        .buttonStyle(.plain)
        .disabled(
            display.isFlipDisabled ||
            card.isMatched ||
            card.isFaceUp ||
            display.phase != .playing
        )
        .accessibilityLabel(
            faceUp ? card.word : String(localized: "Закрытая карточка")
        )
        .accessibilityHint(
            faceUp
                ? String(localized: "Карточка открыта")
                : String(localized: "Нажми, чтобы открыть")
        )
        .accessibilityValue(
            card.isMatched ? String(localized: "Найдена") : ""
        )
    }

    @ViewBuilder
    private func cardFaceContent(card: MemoryCard) -> some View {
        VStack(spacing: 4) {
            HSContentSymbol(card.emoji, size: emojiSize)
            Text(card.word)
                .font(TypographyTokens.caption(wordFontSize))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var cardBackContent: some View {
        Image(systemName: "questionmark")
            .font(TypographyTokens.title(questionSize).weight(.bold))
            .foregroundStyle(.white)
            .accessibilityHidden(true)
    }

    private func cardOverlay(card: MemoryCard, isHinted: Bool) -> some View {
        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
            .strokeBorder(
                isHinted
                    ? ColorTokens.Brand.butter
                    : (card.isMatched
                       ? ColorTokens.Feedback.correct
                       : ColorTokens.Kid.line),
                lineWidth: (isHinted || card.isMatched) ? 3 : 1
            )
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.25),
                value: isHinted
            )
    }

    // MARK: - Bottom bar (hints + difficulty)

    private var bottomBar: some View {
        HStack {
            Text(display.difficultyLabel)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            Spacer()
            hintButton
        }
    }

    private var hintButton: some View {
        Button {
            Task {
                await interactor.useHint(.init())
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "lightbulb.fill")
                    .font(TypographyTokens.caption(13))
                    .accessibilityHidden(true)
                Text(String(localized: "Подсказка (\(display.hintsRemaining))"))
                    .font(TypographyTokens.caption(13).weight(.semibold))
            }
            .padding(.horizontal, SpacingTokens.small)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(display.hintButtonEnabled
                          ? ColorTokens.Brand.butter.opacity(0.25)
                          : ColorTokens.Kid.surfaceAlt)
            )
            .foregroundStyle(
                display.hintButtonEnabled
                    ? ColorTokens.Brand.butter
                    : ColorTokens.Kid.inkMuted
            )
        }
        .disabled(!display.hintButtonEnabled || display.phase != .playing)
        .accessibilityLabel(
            String(localized: "Подсказка. Осталось: \(display.hintsRemaining)")
        )
        .accessibilityHint(
            display.hintButtonEnabled
                ? String(localized: "Нажми, чтобы получить подсказку")
                : String(localized: "Подсказки закончились")
        )
    }

    // MARK: - Round completed

    private var roundCompletedView: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer()
            starsRow
            Text(display.scoreLabel)
                .font(TypographyTokens.title(28))
                .foregroundStyle(ColorTokens.Kid.ink)
                .monospacedDigit()
                .accessibilityLabel(String(localized: "Пары: \(display.scoreLabel)"))
            Text(display.completionMessage)
                .font(TypographyTokens.body(17))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.xLarge)
            Text(display.roundSummary)
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
            Spacer()
            if display.hasNextRound {
                HSButton(
                    String(localized: "Следующий раунд"),
                    style: .primary,
                    icon: "arrow.right.circle.fill"
                ) {
                    Task { await interactor.advanceToNextRound() }
                }
                .frame(maxWidth: 320)
                .accessibilityLabel(String(localized: "Перейти к следующему раунду"))
            } else {
                HSButton(
                    String(localized: "Завершить"),
                    style: .primary,
                    icon: "checkmark.circle.fill"
                ) { finalize() }
                .frame(maxWidth: 320)
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.bottom, SpacingTokens.large)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Раунд завершён"))
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
            HSButton(
                String(localized: "Завершить"),
                style: .primary,
                icon: "checkmark.circle.fill"
            ) { finalize() }
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
                    .font(TypographyTokens.display(44).weight(.semibold))
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

    private func handleFlip(cardId: String) {
        guard display.phase == .playing, !display.isFlipDisabled else { return }
        container.soundService.playUISound(.tap)
        Task {
            await interactor.flipCard(.init(cardId: cardId))
        }
    }

    private func finalize() {
        guard display.pendingFinalScore == nil else { return }
        container.soundService.playUISound(.complete)
        display.pendingFinalScore = display.finalScore
    }

    // MARK: - Computed helpers

    private var matchedProgress: Double {
        let total = max(display.totalPairs, 1)
        return Double(display.matchedPairs) / Double(total)
    }

    private func timerColor(for name: String) -> Color {
        switch name {
        case "red":    return ColorTokens.Feedback.incorrect
        case "orange": return ColorTokens.Brand.butter
        default:       return ColorTokens.Brand.mint
        }
    }

    private var cardHeight: CGFloat {
        switch display.columns {
        case 6:  return 64
        case 4 where display.totalPairs > 8: return 72
        default: return 86
        }
    }

    private var emojiSize: CGFloat {
        display.columns == 6 ? 24 : 32
    }

    private var wordFontSize: CGFloat {
        display.columns == 6 ? 10 : 12
    }

    private var questionSize: CGFloat {
        display.columns == 6 ? 18 : 22
    }

    // MARK: - Group key inference

    private static func groupKey(for sound: String) -> String {
        switch sound.uppercased() {
        case "С", "З", "Ц":       return "whistling"
        case "Ш", "Ж", "Ч", "Щ":  return "hissing"
        case "Р", "Л":             return "sonorant"
        case "К", "Г", "Х":        return "velar"
        default:                   return "any"
        }
    }
}

// MARK: - MemoryDisplay: DisplayLogic adapter

extension MemoryDisplay: MemoryDisplayLogic {

    func displayLoadSession(_ viewModel: MemoryModels.LoadSession.ViewModel) {
        cards = viewModel.cards
        greeting = viewModel.greeting
        matchedPairs = 0
        totalPairs = max(1, cards.count / 2)
        lastMatchedPairId = nil
        isFlipDisabled = false
        difficultyLabel = viewModel.difficultyLabel
        roundLabel = viewModel.roundLabel
        hintsRemaining = viewModel.hintsRemaining
        hintButtonEnabled = viewModel.hintsRemaining > 0
        columns = viewModel.columns
        highlightedCardIds = []
        streakCount = 0
        megaStreak = false
        voiceCue = nil
        phase = .playing
    }

    func displayFlipCard(_ viewModel: MemoryModels.FlipCard.ViewModel) {
        cards = viewModel.cards
        lastMatchedPairId = viewModel.matchedPairId
        let matchedCards = cards.filter { $0.isMatched }.count
        matchedPairs = matchedCards / 2
        let faceUpNonMatched = cards.filter { $0.isFaceUp && !$0.isMatched }.count
        isFlipDisabled = (faceUpNonMatched >= 2)
        streakCount = viewModel.streakCount
        megaStreak = viewModel.megaStreak
        voiceCue = viewModel.voiceCue
        hintButtonEnabled = (hintsRemaining > 0) && !isFlipDisabled
    }

    func displayTimerTick(_ viewModel: MemoryModels.TimerTick.ViewModel) {
        timerLabel = viewModel.timerLabel
        timerColor = viewModel.timerColor
    }

    func displayUseHint(_ viewModel: MemoryModels.UseHint.ViewModel) {
        highlightedCardIds = viewModel.highlightedCardIds
        hintsRemaining = viewModel.hintsRemaining
        hintButtonEnabled = viewModel.hintButtonEnabled
    }

    func displayCompleteRound(_ viewModel: MemoryModels.CompleteRound.ViewModel) {
        starsEarned = viewModel.starsEarned
        scoreLabel = viewModel.scoreLabel
        completionMessage = viewModel.message
        roundSummary = viewModel.roundSummary
        finalScore = viewModel.finalScore
        hasNextRound = viewModel.hasNextRound
        phase = .roundCompleted
    }

    func displayCompleteSession(_ viewModel: MemoryModels.CompleteSession.ViewModel) {
        starsEarned = viewModel.starsEarned
        scoreLabel = viewModel.scoreLabel
        completionMessage = viewModel.message
        finalScore = viewModel.finalScore
        phase = .completed
    }
}

// MARK: - Preview

#Preview("Playing — Easy") {
    MemoryView(
        soundGroup: "sonorant",
        childName: "Саша",
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}

#Preview("Playing — Hard") {
    MemoryView(
        soundGroup: "hissing",
        childName: "",
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
