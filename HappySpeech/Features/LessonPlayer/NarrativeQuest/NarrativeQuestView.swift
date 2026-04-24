import SwiftUI
import OSLog

// MARK: - NarrativeQuestView
//
// «Квест с Лялей» — нарративная игра из 4 этапов. Ляля ведёт ребёнка
// через мини-историю, на каждом этапе произносится ключевое слово,
// результат влияет на финал. View — чистый SwiftUI, вся логика — в
// VIP-стеке (Interactor/Presenter).
//
// Фазы:
//   loading → questIntro → stageNarration → recording → stageFeedback
//           → (repeat для следующего этапа) → questComplete → completed

struct NarrativeQuestView: View {

    // MARK: - API

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    // MARK: - VIP stack

    @State private var display: NarrativeQuestDisplay
    private let interactor: NarrativeQuestInteractor
    private let presenter: NarrativeQuestPresenter
    private let bridge: NarrativeQuestStoreBridge

    // MARK: - Local UI state

    @State private var bootstrapped = false
    @State private var asrTask: Task<Void, Never>?
    @State private var autoStopTask: Task<Void, Never>?
    @State private var overlayTask: Task<Void, Never>?
    @State private var micPulse = false

    // MARK: - Constants

    private static let autoStopAfter: Duration = .seconds(3)
    private static let successOverlayDuration: Duration = .milliseconds(1300)

    private let logger = Logger(subsystem: "ru.happyspeech", category: "NarrativeQuest")

    // MARK: - Init

    init(activity: SessionActivity, onComplete: @escaping (Float) -> Void) {
        self.activity = activity
        self.onComplete = onComplete

        let display = NarrativeQuestDisplay()
        let presenter = NarrativeQuestPresenter()
        let interactor = NarrativeQuestInteractor(presenter: presenter)
        let bridge = NarrativeQuestStoreBridge(display: display)
        presenter.displayLogic = bridge

        self._display = State(initialValue: display)
        self.interactor = interactor
        self.presenter = presenter
        self.bridge = bridge
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            content
            if display.showSuccessOverlay {
                successOverlay
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .task { bootstrapOnce() }
        .onChange(of: display.pendingFinalScore) { _, newScore in
            if let newScore { onComplete(newScore) }
        }
        .onDisappear {
            asrTask?.cancel()
            autoStopTask?.cancel()
            overlayTask?.cancel()
            interactor.cancel()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Квест с Лялей"))
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        switch display.phase {
        case .loading:
            loadingView
        case .questIntro:
            questIntroView
        case .stageNarration:
            stageNarrationView
        case .recording:
            recordingView
        case .stageFeedback:
            stageFeedbackView
        case .questComplete, .completed:
            questCompleteView
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
                .tint(ColorTokens.Brand.primary)
            Text(String(localized: "Готовим квест…"))
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    // MARK: - Quest intro

    private var questIntroView: some View {
        VStack(spacing: SpacingTokens.large) {
            header
            Spacer(minLength: 0)

            VStack(spacing: SpacingTokens.medium) {
                Text(display.finalRewardEmoji)
                    .font(.system(size: 96))
                    .accessibilityHidden(true)

                Text(display.questTitle)
                    .font(TypographyTokens.title(28))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)

                lyalyaBubble(text: display.introNarration)
                    .padding(.horizontal, SpacingTokens.screenEdge)
            }

            Spacer(minLength: 0)

            HSButton(String(localized: "Начать квест!"), style: .primary, icon: "sparkles") {
                container.soundService.playUISound(.tap)
                container.hapticService.selection()
                interactor.startStage(.init(stageIndex: 0))
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .accessibilityHint(String(localized: "Начнёт первый этап квеста"))
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    // MARK: - Stage narration

    private var stageNarrationView: some View {
        VStack(spacing: SpacingTokens.medium) {
            header
            stageIndicator
            Spacer(minLength: 0)

            VStack(spacing: SpacingTokens.medium) {
                lyalyaBubble(text: display.narration)
                taskCard
                targetWordChip
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer(minLength: 0)

            HSButton(String(localized: "Я готов!"), style: .primary, icon: "mic.fill") {
                container.soundService.playUISound(.tap)
                interactor.recordWord(.init(stageIndex: display.stageNumber - 1))
                startListening()
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .accessibilityHint(String(localized: "Начнёт запись голоса"))
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    // MARK: - Recording

    private var recordingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            header
            stageIndicator
            Spacer(minLength: 0)

            VStack(spacing: SpacingTokens.medium) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.Brand.primary.opacity(0.12))
                        .frame(width: 220, height: 220)
                        .scaleEffect(reduceMotion ? 1.0 : (micPulse ? 1.12 : 1.0))
                        .animation(
                            reduceMotion
                                ? nil
                                : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                            value: micPulse
                        )
                    Image(systemName: "mic.fill")
                        .font(.system(size: 88, weight: .bold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .accessibilityHidden(true)
                }
                .onAppear { if !reduceMotion { micPulse = true } }
                .onDisappear { micPulse = false }

                Text(display.targetWord)
                    .font(TypographyTokens.kidDisplay(36))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, SpacingTokens.small)
                    .accessibilityLabel(display.targetWord)

                Text(display.micLabel.isEmpty ? String(localized: "Говори!") : display.micLabel)
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Brand.primary)
            }

            Spacer(minLength: 0)

            HSButton(String(localized: "Готово"), style: .secondary, icon: "stop.fill") {
                stopListeningEarly()
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .accessibilityHint(String(localized: "Остановить запись раньше"))
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    // MARK: - Stage feedback

    private var stageFeedbackView: some View {
        VStack(spacing: SpacingTokens.medium) {
            header
            stageIndicator
            Spacer(minLength: 0)

            VStack(spacing: SpacingTokens.medium) {
                if display.feedbackSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 96, weight: .bold))
                        .foregroundStyle(ColorTokens.Brand.mint)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(ColorTokens.Brand.sky)
                        .accessibilityHidden(true)
                }
                Text(display.feedbackText)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, SpacingTokens.screenEdge)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(display.feedbackText)

            Spacer(minLength: 0)
            // Auto-advance идёт из Interactor через scheduleAdvance —
            // дополнительных кнопок не нужно, ребёнок просто смотрит.
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    // MARK: - Quest complete

    private var questCompleteView: some View {
        VStack(spacing: SpacingTokens.medium) {
            Spacer(minLength: 0)

            HSMascotView(mood: .celebrating, size: 140)
                .accessibilityHidden(true)

            Text(display.finalRewardEmoji)
                .font(.system(size: 84))
                .accessibilityHidden(true)

            if !display.collectedEmojis.isEmpty {
                HStack(spacing: SpacingTokens.tiny) {
                    ForEach(Array(display.collectedEmojis.enumerated()), id: \.offset) { _, emoji in
                        Text(emoji)
                            .font(.system(size: 32))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "Собранные награды"))
            }

            HStack(spacing: SpacingTokens.tiny) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < display.starsEarned ? "star.fill" : "star")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(
                            index < display.starsEarned
                                ? ColorTokens.Brand.gold
                                : ColorTokens.Kid.line
                        )
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(display.scoreLabel)

            Text(display.scoreLabel)
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Kid.ink)

            Text(display.completionMessage)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer(minLength: 0)

            HSButton(String(localized: "Завершить"), style: .primary, icon: "checkmark.circle.fill") {
                container.soundService.playUISound(.correct)
                container.hapticService.notification(.success)
                onComplete(display.lastScore)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    // MARK: - Success overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.15).ignoresSafeArea()
            VStack(spacing: SpacingTokens.small) {
                Text(display.rewardEmoji)
                    .font(.system(size: 72))
                    .accessibilityHidden(true)
                Text(display.feedbackText)
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            .padding(SpacingTokens.large)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(ColorTokens.Brand.mint.opacity(0.95))
            )
            .padding(.horizontal, SpacingTokens.xLarge)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(display.feedbackText)
    }

    // MARK: - Reusable pieces

    private var header: some View {
        HStack(alignment: .center, spacing: SpacingTokens.small) {
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(display.questTitle)
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "Квест с Лялей"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            Spacer()
            HSMascotView(mood: mascotMood, size: 64)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    private var stageIndicator: some View {
        VStack(spacing: SpacingTokens.tiny) {
            HStack(alignment: .firstTextBaseline) {
                Text(stageLabel)
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(Array(display.collectedEmojis.enumerated()), id: \.offset) { _, emoji in
                        Text(emoji).font(.system(size: 20))
                    }
                }
                .accessibilityHidden(true)
            }
            HSProgressBar(value: display.progressFraction)
                .frame(height: 10)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stageLabel)
    }

    private var stageLabel: String {
        String(
            format: String(localized: "Этап %d из %d"),
            display.stageNumber,
            display.totalStages
        )
    }

    private func lyalyaBubble(text: String) -> some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                Text(String(localized: "Ляля:"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                Text(text)
                    .font(TypographyTokens.body(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var taskCard: some View {
        HSCard(style: .tinted(ColorTokens.Brand.butter.opacity(0.35))) {
            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                Text(String(localized: "Задача:"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                Text(display.task)
                    .font(TypographyTokens.body(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.9)
                if !display.hint.isEmpty {
                    Text(display.hint)
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .padding(.top, SpacingTokens.micro)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var targetWordChip: some View {
        Text(display.targetWord)
            .font(TypographyTokens.title(24))
            .foregroundStyle(ColorTokens.Brand.primary)
            .padding(.horizontal, SpacingTokens.medium)
            .padding(.vertical, SpacingTokens.small)
            .background(
                Capsule().fill(ColorTokens.Kid.surface)
            )
            .accessibilityLabel(
                String(format: String(localized: "Целевое слово: %@"), display.targetWord)
            )
    }

    private var mascotMood: MascotMood {
        switch display.phase {
        case .loading:          return .thinking
        case .questIntro:       return .waving
        case .stageNarration:   return .explaining
        case .recording:        return .encouraging
        case .stageFeedback:    return display.feedbackSuccess ? .celebrating : .encouraging
        case .questComplete:    return .celebrating
        case .completed:        return .happy
        }
    }

    // MARK: - Flow

    private func bootstrapOnce() {
        guard !bootstrapped else { return }
        bootstrapped = true
        interactor.loadQuest(.init(
            soundTarget: activity.soundTarget,
            childName: ""
        ))
        logger.debug("NarrativeQuest bootstrap soundTarget=\(activity.soundTarget, privacy: .public)")
    }

    // MARK: - Recording pipeline

    private func startListening() {
        asrTask?.cancel()
        let audioService = container.audioService
        asrTask = Task { @MainActor in
            // Разрешение на микрофон обычно уже выдано на PermissionsView.
            if !audioService.isPermissionGranted {
                let granted = await audioService.requestPermission()
                if !granted {
                    submitFallback()
                    return
                }
            }
            do {
                try await audioService.startRecording()
                scheduleAutoStop()
            } catch {
                logger.error("NarrativeQuest startRecording failed: \(error.localizedDescription)")
                submitFallback()
            }
        }
    }

    private func scheduleAutoStop() {
        autoStopTask?.cancel()
        autoStopTask = Task { @MainActor in
            try? await Task.sleep(for: Self.autoStopAfter)
            guard !Task.isCancelled else { return }
            stopListening()
        }
    }

    private func stopListeningEarly() {
        autoStopTask?.cancel()
        stopListening()
    }

    private func stopListening() {
        let audioService = container.audioService
        let asrService = container.asrService
        asrTask?.cancel()
        asrTask = Task { @MainActor in
            do {
                let url = try await audioService.stopRecording()
                let result = try await asrService.transcribe(url: url)
                submitTranscript(
                    transcript: result.transcript,
                    confidence: Float(result.confidence)
                )
            } catch {
                logger.error("NarrativeQuest stopRecording/transcribe failed: \(error.localizedDescription)")
                submitFallback()
            }
        }
    }

    private func submitTranscript(transcript: String, confidence: Float) {
        interactor.evaluateWord(.init(transcript: transcript, confidence: confidence))
        scheduleOverlayDismiss()
    }

    /// Fallback, когда запись/ASR упал: отправляем пустой transcript
    /// с умеренной confidence — скоринг даст мягкий пропуск, чтобы
    /// не ломать прогресс ребёнка.
    private func submitFallback() {
        let confidence: Float = 0.7
        interactor.evaluateWord(.init(transcript: "", confidence: confidence))
        scheduleOverlayDismiss()
    }

    private func scheduleOverlayDismiss() {
        overlayTask?.cancel()
        overlayTask = Task { @MainActor in
            try? await Task.sleep(for: Self.successOverlayDuration)
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                display.showSuccessOverlay = false
            }
        }
    }
}

// MARK: - StoreBridge

/// Тонкий bridge между презентером и `@Observable` store.
/// Обновляет свойства стора в главном потоке — View автоматически
/// реагирует через Observation framework.
@MainActor
final class NarrativeQuestStoreBridge: NarrativeQuestDisplayLogic {

    private let display: NarrativeQuestDisplay

    init(display: NarrativeQuestDisplay) {
        self.display = display
    }

    func displayLoadQuest(_ viewModel: NarrativeQuestModels.LoadQuest.ViewModel) {
        display.questTitle = viewModel.questTitle
        display.totalStages = viewModel.totalStages
        display.finalRewardEmoji = viewModel.finalRewardEmoji
        display.introNarration = viewModel.introNarration
        display.progressFraction = 0
        display.stageNumber = 0
        display.collectedEmojis = []
        display.phase = .questIntro
    }

    func displayStartStage(_ viewModel: NarrativeQuestModels.StartStage.ViewModel) {
        display.narration = viewModel.narration
        display.task = viewModel.task
        display.targetWord = viewModel.targetWord
        display.hint = viewModel.hint
        display.rewardEmoji = viewModel.rewardEmoji
        display.stageNumber = viewModel.stageNumber
        display.totalStages = viewModel.totalStages
        display.progressFraction = viewModel.progressFraction
        display.isListening = false
        display.showSuccessOverlay = false
        display.phase = .stageNarration
    }

    func displayRecordWord(_ viewModel: NarrativeQuestModels.RecordWord.ViewModel) {
        display.isListening = viewModel.isListening
        display.micLabel = viewModel.micLabel
        if viewModel.isListening {
            display.phase = .recording
        }
    }

    func displayEvaluateWord(_ viewModel: NarrativeQuestModels.EvaluateWord.ViewModel) {
        display.feedbackText = viewModel.feedbackText
        display.feedbackSuccess = viewModel.feedbackSuccess
        display.rewardEmoji = viewModel.rewardEmoji
        display.showSuccessOverlay = viewModel.showSuccessOverlay
        display.lastScore = viewModel.score
        display.phase = .stageFeedback
    }

    func displayAdvanceStage(_ viewModel: NarrativeQuestModels.AdvanceStage.ViewModel) {
        display.collectedEmojis = viewModel.collectedEmojis
        display.progressFraction = viewModel.progressFraction
        display.stageNumber = viewModel.stageNumber
        // Фаза меняется в startStage/completeQuest — здесь только накопление.
    }

    func displayCompleteQuest(_ viewModel: NarrativeQuestModels.CompleteQuest.ViewModel) {
        display.starsEarned = viewModel.starsEarned
        display.collectedEmojis = viewModel.collectedEmojis
        display.finalRewardEmoji = viewModel.finalRewardEmoji
        display.completionMessage = viewModel.completionMessage
        display.scoreLabel = viewModel.scoreLabel
        display.lastScore = viewModel.normalizedScore
        display.progressFraction = 1.0
        display.showSuccessOverlay = false
        display.phase = .questComplete
        display.pendingFinalScore = viewModel.normalizedScore
    }
}

// MARK: - Preview

#Preview {
    NarrativeQuestView(
        activity: SessionActivity(
            id: "preview",
            gameType: .narrativeQuest,
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
