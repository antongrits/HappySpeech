import SwiftUI

// MARK: - RepeatAfterModelView
//
// «Повтори за Лялей» — плеер проигрывает эталон, ребёнок жмёт микрофон и
// произносит. Транскрипт + confidence из `ASRService` прокидываются в
// интерактор, тот считает score.
//
// 7-фазный state machine (см. `RepeatPhase`):
//   loading → wordPreview → modelPlaying → waiting → recording
//           → processing → feedback → wordPreview … → completed
//
// UI-блоки:
//   • Header (Ляля + greeting + progress);
//   • WordCard (emoji, слово, подсветка букв, AttemptDots);
//   • RecordMicButton (большой центральный микрофон, эталон record-and-score);
//   • Feedback (✓ / ↻ + score bar);
//   • Completed (звёздочки + сообщение).
//
// Source of truth UI — `RepeatAfterModelDisplay` (@Observable store).

struct RepeatAfterModelView: View {

    // MARK: - API

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Store + VIP stack

    @State private var display: RepeatAfterModelDisplay
    private let interactor: RepeatAfterModelInteractor
    private let presenter: RepeatAfterModelPresenter
    private let bridge: RepeatAfterModelStoreBridge

    // Local UI-only state
    @State private var ringPulse: Bool = false
    @State private var sessionStarted: Bool = false
    @State private var letterHighlightTask: Task<Void, Never>?
    @State private var highlightedLetterIndex: Int = -1
    @State private var modelPlaybackTask: Task<Void, Never>?

    // MARK: - Init

    init(activity: SessionActivity, onComplete: @escaping (Float) -> Void) {
        self.activity = activity
        self.onComplete = onComplete

        let display = RepeatAfterModelDisplay()
        let interactor = RepeatAfterModelInteractor()
        let presenter = RepeatAfterModelPresenter()
        let bridge = RepeatAfterModelStoreBridge(display: display)

        interactor.presenter = presenter
        presenter.viewModel = bridge

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
        }
        .task { startSessionOnce() }
        .onChange(of: display.pendingFinalScore) { _, newScore in
            if let newScore { onComplete(newScore) }
        }
        .onChange(of: display.phase) { _, newPhase in
            handlePhaseChange(newPhase)
        }
        .onDisappear {
            letterHighlightTask?.cancel()
            letterHighlightTask = nil
            modelPlaybackTask?.cancel()
            modelPlaybackTask = nil
            // recordingTask отменяется внутри interactor.cancel() (gap #10).
            interactor.cancel()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "repeat.screen.a11y"))
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        switch display.phase {
        case .loading:
            loadingView
        case .wordPreview:
            wordPreviewView
        case .modelPlaying:
            modelPlayingView
        case .waiting:
            waitingView
        case .recording:
            recordingView
        case .processing:
            processingView
        case .feedback:
            feedbackView
        case .completed:
            completedView
        @unknown default:
            EmptyView()
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
            Text(String(localized: "repeat.loading"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    // MARK: - Word preview

    private var wordPreviewView: some View {
        VStack(spacing: SpacingTokens.large) {
            header
            Spacer(minLength: 0)
            wordCard(highlightActive: false)
            attemptDotsView
            Spacer(minLength: 0)
            wordPreviewBottom
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    @ViewBuilder
    private func wordCard(highlightActive: Bool) -> some View {
        if let word = display.currentWord {
            HSLiquidGlassCard(style: .primary, padding: SpacingTokens.large) {
                VStack(spacing: SpacingTokens.medium) {
                    HSContentSymbol(word.emoji, size: 96)

                    LetterHighlightView(
                        word: word.word,
                        highlightedIndex: highlightActive ? highlightedLetterIndex : -1
                    )

                    Text(display.syllabification)
                        .font(TypographyTokens.body(16))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(word.word)
            .accessibilityHint(display.syllabification)
        }
    }

    private var wordPreviewBottom: some View {
        VStack(spacing: SpacingTokens.small) {
            // Кнопка «Послушать» — replay эталона (до 3 раз).
            HSButton(
                display.replayLimitReached
                    ? String(localized: "repeat.replay.limit_reached")
                    : String(localized: "repeat.button.listen"),
                style: .secondary,
                icon: "speaker.wave.2.fill"
            ) {
                container.soundService.playUISound(.tap)
                interactor.replayModel(.init())
                triggerModelPlayback()
            }
            .disabled(display.replayLimitReached)
            .accessibilityHint(String(localized: "repeat.button.listen.hint"))

            HSButton(
                String(localized: "repeat.button.record"),
                style: .primary,
                icon: "mic.fill"
            ) {
                startRecording()
            }
            .accessibilityIdentifier("recordButton")
            .accessibilityHint(String(localized: "repeat.button.record.hint"))

            // Кнопка подсказки (только если ещё есть уровни).
            if display.hintLevel != RepeatHintLevel.sloMoReplay {
                Button {
                    container.soundService.playUISound(.tap)
                    interactor.requestHint(.init())
                } label: {
                    Label(
                        String(localized: "repeat.button.hint"),
                        systemImage: "lightbulb.fill"
                    )
                    .font(TypographyTokens.caption(14))
                    .foregroundStyle(ColorTokens.Brand.lilac)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "repeat.button.hint"))
                .accessibilityHint(String(localized: "repeat.button.hint.a11y"))
            }

            // Hint panel (показывается если hintLevel != .none).
            hintPanel
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    @ViewBuilder
    private var hintPanel: some View {
        switch display.hintLevel {
        case RepeatHintLevel.none:
            EmptyView()
        case RepeatHintLevel.syllabification:
            VStack(spacing: SpacingTokens.tiny) {
                Text(String(localized: "repeat.hint.syllabification"))
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                Text(display.syllabification)
                    .font(TypographyTokens.headline(22).weight(.bold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            .padding(SpacingTokens.small)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Brand.primary.opacity(0.08))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(display.syllabification)
        case RepeatHintLevel.articulationDiagram:
            VStack(spacing: SpacingTokens.tiny) {
                Text(String(localized: "repeat.hint.articulation"))
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                Image(display.articulationAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .accessibilityLabel(String(localized: "repeat.hint.articulation.a11y"))
            }
            .padding(SpacingTokens.small)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Kid.surface)
            )
        case RepeatHintLevel.sloMoReplay:
            VStack(spacing: SpacingTokens.tiny) {
                Text(String(localized: "repeat.hint.slomo"))
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                Button {
                    container.soundService.playUISound(.tap)
                    interactor.requestSloMo(.init(playbackRate: 0.75))
                    triggerModelPlayback()
                } label: {
                    Label(
                        String(localized: "repeat.button.slomo"),
                        systemImage: "tortoise.fill"
                    )
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Brand.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "repeat.button.slomo"))
            }
            .padding(SpacingTokens.small)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Brand.primary.opacity(0.08))
            )
        }
    }

    // MARK: - Model playing (Ляля произносит эталон)

    private var modelPlayingView: some View {
        VStack(spacing: SpacingTokens.large) {
            header
            Spacer(minLength: 0)
            wordCard(highlightActive: true)
            attemptDotsView
            Spacer(minLength: 0)

            VStack(spacing: SpacingTokens.tiny) {
                Image(systemName: "speaker.wave.3.fill")
                    .font(TypographyTokens.title(28).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating, value: ringPulse)
                    .accessibilityHidden(true)
                Text(String(localized: "repeat.phase.model_playing"))
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Brand.primary)
            }
            .padding(.bottom, SpacingTokens.large)
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    // MARK: - Waiting (приготовься)

    private var waitingView: some View {
        VStack(spacing: SpacingTokens.large) {
            header
            Spacer(minLength: 0)
            VStack(spacing: SpacingTokens.medium) {
                HSMascotView(mood: .pointing, size: 140)
                    .accessibilityHidden(true)
                Text(String(localized: "repeat.phase.waiting"))
                    .font(TypographyTokens.title(28))
                    .foregroundStyle(ColorTokens.Brand.primary)
            }
            attemptDotsView
            Spacer(minLength: 0)
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    // MARK: - Recording

    private var recordingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            header
            wordCard(highlightActive: false)
            Spacer(minLength: 0)

            // Большой центральный микрофон в стиле эталона (состояние записи).
            RecordMicButton(
                state: .recording,
                hint: display.micLabel,
                onTap: stopRecording
            )
            .padding(.horizontal, SpacingTokens.screenEdge)

            // Spectrogram visualizer — визуальный feedback голоса ребёнка.
            // Reduce Motion: SpectrogramVisualizerView сам переключается на StaticSpectrogramView.
            SpectrogramVisualizerView(
                referenceSpectrogram: nil,
                style: .warm
            )
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .padding(.horizontal, SpacingTokens.screenEdge)
            .accessibilityLabel(String(localized: "spectrogram.recording.a11y", defaultValue: "Визуализация твоего голоса"))

            // v31 Волна D Ф.4 — live транскрипт через SpeechAnalyzerService
            // (iOS 26 SpeechAnalyzer + WhisperKit fallback). Видим только в фазе
            // .recording, активируется автоматически.
            RepeatAfterModelLiveTranscriptView(isActive: display.phase == .recording)
                .padding(.horizontal, SpacingTokens.screenEdge)

            attemptDotsView
            Spacer(minLength: 0)
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    // MARK: - Processing

    private var processingView: some View {
        VStack(spacing: SpacingTokens.large) {
            header
            Spacer(minLength: 0)
            VStack(spacing: SpacingTokens.medium) {
                HSMascotView(mood: .thinking, size: 140)
                    .accessibilityHidden(true)
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)
                Text(String(localized: "repeat.phase.processing"))
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Kid.ink)
            }
            attemptDotsView
            Spacer(minLength: 0)
        }
        .padding(.vertical, SpacingTokens.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "repeat.phase.processing"))
    }

    // MARK: - Feedback

    private var feedbackView: some View {
        VStack(spacing: SpacingTokens.medium) {
            header
            wordCard(highlightActive: false)
            Spacer(minLength: 0)
            // Карточка результата в стиле эталона: кольцо счёта + звёзды +
            // ободряющий текст + Ляля.
            RecordLessonFeedbackCard(
                scoreFraction: Double(display.score),
                scoreCaption: nil,
                stars: display.roundStars,
                title: display.feedbackText,
                detail: feedbackDetail,
                passed: display.passed,
                ctaTitle: display.canAdvance
                    ? String(localized: "repeat.button.next_word")
                    : String(localized: "repeat.button.retry"),
                ctaIcon: display.canAdvance ? "arrow.right" : "arrow.counterclockwise",
                ctaIdentifier: "gameNextButton"
            ) {
                container.soundService.playUISound(.tap)
                if display.canAdvance {
                    interactor.advanceWord()
                } else {
                    // Возвращаемся к wordPreview того же слова — попыток ещё есть.
                    display.phase = .wordPreview
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            attemptDotsView
            Spacer(minLength: 0)
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    /// Объединяет encouragement и мягкую диагностику в одну строку описания
    /// для карточки результата.
    private var feedbackDetail: String? {
        var parts: [String] = []
        if let enc = display.encouragement, !enc.isEmpty { parts.append(enc) }
        if !display.passed, let diag = display.diagnosticText, !diag.isEmpty {
            parts.append(diag)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer(minLength: 0)
            HSMascotView(mood: .celebrating, size: 140)
                .accessibilityHidden(true)

            HStack(spacing: SpacingTokens.tiny) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < display.starsEarned ? "star.fill" : "star")
                        .font(TypographyTokens.display(44).weight(.bold))
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
                .font(TypographyTokens.headline(20))
                .foregroundStyle(ColorTokens.Kid.ink)

            Text(display.completionMessage)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.screenEdge)

            if !display.statsLabel.isEmpty {
                Text(display.statsLabel)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .accessibilityLabel(display.statsLabel)
            }

            Spacer(minLength: 0)

            HSButton(
                String(localized: "repeat.button.finish"),
                style: .primary,
                icon: "checkmark.circle.fill"
            ) {
                container.soundService.playUISound(.correct)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: SpacingTokens.small) {
            RecordLessonHeader(
                sound: Self.soundBadge(for: activity.soundTarget),
                subtitle: display.progressLabel,
                progress: headerProgress
            )
            HSMascotView(mood: mascotMood, size: 64)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    /// Доля прогресса для шапки: текущее слово из общего числа.
    private var headerProgress: Double {
        guard display.totalWords > 0 else { return 0 }
        let parsed = Self.parseWordIndex(display.progressLabel)
        return Double(parsed) / Double(display.totalWords)
    }

    /// Бейдж звука из soundTarget («Р», «С», …) — если короткий.
    static func soundBadge(for soundTarget: String) -> String {
        let trimmed = soundTarget.trimmingCharacters(in: .whitespaces)
        return trimmed.count <= 2 ? trimmed : ""
    }

    /// Извлекает индекс текущего слова из локализованной метки прогресса
    /// (первое число), чтобы заполнить полосу. Без числа → 0.
    static func parseWordIndex(_ label: String) -> Int {
        let digits = label.prefix { !$0.isNumber }.isEmpty
            ? label
            : String(label.drop { !$0.isNumber })
        let number = digits.prefix { $0.isNumber }
        return Int(number) ?? 0
    }

    private var mascotMood: MascotMood {
        switch display.phase {
        case .loading:       return .thinking
        case .wordPreview:   return .explaining
        case .modelPlaying:  return .singing
        case .waiting:       return .pointing
        case .recording:     return .encouraging
        case .processing:    return .thinking
        case .feedback:      return display.passed ? .celebrating : .encouraging
        case .completed:     return .happy
        }
    }

    // MARK: - Attempt dots

    /// 3 кружка под слово — закрашиваются по мере использованных попыток.
    /// Текущая попытка подсвечена брендовым цветом, использованные — серой
    /// заливкой, ещё не использованные — пустые.
    private var attemptDotsView: some View {
        let totalAttempts = 3
        let used = max(0, totalAttempts - max(0, totalAttempts - currentAttemptsLeft))
        let usedCount = totalAttempts - currentAttemptsLeft
        return HStack(spacing: SpacingTokens.tiny) {
            ForEach(0..<totalAttempts, id: \.self) { idx in
                attemptDot(index: idx, usedCount: usedCount)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            localized: "repeat.attempts.dot.a11y \(used) \(totalAttempts)"
        ))
    }

    private func attemptDot(index: Int, usedCount: Int) -> some View {
        let isUsed = index < usedCount
        let isCurrent = index == usedCount && index < 3
        return Circle()
            .fill(dotFill(isUsed: isUsed, isCurrent: isCurrent))
            .frame(width: 14, height: 14)
            .overlay(
                Circle().strokeBorder(ColorTokens.Kid.line, lineWidth: isUsed || isCurrent ? 0 : 1)
            )
    }

    private func dotFill(isUsed: Bool, isCurrent: Bool) -> Color {
        if isCurrent { return ColorTokens.Brand.primary }
        if isUsed { return ColorTokens.Kid.inkMuted.opacity(0.4) }
        return Color.clear
    }

    /// Оставшиеся попытки берутся напрямую из числового поля Display
    /// (`attemptsLeft`), которое заполняет Presenter из Interactor — без
    /// парсинга локализованной строки.
    private var currentAttemptsLeft: Int {
        max(0, min(3, display.attemptsLeft))
    }

    // MARK: - Recording control
    //
    // gap #10: пайплайн записи/ASR вынесен в Interactor — View лишь шлёт
    // интенты. Фазы .recording/.processing и обработка отказа/сбоя
    // (noInput, без фабрикации оценки) приходят обратно через Presenter.

    private func startRecording() {
        container.soundService.playUISound(.tap)
        interactor.startRecordingIntent()
    }

    private func stopRecording() {
        interactor.stopRecordingIntent()
    }

    // MARK: - Phase change handler (LetterHighlight + auto-progression)

    private func handlePhaseChange(_ newPhase: RepeatPhase) {
        switch newPhase {
        case .modelPlaying:
            startLetterHighlight()
        case .wordPreview, .recording, .processing, .feedback, .completed, .loading, .waiting:
            stopLetterHighlight()
        }
    }

    /// Автопроигрывание эталонного слова: переходит wordPreview → modelPlaying.
    /// Реальный аудио-asset не блокируем — играем UI-звук и запускаем
    /// псевдо-таймер длительности (200мс на букву), чтобы LetterHighlight
    /// дошёл до конца и сам перевёл фазу в waiting → wordPreview.
    private func triggerModelPlayback() {
        guard display.phase == .wordPreview else { return }
        display.phase = .modelPlaying
    }

    private func startLetterHighlight() {
        guard let word = display.currentWord?.word, !word.isEmpty else { return }
        ringPulse = true
        highlightedLetterIndex = -1
        letterHighlightTask?.cancel()
        letterHighlightTask = Task { @MainActor in
            let letters = Array(word)
            let stepMs: UInt64 = 200_000_000 // 200ms
            for idx in 0..<letters.count {
                if Task.isCancelled { return }
                highlightedLetterIndex = idx
                try? await Task.sleep(nanoseconds: stepMs)
            }
            if Task.isCancelled { return }
            highlightedLetterIndex = -1
            ringPulse = false
            // Короткая пауза «приготовиться», затем возвращаем в wordPreview.
            display.phase = .waiting
            try? await Task.sleep(nanoseconds: 600_000_000)
            if Task.isCancelled { return }
            display.phase = .wordPreview
        }
    }

    private func stopLetterHighlight() {
        letterHighlightTask?.cancel()
        letterHighlightTask = nil
        highlightedLetterIndex = -1
        ringPulse = false
    }

    // MARK: - Flow helpers

    private func startSessionOnce() {
        guard !sessionStarted else { return }
        sessionStarted = true
        // Block H: подключаем narrationService из AppContainer.
        interactor.connect(narrationService: container.kidLLMNarrationService)
        // F1-016: планировщик повторов из контейнера — исход каждого слова
        // попадает в дневное расписание повторений.
        interactor.connect(reviewScheduler: container.reviewScheduler)
        // gap #10: запись/ASR живут в Interactor — внедряем сервисы по DI.
        interactor.connect(
            audioService: container.audioService,
            asrService: container.asrService
        )
        let soundGroup = Self.soundGroup(for: activity.soundTarget)
        interactor.loadSession(.init(
            soundGroup: soundGroup,
            childName: "",
            childId: container.currentChildId
        ))
        interactor.startWord(.init(wordIndex: 0))
    }

    // MARK: - Sound group resolution

    static func soundGroup(for soundTarget: String) -> String {
        let trimmed = soundTarget.trimmingCharacters(in: .whitespaces)
        for family in SoundFamily.allCases where family.sounds.contains(trimmed) {
            return family.rawValue
        }
        return SoundFamily.whistling.rawValue
    }
}
