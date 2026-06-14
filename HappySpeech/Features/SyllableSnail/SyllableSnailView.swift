import OSLog
import SwiftUI

// MARK: - SyllableSnailViewModelHolder

@MainActor
@Observable
final class SyllableSnailViewModelHolder: SyllableSnailDisplayLogic {

    var startVM: SyllableSnailModels.Start.ViewModel?
    var currentRound: SyllableSnailModels.Start.RoundViewModel?

    // Светофор / реплика.
    var lastFeedback: FeedbackTier?
    var lastLyalyaLine: String?

    // Режим A: счётчик хлопков.
    var tapCount: Int = 0

    // Режимы B/C: банк и слоты.
    var bankTiles: [SyllableSnailModels.Start.TileViewModel] = []
    var slotTiles: [SyllableSnailModels.Start.TileViewModel] = []
    /// Индекс слота-подсказки (первый неверный) — для статичной обводки.
    var hintSlotIndex: Int?

    // Анимация «улитка дошла до домика».
    var snailReachedHome: Bool = false

    var summary: SyllableSnailModels.SummaryViewModel?
    var isFinished: Bool = false
    var showCelebration: Bool = false
    /// Счётчик попыток в текущем раунде (для номера попытки в Request).
    var attemptInRound: Int = 0

    func displayStart(viewModel: SyllableSnailModels.Start.ViewModel) async {
        self.startVM = viewModel
        applyRound(viewModel.firstRound)
        self.isFinished = false
        self.summary = nil
        self.showCelebration = false
        self.lastFeedback = nil
        self.lastLyalyaLine = nil
    }

    func displayTap(viewModel: SyllableSnailModels.Tap.ViewModel) async {
        self.lastFeedback = viewModel.feedback
        self.lastLyalyaLine = viewModel.lyalyaLine
        self.snailReachedHome = viewModel.snailReachedHome
        finish(isFinished: viewModel.isFinished, summary: viewModel.summary)
        advanceIfNeeded(viewModel.nextRound)
    }

    func displaySubmit(viewModel: SyllableSnailModels.Submit.ViewModel) async {
        self.lastFeedback = viewModel.feedback
        self.lastLyalyaLine = viewModel.lyalyaLine
        self.snailReachedHome = viewModel.snailReachedHome
        self.hintSlotIndex = viewModel.showHint ? viewModel.firstWrongSlotIndex : nil
        finish(isFinished: viewModel.isFinished, summary: viewModel.summary)
        advanceIfNeeded(viewModel.nextRound)
    }

    func displayFix(viewModel: SyllableSnailModels.Fix.ViewModel) async {
        self.lastFeedback = viewModel.feedback
        self.lastLyalyaLine = viewModel.lyalyaLine
        self.snailReachedHome = viewModel.snailReachedHome
        self.hintSlotIndex = viewModel.showHint ? viewModel.firstWrongSlotIndex : nil
        finish(isFinished: viewModel.isFinished, summary: viewModel.summary)
        advanceIfNeeded(viewModel.nextRound)
    }

    // MARK: Local helpers

    private func finish(isFinished: Bool, summary: SyllableSnailModels.SummaryViewModel?) {
        self.isFinished = isFinished
        self.summary = summary
        self.showCelebration = summary?.showCelebration ?? false
    }

    private func advanceIfNeeded(_ next: SyllableSnailModels.Start.RoundViewModel?) {
        guard let next else { return }
        applyRound(next)
        self.lastFeedback = nil
        self.lastLyalyaLine = nil
    }

    private func applyRound(_ round: SyllableSnailModels.Start.RoundViewModel) {
        self.currentRound = round
        self.tapCount = 0
        self.bankTiles = round.tiles
        self.slotTiles = []
        self.hintSlotIndex = nil
        self.snailReachedHome = false
        self.attemptInRound = 0
    }
}

// MARK: - SyllableSnailView (Clean Swift: View)
//
// F2-003 «Слоговая улитка» (Wave 2).
//
// Детская игра слоговой структуры. Улитка ползёт по «тропинке слогов» к домику.
// Три режима поверх единого экрана:
//   • A «прохлопай» — крупная зона-хлопок; число тапов ≈ число слогов;
//   • B «выложи»    — банк перемешанных слогов → слоты тропинки;
//   • C «почини»    — преднабор перестановки → переставить в правильный порядок.
//
// Accessibility:
//   • Kid circuit: плитки/кнопка-хлопок/слоты ≥ 56pt.
//   • VoiceOver: слог-плитка «слог ма»; слот «домик 1, пустой»; кнопка хлопка.
//   • Dynamic Type: тексты с minimumScaleFactor(0.85) + lineLimit(nil).
//   • Reduced Motion: ползание/прыжки → дискретно без spring; подсказка слота →
//     статичная обводка; confetti → static.
//   • Light + Dark: ColorTokens.Kid + Brand адаптируются.
//   • Без таймера by design (антифатиговое правило / заикание).

struct SyllableSnailView: View {

    let childId: String
    let preferredMode: SnailMode?
    let preferredTier: SyllableTier?

    @State private var holder = SyllableSnailViewModelHolder()
    @State private var interactor: SyllableSnailInteractor?
    @State private var presenter: SyllableSnailPresenter?
    @State private var router: SyllableSnailRouter?

    @Environment(\.exitGame) private var exitGame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppContainer.self) private var container

    init(
        childId: String,
        preferredMode: SnailMode? = nil,
        preferredTier: SyllableTier? = nil
    ) {
        self.childId = childId
        self.preferredMode = preferredMode
        self.preferredTier = preferredTier
    }

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SyllableSnail.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // kidWarm mesh (тёплый игровой вайб). Reduced Motion: убираем
                // анимированный/блендовый фон для детерминизма снимков.
                if !reduceMotion {
                    HSMeshGradientBackground(palette: .kidWarm, animated: true)
                        .ignoresSafeArea()
                        .opacity(colorScheme == .dark ? 0.18 : 0.28)
                        .blendMode(.softLight)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                if holder.isFinished, let summary = holder.summary {
                    summarySection(summary)
                } else if let round = holder.currentRound {
                    gameSection(round: round)
                } else {
                    loadingSection
                }

                if holder.showCelebration {
                    HSConfettiView(preset: .celebration, isActive: $holder.showCelebration)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .navigationTitle(Text("syllableSnail.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exitGame()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("syllableSnail.close.a11y"))
                }
            }
            .task {
                await setupAndStart()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Game

    private func gameSection(
        round: SyllableSnailModels.Start.RoundViewModel
    ) -> some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.sp4) {
                    progressHeader(round)

                    HSSpeechBubble(
                        holder.lastLyalyaLine ?? round.promptLyalya,
                        direction: .left,
                        style: holder.lastFeedback == nil ? .question : bubbleStyle(holder.lastFeedback)
                    )
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .id("bubble-\(round.id)-\(holder.lastFeedback?.rawValue ?? "q")")
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))

                    wordCard(round: round)
                        .id(round.id)
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))

                    replayButton(round: round)

                    // Тропинка-улитка (общий визуальный мотив всех режимов).
                    // Spacer'ы убраны: на SE 375pt они раздували вертикаль и
                    // уводили кнопки действия («Убрать один хлопок»/«Проверить»)
                    // под сгиб. Фиксированный отступ держит действия на виду.
                    snailPath(round: round)
                        .padding(.horizontal, SpacingTokens.screenEdge)
                        .padding(.vertical, SpacingTokens.sp2)

                    // Подвью по режиму.
                    modeSection(round: round)
                        .padding(.horizontal, SpacingTokens.screenEdge)
                }
                .frame(minHeight: geo.size.height, alignment: .top)
                .padding(.top, SpacingTokens.sp2)
                .padding(.bottom, SpacingTokens.sp6)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaPadding(.bottom, SpacingTokens.small)
            .animation(reduceMotion ? nil : .spring(duration: 0.35), value: round.id)
        }
    }

    private func progressHeader(
        _ round: SyllableSnailModels.Start.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            HStack {
                Text(holder.startVM?.modeLabel ?? "")
                    .font(TypographyTokens.caption(12).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                Spacer()
                Text(round.progressLabel)
                    .font(TypographyTokens.caption(12).monospacedDigit())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.Kid.surfaceAlt)
                    Capsule()
                        .fill(ColorTokens.Brand.primary)
                        .frame(width: max(0, geo.size.width * round.progressFraction))
                }
            }
            .frame(height: 10)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.sp4)
    }

    private func wordCard(
        round: SyllableSnailModels.Start.RoundViewModel
    ) -> some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp5) {
            VStack(spacing: SpacingTokens.sp3) {
                HSContentSymbol(round.imageAsset, size: 88, tint: ColorTokens.Brand.primary)
                Text(round.wordText)
                    .font(TypographyTokens.title(30))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(round.accessibilityLabel))
    }

    private func replayButton(
        round: SyllableSnailModels.Start.RoundViewModel
    ) -> some View {
        Button {
            Task { await replaySyllables(round: round) }
        } label: {
            Label {
                Text("syllableSnail.replay")
                    .font(TypographyTokens.body(15).weight(.medium))
            } icon: {
                Image(systemName: "speaker.wave.2.fill")
            }
            .foregroundStyle(ColorTokens.Brand.primary)
            .padding(.horizontal, SpacingTokens.sp4)
            .frame(minHeight: 44)
            .background(Capsule().fill(ColorTokens.Kid.surface))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("syllableSnail.replay.a11y"))
    }

    // MARK: - Snail path

    /// Тропинка из «домиков»-слогов; улитка стоит в начале и доходит до домика
    /// при попадании. Чисто визуальный мотив (a11y скрыт — статусы озвучивают
    /// слоты/счётчик режима).
    private func snailPath(
        round: SyllableSnailModels.Start.RoundViewModel
    ) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: "tortoise.fill")
                .font(.title2)
                .foregroundStyle(ColorTokens.Brand.mint)
                .scaleEffect(reduceMotion ? 1 : (holder.snailReachedHome ? 1.15 : 1))
                .accessibilityHidden(true)

            ForEach(0..<max(1, round.pathSlotsCount), id: \.self) { _ in
                Image(systemName: "house.fill")
                    .font(.body)
                    .foregroundStyle(
                        holder.snailReachedHome
                            ? ColorTokens.Brand.gold
                            : ColorTokens.Kid.inkMuted.opacity(0.5)
                    )
            }

            Image(systemName: "flag.fill")
                .font(.body)
                .foregroundStyle(holder.snailReachedHome ? ColorTokens.Brand.gold : ColorTokens.Kid.inkMuted)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp2)
        .accessibilityHidden(true)
    }

    // MARK: - Mode sections

    @ViewBuilder
    private func modeSection(
        round: SyllableSnailModels.Start.RoundViewModel
    ) -> some View {
        switch round.mode {
        case .clap:
            clapSection(round: round)
        case .build, .fix:
            assembleSection(round: round)
        }
    }

    // Режим A — крупная зона-хлопок + счётчик.
    private func clapSection(
        round: SyllableSnailModels.Start.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp3) {
            Text(String(format: String(localized: "syllableSnail.clap.count"), holder.tapCount))
                .font(TypographyTokens.headline(20).monospacedDigit())
                .foregroundStyle(ColorTokens.Brand.primary)
                .accessibilityLabel(Text(
                    String(format: String(localized: "syllableSnail.clap.count.a11y"), holder.tapCount)
                ))

            Button {
                holder.tapCount += 1
                container.hapticService.impact(.medium)
            } label: {
                VStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                    Text("syllableSnail.clap.button")
                        .font(TypographyTokens.headline(18))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, minHeight: 96)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Brand.primary)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("syllableSnail.clap.button.a11y"))
            .accessibilityHint(Text("syllableSnail.clap.button.hint"))

            HStack(spacing: SpacingTokens.sp3) {
                Button {
                    holder.tapCount = max(0, holder.tapCount - 1)
                } label: {
                    Text("syllableSnail.clap.undo")
                        .font(TypographyTokens.body(15).weight(.medium))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Kid.surface)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("syllableSnail.clap.undo.a11y"))

                Button {
                    Task { await submitTap() }
                } label: {
                    Text("syllableSnail.clap.done")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(holder.tapCount > 0 ? ColorTokens.Brand.gold : ColorTokens.Kid.surfaceAlt)
                        )
                }
                .buttonStyle(.plain)
                .disabled(holder.tapCount == 0)
                .accessibilityLabel(Text("syllableSnail.clap.done.a11y"))
            }
        }
    }

    // Режим B/C — слоты тропинки + банк слогов.
    private func assembleSection(
        round: SyllableSnailModels.Start.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp3) {
            // Слоты (домики тропинки).
            KidSectionLabel(String(localized: "syllableSnail.section.path"))
            HStack(spacing: SpacingTokens.sp2) {
                ForEach(0..<round.pathSlotsCount, id: \.self) { index in
                    slotView(index: index)
                }
            }

            // Банк перемешанных слогов.
            KidSectionLabel(String(localized: "syllableSnail.section.syllables"))
            KidTrayContainer {
                HStack(spacing: SpacingTokens.sp2) {
                    ForEach(holder.bankTiles) { tile in
                        tileView(tile, inBank: true)
                    }
                }
                .frame(minHeight: 60)
            }

            Button {
                Task { await submitAssembled(round: round) }
            } label: {
                Text("syllableSnail.assemble.check")
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(holder.slotTiles.count == round.pathSlotsCount
                                  ? ColorTokens.Brand.primary
                                  : ColorTokens.Kid.surfaceAlt)
                    )
            }
            .buttonStyle(.plain)
            .disabled(holder.slotTiles.count != round.pathSlotsCount)
            .accessibilityLabel(Text("syllableSnail.assemble.check.a11y"))
        }
    }

    private func slotView(index: Int) -> some View {
        let tile = index < holder.slotTiles.count ? holder.slotTiles[index] : nil
        let isHint = holder.hintSlotIndex == index
        return Button {
            if tile != nil { returnTileFromSlot(at: index) }
        } label: {
            Group {
                if let tile {
                    Text(tile.text)
                        .font(TypographyTokens.headline(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } else {
                    Image(systemName: "house")
                        .font(.title3)
                        .foregroundStyle(ColorTokens.Kid.inkMuted.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .fill(tile == nil ? ColorTokens.Kid.surfaceAlt : ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .strokeBorder(
                        slotStroke(tile: tile, isHint: isHint, isActive: index == holder.slotTiles.count),
                        style: StrokeStyle(
                            lineWidth: (isHint || tile == nil) ? 2 : 0,
                            dash: tile == nil ? [6, 4] : []
                        )
                    )
            )
            .overlay(alignment: .top) {
                KidSlotOrderBadge(order: index + 1).offset(y: -9)
            }
            .overlay(alignment: .topTrailing) {
                if tile != nil, holder.lastFeedback == .hit {
                    KidCorrectTick().scaleEffect(0.7).offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(
            tile == nil
                ? String(format: String(localized: "syllableSnail.slot.empty.a11y"), index + 1)
                : String(format: String(localized: "syllableSnail.slot.filled.a11y"), index + 1, tile?.text ?? "")
        ))
    }

    private func tileView(
        _ tile: SyllableSnailModels.Start.TileViewModel,
        inBank: Bool
    ) -> some View {
        Button {
            addTileToSlot(tile)
        } label: {
            Text(tile.text)
                .font(TypographyTokens.headline(20))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, SpacingTokens.sp3)
                .frame(minWidth: 56, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Brand.lilac.opacity(0.25))
                )
                .depthShadow(ShadowTokens.kidDepth)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(tile.accessibilityLabel))
        .accessibilityHint(Text("syllableSnail.tile.hint"))
    }

    // MARK: - Summary

    private func summarySection(
        _ summary: SyllableSnailModels.SummaryViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            // Верхний отступ меньше нижнего распорки — контент сидит в верхней
            // трети, без большой пустоты над иконкой. Улитка «дошла до домика»
            // как визуальный итог пути заполняет середину.
            Spacer(minLength: SpacingTokens.sp4)

            Image(systemName: summary.accuracyFraction >= 0.8
                ? "tortoise.circle.fill"
                : "hand.thumbsup.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(ColorTokens.Brand.gold)
                .hsSymbolEffect(.bounce, value: summary.scoreText)
                .accessibilityHidden(true)

            Text(summary.title)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.8)

            Text(summary.scoreText)
                .font(TypographyTokens.headline(20).monospacedDigit())
                .foregroundStyle(ColorTokens.Brand.primary)

            Text(summary.encouragement)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, SpacingTokens.sp6)

            // «Улитка дошла до домика» — итоговый визуальный мотив пути.
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "tortoise.fill")
                    .font(.title2)
                    .foregroundStyle(ColorTokens.Brand.mint)
                ForEach(0..<3, id: \.self) { _ in
                    Image(systemName: "house.fill")
                        .font(.body)
                        .foregroundStyle(ColorTokens.Brand.gold)
                }
                Image(systemName: "flag.fill")
                    .font(.body)
                    .foregroundStyle(ColorTokens.Brand.gold)
            }
            .padding(.top, SpacingTokens.sp2)
            .accessibilityHidden(true)

            Spacer()

            VStack(spacing: SpacingTokens.sp3) {
                Button {
                    Task { await setupAndStart(forceRestart: true) }
                } label: {
                    Text("syllableSnail.summary.again")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("syllableSnail.summary.again.hint"))

                Button {
                    exitGame()
                } label: {
                    Text("syllableSnail.summary.done")
                        .font(TypographyTokens.body(16).weight(.medium))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp6)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("syllableSnail.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Styling

    private func bubbleStyle(_ feedback: FeedbackTier?) -> HSSpeechBubble.BubbleStyle {
        switch feedback {
        case .hit:    return .lyalya
        case .retry:  return .hint
        case .almost, .none: return .question
        }
    }

    private func slotStroke(
        tile: SyllableSnailModels.Start.TileViewModel?,
        isHint: Bool,
        isActive: Bool
    ) -> Color {
        if isHint { return ColorTokens.Brand.butter }
        guard tile == nil else { return .clear }
        return isActive
            ? ColorTokens.Brand.primary
            : ColorTokens.Brand.primary.opacity(0.45)
    }

    // MARK: - Local tile manipulation (B/C)

    private func addTileToSlot(_ tile: SyllableSnailModels.Start.TileViewModel) {
        guard let round = holder.currentRound,
              holder.slotTiles.count < round.pathSlotsCount,
              let bankIndex = holder.bankTiles.firstIndex(of: tile) else { return }
        holder.bankTiles.remove(at: bankIndex)
        holder.slotTiles.append(tile)
        holder.hintSlotIndex = nil
        container.hapticService.selection()
    }

    private func returnTileFromSlot(at index: Int) {
        guard index < holder.slotTiles.count else { return }
        let tile = holder.slotTiles.remove(at: index)
        holder.bankTiles.append(tile)
        holder.hintSlotIndex = nil
        container.hapticService.selection()
    }

    // MARK: - Wiring

    private func setupAndStart(forceRestart: Bool = false) async {
        if interactor == nil {
            let presenter = SyllableSnailPresenter(displayLogic: holder)
            let worker = SyllableSnailWorker(childRepository: container.childRepository)
            let interactor = SyllableSnailInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService,
                adaptivePlanner: container.adaptivePlannerService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = SyllableSnailRouter(dismissAction: { exitGame() })
        }
        _ = forceRestart
        await interactor?.start(
            request: .init(childId: childId, mode: preferredMode, preferredTier: preferredTier)
        )
    }

    private func submitTap() async {
        holder.attemptInRound += 1
        await interactor?.tap(
            request: .init(tapCount: holder.tapCount, attemptInRound: holder.attemptInRound)
        )
    }

    private func submitAssembled(round: SyllableSnailModels.Start.RoundViewModel) async {
        holder.attemptInRound += 1
        let ids = holder.slotTiles.map(\.id)
        switch round.mode {
        case .build:
            await interactor?.submit(
                request: .init(tileIds: ids, attemptInRound: holder.attemptInRound)
            )
        case .fix:
            await interactor?.fix(
                request: .init(orderedTileIds: ids, attemptInRound: holder.attemptInRound)
            )
        case .clap:
            break
        }
    }

    private func replaySyllables(round: SyllableSnailModels.Start.RoundViewModel) async {
        // По-слоговое проговаривание — методически обязательно для режима A.
        // Хаптика подтверждает нажатие; аудио-пайплайн — Lyalya TTS-паки.
        container.hapticService.selection()
        Self.logger.debug("Replay syllables requested for \(round.wordText, privacy: .public)")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SyllableSnail / game") {
    SyllableSnailView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
