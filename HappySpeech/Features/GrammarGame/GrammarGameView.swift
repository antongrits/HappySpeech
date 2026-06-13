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

    // Exit confirmation (item-driven sheet — устраняет race пустого шита)
    @State var exitViewModel: GrammarGameModels.ExitConfirmation.ViewModel?

    // Loading / error
    @State var isLoading: Bool = true
    @State var errorMessage: String? = nil

    // Difficulty capsule color
    @State var difficultyColor: Color = ColorTokens.Semantic.success

    // SE adaptation
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State var screenWidth: CGFloat = 390
    // SE 3 имеет ширину РОВНО 375pt — строгое `< 375` его исключало, из-за чего
    // компактные отступы/размеры к нему не применялись и нижние кнопки уходили
    // под сгиб. `<= 375` корректно охватывает SE.
    var isSmallDevice: Bool { screenWidth <= 375 }

    /// Верхний отступ контента: на SE минимизируем, чтобы варианты ответов
    /// помещались без скролла.
    private var contentTopInset: CGFloat {
        isSmallDevice ? SpacingTokens.regular : SpacingTokens.xxLarge
    }

    // Reduced Motion
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Init (DI через инициализатор)

    /// Bootstrap-замыкание (опционально). Вызывается один раз в `.task` уже на
    /// экземпляре View, установленном в иерархию, и получает `GrammarGameDisplayHost`,
    /// привязанный к актуальным `@State`. Координатор использует его, чтобы связать
    /// `Presenter.display` и запустить загрузку игры.
    private let onBootstrap: ((GrammarGameDisplayHost) -> Void)?

    @State private var didBootstrap = false

    init(
        mode: GrammarGameMode,
        difficulty: GrammarDifficulty = .medium,
        childId: String = "default",
        interactor: any GrammarGameBusinessLogic,
        router: GrammarGameRouter,
        onBootstrap: ((GrammarGameDisplayHost) -> Void)? = nil
    ) {
        self.interactor = interactor
        self.router = router
        self.onBootstrap = onBootstrap
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
        .sheet(item: $exitViewModel) { vm in
            exitConfirmationSheet(vm)
        }
        .accessibilityLabel(String(format: String(localized: "grammar.game.title %@"), modeTitle))
        .task {
            guard !didBootstrap, let onBootstrap else { return }
            didBootstrap = true
            onBootstrap(makeDisplayHost())
        }
    }

    // MARK: - Background

    /// Однотонный тёплый кремовый фон эталона kid-game-tap (без mesh/градиент-
    /// смешивания, без движения).
    private var backgroundLayer: some View {
        ColorTokens.Kid.bg.ignoresSafeArea()
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
        HStack(alignment: .center, spacing: SpacingTokens.small) {
            // Тонкий коралловый прогресс-бар эталона + чип сложности.
            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                difficultyCapsule
                roundProgressBar
            }

            Button {
                interactor.requestExit()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(ColorTokens.Kid.surface))
                    .kidTileShadow()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "grammar.game.exit.confirm", bundle: .main))
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.tiny)
    }

    private var roundProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(ColorTokens.Kid.line)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * progressFraction))
                    .animation(reduceMotion ? nil : .spring(response: 0.3), value: currentRoundIndex)
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                format: String(localized: "grammar.game.round.progress"),
                currentRoundIndex + 1,
                totalRounds
            )
        )
    }

    private var progressFraction: Double {
        guard totalRounds > 0 else { return 0 }
        return Double(currentRoundIndex + 1) / Double(totalRounds)
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
                    .padding(.top, contentTopInset)
            case .genitive(let containers, let correctIndex):
                genitiveContentView(containers: containers, correctIndex: correctIndex)
                    .padding(.top, contentTopInset)
            case .instrumental(let partyMode):
                instrumentalContentView(partyMode: partyMode)
                    .padding(.top, contentTopInset)
            case .none:
                pluralContentView
                    .padding(.top, contentTopInset)
            }
        }
    }

    // MARK: - Plural Content (Один — много)

    private var pluralContentView: some View {
        VStack(spacing: SpacingTokens.xLarge) {
            // Step 10 Batch C — Pattern 2: HSLiquidGlassCard(.elevated) wraps
            // hero pair (question bubble + 1→many transformation). ultraThick
            // material поверх kidCool mesh — kavsoft-style hero focal point.
            HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.regular) {
                VStack(spacing: SpacingTokens.large) {
                    HSSpeechBubble(questionText, direction: .right, style: .question)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(questionText)

                    // Трансформация: 1 предмет → много
                    HStack(spacing: SpacingTokens.small) {
                        singularImageTile

                        Image(systemName: "arrow.right.circle.fill")
                            .font(TypographyTokens.title(28))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            // Step 10 Batch C — Pattern 5: pulse on arrow when
                            // user selects a choice (state-reactive feedback).
                            .hsSymbolEffect(.pulse, value: selectedChoiceId ?? "")

                        pluralResultArea
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            // Варианты ответов
            VStack(spacing: SpacingTokens.regular) {
                ForEach(choices) { choice in
                    pluralChoiceButton(choice)
                        // Step 10 Batch C — лёгкий scroll-stagger (только масштаб).
                        // Opacity НЕ гасим до 0: на SE варианты лежат у нижнего
                        // края scroll-вьюшки, и opacity→0 делал их невидимыми до
                        // скролла (неочевидный скролл = жалоба). Кнопки видимы всегда.
                        .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                            content
                                .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.96))
                        }
                        .hsParallaxTile(factor: 0.25)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            // Подсказка (после N ошибок)
            if showHint, let hint = hintText {
                hintView(hint)
            }
        }
    }

    /// Адаптивный размер плитки пары «1 → много»: две плитки + стрелка + отступы
    /// должны влезать в карточку на любой ширине (SE 375pt включительно, где
    /// фиксированные 160pt давали обрезку правой плитки за краем экрана).
    private var heroTileSize: CGFloat {
        let inner = screenWidth - 2 * SpacingTokens.screenEdge - 2 * SpacingTokens.regular
        let arrowAndGaps: CGFloat = 40 + 2 * SpacingTokens.small
        let maxTile = ((inner - arrowAndGaps) / 2).rounded(.down)
        return min(160, max(96, maxTile))
    }

    private var singularImageTile: some View {
        let tileSize = heroTileSize
        return HSPictTile(
            symbol: "questionmark.circle",
            label: String(localized: "grammar.game.accessibility.one_item", bundle: .main),
            state: .neutral
        ) {}
        .frame(width: tileSize, height: tileSize)
    }

    private var pluralResultArea: some View {
        let tileSize = heroTileSize
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
        .background(ctaTrayBackground)
    }

    @ViewBuilder
    private var ctaTrayBackground: some View {
        if #available(iOS 26, *), !reduceMotion {
            // iOS 26 Liquid Glass — adaptive blur matching system bottom bars.
            Color.clear.glassEffect(.regular)
        } else {
            // iOS 17–25 (and Reduced Motion) fallback — static ultraThinMaterial.
            Rectangle().fill(.ultraThinMaterial)
        }
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

            Text(String(
                format: String(localized: "grammar.game.session.correctCount %lld %lld", bundle: .main),
                sessionCorrectCount, totalRounds
            ))
                .font(TypographyTokens.headline(20))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)

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
                    exitViewModel = nil
                    router.dismissGame()
                }
                HSButton(vm.cancelLabel, style: .primary) {
                    exitViewModel = nil
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
