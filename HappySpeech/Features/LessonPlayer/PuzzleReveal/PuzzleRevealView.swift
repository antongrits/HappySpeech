import OSLog
import SwiftUI

// MARK: - PuzzleRevealView
//
// «Сложи пазл»: 3×3 плиток закрывают картинку. За каждое правильно
// произнесённое слово открывается одна плитка. 5 пазлов в сессии.
//
// Архитектура — Clean Swift VIP. Interactor / Presenter / Router / StoreBridge
// создаются один раз в `bootstrap()` и удерживаются как `@State`, чтобы
// SwiftUI не пересоздавал их при каждом ре-рендере.

struct PuzzleRevealView: View {

    // MARK: - Inputs

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.exitGame) private var exitGame

    // MARK: - State

    @State private var display = PuzzleRevealDisplay()
    @State private var interactor: PuzzleRevealInteractor?
    @State private var presenter: PuzzleRevealPresenter?
    @State private var router: PuzzleRevealRouter?
    @State private var storeBridge: PuzzleRevealStoreBridge?
    @State private var bootstrapped = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "PuzzleRevealView")

    // MARK: - Body

    var body: some View {
        ZStack {
            KidGameCanvasBackground(palette: .kidWarm)
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
        .accessibilityLabel(String(localized: "Сложи пазл"))
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        switch display.phase {
        case .loading:
            loadingView
        case .ready, .recording, .evaluating, .tileReveal:
            playingView
        case .puzzleComplete:
            puzzleCompleteView
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
            Text(String(localized: "Готовим пазл…"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Playing

    private var playingView: some View {
        KidGameCanvasScaffold(
            title: Text(String(localized: "Сложи пазл")),
            subtitle: String(localized: "Пазл \(display.puzzleIndex + 1) из \(display.totalPuzzles)"),
            progress: display.progressFraction,
            palette: .kidWarm,
            onExit: { exitGame() }
        ) {
            puzzleCanvasContent
        } toolbar: {
            puzzleControls
        }
    }

    // MARK: Canvas content (внутри холста)

    private var puzzleCanvasContent: some View {
        VStack(spacing: SpacingTokens.small) {
            HStack(spacing: SpacingTokens.small) {
                Text(display.word)
                    .font(TypographyTokens.title(30))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel(String(localized: "Слово: \(display.word)"))
            }
            .frame(maxWidth: .infinity)

            Text(display.hintText)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)

            puzzleGrid

            feedbackLine

            Spacer(minLength: 0)

            HStack(alignment: .bottom) {
                KidGameMascotBubble(
                    message: display.lastFeedback.isEmpty
                        ? String(localized: "Скажи слово вслух!")
                        : display.lastFeedback,
                    state: display.lastScore >= 0.6 ? .celebrating : .explaining,
                    size: 48
                )
                Spacer(minLength: 0)
            }
        }
        .padding(SpacingTokens.small)
    }

    // MARK: Grid 3×3

    private var puzzleGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3),
            spacing: 4
        ) {
            ForEach(display.tiles) { tile in
                PuzzleTileView(
                    tile: tile,
                    emoji: display.emoji,
                    isRevealing: tile.index == display.revealingTileIndex,
                    reduceMotion: reduceMotion
                )
            }
        }
        .frame(maxWidth: 280)
        .accessibilityLabel(
            String(localized: "Открыто плиток: \(openedTiles) из \(PuzzleRevealInteractor.tileCount)")
        )
    }

    // MARK: Feedback

    @ViewBuilder
    private var feedbackLine: some View {
        if !display.lastFeedback.isEmpty {
            Text(display.lastFeedback)
                .font(TypographyTokens.headline(18))
                .foregroundStyle(feedbackColor)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.8)
                .accessibilityHidden(true)
        }
    }

    private var feedbackColor: Color {
        if display.lastScore >= 0.85 { return ColorTokens.Feedback.correct }
        if display.lastScore >= 0.6 { return ColorTokens.Brand.primary }
        return ColorTokens.Kid.inkMuted
    }

    // MARK: Controls (toolbar CTA)

    @ViewBuilder
    private var puzzleControls: some View {
        if display.isASRAvailable {
            asrControls
        } else {
            fallbackControls
        }
    }

    @ViewBuilder
    private var asrControls: some View {
        switch display.phase {
        case .ready, .tileReveal:
            KidGameCTAButton(
                title: String(localized: "Говори"),
                systemImage: "mic.fill"
            ) {
                container.hapticService.selection()
                interactor?.startRecord(.init())
            }
        case .recording:
            KidGameCTAButton(
                title: String(localized: "Стоп"),
                systemImage: "stop.fill"
            ) {
                container.hapticService.selection()
                interactor?.stopRecord(.init())
            }
        case .evaluating:
            KidGameCTAButton(
                title: String(localized: "Проверяем…"),
                isLoading: true
            ) { }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var fallbackControls: some View {
        switch display.phase {
        case .ready, .tileReveal:
            KidGameCTAButton(
                title: String(localized: "Я произнёс!"),
                systemImage: "checkmark"
            ) {
                container.hapticService.selection()
                // В fallback режиме считаем нажатие завершением «псевдо-записи».
                interactor?.startRecord(.init())
                interactor?.stopRecord(.init())
            }
        case .evaluating, .recording:
            KidGameCTAButton(
                title: String(localized: "Проверяем…"),
                isLoading: true
            ) { }
        default:
            EmptyView()
        }
    }

    // MARK: - Puzzle complete (после 9 плиток)

    private var puzzleCompleteView: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer()
            Image(systemName: "party.popper.fill")
                .font(.system(size: 72, weight: .regular))
                .foregroundStyle(ColorTokens.Brand.gold)
                .accessibilityHidden(true)
            Text(String(localized: "Пазл собран!"))
                .font(TypographyTokens.title(28))
                .foregroundStyle(ColorTokens.Kid.ink)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.8)
            HSContentSymbol(display.emoji, size: 120, tint: ColorTokens.Brand.primary)
                .scaleEffect(reduceMotion ? 1 : 1.0)
                .transition(.scale.combined(with: .opacity))
            Text(display.word)
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Brand.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            HSButton(
                nextPuzzleButtonTitle,
                style: .primary,
                icon: "arrow.right.circle.fill"
            ) {
                container.soundService.playUISound(.complete)
                container.hapticService.notification(.success)
                interactor?.nextPuzzle(.init())
            }
            .frame(maxWidth: 320)
            .padding(.bottom, SpacingTokens.large)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Пазл собран: \(display.word)"))
    }

    private var nextPuzzleButtonTitle: String {
        display.puzzleIndex + 1 < display.totalPuzzles
            ? String(localized: "Дальше")
            : String(localized: "Завершить")
    }

    // MARK: - Completed (финал сессии)

    private var completedView: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer()
            starsRow
            Text(display.scoreLabel)
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
                .monospacedDigit()
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.large)
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
            ) {
                finalize()
            }
            .frame(maxWidth: 320)
            .padding(.bottom, SpacingTokens.large)
            .accessibilityIdentifier("gameNextButton")
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Сессия завершена"))
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

    private func finalize() {
        guard display.pendingFinalScore == nil else { return }
        container.soundService.playUISound(.complete)
        container.hapticService.notification(.success)
        display.pendingFinalScore = display.finalScore
    }

    private var openedTiles: Int {
        display.tiles.filter { $0.isRevealed }.count
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let interactor = PuzzleRevealInteractor(container: container)
        let presenter = PuzzleRevealPresenter()
        let router = PuzzleRevealRouter()
        let store = PuzzleRevealStoreBridge(display: display)

        interactor.presenter = presenter
        interactor.router = router
        presenter.viewModel = store
        router.onDismiss = { [weak display] in
            guard let display else { return }
            if display.pendingFinalScore == nil {
                display.pendingFinalScore = display.finalScore
            }
        }

        self.interactor = interactor
        self.presenter = presenter
        self.router = router
        self.storeBridge = store

        interactor.loadPuzzle(.init(activity: activity, puzzleIndex: 0))
    }
}

// MARK: - PuzzleTileView (private)

private struct PuzzleTileView: View {

    let tile: PuzzleTile
    let emoji: String
    let isRevealing: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                .fill(backgroundFill)

            if tile.isRevealed {
                Text(emoji)
                    .font(TypographyTokens.display(40))
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "questionmark")
                    .font(TypographyTokens.title(22).weight(.heavy))
                    .foregroundStyle(ColorTokens.Overlay.onAccent.opacity(0.9))
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 90, height: 90)
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                .strokeBorder(borderColor, lineWidth: tile.isRevealed ? 2 : 1)
        )
        .scaleEffect(isRevealing && !reduceMotion ? 1.08 : 1.0)
        .rotation3DEffect(
            .degrees(tile.isRevealed ? 0 : 180),
            axis: (x: 0, y: 1, z: 0)
        )
        .animation(
            reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.75),
            value: tile.isRevealed
        )
        .animation(
            reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.6),
            value: isRevealing
        )
        .accessibilityLabel(
            tile.isRevealed
                ? String(localized: "Плитка открыта")
                : String(localized: "Плитка закрыта")
        )
    }

    private var backgroundFill: Color {
        tile.isRevealed
            ? ColorTokens.Kid.surface
            : ColorTokens.Brand.primary.opacity(0.85)
    }

    private var borderColor: Color {
        tile.isRevealed
            ? ColorTokens.Feedback.correct
            : ColorTokens.Brand.primaryHi
    }
}

// MARK: - PuzzleRevealStoreBridge
//
// Мостик между Presenter и @Observable Display. Преобразует ViewModel
// в поля на Display — SwiftUI автоматически реагирует.

@MainActor
final class PuzzleRevealStoreBridge: PuzzleRevealDisplayLogic {

    private let display: PuzzleRevealDisplay

    init(display: PuzzleRevealDisplay) {
        self.display = display
    }

    func displayLoadPuzzle(_ viewModel: PuzzleRevealModels.LoadPuzzle.ViewModel) {
        display.tiles = viewModel.tiles
        display.word = viewModel.word
        display.emoji = viewModel.emoji
        display.hintText = viewModel.hintText
        display.puzzleIndex = viewModel.puzzleIndex
        display.totalPuzzles = viewModel.totalPuzzles
        display.attemptNumber = viewModel.attemptNumber
        display.progressFraction = viewModel.progressFraction
        display.isASRAvailable = viewModel.isASRAvailable
        display.phase = .ready
        display.lastFeedback = ""
        display.lastScore = 0
        display.revealingTileIndex = nil
    }

    func displayStartRecord(_ viewModel: PuzzleRevealModels.StartRecord.ViewModel) {
        display.phase = .recording
    }

    func displayStopRecord(_ viewModel: PuzzleRevealModels.StopRecord.ViewModel) {
        display.phase = .evaluating
    }

    func displayRevealTile(_ viewModel: PuzzleRevealModels.RevealTile.ViewModel) {
        display.tiles = viewModel.tiles
        display.revealingTileIndex = viewModel.tileIndex
        display.lastFeedback = viewModel.feedbackText
        display.lastScore = viewModel.lastScore
        display.progressFraction = viewModel.progressFraction
        display.attemptNumber = viewModel.attemptNumber
        display.phase = viewModel.allRevealed ? .puzzleComplete : .tileReveal
    }

    func displayNextPuzzle(_ viewModel: PuzzleRevealModels.NextPuzzle.ViewModel) {
        if viewModel.hasNext {
            // загрузка следующего пазла придёт отдельным displayLoadPuzzle
            display.phase = .loading
        }
    }

    func displayComplete(_ viewModel: PuzzleRevealModels.Complete.ViewModel) {
        display.finalScore = viewModel.finalScore
        display.starsEarned = viewModel.starsEarned
        display.scoreLabel = viewModel.scoreLabel
        display.completionMessage = viewModel.completionMessage
        display.phase = .completed
    }
}

// MARK: - Preview

#Preview("Playing") {
    PuzzleRevealView(
        activity: SessionActivity(
            id: "preview",
            gameType: .puzzleReveal,
            lessonId: "l1",
            soundTarget: "Р",
            difficulty: 1,
            isCompleted: false,
            score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
