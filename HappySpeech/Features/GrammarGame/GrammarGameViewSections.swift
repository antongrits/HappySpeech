import SwiftUI

// MARK: - GrammarGameView + GrammarGameDisplayLogic

extension GrammarGameView {

    // MARK: GrammarGameDisplayLogic (вызываются через GrammarGameDisplayHost)

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

    // MARK: Display Host factory

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

// MARK: - GrammarGameView + Game Mode Content Views

extension GrammarGameView {

    // MARK: - Dative Content (Кому что нужно — drag-and-drop)

    func dativeContentView(
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
    func nearestCharacterId(
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

    func genitiveContentView(
        containers: [GenitiveContainer],
        correctIndex: Int
    ) -> some View {
        VStack(spacing: SpacingTokens.xLarge) {
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

    func instrumentalContentView(partyMode: Bool) -> some View {
        VStack(spacing: SpacingTokens.xLarge) {
            if partyMode {
                partyModeView
            } else {
                standardInstrumentalView
            }
        }
    }

    var standardInstrumentalView: some View {
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

    func instrumentalChoiceCard(_ choice: GrammarChoice) -> some View {
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

    var partyModeView: some View {
        VStack(spacing: SpacingTokens.xLarge) {
            Text(String(localized: "grammar.game.party.title", bundle: .main))
                .font(.system(size: isSmallDevice ? 28 : 36, weight: .bold, design: .rounded))
                .foregroundStyle(ColorTokens.Kid.ink)
                .padding(.top, SpacingTokens.xxLarge)

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

            VStack(spacing: SpacingTokens.regular) {
                ForEach(choices) { choice in
                    instrumentalChoiceCard(choice)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
    }
}
