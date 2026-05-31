import OSLog
import SwiftUI

// MARK: - WhoseTailViewModelHolder

@MainActor
@Observable
final class WhoseTailViewModelHolder: WhoseTailDisplayLogic {

    var startVM: WhoseTailModels.Start.ViewModel?
    var currentRound: WhoseTailModels.Start.RoundViewModel?
    var lastFeedback: FeedbackTier?
    var lastLyalyaLine: String?
    /// id варианта, который ребёнок выбрал в последней попытке.
    var chosenOptionId: String?
    /// id правильного варианта текущего раунда (подсветка на hit).
    var revealedOptionId: String?
    /// id варианта-подсказки (после 2 промахов).
    var hintOptionId: String?
    /// Целевая форма прилагательного (озвучка + субтитр) на hit.
    var spokenForm: String?
    /// Попросить «скажи, чей хвост?» (7–8 лет).
    var askToRepeat: Bool = false
    var summary: WhoseTailModels.Answer.SummaryViewModel?
    var isFinished: Bool = false
    var showCelebration: Bool = false
    /// Счётчик попыток в текущем раунде (для номера попытки в Request).
    var attemptInRound: Int = 0

    func displayStart(viewModel: WhoseTailModels.Start.ViewModel) async {
        self.startVM = viewModel
        self.currentRound = viewModel.firstRound
        resetRoundState()
        self.isFinished = false
        self.summary = nil
        self.showCelebration = false
    }

    func displayAnswer(viewModel: WhoseTailModels.Answer.ViewModel) async {
        self.lastFeedback = viewModel.feedback
        self.lastLyalyaLine = viewModel.lyalyaLine
        self.hintOptionId = viewModel.hintOptionId
        self.askToRepeat = viewModel.askToRepeat
        self.isFinished = viewModel.isFinished
        self.summary = viewModel.summary
        self.showCelebration = viewModel.summary?.showCelebration ?? false

        if viewModel.feedback == .hit {
            self.revealedOptionId = viewModel.correctOptionId
            self.spokenForm = viewModel.spokenForm
        }

        if let next = viewModel.nextRound {
            // Новый раунд — стираем состояние предыдущего.
            self.currentRound = next
            resetRoundState()
            self.lastFeedback = nil
            self.lastLyalyaLine = nil
        }
    }

    private func resetRoundState() {
        self.chosenOptionId = nil
        self.revealedOptionId = nil
        self.hintOptionId = nil
        self.spokenForm = nil
        self.askToRepeat = false
        self.attemptInRound = 0
    }
}

// MARK: - WhoseTailView (Clean Swift: View)
//
// F2-006 «Чей хвост / чей домик» (Wave 2).
//
// Детская игра словообразования прилагательных: «Чей это хвост?». Улика-картинка
// крупно сверху (хвост / домик / предмет). Ляля задаёт вопрос-загадку. Ребёнок
// сопоставляет улику с правильным зверем/материалом (тап по карточке); при
// попадании система проговаривает целевую форму прилагательного («Это лисий
// хвост!») — закрепление формы по слуху (методическое ядро словообразования).
//
// Accessibility:
//   • Kid circuit: карточки-варианты крупные (touch ≥ 96pt)
//   • VoiceOver: улика — вопрос «чей?»; вариант — слово зверя/материала; на hit
//     озвучивается spokenForm + субтитр (целевая форма)
//   • Dynamic Type: подписи вариантов minimumScaleFactor(0.85) + lineLimit(nil)
//   • Reduced Motion: «прирастание хвоста»/подсветка → opacity/обводка без
//     spring; confetti → static
//   • Light + Dark: ColorTokens.Kid + Brand адаптируются

struct WhoseTailView: View {

    let childId: String

    @State private var holder = WhoseTailViewModelHolder()
    @State private var interactor: WhoseTailInteractor?
    @State private var presenter: WhoseTailPresenter?
    @State private var router: WhoseTailRouter?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WhoseTail.View"
    )

    private let columns = [
        GridItem(.flexible(), spacing: SpacingTokens.sp3),
        GridItem(.flexible(), spacing: SpacingTokens.sp3)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // Тёплый mesh; ненавязчиво. Reduced Motion: убираем
                // анимированный фон (accessibility + детерминизм снимков).
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
            .navigationTitle(Text("whoseTail.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("whoseTail.close.a11y"))
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
        round: WhoseTailModels.Start.RoundViewModel
    ) -> some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.sp4) {
                    progressHeader(round)

                    // Ляля задаёт вопрос-загадку.
                    HSSpeechBubble(
                        holder.lastLyalyaLine ?? round.promptLyalya,
                        direction: .left,
                        style: holder.lastFeedback == nil ? .question : bubbleStyle(holder.lastFeedback)
                    )
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .id("bubble-\(round.id)-\(holder.lastFeedback?.rawValue ?? "q")")
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))

                    Spacer(minLength: 0)

                    // Улика-картинка (хвост / домик / предмет) крупно.
                    cueCard(round: round)
                        .id(round.id)
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))

                    // Просьба повторить форму (7–8 лет) на hit.
                    if holder.askToRepeat, holder.lastFeedback == .hit {
                        repeatBanner
                            .padding(.horizontal, SpacingTokens.screenEdge)
                            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    }

                    Spacer(minLength: 0)

                    // Сетка карточек-вариантов (звери / материалы).
                    optionsGrid(round: round)
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
        _ round: WhoseTailModels.Start.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            Text(round.progressLabel)
                .font(TypographyTokens.caption(12).monospacedDigit())
                .foregroundStyle(ColorTokens.Kid.inkMuted)

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

    // MARK: - Cue card (улика)

    private func cueCard(
        round: WhoseTailModels.Start.RoundViewModel
    ) -> some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp5) {
            VStack(spacing: SpacingTokens.sp3) {
                HSContentSymbol(round.cueImage, size: 150, tint: ColorTokens.Brand.primary)
                    // На hit улика «оживает» — лёгкий акцент.
                    .scaleEffect(reduceMotion ? 1 : (holder.lastFeedback == .hit ? 1.08 : 1))

                // Субтитр целевой формы на hit (закрепление формы текстом, F8-012).
                if let form = holder.spokenForm, holder.lastFeedback == .hit, !form.isEmpty {
                    Text(form)
                        .font(TypographyTokens.headline(20))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            String(format: String(localized: "whoseTail.cue.a11y"), round.promptLyalya)
        ))
    }

    private var repeatBanner: some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: "mouth.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(ColorTokens.Brand.lilac)
                .accessibilityHidden(true)
            Text("whoseTail.repeat.prompt")
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Brand.lilac.opacity(0.18))
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Options grid (карточки-варианты)

    private func optionsGrid(
        round: WhoseTailModels.Start.RoundViewModel
    ) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp3) {
            ForEach(round.options) { option in
                optionCard(option)
            }
        }
    }

    private func optionCard(
        _ option: WhoseTailModels.Start.OptionViewModel
    ) -> some View {
        let isRevealed = holder.revealedOptionId == option.id
        let isHinted = holder.hintOptionId == option.id
        let isChosenMiss = holder.chosenOptionId == option.id
            && holder.lastFeedback != nil
            && holder.lastFeedback != .hit

        return Button {
            Task { await chooseOption(option.id) }
        } label: {
            HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp3) {
                VStack(spacing: SpacingTokens.sp2) {
                    HSContentSymbol(option.imageAsset, size: 64, tint: ColorTokens.Brand.primary)
                        // На hit правильный «прирастает» к улике — лёгкий акцент.
                        .scaleEffect(reduceMotion ? 1 : (isRevealed ? 1.08 : 1))
                    Text(option.word)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 96)
            }
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .stroke(cardStroke(isRevealed: isRevealed, isHinted: isHinted, isMiss: isChosenMiss),
                            lineWidth: cardStrokeWidth(isRevealed: isRevealed, isHinted: isHinted, isMiss: isChosenMiss))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(option.accessibilityLabel))
        .accessibilityHint(Text("whoseTail.option.hint"))
        .accessibilityAddTraits(isRevealed ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Summary

    private func summarySection(
        _ summary: WhoseTailModels.Answer.SummaryViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            Spacer()

            Image(systemName: summary.accuracyFraction >= 0.8
                ? "pawprint.circle.fill"
                : "hand.thumbsup.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(ColorTokens.Brand.gold)
                .hsSymbolEffect(.bounce, value: summary.scoreText)
                .accessibilityHidden(true)

            Text(summary.title)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(summary.scoreText)
                .font(TypographyTokens.headline(20).monospacedDigit())
                .foregroundStyle(ColorTokens.Brand.primary)

            Text(summary.encouragement)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, SpacingTokens.sp6)

            Spacer()

            VStack(spacing: SpacingTokens.sp3) {
                Button {
                    Task { await setupAndStart(forceRestart: true) }
                } label: {
                    Text("whoseTail.summary.again")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("whoseTail.summary.again.hint"))

                Button {
                    dismiss()
                } label: {
                    Text("whoseTail.summary.done")
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
            Text("whoseTail.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Card styling

    private func cardStroke(isRevealed: Bool, isHinted: Bool, isMiss: Bool) -> Color {
        if isRevealed { return ColorTokens.Brand.mint }
        if isHinted { return ColorTokens.Brand.lilac }
        if isMiss { return ColorTokens.Brand.butter }
        return .clear
    }

    private func cardStrokeWidth(isRevealed: Bool, isHinted: Bool, isMiss: Bool) -> CGFloat {
        if isRevealed || isHinted || isMiss { return 3 }
        return 0
    }

    private func bubbleStyle(_ feedback: FeedbackTier?) -> HSSpeechBubble.BubbleStyle {
        switch feedback {
        case .hit:    return .lyalya
        case .retry:  return .hint
        case .almost, .none: return .question
        }
    }

    // MARK: - Wiring

    private func setupAndStart(forceRestart: Bool = false) async {
        if interactor == nil {
            let presenter = WhoseTailPresenter(displayLogic: holder)
            let worker = WhoseTailWorker(childRepository: container.childRepository)
            let interactor = WhoseTailInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService,
                adaptivePlanner: container.adaptivePlannerService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = WhoseTailRouter(dismissAction: { dismiss() })
        }
        _ = forceRestart
        await interactor?.start(request: .init(childId: childId, preferredSubtask: nil))
    }

    private func chooseOption(_ optionId: String) async {
        holder.chosenOptionId = optionId
        holder.attemptInRound += 1
        await interactor?.answer(
            request: .init(chosenOptionId: optionId, attemptInRound: holder.attemptInRound)
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("WhoseTail / game") {
    WhoseTailView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
