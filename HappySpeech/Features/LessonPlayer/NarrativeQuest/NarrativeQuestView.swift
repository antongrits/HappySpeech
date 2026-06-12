import OSLog
import SwiftUI

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
    @State private var overlayTask: Task<Void, Never>?
    @State private var micPulse = false

    // MARK: - Constants

    private static let successOverlayDuration: Duration = .milliseconds(1300)

    private let logger = Logger(subsystem: "ru.happyspeech", category: "NarrativeQuest")

    // MARK: - Init

    init(activity: SessionActivity, onComplete: @escaping (Float) -> Void) {
        self.activity = activity
        self.onComplete = onComplete

        let display = NarrativeQuestDisplay()
        let presenter = NarrativeQuestPresenter()
        // Block H: narrationService подключается в .task через container,
        // чтобы не зависеть от @Environment в init (недоступен вне body).
        let interactor = NarrativeQuestInteractor(presenter: presenter, narrationService: nil)
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
        .onChange(of: display.showSuccessOverlay) { _, isShown in
            // gap #10: оверлей показывает StoreBridge из EvaluateWord — здесь
            // лишь чистая UI-анимация авто-скрытия (без доступа к сервисам).
            if isShown { scheduleOverlayDismiss() }
        }
        .onDisappear {
            overlayTask?.cancel()
            // recordingTask/autoStopTask отменяются в interactor.cancel() (gap #10).
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
        VStack(spacing: SpacingTokens.medium) {
            header

            // P0.5 v32: glass CTA footer — ScrollView + safeAreaInset glass pill.
            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.small) {
                    Image(systemName: display.finalRewardEmoji)
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(ColorTokens.Brand.gold)
                        .accessibilityHidden(true)

                    Text(display.questTitle)
                        .font(TypographyTokens.title(24))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)

                    lyalyaBubble(text: display.introNarration)
                        .padding(.horizontal, SpacingTokens.screenEdge)
                }
                .padding(.top, SpacingTokens.small)
                .padding(.bottom, SpacingTokens.sp16)
            }
            .scrollBounceBehavior(.basedOnSize)
            .glassCTAFooter {
                HSButton(String(localized: "Начать"), style: .primary, icon: "sparkles") {
                    container.soundService.playUISound(.tap)
                    container.hapticService.selection()
                    interactor.startStage(.init(stageIndex: 0))
                }
                .accessibilityIdentifier("gameNextButton")
                .accessibilityHint(String(localized: "Начнёт первый этап квеста"))
            }
        }
        .padding(.vertical, SpacingTokens.regular)
    }

    // MARK: - Stage narration

    private var stageNarrationView: some View {
        VStack(spacing: SpacingTokens.small) {
            header
            stageIndicator

            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.small) {
                    lyalyaBubble(text: display.narration)
                    taskCard
                    targetWordChip

                    // Block H: кнопка-подсказки — загружает LLM hint в фоне.
                    HintButtonView(
                        gameType: "narrative_quest",
                        currentStep: "\(display.stageNumber)"
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, SpacingTokens.small)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.small)
            }
            .scrollBounceBehavior(.basedOnSize)

            HSButton(String(localized: "Я готов!"), style: .primary, icon: "mic.fill") {
                container.soundService.playUISound(.tap)
                // gap #10: запись/ASR в Interactor — View шлёт только интент.
                interactor.startListeningIntent(stageIndex: display.stageNumber - 1)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .accessibilityHint(String(localized: "Начнёт запись голоса"))
        }
        .padding(.vertical, SpacingTokens.regular)
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
                        .font(TypographyTokens.kidDisplay(88))
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
                interactor.stopListeningEarlyIntent()
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
                        .font(TypographyTokens.kidDisplay(96))
                        .foregroundStyle(ColorTokens.Brand.mint)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(TypographyTokens.kidDisplay(80))
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

            Image(systemName: display.finalRewardEmoji)
                .font(.system(size: 84, weight: .bold))
                .foregroundStyle(ColorTokens.Brand.gold)
                .accessibilityHidden(true)

            if !display.collectedEmojis.isEmpty {
                HStack(spacing: SpacingTokens.tiny) {
                    ForEach(Array(display.collectedEmojis.enumerated()), id: \.offset) { _, emoji in
                        Text(emoji)
                            .font(TypographyTokens.kidDisplay(32))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "Собранные награды"))
            }

            HStack(spacing: SpacingTokens.tiny) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < display.starsEarned ? "star.fill" : "star")
                        .font(TypographyTokens.kidDisplay(40))
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
            .accessibilityIdentifier("gameNextButton")
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    // MARK: - Success overlay

    private var successOverlay: some View {
        ZStack {
            ColorTokens.Overlay.dimmer.ignoresSafeArea()
            HSLiquidGlassCard(
                style: .tinted(ColorTokens.Brand.mint),
                padding: SpacingTokens.large
            ) {
                VStack(spacing: SpacingTokens.small) {
                    HSContentSymbol(display.rewardEmoji, size: 64, tint: ColorTokens.Brand.gold)
                    Text(display.feedbackText)
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
            }
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
                        Text(emoji).font(TypographyTokens.headline(20))
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
        HSLiquidGlassCard(style: .primary) {
            HStack(alignment: .top, spacing: SpacingTokens.small) {
                LyalyaMascotView(state: .explaining, size: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                    Text(String(localized: "Ляля:"))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                    Text(text)
                        .font(TypographyTokens.body(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var taskCard: some View {
        HSLiquidGlassCard(style: .tinted(ColorTokens.Brand.butter)) {
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
        // Block H: подключаем narrationService из AppContainer до loadQuest.
        interactor.connect(narrationService: container.kidLLMNarrationService)
        // F1-016: планировщик повторов из контейнера — исход слова на каждом
        // этапе попадает в дневное расписание повторений.
        interactor.connect(reviewScheduler: container.reviewScheduler)
        // gap #10: запись/ASR живут в Interactor — внедряем сервисы по DI.
        interactor.connect(
            audioService: container.audioService,
            asrService: container.asrService
        )
        interactor.loadQuest(.init(
            soundTarget: activity.soundTarget,
            childName: "",
            childId: container.currentChildId
        ))
        logger.debug("NarrativeQuest bootstrap soundTarget=\(activity.soundTarget, privacy: .public)")
    }

    // MARK: - Success overlay dismissal
    //
    // gap #10: пайплайн записи/ASR вынесен в Interactor — View лишь шлёт
    // интенты (startListeningIntent/stopListeningEarlyIntent). Авто-скрытие
    // success-оверлея — чистая UI-анимация: при появлении (`showSuccessOverlay`
    // выставляет StoreBridge из EvaluateWord) запускаем таймер и убираем его.

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
