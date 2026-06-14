import OSLog
import SwiftUI

// MARK: - WordFormationViewModelHolder

@MainActor
@Observable
final class WordFormationViewModelHolder: WordFormationDisplayLogic {

    var startVM: WordFormationModels.Start.ViewModel?
    var currentRound: WordFormationModels.Start.RoundViewModel?
    var lastFeedback: FeedbackTier?
    var lastLyalyaLine: String?
    /// id варианта, который ребёнок выбрал в последней попытке.
    var chosenOptionId: String?
    /// id нормативной формы текущего раунда (подсветка на hit).
    var revealedOptionId: String?
    /// id варианта-подсказки (после 2 промахов).
    var hintOptionId: String?
    /// Нормативная форма (озвучка + субтитр) на hit.
    var spokenForm: String?
    /// Попросить «повтори форму» (7–8 лет).
    var askToRepeat: Bool = false
    var summary: WordFormationModels.Answer.SummaryViewModel?
    var isFinished: Bool = false
    var showCelebration: Bool = false
    /// Счётчик попыток в текущем раунде (для номера попытки в Request).
    var attemptInRound: Int = 0

    func displayStart(viewModel: WordFormationModels.Start.ViewModel) async {
        self.startVM = viewModel
        self.currentRound = viewModel.firstRound
        resetRoundState()
        self.isFinished = false
        self.summary = nil
        self.showCelebration = false
    }

    func displayAnswer(viewModel: WordFormationModels.Answer.ViewModel) async {
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

// MARK: - WordFormationView (Clean Swift: View)
//
// F2-007 «Назови ласково / Один-много-нет» (Wave 2).
//
// Детская игра словообразования: «Скажи правильно». Картинка-основа крупно
// сверху (стол, стул, гриб…). Ляля задаёт под-задачу (назови ласково / один-
// много / чего много-нет). Ребёнок выбирает нормативную форму среди текстовых
// вариантов; на попадание система проговаривает верную форму (закрепление по
// слуху — методическое ядро).
//
// Accessibility:
//   • Kid circuit: варианты-кнопки крупные (touch ≥ 56pt)
//   • VoiceOver: основа — слово + картинка; вариант — текст формы; на hit
//     озвучивается spokenForm + субтитр
//   • Dynamic Type: подписи вариантов minimumScaleFactor(0.85) + lineLimit(nil)
//   • Reduced Motion: «множение»/«уменьшение» → opacity/обводка без spring;
//     confetti → static
//   • Light + Dark: ColorTokens.Kid + Brand адаптируются

struct WordFormationView: View {

    let childId: String

    @State private var holder = WordFormationViewModelHolder()
    @State private var interactor: WordFormationInteractor?
    @State private var presenter: WordFormationPresenter?
    @State private var router: WordFormationRouter?

    @Environment(\.exitGame) private var exitGame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WordFormation.View"
    )

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
            .navigationTitle(Text("wordFormation.title"))
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
                    .accessibilityLabel(Text("wordFormation.close.a11y"))
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
        round: WordFormationModels.Start.RoundViewModel
    ) -> some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.sp4) {
                    progressHeader(round)

                    // Ляля задаёт под-задачу.
                    HSSpeechBubble(
                        holder.lastLyalyaLine ?? round.promptLyalya,
                        direction: .left,
                        style: holder.lastFeedback == nil ? .question : bubbleStyle(holder.lastFeedback)
                    )
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .id("bubble-\(round.id)-\(holder.lastFeedback?.rawValue ?? "q")")
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))

                    Spacer(minLength: 0)

                    // Картинка-основа.
                    baseCard(round: round)
                        .id(round.id)
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))

                    // Просьба повторить форму (7–8 лет) на hit.
                    if holder.askToRepeat, holder.lastFeedback == .hit {
                        repeatBanner
                            .padding(.horizontal, SpacingTokens.screenEdge)
                            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    }

                    Spacer(minLength: 0)

                    // Текстовые варианты-формы.
                    KidSectionLabel(String(localized: "wordFormation.section.choose"))
                        .padding(.horizontal, SpacingTokens.screenEdge)
                    optionsStack(round: round)
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
        _ round: WordFormationModels.Start.RoundViewModel
    ) -> some View {
        let total = max(holder.startVM?.totalRounds ?? 1, 1)
        let current = min(max(Int((round.progressFraction * Double(total)).rounded(.up)), 1), total)
        return HStack(spacing: SpacingTokens.small) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.Kid.line)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * round.progressFraction))
                }
            }
            .frame(height: 12)
            .accessibilityHidden(true)
            KidStepChip(current: max(current, 1), total: total)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.sp4)
    }

    private func baseCard(
        round: WordFormationModels.Start.RoundViewModel
    ) -> some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp5) {
            VStack(spacing: SpacingTokens.sp3) {
                HSContentSymbol(round.baseImage, size: 96, tint: ColorTokens.Brand.primary)
                    // На hit основа «множится / уменьшается» — лёгкий акцент.
                    .scaleEffect(reduceMotion ? 1 : (holder.lastFeedback == .hit ? 1.08 : 1))
                Text(round.baseWord)
                    .font(TypographyTokens.title(30))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            String(format: String(localized: "wordFormation.base.a11y"), round.baseWord)
        ))
    }

    private var repeatBanner: some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: "mouth.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(ColorTokens.Brand.lilac)
                .accessibilityHidden(true)
            Text("wordFormation.repeat.prompt")
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

    // MARK: - Options (текстовые варианты-формы)

    private func optionsStack(
        round: WordFormationModels.Start.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp3) {
            ForEach(round.options) { option in
                optionButton(option)
            }
        }
    }

    private func optionButton(
        _ option: WordFormationModels.Start.OptionViewModel
    ) -> some View {
        let isRevealed = holder.revealedOptionId == option.id
        let isHinted = holder.hintOptionId == option.id
        let isChosenMiss = holder.chosenOptionId == option.id
            && holder.lastFeedback != nil
            && holder.lastFeedback != .hit

        return Button {
            Task { await chooseOption(option.id) }
        } label: {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.body)
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)
                Text(option.text)
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .padding(.horizontal, SpacingTokens.sp4)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(optionBackground(isRevealed: isRevealed, isMiss: isChosenMiss))
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .stroke(optionStroke(isRevealed: isRevealed, isHinted: isHinted, isMiss: isChosenMiss),
                            lineWidth: optionStrokeWidth(isRevealed: isRevealed, isHinted: isHinted, isMiss: isChosenMiss))
            )
            .depthShadow(ShadowTokens.kidDepth)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(option.accessibilityLabel))
        .accessibilityHint(Text("wordFormation.option.hint"))
        .accessibilityAddTraits(isRevealed ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Summary

    private func summarySection(
        _ summary: WordFormationModels.Answer.SummaryViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            Spacer()

            Image(systemName: summary.accuracyFraction >= 0.8
                ? "text.bubble.fill"
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
                .padding(.horizontal, SpacingTokens.sp6)

            Spacer()

            VStack(spacing: SpacingTokens.sp3) {
                Button {
                    Task { await setupAndStart(forceRestart: true) }
                } label: {
                    Text("wordFormation.summary.again")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("wordFormation.summary.again.hint"))

                Button {
                    exitGame()
                } label: {
                    Text("wordFormation.summary.done")
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
            Text("wordFormation.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Option styling

    private func optionBackground(isRevealed: Bool, isMiss: Bool) -> Color {
        if isRevealed { return ColorTokens.Brand.mint.opacity(0.28) }
        if isMiss { return ColorTokens.Kid.surfaceAlt }
        return ColorTokens.Kid.surface
    }

    private func optionStroke(isRevealed: Bool, isHinted: Bool, isMiss: Bool) -> Color {
        if isRevealed { return ColorTokens.Brand.mint }
        if isHinted { return ColorTokens.Brand.lilac }
        if isMiss { return ColorTokens.Brand.butter }
        return .clear
    }

    private func optionStrokeWidth(isRevealed: Bool, isHinted: Bool, isMiss: Bool) -> CGFloat {
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
            let presenter = WordFormationPresenter(displayLogic: holder)
            let worker = WordFormationWorker(childRepository: container.childRepository)
            let interactor = WordFormationInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService,
                adaptivePlanner: container.adaptivePlannerService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = WordFormationRouter(dismissAction: { exitGame() })
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
#Preview("WordFormation / game") {
    WordFormationView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
