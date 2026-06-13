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
    // A-08 «Спокойный режим» — мгновенный flip без 3D-вращения (как reduceMotion).
    @Environment(\.calmMode) private var calmMode

    /// A-08: объединённый флаг «без резкого движения» — reduceMotion ИЛИ calmMode.
    private var calmReduce: Bool { reduceMotion || calmMode }

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
            HSMeshGradientBackground(palette: .kidWarm)
                .ignoresSafeArea()
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
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.regular) {
                    header
                    mascotStrip
                    grid
                    Spacer(minLength: 0)
                    bottomBar
                }
                .frame(minHeight: geo.size.height, alignment: .top)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.regular)
                .padding(.bottom, SpacingTokens.sp6)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaPadding(.bottom, SpacingTokens.small)
        }
    }

    // MARK: - Header (title + stat chips + progress)

    private var header: some View {
        VStack(spacing: SpacingTokens.small) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.small) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(display.greeting.isEmpty
                         ? String(localized: "Найди пару")
                         : display.greeting)
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(display.roundLabel)
                        .font(TypographyTokens.caption(12.5))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: SpacingTokens.tiny)
                if display.streakCount >= 3 {
                    streakBadge
                }
            }

            statStrip

            VStack(spacing: SpacingTokens.micro) {
                HSProgressBar(value: matchedProgress)
                    .frame(height: 8)
                HStack {
                    Text(String(localized: "Прогресс"))
                    Spacer()
                    Text(String(localized: "\(display.matchedPairs) из \(display.totalPairs) пар"))
                        .monospacedDigit()
                }
                .font(TypographyTokens.caption(11.5))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Stat chips (real model fields only)

    private var statStrip: some View {
        HStack(spacing: SpacingTokens.tiny) {
            statChip(
                dot: ColorTokens.Feedback.correct,
                value: "\(display.matchedPairs) / \(display.totalPairs)",
                label: String(localized: "найдено пар")
            )
            statChip(
                dot: ColorTokens.Brand.butter,
                value: "\(display.hintsRemaining)",
                label: String(localized: "подсказки")
            )
            statChip(
                dot: ColorTokens.Brand.lilac,
                value: difficultyShort,
                label: String(localized: "уровень")
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "Найдено пар: \(display.matchedPairs) из \(display.totalPairs). Подсказок: \(display.hintsRemaining). \(display.difficultyLabel)"
        ))
    }

    private func statChip(dot: Color, value: String, label: String) -> some View {
        HStack(spacing: SpacingTokens.tiny) {
            Circle()
                .fill(dot)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(TypographyTokens.caption(15).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(TypographyTokens.caption(10.5).weight(.medium))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SpacingTokens.tiny)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .shadow(color: ColorTokens.Overlay.shadow, radius: 6, y: 2)
    }

    // MARK: Mascot cheer strip

    private var mascotStrip: some View {
        HStack(alignment: .center, spacing: SpacingTokens.tiny) {
            Spacer(minLength: 0)
            HSSpeechBubble(mascotCheer, direction: .right, style: .lyalya, maxWidth: 220)
            LyalyaMascotView(state: display.streakCount >= 3 ? .celebrating : .happy, size: 50)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
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
            ForEach(Array(display.cards.enumerated()), id: \.element.id) { index, card in
                cardTile(card)
                    .accessibilityIdentifier("memoryCard_\(index)")
            }
        }
        .overlay(alignment: .topTrailing) {
            // Faint inset win-hint stars — decorative, not the focus.
            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(ColorTokens.Brand.butter)
                .opacity(0.13)
                .offset(x: -4, y: -10)
                .accessibilityHidden(true)
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
                } else if faceUp {
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(ColorTokens.Kid.surface)
                } else {
                    // Coral-tinted «рубашка» — мягкий тёплый градиент в одном hue.
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    ColorTokens.Brand.primaryHi,
                                    ColorTokens.Brand.primary
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                if faceUp {
                    cardFaceContent(card: card)
                } else {
                    cardBackContent
                }
            }
            .frame(height: cardHeight)
            .overlay(cardOverlay(card: card, isHinted: isHinted))
            .overlay(alignment: .topTrailing) {
                if card.isMatched {
                    matchedTick
                }
            }
            .shadow(color: ColorTokens.Overlay.shadow, radius: 3, y: 1)
            .scaleEffect(card.isMatched && !calmReduce ? 1.02 : 1.0)
            .rotation3DEffect(
                .degrees(calmReduce ? 0 : (faceUp ? 0 : 180)),
                axis: (0, 1, 0)
            )
            .animation(
                calmReduce
                    ? nil
                    : .spring(response: 0.35, dampingFraction: 0.7),
                value: faceUp
            )
            .animation(
                calmReduce ? nil : .spring(response: 0.35, dampingFraction: 0.7),
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
        // Маленький эмблема-знак Ляли на «рубашке» (вместо абстрактного ?).
        LyalyaMascotView(state: .idle, size: emblemSize)
            .accessibilityHidden(true)
    }

    private var matchedTick: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .frame(width: 20, height: 20)
            .background(Circle().fill(ColorTokens.Feedback.correct))
            .shadow(color: ColorTokens.Feedback.correct.opacity(0.45), radius: 3, y: 1)
            .padding(7)
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
                calmReduce ? nil : .easeInOut(duration: 0.25),
                value: isHinted
            )
    }

    // MARK: - Bottom bar (hints + difficulty)

    private var bottomBar: some View {
        VStack(spacing: SpacingTokens.small) {
            HStack(spacing: SpacingTokens.small) {
                hintButton
                Spacer(minLength: SpacingTokens.tiny)
                replayButton
            }
            Text(String(localized: "Кнопка «Дальше» появится после победы"))
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
        }
    }

    private var replayButton: some View {
        Button {
            container.soundService.playUISound(.tap)
            Task {
                await interactor.loadSession(.init(
                    soundGroup: soundGroup,
                    childName: childName,
                    startDifficulty: .easy
                ))
            }
        } label: {
            HStack(spacing: SpacingTokens.tiny) {
                Image(systemName: "arrow.counterclockwise")
                    .font(TypographyTokens.caption(14).weight(.bold))
                    .accessibilityHidden(true)
                Text(String(localized: "Заново"))
                    .font(TypographyTokens.caption(15).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(ColorTokens.Brand.primary, lineWidth: 1.5)
            )
            .foregroundStyle(ColorTokens.Brand.primary)
        }
        .buttonStyle(.plain)
        .disabled(display.phase != .playing)
        .accessibilityLabel(String(localized: "Заново"))
        .accessibilityHint(String(localized: "Начать игру сначала"))
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
                .accessibilityIdentifier("gameNextButton")
                .accessibilityLabel(String(localized: "Перейти к следующему раунду"))
            } else {
                HSButton(
                    String(localized: "Завершить"),
                    style: .primary,
                    icon: "checkmark.circle.fill"
                ) { finalize() }
                .frame(maxWidth: 320)
                .accessibilityIdentifier("gameNextButton")
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.bottom, SpacingTokens.large)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Раунд завершён"))
    }

    // MARK: - Completed

    private var completedView: some View {
        // P0.5 v32: glass CTA footer pattern.
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
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.bottom, SpacingTokens.sp16)
        .safeAreaInset(edge: .bottom) {
            HSLiquidGlassCard(style: .primary, padding: SpacingTokens.regular) {
                HSButton(
                    String(localized: "Завершить"),
                    style: .primary,
                    icon: "checkmark.circle.fill"
                ) { finalize() }
                .accessibilityIdentifier("gameNextButton")
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.tiny)
        }
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

    private var emblemSize: CGFloat {
        display.columns == 6 ? 30 : 38
    }

    /// Короткая мотивирующая реплика маскота над сеткой.
    private var mascotCheer: String {
        if display.streakCount >= 3 {
            return String(localized: "Отлично!")
        }
        return String(localized: "Найди пару!")
    }

    /// Сжатый ярлык уровня для stat-чипа (исходный `difficultyLabel`
    /// может быть длинным, чип узкий на SE).
    private var difficultyShort: String {
        let label = display.difficultyLabel
        return label.isEmpty ? String(localized: "—") : label
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
