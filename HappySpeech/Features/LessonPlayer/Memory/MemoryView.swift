import SwiftUI
import OSLog

// MARK: - MemoryView
//
// «Найди пару» — сетка 4×4 = 16 карточек (8 пар emoji+слово). Ребёнок
// переворачивает по две; если совпали — остаются открытыми, если нет —
// закрываются через 1 с (логика в Interactor). Таймер 60 с. По окончании —
// экран со звёздами и CTA «Завершить».

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
                childName: childName
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
    }

    // MARK: Playing

    private var playingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            header
            grid
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.large)
        .padding(.bottom, SpacingTokens.medium)
    }

    private var header: some View {
        VStack(spacing: SpacingTokens.small) {
            HStack(alignment: .firstTextBaseline) {
                Text(display.greeting.isEmpty
                     ? String(localized: "Найди все пары")
                     : display.greeting)
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Spacer()
                timerBadge
            }
            HStack {
                Text(String(localized: "Найдено пар: \(display.matchedPairs) из \(display.totalPairs)"))
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .monospacedDigit()
                Spacer()
            }
            HSProgressBar(value: matchedProgress)
                .frame(height: 8)
        }
        .frame(maxWidth: .infinity)
    }

    private var timerBadge: some View {
        HStack(spacing: SpacingTokens.tiny) {
            Image(systemName: "timer")
                .font(.system(size: 13, weight: .semibold))
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

    private var grid: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: SpacingTokens.small),
            count: 4
        )
        return LazyVGrid(columns: columns, spacing: SpacingTokens.small) {
            ForEach(display.cards) { card in
                cardTile(card)
            }
        }
    }

    private func cardTile(_ card: MemoryCard) -> some View {
        let faceUp = card.isFaceUp || card.isMatched
        return Button {
            handleFlip(cardId: card.id)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(faceUp
                          ? ColorTokens.Kid.surface
                          : ColorTokens.Brand.primary.opacity(0.85))
                if faceUp {
                    VStack(spacing: 4) {
                        Text(card.emoji)
                            .font(.system(size: 36))
                            .accessibilityHidden(true)
                        Text(card.word)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                } else {
                    Image(systemName: "questionmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(height: 86)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .strokeBorder(
                        card.isMatched
                            ? ColorTokens.Feedback.correct
                            : ColorTokens.Kid.line,
                        lineWidth: card.isMatched ? 3 : 1
                    )
            )
            .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
            .scaleEffect(card.isMatched && !reduceMotion ? 1.02 : 1.0)
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
        .accessibilityHint(faceUp ? "" : String(localized: "Нажми, чтобы открыть"))
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

    // MARK: - Helpers

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

// MARK: - Display: DisplayLogic adapter

extension MemoryDisplay: MemoryDisplayLogic {

    func displayLoadSession(_ viewModel: MemoryModels.LoadSession.ViewModel) {
        cards = viewModel.cards
        greeting = viewModel.greeting
        matchedPairs = 0
        totalPairs = max(1, cards.count / 2)
        lastMatchedPairId = nil
        isFlipDisabled = false
        phase = .playing
    }

    func displayFlipCard(_ viewModel: MemoryModels.FlipCard.ViewModel) {
        cards = viewModel.cards
        lastMatchedPairId = viewModel.matchedPairId
        // Счётчик найденных пар — считаем по matched карточкам в колоде.
        let matchedCards = cards.filter { $0.isMatched }.count
        matchedPairs = matchedCards / 2
        // isFlipDisabled — если сейчас ровно две карты лицом вверх и не matched.
        let faceUpNonMatched = cards.filter { $0.isFaceUp && !$0.isMatched }.count
        isFlipDisabled = (faceUpNonMatched >= 2)
    }

    func displayTimerTick(_ viewModel: MemoryModels.TimerTick.ViewModel) {
        timerLabel = viewModel.timerLabel
        timerColor = viewModel.timerColor
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

#Preview("Playing") {
    MemoryView(
        soundGroup: "sonorant",
        childName: "Саша",
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
