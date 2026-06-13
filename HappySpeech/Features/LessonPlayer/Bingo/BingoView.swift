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
            HSMeshGradientBackground(palette: .kidWarm)
                .ignoresSafeArea()
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
            VStack(spacing: SpacingTokens.medium) {
                lyalyaHeader
                calledWordBanner
                progressBar
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            // Redesign v34 (3.17): сетка переведена с 5 колонок на 3, ячейка
            // 108×135pt, иллюстрация 72pt, подпись Bold 15pt. Гориз. отступ
            // — 20pt по краям, gap между ячейками 11pt (см. спеку §2.5).
            // Бизнес-логика бинго 5×5 не меняется: индексы линий по-прежнему
            // считаются по `BingoLineCatalog.side` (5).
            ScrollView(showsIndicators: false) {
                grid
                    .padding(.horizontal, BingoGridMetrics.horizontalPadding)
                    .padding(.bottom, SpacingTokens.medium)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.top, SpacingTokens.large)
        .padding(.bottom, SpacingTokens.medium)
        .safeAreaPadding(.bottom, SpacingTokens.tiny)
    }

    private var lyalyaHeader: some View {
        HStack(alignment: .center, spacing: SpacingTokens.tiny) {
            LyalyaMascotView(state: display.isCalling ? .explaining : .happy, size: 56)
                .accessibilityHidden(true)
            HSSpeechBubble(
                bingoCheer,
                direction: .left,
                style: .lyalya,
                maxWidth: 220
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
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
            .accessibilityIdentifier("bingoNextWordButton")
            .accessibilityLabel(String(localized: "bingo.accessibility.next_word"))
        }
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.vertical, SpacingTokens.small)
        .background(
            // D-29 v27 — callout озвучки получает консистентный «материал»:
            // hairline-бордер + мягкая тень, как у HSCard(.elevated) —
            // карточка явно приподнята над акцентным фоном урока.
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .strokeBorder(ColorTokens.Overlay.highlight, lineWidth: 0.5)
        )
        .kidCardShadow()
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

    // MARK: Grid (3-column visual, 5×5 logical)

    private var grid: some View {
        // Redesign v34 (3.17): фиксированная ширина ячейки (108pt) и gap 11pt
        // обеспечивают: 20 + 3×108 + 2×11 + 20 = 386pt → запас ≥7pt на iPhone 17 Pro
        // ширине 393pt. Меньше колонок = крупнее иллюстрация (72pt) и читаемая
        // подпись (15pt Bold) для детей 5–8 лет.
        let columns = Array(
            repeating: GridItem(.fixed(BingoGridMetrics.cellWidth), spacing: BingoGridMetrics.cellGap),
            count: BingoGridMetrics.visualColumns
        )
        return LazyVGrid(columns: columns, spacing: BingoGridMetrics.cellGap) {
            ForEach(Array(display.cells.enumerated()), id: \.element.id) { index, cell in
                BingoCellView(
                    cell: cell,
                    index: index,
                    reduceMotion: reduceMotion
                ) {
                    handleTap(cell: cell)
                }
                .disabled(display.phase != .playing || cell.isMarked)
                .accessibilityIdentifier("bingoCell_\(index)")
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
                    .accessibilityIdentifier("gameNextButton")
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
            .accessibilityIdentifier("gameNextButton")
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

    // MARK: - Computed helpers

    /// Короткая реплика маскота над сеткой.
    private var bingoCheer: String {
        display.isCalling
            ? String(localized: "Слушай слово!")
            : String(localized: "Найди слово!")
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

// MARK: - BingoGridMetrics
//
// Redesign v34 (3.17): фиксированные размеры визуальной сетки.
// Расчёт: 20 + 3×108 + 2×11 + 20 = 386pt → 7pt запас на iPhone 17 Pro (393pt).
// Бизнес-логика бинго 5×5 остаётся в `BingoLineCatalog` (25 ячеек, 12 линий).

private enum BingoGridMetrics {
    static let visualColumns: Int = 3
    static let cellWidth: CGFloat = 108
    static let cellHeight: CGFloat = 135
    static let cellGap: CGFloat = 11
    static let horizontalPadding: CGFloat = 20
    static let illustrationSize: CGFloat = 72
    static let wordFontSize: CGFloat = 15
    static let staggerDelay: Double = 0.030  // 30ms между ячейками
}

// MARK: - BingoCellView

/// Одна клетка 108×135pt — три визуальных состояния:
/// `normal` (ждёт нажатия), `found` (отмечена правильно, `isMarked`),
/// `winner` (входит в выигрышную линию 5-в-ряд по 5×5 логической сетке).
/// Состояний `selected`/`missed`/`locked` бинго не имеет — нажатие =
/// мгновенная отметка.
private struct BingoCellView: View {

    let cell: BingoCell
    let index: Int
    let reduceMotion: Bool
    let onTap: () -> Void

    @State private var didAppear: Bool = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: SpacingTokens.micro) {
                Spacer(minLength: 8)
                illustration
                Text(cell.word)
                    .font(.system(size: BingoGridMetrics.wordFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 6)
            }
            .frame(width: BingoGridMetrics.cellWidth, height: BingoGridMetrics.cellHeight)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .overlay(alignment: .topTrailing) {
                if cell.isMarked {
                    // Маленький mint-tick — единственное «зелёное» пятно
                    // (семантика «найдено»), не крупная заливка.
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(ColorTokens.Semantic.success))
                        .shadow(color: ColorTokens.Semantic.success.opacity(0.45), radius: 3, y: 1)
                        .padding(7)
                        .accessibilityHidden(true)
                }
            }
            .scaleEffect(scaleEffect)
            .opacity(didAppear ? 1.0 : 0.0)
            .animation(
                reduceMotion ? .easeOut(duration: 0.15) : MotionTokens.rewardPop,
                value: cell.isMarked
            )
            .animation(
                reduceMotion ? .easeOut(duration: 0.15) : MotionTokens.playful,
                value: cell.isWinner
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            // Stagger ~30ms на каждую ячейку — поэтапное появление сетки.
            let delay = reduceMotion ? 0.0 : Double(index) * BingoGridMetrics.staggerDelay
            withAnimation(
                reduceMotion
                    ? .easeOut(duration: 0.2)
                    : MotionTokens.playful.delay(delay)
            ) {
                didAppear = true
            }
        }
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(cell.isMarked ? [] : .isButton)
    }

    // MARK: Subviews

    private var illustration: some View {
        HSContentSymbol(
            ListenAndChoosePresenter.imageSymbol(for: cell.word),
            size: BingoGridMetrics.illustrationSize,
            tint: ColorTokens.Brand.primary
        )
        .frame(width: BingoGridMetrics.illustrationSize, height: BingoGridMetrics.illustrationSize)
        .accessibilityHidden(true)
    }

    // MARK: Styling

    private var backgroundFill: Color {
        // Тёплые заливки в палитре приложения; «найдено»/«выигрыш» —
        // мягкий коралловый тинт (не зелёная заливка). Семантика
        // совпадения передаётся mint-tick'ом и рамкой.
        if cell.isWinner {
            return ColorTokens.Brand.primaryLo.opacity(0.55)
        } else if cell.isMarked {
            return ColorTokens.Brand.primaryLo.opacity(0.30)
        } else {
            return ColorTokens.Kid.surface
        }
    }

    private var borderColor: Color {
        if cell.isWinner {
            return ColorTokens.Brand.primary
        } else if cell.isMarked {
            return ColorTokens.Semantic.success
        } else {
            return ColorTokens.Kid.line
        }
    }

    private var borderWidth: CGFloat {
        cell.isWinner ? 3 : (cell.isMarked ? 2 : 1)
    }

    private var textColor: Color {
        cell.isWinner ? ColorTokens.Brand.primary : ColorTokens.Kid.ink
    }

    private var scaleEffect: CGFloat {
        guard !reduceMotion else { return 1.0 }
        if cell.isWinner { return 1.06 }
        if cell.isMarked { return 1.02 }
        return 1.0
    }

    private var accessibilityText: String {
        if cell.isWinner {
            return "\(cell.word), \(String(localized: "bingo.accessibility.winning_line_cell"))"
        } else if cell.isMarked {
            return "\(cell.word), \(String(localized: "bingo.accessibility.marked"))"
        } else {
            return cell.word
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
