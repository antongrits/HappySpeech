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

    @State private var modeTitle: String = ""
    @State private var difficultyLabel: String = ""
    @State private var totalRounds: Int = 7
    @State private var currentRoundIndex: Int = 0

    // Round display
    @State private var questionText: String = ""
    @State private var choices: [GrammarChoice] = []
    @State private var imageName: String = ""
    @State private var roundExtraData: GrammarRoundExtra = .none
    @State private var audioFile: String = ""

    // Feedback state
    @State private var selectedChoiceId: String? = nil
    @State private var correctChoiceId: String? = nil
    @State private var feedbackText: String = ""
    @State private var hintText: String? = nil
    @State private var showHint: Bool = false
    @State private var showRewardBurst: Bool = false

    // Dative drag state
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var hoveredCharacterId: String? = nil
    @State private var dragFeedbackPhrase: String = ""
    @State private var dragIsCorrect: Bool? = nil

    // Session complete
    @State private var showSessionComplete: Bool = false
    @State private var sessionSuccessRate: Float = 0
    @State private var sessionCorrectCount: Int = 0
    @State private var sessionResultText: String = ""
    @State private var showSessionReward: Bool = false

    // Exit confirmation
    @State private var showExitSheet: Bool = false
    @State private var exitViewModel: GrammarGameModels.ExitConfirmation.ViewModel?

    // Loading / error
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil

    // Difficulty capsule color
    @State private var difficultyColor: Color = ColorTokens.Semantic.success

    // SE adaptation
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var screenWidth: CGFloat = 390
    private var isSmallDevice: Bool { screenWidth < 375 }

    // Reduced Motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    // MARK: - Dative Content (Кому что нужно — drag-and-drop)

    private func dativeContentView(
        characters: [DativeCharacter],
        targetIndex: Int
    ) -> some View {
        VStack(spacing: SpacingTokens.xLarge) {
            HSSpeechBubble(questionText, direction: .right, style: .question)
                .padding(.horizontal, SpacingTokens.screenEdge)

            // Ряд персонажей — drop targets
            HStack(spacing: SpacingTokens.regular) {
                ForEach(characters) { char in
                    DativeDropTargetView(
                        character: char,
                        isHighlighted: hoveredCharacterId == char.id,
                        isSmall: isSmallDevice
                    )
                    .onTapGesture {
                        // VoiceOver fallback: tap вместо drag
                        Task {
                            await interactor.evaluateDragDrop(
                                .init(droppedOnCharacterId: char.id, roundIndex: currentRoundIndex)
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            // Draggable предмет
            let tileSize: CGFloat = isSmallDevice ? 120 : 160
            HSPictTile(symbol: "bag", label: questionText, state: .neutral) {}
                .frame(width: tileSize, height: tileSize)
                .scaleEffect(isDragging ? 1.1 : 1.0)
                .shadow(
                    color: isDragging ? ColorTokens.Brand.primary.opacity(0.3) : .clear,
                    radius: 12
                )
                .animation(
                    reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
                    value: isDragging
                )
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { value in
                            isDragging = true
                            dragOffset = value.translation
                            // Определяем ближайший drop target
                            hoveredCharacterId = nearestCharacterId(
                                dragLocation: value.location,
                                characters: characters
                            )
                        }
                        .onEnded { _ in
                            isDragging = false
                            dragOffset = .zero
                            if let charId = hoveredCharacterId {
                                Task {
                                    await interactor.evaluateDragDrop(
                                        .init(droppedOnCharacterId: charId, roundIndex: currentRoundIndex)
                                    )
                                }
                            }
                            hoveredCharacterId = nil
                        }
                )
                .accessibilityLabel(String(localized: "grammar.game.accessibility.drag_item", bundle: .main))
                .accessibilityHint(String(localized: "grammar.game.accessibility.drag_to_character", bundle: .main))

            if !dragFeedbackPhrase.isEmpty {
                Text(dragFeedbackPhrase)
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(dragIsCorrect == true
                                     ? ColorTokens.Semantic.success
                                     : ColorTokens.Semantic.error)
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .transition(.opacity)
            }
        }
    }

    /// Простая эвристика — берёт ближайший target по горизонтали.
    private func nearestCharacterId(
        dragLocation: CGPoint,
        characters: [DativeCharacter]
    ) -> String? {
        guard !characters.isEmpty else { return nil }
        let segmentWidth = self.screenWidth / CGFloat(characters.count)
        let idx = Int(dragLocation.x / segmentWidth)
        let clampedIdx = max(0, min(idx, characters.count - 1))
        return characters[clampedIdx].id
    }

    // MARK: - Genitive Content (Откуда взял — tap containers)

    private func genitiveContentView(
        containers: [GenitiveContainer],
        correctIndex: Int
    ) -> some View {
        VStack(spacing: SpacingTokens.xLarge) {
            // Анимационная сцена
            GenitiveSceneView(
                containers: containers,
                selectedContainerId: selectedChoiceId,
                correctContainerId: correctChoiceId
            )
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Kid.surfaceAlt)
            )
            .padding(.horizontal, SpacingTokens.screenEdge)
            .accessibilityLabel(String(localized: "grammar.game.title.genitive", bundle: .main))

            HSSpeechBubble(questionText, direction: .right, style: .question)
                .padding(.horizontal, SpacingTokens.screenEdge)

            if showHint, let hint = hintText {
                hintView(hint)
            }
        }
    }

    // MARK: - Instrumental Content (С кем дружу)

    private func instrumentalContentView(partyMode: Bool) -> some View {
        VStack(spacing: SpacingTokens.xLarge) {
            if partyMode {
                partyModeView
            } else {
                standardInstrumentalView
            }
        }
    }

    private var standardInstrumentalView: some View {
        VStack(spacing: SpacingTokens.xLarge) {
            HSLiquidGlassCard {
                HStack(spacing: SpacingTokens.large) {
                    Image(systemName: "heart.circle.fill")
                        .font(TypographyTokens.kidDisplay(40))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(width: 56, height: 56)

                    Text(questionText)
                        .font(TypographyTokens.headline(22))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
                .padding(SpacingTokens.cardPad)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            VStack(spacing: SpacingTokens.regular) {
                ForEach(choices) { choice in
                    instrumentalChoiceCard(choice)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            if showHint, let hint = hintText {
                hintView(hint)
            }
        }
    }

    private func instrumentalChoiceCard(_ choice: GrammarChoice) -> some View {
        let state = choiceButtonState(for: choice)
        return Button {
            onChoiceTapped(choice.id)
        } label: {
            HStack(spacing: SpacingTokens.large) {
                Image(systemName: "person.circle.fill")
                    .font(TypographyTokens.title(28))
                    .foregroundStyle(state.textColor)
                    .frame(width: 56, height: 56)

                Text(choice.text)
                    .font(TypographyTokens.headline(22))
                    .foregroundStyle(state.textColor)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)

                Spacer()

                Image(systemName: stateIcon(for: choice))
                    .foregroundStyle(state.border)
                    .font(TypographyTokens.headline(22))
            }
            .padding(SpacingTokens.cardPad)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(state.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .strokeBorder(state.border, lineWidth: state.borderWidth)
                    )
            )
        }
        .frame(maxWidth: .infinity, minHeight: isSmallDevice ? 60 : 72)
        .disabled(selectedChoiceId != nil && selectedChoiceId == correctChoiceId)
        .accessibilityLabel(choice.text)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(selectedChoiceId == choice.id ? .isSelected : [])
    }

    private var partyModeView: some View {
        VStack(spacing: SpacingTokens.xLarge) {
            Text(String(localized: "grammar.game.party.title", bundle: .main))
                .font(.system(size: isSmallDevice ? 28 : 36, weight: .bold, design: .rounded))
                .foregroundStyle(ColorTokens.Kid.ink)
                .padding(.top, SpacingTokens.xxLarge)

            // Зона вечеринки — пустые места для гостей
            PartyGuestsGrid(
                confirmedCount: currentRoundIndex,
                totalGuests: totalRounds
            )
            .frame(height: 200)
            .padding(.horizontal, SpacingTokens.screenEdge)
            .accessibilityLabel(
                "\(String(localized: "grammar.game.party.title", bundle: .main)). " +
                "\(currentRoundIndex) гостей из \(totalRounds)"
            )

            // Карточка текущего гостя
            if !questionText.isEmpty {
                HSLiquidGlassCard {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .font(TypographyTokens.title(28))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .frame(width: 56, height: 56)
                        Text(questionText)
                            .font(TypographyTokens.headline(20))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                    }
                    .padding(SpacingTokens.cardPad)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            }

            // Варианты (в party mode — карточки)
            VStack(spacing: SpacingTokens.regular) {
                ForEach(choices) { choice in
                    instrumentalChoiceCard(choice)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
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

    private func hintView(_ hint: String) -> some View {
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

    private struct ChoiceButtonAppearance {
        let background: Color
        let border: Color
        let borderWidth: CGFloat
        let textColor: Color
    }

    private func choiceButtonState(for choice: GrammarChoice) -> ChoiceButtonAppearance {
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

    private func stateIcon(for choice: GrammarChoice) -> String {
        if let selected = selectedChoiceId {
            if choice.id == correctChoiceId { return "checkmark.circle.fill" }
            if choice.id == selected && selected != correctChoiceId { return "xmark.circle.fill" }
        }
        if selectedChoiceId == choice.id { return "circle.inset.filled" }
        return "circle"
    }

    // MARK: - Tap handler

    private func onChoiceTapped(_ choiceId: String) {
        guard selectedChoiceId == nil else { return }    // блокируем повторный выбор
        selectedChoiceId = choiceId
        Task {
            await interactor.evaluateAnswer(
                .init(selectedChoiceId: choiceId, roundIndex: currentRoundIndex)
            )
        }
    }

    // MARK: - GrammarGameDisplayLogic (вызываются через GrammarGameDisplayHost)

    func displayLoadGame(_ viewModel: GrammarGameModels.LoadGame.ViewModel) {
        modeTitle = viewModel.modeTitle
        difficultyLabel = viewModel.difficultyLabel
        totalRounds = viewModel.totalRounds
        isLoading = false
    }

    func displayRound(_ viewModel: GrammarGameModels.PresentRound.ViewModel) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) {
            questionText   = viewModel.questionText
            choices        = viewModel.choices
            imageName      = viewModel.imageName
            roundExtraData = viewModel.extraData
            audioFile      = viewModel.audioFile
            currentRoundIndex = viewModel.roundIndex
            selectedChoiceId = nil
            correctChoiceId  = nil
            feedbackText     = ""
            hintText         = nil
            showHint         = false
            dragFeedbackPhrase = ""
            dragIsCorrect    = nil
            showRewardBurst  = false
        }
    }

    func displayEvaluateAnswer(_ viewModel: GrammarGameModels.EvaluateAnswer.ViewModel) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.4)) {
            correctChoiceId = viewModel.correctChoiceId
            feedbackText    = viewModel.feedbackText
            hintText        = viewModel.hintText
            showHint        = viewModel.showHint
        }
        if viewModel.isCorrect {
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.2)) {
                showRewardBurst = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                withAnimation { showRewardBurst = false }
            }
        }
    }

    func displayDragDrop(_ viewModel: GrammarGameModels.DragDrop.ViewModel) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.4)) {
            dragFeedbackPhrase = viewModel.feedbackPhrase
            dragIsCorrect      = viewModel.isCorrect
            if viewModel.isCorrect {
                correctChoiceId  = viewModel.correctCharacterId
                selectedChoiceId = viewModel.droppedCharacterId
                showRewardBurst  = true
            }
        }
        if viewModel.isCorrect {
            Task {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                withAnimation { showRewardBurst = false }
                try? await Task.sleep(nanoseconds: 600_000_000)
                await interactor.advanceToNextRound()
            }
        }
    }

    func displaySessionComplete(_ viewModel: GrammarGameModels.SessionComplete.ViewModel) {
        sessionResultText   = viewModel.resultText
        sessionSuccessRate  = viewModel.successRate
        sessionCorrectCount = viewModel.correctCount
        totalRounds         = viewModel.totalRounds
        showSessionReward   = viewModel.showReward
        withAnimation(reduceMotion ? nil : .spring(response: 0.5)) {
            showSessionComplete = true
            if viewModel.showReward { showRewardBurst = true }
        }
        if viewModel.showReward {
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation { showRewardBurst = false }
            }
        }
    }

    func displayExitConfirmation(_ viewModel: GrammarGameModels.ExitConfirmation.ViewModel) {
        exitViewModel = viewModel
        showExitSheet = true
    }

    func displayError(_ message: String) {
        errorMessage = message
        isLoading = false
    }

    /// Создаёт GrammarGameDisplayHost, привязанный к этому view.
    /// Используется при внедрении GrammarGamePresenter.
    @MainActor
    func makeDisplayHost() -> GrammarGameDisplayHost {
        let host = GrammarGameDisplayHost()
        host.onLoadGame        = { [self] vm in displayLoadGame(vm) }
        host.onRound           = { [self] vm in displayRound(vm) }
        host.onEvaluate        = { [self] vm in displayEvaluateAnswer(vm) }
        host.onDragDrop        = { [self] vm in displayDragDrop(vm) }
        host.onSessionComplete = { [self] vm in displaySessionComplete(vm) }
        host.onExitConfirm     = { [self] vm in displayExitConfirmation(vm) }
        host.onError           = { [self] msg in displayError(msg) }
        return host
    }
}

// MARK: - PluralPreviewGrid

/// Сетка из 5 копий иконки предмета (анимация «много»).
private struct PluralPreviewGrid: View {
    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 8
        ) {
            ForEach(0..<5, id: \.self) { _ in
                Image(systemName: "circle.fill")
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Brand.primary.opacity(0.7))
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Brand.primary.opacity(0.08))
        )
    }
}

// MARK: - DativeDropTargetView

private struct DativeDropTargetView: View {
    let character: DativeCharacter
    let isHighlighted: Bool
    var isSmall: Bool = false

    private let frameWidth: CGFloat
    private let frameHeight: CGFloat

    init(character: DativeCharacter, isHighlighted: Bool, isSmall: Bool = false) {
        self.character = character
        self.isHighlighted = isHighlighted
        self.isSmall = isSmall
        self.frameWidth  = isSmall ? 80 : 100
        self.frameHeight = isSmall ? 100 : 120
    }

    var body: some View {
        VStack(spacing: SpacingTokens.small) {
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(isHighlighted
                          ? ColorTokens.Brand.primary.opacity(0.15)
                          : ColorTokens.Kid.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .strokeBorder(
                                isHighlighted ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                                lineWidth: isHighlighted ? 3 : 1.5
                            )
                    )
                    .frame(width: frameWidth, height: frameHeight)

                Image(systemName: "person.circle.fill")
                    .font(TypographyTokens.kidDisplay(40))
                    .foregroundStyle(ColorTokens.Brand.primary)
            }

            Text(character.dativeName)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityLabel("\(character.dativeName), поле для перетаскивания")
        .accessibilityHint(String(localized: "grammar.game.accessibility.drop_here", bundle: .main))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - GenitiveSceneView

private struct GenitiveSceneView: View {
    let containers: [GenitiveContainer]
    let selectedContainerId: String?
    let correctContainerId: String?

    var body: some View {
        ZStack {
            // Фон сцены (заглушка)
            Color.clear

            // Ляля держит предмет в верхней части
            Image(systemName: "person.fill")
                .font(TypographyTokens.kidDisplay(40))
                .foregroundStyle(ColorTokens.Brand.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 20)

            // Контейнеры в нижней части
            HStack(spacing: SpacingTokens.large) {
                ForEach(containers) { container in
                    ContainerTapTargetView(
                        container: container,
                        isSelected: selectedContainerId == container.id,
                        isCorrect: correctContainerId == container.id
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SpacingTokens.xLarge)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, SpacingTokens.xLarge)
        }
    }
}

// MARK: - ContainerTapTargetView

private struct ContainerTapTargetView: View {
    let container: GenitiveContainer
    let isSelected: Bool
    let isCorrect: Bool

    var body: some View {
        VStack(spacing: SpacingTokens.tiny) {
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .strokeBorder(borderColor, lineWidth: borderWidth)
                    )
                Image(systemName: "cube.box.fill")
                    .font(TypographyTokens.kidDisplay(32))
                    .foregroundStyle(ColorTokens.Brand.primary)
            }
            .frame(width: 80, height: 88)

            Text(container.genitiveName)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .accessibilityLabel("\(container.genitiveName), нажмите чтобы выбрать")
        .accessibilityAddTraits(.isButton)
    }

    private var backgroundColor: Color {
        if isCorrect { return ColorTokens.Semantic.successBg }
        if isSelected { return ColorTokens.Semantic.errorBg }
        return ColorTokens.Kid.surface
    }

    private var borderColor: Color {
        if isCorrect { return ColorTokens.Semantic.success }
        if isSelected { return ColorTokens.Semantic.error }
        return ColorTokens.Kid.line
    }

    private var borderWidth: CGFloat { isSelected || isCorrect ? 3 : 1.5 }
}

// MARK: - PartyGuestsGrid

private struct PartyGuestsGrid: View {
    let confirmedCount: Int
    let totalGuests: Int

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.regular), count: 3),
            spacing: SpacingTokens.regular
        ) {
            ForEach(0..<totalGuests, id: \.self) { idx in
                if idx < confirmedCount {
                    // Прибывший гость
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Brand.primary.opacity(0.15))
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(TypographyTokens.title(28))
                                .foregroundStyle(ColorTokens.Brand.primary)
                        )
                        .transition(.scale.animation(.spring(response: 0.5).delay(Double(idx) * 0.1)))
                } else {
                    // Пустое место
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                        .foregroundStyle(ColorTokens.Kid.line)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: "person.badge.plus")
                                .font(TypographyTokens.headline(22))
                                .foregroundStyle(ColorTokens.Kid.inkSoft)
                        )
                }
            }
        }
    }
}
