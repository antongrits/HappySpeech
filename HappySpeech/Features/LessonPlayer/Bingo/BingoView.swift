import OSLog
import SwiftUI

// MARK: - BingoView
//
// «Бинго со звуком», 5×5. Маскот зачитывает слова (TTS ru-RU); ребёнок ищет
// каждое на своей карточке и нажимает. Цель — собрать пять в ряд (горизонталь,
// вертикаль или диагональ). Звёзды в финале начисляются по hit-rate с бонусом
// за факт «бинго».
//
// Архитектура: Clean Swift VIP. Все три участника создаются один раз в
// `bootstrap()` и удерживаются как `@State` — иначе SwiftUI пересоздаст их
// при каждом ре-рендере, и состояние игры рассыплется.

struct BingoView: View {

    // MARK: - Inputs

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State

    @State private var display = BingoViewDisplay()
    @State private var interactor: BingoInteractor?
    @State private var presenter: BingoPresenter?
    @State private var router: BingoRouter?
    @State private var bootstrapped = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "BingoView")

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            content

            if display.phase == .bingo {
                bingoOverlay
            }
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
        .accessibilityLabel(String(localized: "bingo.accessibility.label"))
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        switch display.phase {
        case .loading:
            loadingView
        case .playing, .bingo:
            playingView
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
            Text(String(localized: "bingo.status.preparing"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Playing

    private var playingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            lyalyaHeader
            calledWordBanner
            progressBar
            // Spectrogram — toggle через Settings → Display → Показать спектрограмму.
            // По умолчанию показывается только во время озвучивания слова Лялей.
            // Reduce Motion: StaticSpectrogramView (один фрейм, без анимации).
            if display.isCalling {
                SpectrogramVisualizerView(
                    referenceSpectrogram: nil,
                    style: .neutral
                )
                .frame(maxWidth: .infinity)
                .frame(height: 90)
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                .accessibilityLabel(
                    String(localized: "spectrogram.bingo.a11y", defaultValue: "Звук называемого слова")
                )
            }
            grid
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.large)
        .padding(.bottom, SpacingTokens.medium)
    }

    private var lyalyaHeader: some View {
        LyalyaMascotView(state: display.isCalling ? .explaining : .idle, size: 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)
    }

    // MARK: Banner

    private var calledWordBanner: some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: "speaker.wave.2.fill")
                .font(TypographyTokens.headline(22))
                .foregroundStyle(ColorTokens.Brand.primary)
                .scaleEffect(display.isCalling && !reduceMotion ? 1.12 : 1.0)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.45).repeatForever(autoreverses: true),
                    value: display.isCalling
                )
                .accessibilityHidden(true)

            Text(display.calledWord.isEmpty
                 ? String(localized: "bingo.hint.listen_carefully")
                 : display.calledWord)
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityLabel(
                    display.calledWord.isEmpty
                        ? String(localized: "bingo.hint.listen")
                        : String(
                            format: NSLocalizedString("bingo.status.word_called %@", comment: ""),
                            display.calledWord
                        )
                )

            Spacer()

            Button {
                interactor?.callNextWord()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .padding(.horizontal, SpacingTokens.small)
                    .padding(.vertical, SpacingTokens.tiny)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "bingo.accessibility.next_word"))
        }
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.vertical, SpacingTokens.small)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
        .opacity(display.isCalling || display.calledWord.isEmpty ? 1 : 0.85)
    }

    // MARK: Progress

    private var progressBar: some View {
        HStack(spacing: SpacingTokens.small) {
            HSProgressBar(value: display.progressFraction)
                .frame(height: 8)
                .accessibilityLabel(
                    String(
                        format: NSLocalizedString("bingo.accessibility.read_progress %lld %lld", comment: ""),
                        display.calledWordIndex,
                        display.totalWords
                    )
                )
            Text("\(display.calledWordIndex)/\(display.totalWords)")
                .font(TypographyTokens.mono(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .monospacedDigit()
                .accessibilityHidden(true)
        }
    }

    // MARK: Grid 5×5

    private var grid: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: SpacingTokens.tiny),
            count: BingoLineCatalog.side
        )
        return LazyVGrid(columns: columns, spacing: SpacingTokens.tiny) {
            ForEach(display.cells) { cell in
                BingoCellView(cell: cell, reduceMotion: reduceMotion) {
                    handleTap(cell: cell)
                }
                .disabled(display.phase != .playing || cell.isMarked)
            }
        }
    }

    // MARK: - Bingo overlay

    private var bingoOverlay: some View {
        ZStack {
            ColorTokens.Overlay.dimmerHeavy.ignoresSafeArea()
            HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.large) {
                VStack(spacing: SpacingTokens.medium) {
                    LyalyaMascotView(state: .celebrating, size: 80)
                        .accessibilityHidden(true)
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 64, weight: .regular))
                        .foregroundStyle(ColorTokens.Brand.gold)
                        .accessibilityHidden(true)
                    Text(String(localized: "bingo.celebration.bingo"))
                        .font(TypographyTokens.display(40))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(String(localized: "bingo.celebration.five_in_row"))
                        .font(TypographyTokens.body(17))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, SpacingTokens.xLarge)
                    HSButton(
                        String(localized: "bingo.action.finish"),
                        style: .primary,
                        icon: "checkmark.circle.fill"
                    ) {
                        interactor?.completeGame()
                    }
                    .frame(maxWidth: 320)
                }
            }
            .padding(.horizontal, SpacingTokens.large)
        }
        .transition(.opacity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "bingo.accessibility.bingo_win"))
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
                String(localized: "bingo.action.finish"),
                style: .primary,
                icon: "checkmark.circle.fill"
            ) {
                finalize()
            }
            .frame(maxWidth: 320)
            .padding(.bottom, SpacingTokens.large)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "bingo.accessibility.game_over"))
    }

    private var starsRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(0..<3, id: \.self) { idx in
                Image(systemName: idx < display.starsEarned ? "star.fill" : "star")
                    .font(TypographyTokens.kidDisplay(44))
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
            String(
                format: NSLocalizedString("bingo.summary.stars_earned %lld", comment: ""),
                display.starsEarned
            )
        )
    }

    // MARK: - Actions

    private func handleTap(cell: BingoCell) {
        guard display.phase == .playing else { return }
        guard !cell.isMarked else { return }
        container.soundService.playUISound(.tap)
        container.hapticService.selection()
        interactor?.markCell(.init(cellId: cell.id))
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

        let interactor = BingoInteractor()
        let presenter = BingoPresenter()
        let router = BingoRouter()

        interactor.presenter = presenter
        interactor.router = router
        presenter.display = display
        router.onDismiss = { [weak display] in
            // Запасной канал dismiss — если кто-то вызовет router.routeBack()
            // в обход finalize(), мы всё равно поднимем pendingFinalScore.
            guard let display else { return }
            if display.pendingFinalScore == nil {
                display.pendingFinalScore = display.lastScore
            }
        }

        self.interactor = interactor
        self.presenter = presenter
        self.router = router

        interactor.loadGame(.init(activity: activity))
    }
}

// MARK: - BingoCellView

/// Одна клетка 5×5 — стилизуется по состоянию (marked / winner / idle).
private struct BingoCellView: View {

    let cell: BingoCell
    let reduceMotion: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                    .fill(backgroundFill)

                if cell.isMarked {
                    VStack(spacing: 2) {
                        Image(systemName: "checkmark")
                            .font(TypographyTokens.caption(14))
                            .foregroundStyle(ColorTokens.Overlay.onAccent)
                            .accessibilityHidden(true)
                        Text(cell.word)
                            .font(TypographyTokens.body(11))
                            .foregroundStyle(ColorTokens.Overlay.onAccent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .strikethrough(!cell.isWinner, color: ColorTokens.Overlay.onAccent.opacity(0.7))
                    }
                    .padding(.horizontal, 4)
                } else {
                    Text(cell.word)
                        .font(TypographyTokens.body(12))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.55)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: cell.isWinner ? 3 : 1)
            )
            .scaleEffect(cell.isWinner && !reduceMotion ? 1.04 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7),
                value: cell.isMarked
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(cell.word)
        .accessibilityValue(
            cell.isWinner
                ? String(localized: "bingo.accessibility.winning_line_cell")
                : (cell.isMarked
                    ? String(localized: "bingo.accessibility.marked")
                    : String(localized: "bingo.accessibility.unmarked"))
        )
        .accessibilityAddTraits(cell.isMarked ? [] : .isButton)
    }

    private var backgroundFill: Color {
        if cell.isWinner {
            return ColorTokens.Feedback.correct
        } else if cell.isMarked {
            return ColorTokens.Brand.sky
        } else {
            return ColorTokens.Kid.surface
        }
    }

    private var borderColor: Color {
        if cell.isWinner {
            return ColorTokens.Feedback.correct
        } else if cell.isMarked {
            return ColorTokens.Brand.sky
        } else {
            return ColorTokens.Kid.line
        }
    }
}

// MARK: - Preview

#Preview("Playing") {
    BingoView(
        activity: SessionActivity(
            id: "preview",
            gameType: .bingo,
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
