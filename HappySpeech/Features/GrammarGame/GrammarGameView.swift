import SwiftUI

// MARK: - GrammarGameView

// Корневой SwiftUI-экран Grammar Games.
// Объединяет 4 режима через GrammarGameMode enum.
// Соответствует Clean Swift VIP: View знает только ViewModel, вызывает Interactor.

// MARK: - GrammarGameDisplayLogicHost
// Adapter: GrammarGameDisplayLogic требует AnyObject, GrammarGameView — struct.
// View хранит ссылку на DisplayHost который пробрасывает вызовы через замыкания.

@MainActor
final class GrammarGameDisplayHost: GrammarGameDisplayLogic {
    var onLoadGame:       ((GrammarGameModels.LoadGame.ViewModel) -> Void)?
    var onRound:          ((GrammarGameModels.PresentRound.ViewModel) -> Void)?
    var onEvaluate:       ((GrammarGameModels.EvaluateAnswer.ViewModel) -> Void)?
    var onDragDrop:       ((GrammarGameModels.DragDrop.ViewModel) -> Void)?
    var onSessionComplete:((GrammarGameModels.SessionComplete.ViewModel) -> Void)?
    var onExitConfirm:    ((GrammarGameModels.ExitConfirmation.ViewModel) -> Void)?
    var onError:          ((String) -> Void)?

    func displayLoadGame(_ viewModel: GrammarGameModels.LoadGame.ViewModel) { onLoadGame?(viewModel) }
    func displayRound(_ viewModel: GrammarGameModels.PresentRound.ViewModel) { onRound?(viewModel) }
    func displayEvaluateAnswer(_ viewModel: GrammarGameModels.EvaluateAnswer.ViewModel) { onEvaluate?(viewModel) }
    func displayDragDrop(_ viewModel: GrammarGameModels.DragDrop.ViewModel) { onDragDrop?(viewModel) }
    func displaySessionComplete(_ viewModel: GrammarGameModels.SessionComplete.ViewModel) { onSessionComplete?(viewModel) }
    func displayExitConfirmation(_ viewModel: GrammarGameModels.ExitConfirmation.ViewModel) { onExitConfirm?(viewModel) }
    func displayError(_ message: String) { onError?(message) }
}

struct GrammarGameView: View {

    // MARK: - VIP wiring

    let interactor: any GrammarGameBusinessLogic
    let router: GrammarGameRouter

    // MARK: - View state (только UI-состояние)

    @State var modeTitle: String = ""
    @State var difficultyLabel: String = ""
    @State var totalRounds: Int = 7
    @State var currentRoundIndex: Int = 0

    // Round display
    @State var questionText: String = ""
    @State var choices: [GrammarChoice] = []
    @State var imageName: String = ""
    @State var roundExtraData: GrammarRoundExtra = .none
    @State var audioFile: String = ""

    // Feedback state
    @State var selectedChoiceId: String? = nil
    @State var correctChoiceId: String? = nil
    @State var feedbackText: String = ""
    @State var hintText: String? = nil
    @State var showHint: Bool = false
    @State var showRewardBurst: Bool = false

    // Dative drag state
    @State var dragOffset: CGSize = .zero
    @State var isDragging: Bool = false
    @State var hoveredCharacterId: String? = nil
    @State var dragFeedbackPhrase: String = ""
    @State var dragIsCorrect: Bool? = nil

    // Session complete
    @State var showSessionComplete: Bool = false
    @State var sessionSuccessRate: Float = 0
    @State var sessionCorrectCount: Int = 0
    @State var sessionResultText: String = ""
    @State var showSessionReward: Bool = false

    // Exit confirmation
    @State var showExitSheet: Bool = false
    @State var exitViewModel: GrammarGameModels.ExitConfirmation.ViewModel?

    // Loading / error
    @State var isLoading: Bool = true
    @State var errorMessage: String? = nil

    // Difficulty capsule color
    @State var difficultyColor: Color = ColorTokens.Semantic.success

    // SE adaptation
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State var screenWidth: CGFloat = 390
    var isSmallDevice: Bool { screenWidth < 375 }

    // Reduced Motion
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Init (DI через инициализатор)

    init(
        mode: GrammarGameMode,
        difficulty: GrammarDifficulty = .medium,
        childId: String = "default",
        interactor: any GrammarGameBusinessLogic,
        router: GrammarGameRouter
    ) {
        self.interactor = interactor
        self.router = router
        self._modeTitle = State(initialValue: mode.localizedTitle)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            backgroundLayer

            if isLoading {
                loadingLayer
            } else if showSessionComplete {
                sessionCompleteLayer
            } else if let err = errorMessage {
                errorLayer(err)
            } else {
                mainContentLayer
            }

            // Маскот overlay — всегда поверх контента
            if !showSessionComplete && !isLoading {
                mascotOverlay
            }

            // Reward burst overlay
            if showRewardBurst {
                HSRewardBurst(isShowing: showRewardBurst)
                    .transition(.opacity)
                    .zIndex(10)
                    .allowsHitTesting(false)
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            screenWidth = newWidth
        }
        .sheet(isPresented: $showExitSheet) {
            if let vm = exitViewModel {
                exitConfirmationSheet(vm)
            }
        }
        .accessibilityLabel(String(localized: "grammar.game.title.\(modeTitle)"))
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [ColorTokens.Kid.bg, ColorTokens.Kid.bgDeep],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Main content (TopBar + ContentArea + ActionArea)

    private var mainContentLayer: some View {
        VStack(spacing: 0) {
            topBar
            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            actionArea
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .center) {
            Button {
                interactor.requestExit()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            .frame(width: 44, height: 44)
            .accessibilityLabel(String(localized: "grammar.game.exit.confirm", bundle: .main))

            Spacer()

            // Прогресс раундов
            roundProgressDots

            Spacer()

            // Уровень сложности
            difficultyCapsule
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .frame(height: 52)
    }

    private var roundProgressDots: some View {
        HStack(spacing: SpacingTokens.tiny) {
            ForEach(0..<totalRounds, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(i <= currentRoundIndex
                          ? ColorTokens.Brand.primary
                          : ColorTokens.Kid.line)
                    .frame(width: isSmallDevice ? 14 : 20, height: 8)
                    .animation(reduceMotion ? nil : .spring(response: 0.3), value: currentRoundIndex)
            }
        }
        .accessibilityLabel(
            String(
                format: String(localized: "grammar.game.round.progress"),
                currentRoundIndex + 1,
                totalRounds
            )
        )
    }

    private var difficultyCapsule: some View {
        Capsule()
            .fill(difficultyColor.opacity(0.15))
            .overlay(
                Text(difficultyLabel)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(difficultyColor)
                    .padding(.horizontal, SpacingTokens.small)
            )
            .frame(height: 28)
    }

    // MARK: - Content Area (mode dispatch)

    @ViewBuilder
    private var contentArea: some View {
        ScrollView(showsIndicators: false) {
            switch roundExtraData {
            case .dative(let characters, let targetIndex):
                dativeContentView(characters: characters, targetIndex: targetIndex)
                    .padding(.top, SpacingTokens.xxLarge)
            case .genitive(let containers, let correctIndex):
                genitiveContentView(containers: containers, correctIndex: correctIndex)
                    .padding(.top, SpacingTokens.xxLarge)
            case .instrumental(let partyMode):
                instrumentalContentView(partyMode: partyMode)
                    .padding(.top, SpacingTokens.xxLarge)
            case .none:
                pluralContentView
                    .padding(.top, SpacingTokens.xxLarge)
            }
        }
    }

    // MARK: - Plural Content (Один — много)

    private var pluralContentView: some View {
        VStack(spacing: SpacingTokens.xLarge) {
            HSSpeechBubble(questionText, direction: .right, style: .question)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(questionText)

            // Трансформация: 1 предмет → много
            HStack(spacing: SpacingTokens.large) {
                singularImageTile

                Image(systemName: "arrow.right.circle.fill")
                    .font(TypographyTokens.title(28))
                    .foregroundStyle(ColorTokens.Brand.primary)

                pluralResultArea
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SpacingTokens.screenEdge)

            // Варианты ответов
            VStack(spacing: SpacingTokens.regular) {
                ForEach(choices) { choice in
                    pluralChoiceButton(choice)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            // Подсказка (после N ошибок)
            if showHint, let hint = hintText {
                hintView(hint)
            }
        }
    }

    private var singularImageTile: some View {
        let tileSize: CGFloat = isSmallDevice ? 120 : 160
        return HSPictTile(
            symbol: "questionmark.circle",
            label: String(localized: "grammar.game.accessibility.one_item", bundle: .main),
            state: .neutral
        ) {}
        .frame(width: tileSize, height: tileSize)
    }

    private var pluralResultArea: some View {
        let tileSize: CGFloat = isSmallDevice ? 120 : 160
        return ZStack {
            if let selected = selectedChoiceId,
               selected == correctChoiceId {
                // Анимация удвоения — 5 копий предмета в сетке
                PluralPreviewGrid()
                    .frame(width: tileSize, height: tileSize)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.7).combined(with: .opacity)
                    )
            } else {
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .foregroundStyle(ColorTokens.Kid.line)
                    .frame(width: tileSize, height: tileSize)
                    .overlay(
                        Image(systemName: "questionmark")
                            .font(TypographyTokens.display(36))
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    )
            }
        }
        .accessibilityLabel(
            selectedChoiceId == correctChoiceId
                ? String(localized: "grammar.game.accessibility.many_items", bundle: .main)
                : String(localized: "grammar.game.accessibility.select_variant", bundle: .main)
        )
    }

    private func pluralChoiceButton(_ choice: GrammarChoice) -> some View {
        let state = choiceButtonState(for: choice)
        return Button {
            onChoiceTapped(choice.id)
        } label: {
            Text(choice.text)
                .font(TypographyTokens.headline(22))
                .foregroundStyle(state.textColor)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpacingTokens.regular)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.button)
                        .fill(state.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: RadiusTokens.button)
                                .strokeBorder(state.border, lineWidth: state.borderWidth)
                        )
                )
        }
        .frame(maxWidth: .infinity, minHeight: isSmallDevice ? 48 : 56)
        .disabled(selectedChoiceId != nil && selectedChoiceId == correctChoiceId)
        .accessibilityLabel(choice.text)
        .accessibilityHint(String(localized: "grammar.game.accessibility.tap_to_select", bundle: .main))
        .accessibilityAddTraits(selectedChoiceId == choice.id ? .isSelected : [])
    }

    // MARK: - Mascot Overlay

    private var mascotOverlay: some View {
        Group {
            if !isSmallDevice {
                LyalyaMascotView(state: mascotState)
                    .frame(width: 96, height: 96)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 60)
                    .padding(.trailing, SpacingTokens.screenEdge)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private var mascotState: LyalyaState {
        guard let selected = selectedChoiceId else { return .explaining }
        if selected == correctChoiceId { return .celebrating }
        return showHint ? .thinking : .encouraging
    }

    // MARK: - Action Area

    private var actionArea: some View {
        VStack(spacing: SpacingTokens.regular) {
            if let selected = selectedChoiceId {
                // Показываем feedback text
                if !feedbackText.isEmpty {
                    Text(feedbackText)
                        .font(TypographyTokens.headline(18))
                        .foregroundStyle(
                            selected == correctChoiceId
                                ? ColorTokens.Semantic.success
                                : ColorTokens.Semantic.error
                        )
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
                // Кнопка «Далее» только после правильного ответа
                if selected == correctChoiceId || showHint {
                    HSButton(
                        String(localized: "grammar.game.cta.next", bundle: .main),
                        style: .primary
                    ) {
                        Task { await interactor.advanceToNextRound() }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, SpacingTokens.xxLarge)
        .background(.ultraThinMaterial)
    }

    // MARK: - Hint View

    func hintView(_ hint: String) -> some View {
        Text(hint)
            .font(TypographyTokens.body(16))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .multilineTextAlignment(.center)
            .padding(SpacingTokens.regular)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm)
                    .fill(ColorTokens.Brand.lilac.opacity(0.12))
            )
            .padding(.horizontal, SpacingTokens.screenEdge)
            .transition(.opacity)
            .accessibilityLabel(String(localized: "grammar.game.feedback.hint", bundle: .main))
    }

    // MARK: - Loading Layer

    private var loadingLayer: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(ColorTokens.Brand.primary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error Layer

    private func errorLayer(_ message: String) -> some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(TypographyTokens.kidDisplay(48))
                .foregroundStyle(ColorTokens.Semantic.warning)
            Text(message)
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.screenEdge)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Session Complete Layer

    private var sessionCompleteLayer: some View {
        VStack(spacing: SpacingTokens.xLarge) {
            Spacer()

            LyalyaMascotView(state: showSessionReward ? .celebrating : .happy)
                .frame(width: 120, height: 120)

            Text(sessionResultText)
                .font(TypographyTokens.title(28))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)

            Text("\(sessionCorrectCount) из \(totalRounds) правильно")
                .font(TypographyTokens.headline(20))
                .foregroundStyle(ColorTokens.Kid.inkMuted)

            HSButton(
                String(localized: "grammar.game.cta.next", bundle: .main),
                style: .primary
            ) {
                router.dismissGame()
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Exit Confirmation Sheet

    private func exitConfirmationSheet(_ vm: GrammarGameModels.ExitConfirmation.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.xLarge) {
            Text(vm.title)
                .font(TypographyTokens.headline(22))
                .foregroundStyle(ColorTokens.Kid.ink)

            Text(vm.body)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)

            HStack(spacing: SpacingTokens.regular) {
                HSButton(vm.confirmLabel, style: .secondary) {
                    showExitSheet = false
                    router.dismissGame()
                }
                HSButton(vm.cancelLabel, style: .primary) {
                    showExitSheet = false
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .padding(SpacingTokens.xLarge)
        .presentationDetents([.height(260)])
        .presentationCornerRadius(RadiusTokens.xl)
    }

    // MARK: - Choice Button State

    struct ChoiceButtonAppearance {
        let background: Color
        let border: Color
        let borderWidth: CGFloat
        let textColor: Color
    }

    func choiceButtonState(for choice: GrammarChoice) -> ChoiceButtonAppearance {
        if let selected = selectedChoiceId {
            if choice.id == correctChoiceId {
                return ChoiceButtonAppearance(
                    background: ColorTokens.Semantic.successBg,
                    border: ColorTokens.Semantic.success,
                    borderWidth: 2,
                    textColor: ColorTokens.Semantic.success
                )
            }
            if choice.id == selected && selected != correctChoiceId {
                return ChoiceButtonAppearance(
                    background: ColorTokens.Semantic.errorBg,
                    border: ColorTokens.Semantic.error,
                    borderWidth: 2,
                    textColor: ColorTokens.Semantic.error
                )
            }
        }
        if selectedChoiceId == choice.id {
            return ChoiceButtonAppearance(
                background: ColorTokens.Brand.primary.opacity(0.12),
                border: ColorTokens.Brand.primary,
                borderWidth: 2,
                textColor: ColorTokens.Brand.primary
            )
        }
        return ChoiceButtonAppearance(
            background: ColorTokens.Kid.surface,
            border: ColorTokens.Kid.line,
            borderWidth: 1.5,
            textColor: ColorTokens.Kid.ink
        )
    }

    func stateIcon(for choice: GrammarChoice) -> String {
        if let selected = selectedChoiceId {
            if choice.id == correctChoiceId { return "checkmark.circle.fill" }
            if choice.id == selected && selected != correctChoiceId { return "xmark.circle.fill" }
        }
        if selectedChoiceId == choice.id { return "circle.inset.filled" }
        return "circle"
    }

    // MARK: - Tap handler

    func onChoiceTapped(_ choiceId: String) {
        guard selectedChoiceId == nil else { return }    // блокируем повторный выбор
        selectedChoiceId = choiceId
        Task {
            await interactor.evaluateAnswer(
                .init(selectedChoiceId: choiceId, roundIndex: currentRoundIndex)
            )
        }
    }
}
