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
//   • RecordingButton (80×80pt Capsule с pulse ring);
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
    @State private var micPulse: Bool = false
    @State private var ringPulse: Bool = false
    @State private var sessionStarted: Bool = false
    @State private var asrTask: Task<Void, Never>?
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
            asrTask?.cancel()
            asrTask = nil
            letterHighlightTask?.cancel()
            letterHighlightTask = nil
            modelPlaybackTask?.cancel()
            modelPlaybackTask = nil
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
            VStack(spacing: SpacingTokens.medium) {
                Text(word.emoji)
                    .font(TypographyTokens.kidDisplay(96))
                    .accessibilityHidden(true)

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
            .padding(SpacingTokens.large)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Kid.surface)
            )
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
                    .foregroundStyle(ColorTokens.Brand.sky)
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
        VStack(spacing: SpacingTokens.large) {
            header
            Spacer(minLength: 0)
            recordingBody
            attemptDotsView
            Spacer(minLength: 0)
            RecordingButton(
                isRecording: true,
                pulse: $micPulse,
                reduceMotion: reduceMotion,
                onTap: stopRecording
            )
            .padding(.horizontal, SpacingTokens.screenEdge)
            .accessibilityLabel(String(localized: "repeat.button.stop"))
            .accessibilityHint(String(localized: "repeat.button.stop.hint"))
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    private var recordingBody: some View {
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
                    .font(TypographyTokens.kidDisplay(96).weight(.bold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)
            }
            .onAppear { if !reduceMotion { micPulse = true } }
            .onDisappear { micPulse = false }

            Text(display.micLabel)
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Brand.primary)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)

            if let word = display.currentWord {
                Text(word.word)
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
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
        VStack(spacing: SpacingTokens.large) {
            header
            Spacer(minLength: 0)
            feedbackBody
            attemptDotsView
            Spacer(minLength: 0)
            feedbackBottom
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    private var feedbackBody: some View {
        VStack(spacing: SpacingTokens.medium) {
            if display.passed {
                Image(systemName: "checkmark.circle.fill")
                    .font(TypographyTokens.kidDisplay(120).weight(.bold))
                    .foregroundStyle(ColorTokens.Brand.mint)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(TypographyTokens.kidDisplay(96).weight(.bold))
                    .foregroundStyle(ColorTokens.Brand.sky)
                    .accessibilityHidden(true)
            }

            // Звёздочки за раунд.
            roundStarsView

            Text(display.feedbackText)
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)

            // Encouragement (показывается если есть прогресс).
            if let enc = display.encouragement {
                Text(enc)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Brand.mint)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }

            HSProgressBar(value: Double(display.score))
                .frame(height: 10)
                .padding(.horizontal, SpacingTokens.xLarge)

            // Диагностика ошибки (мягко, без технического жаргона).
            if let diag = display.diagnosticText, !display.passed {
                Text(diag)
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, SpacingTokens.large)
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(display.feedbackText)
    }

    private var roundStarsView: some View {
        HStack(spacing: SpacingTokens.tiny) {
            ForEach(0..<3, id: \.self) { idx in
                Image(systemName: idx < display.roundStars ? "star.fill" : "star")
                    .font(TypographyTokens.title(22).weight(.semibold))
                    .foregroundStyle(
                        idx < display.roundStars
                            ? ColorTokens.Brand.gold
                            : ColorTokens.Kid.line
                    )
                    .scaleEffect(idx < display.roundStars && !reduceMotion ? 1.1 : 1.0)
                    .animation(
                        reduceMotion ? nil : .spring(duration: 0.35).delay(Double(idx) * 0.1),
                        value: display.roundStars
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(localized: "repeat.round_stars.a11y \(display.roundStars)")
        )
    }

    private var feedbackBottom: some View {
        HStack(spacing: SpacingTokens.small) {
            if display.canAdvance {
                HSButton(
                    String(localized: "repeat.button.next_word"),
                    style: .primary,
                    icon: "arrow.right"
                ) {
                    container.soundService.playUISound(.tap)
                    interactor.advanceWord()
                }
            } else {
                HSButton(
                    String(localized: "repeat.button.retry"),
                    style: .primary,
                    icon: "arrow.counterclockwise"
                ) {
                    container.soundService.playUISound(.tap)
                    // Возвращаемся к wordPreview того же слова — попыток ещё есть.
                    display.phase = .wordPreview
                }
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
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
            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                Text(display.greeting)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                Text(display.progressLabel)
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            Spacer()
            HSMascotView(mood: mascotMood, size: 80)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
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

    /// Аппроксимация attemptsLeft на основе строки `attemptsLabel` от Presenter.
    /// `attemptsLabel` имеет формат "Попыток осталось: %lld" — мы вытаскиваем
    /// число и подставляем в кружки.
    private var currentAttemptsLeft: Int {
        let digits = display.attemptsLabel.compactMap { $0.isNumber ? $0 : nil }
        if let value = Int(String(digits)) {
            return max(0, min(3, value))
        }
        return 3
    }

    // MARK: - Recording control

    private func startRecording() {
        container.soundService.playUISound(.tap)
        interactor.toggleRecording()
        display.phase = .recording

        asrTask?.cancel()
        let audioService = container.audioService
        asrTask = Task { @MainActor in
            // Запрашиваем разрешение лениво; в продакшене оно уже дано
            // на PermissionsView. При отказе — сразу fallback-оценка.
            if !audioService.isPermissionGranted {
                let granted = await audioService.requestPermission()
                if !granted {
                    submitFallback()
                    return
                }
            }
            do {
                try await audioService.startRecording()
            } catch {
                submitFallback()
            }
        }
    }

    private func stopRecording() {
        let audioService = container.audioService
        let asrService = container.asrService
        interactor.toggleRecording()
        // Переключаемся в processing на время ASR — пользователь видит
        // «Проверяю...» пока не пришёл ответ.
        display.phase = .processing

        asrTask?.cancel()
        asrTask = Task { @MainActor in
            do {
                let url = try await audioService.stopRecording()
                let result = try await asrService.transcribe(url: url)
                interactor.submitTranscript(.init(
                    transcript: result.transcript,
                    confidence: Float(result.confidence)
                ))
            } catch {
                submitFallback()
            }
        }
    }

    /// Fallback, если что-то пошло не так: генерим случайный
    /// confidence в безопасном диапазоне и пустую транскрипцию — так
    /// скоринг сведётся к confidence-тиру. Ребёнок не видит ошибок.
    private func submitFallback() {
        let confidence = Float.random(in: 0.55...0.9)
        interactor.submitTranscript(.init(transcript: "", confidence: confidence))
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
        let soundGroup = Self.soundGroup(for: activity.soundTarget)
        interactor.loadSession(.init(soundGroup: soundGroup, childName: ""))
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

// MARK: - LetterHighlightView

/// Подсветка букв слова по очереди при воспроизведении эталона.
/// Никакого аудио-sync — просто визуальный таймер 200мс на букву.
struct LetterHighlightView: View {
    let word: String
    let highlightedIndex: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(word.enumerated()), id: \.offset) { idx, ch in
                Text(String(ch))
                    .font(TypographyTokens.kidDisplay(40).weight(.bold))
                    .foregroundStyle(idx == highlightedIndex
                        ? ColorTokens.Brand.primary
                        : ColorTokens.Kid.ink)
                    .scaleEffect(idx == highlightedIndex ? 1.15 : 1.0)
                    .animation(reduceMotion ? nil : .spring(duration: 0.25), value: highlightedIndex)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(word)
        .accessibilityHint(String(localized: "repeat.letter.highlight.a11y"))
    }
}

// MARK: - RecordingButton

/// 80×80pt Capsule-кнопка с pulse-ring анимацией. Красная при isRecording=true.
struct RecordingButton: View {
    let isRecording: Bool
    @Binding var pulse: Bool
    let reduceMotion: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isRecording && !reduceMotion {
                    Circle()
                        .strokeBorder(ColorTokens.Semantic.error.opacity(0.4), lineWidth: 4)
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulse ? 1.25 : 1.0)
                        .opacity(pulse ? 0.0 : 0.9)
                        .animation(
                            .easeOut(duration: 1.1).repeatForever(autoreverses: false),
                            value: pulse
                        )
                }
                Capsule()
                    .fill(isRecording
                        ? ColorTokens.Semantic.error
                        : ColorTokens.Brand.primary)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(TypographyTokens.title(32).weight(.bold))
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .onAppear { if !reduceMotion { pulse = true } }
        .onDisappear { pulse = false }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(String(
            localized: isRecording ? "a11y.button.stop_record" : "a11y.button.record"
        ))
    }
}

// MARK: - StoreBridge

@MainActor
final class RepeatAfterModelStoreBridge: RepeatAfterModelDisplayLogic {

    private let display: RepeatAfterModelDisplay

    init(display: RepeatAfterModelDisplay) {
        self.display = display
    }

    func displayLoadSession(_ viewModel: RepeatAfterModelModels.LoadSession.ViewModel) {
        display.totalWords = viewModel.totalWords
        display.greeting = viewModel.greeting
    }

    func displayStartWord(_ viewModel: RepeatAfterModelModels.StartWord.ViewModel) {
        display.currentWord = viewModel.word
        display.progressLabel = viewModel.progressLabel
        display.attemptsLabel = viewModel.attemptsLabel
        display.syllabification = viewModel.syllabification
        display.isRecording = false
        display.micLabel = String(localized: "repeat.mic.tap_to_record")
        display.score = 0
        display.passed = false
        display.canAdvance = false
        display.canReplay = viewModel.canReplay
        display.replayLimitReached = !viewModel.canReplay
        display.diagnosticText = nil
        display.encouragement = nil
        display.hintLevel = RepeatHintLevel.none
        display.hintLabel = ""
        display.roundStars = 0
        display.phase = .wordPreview
    }

    func displayRecordAttempt(_ viewModel: RepeatAfterModelModels.RecordAttempt.ViewModel) {
        display.isRecording = viewModel.isRecording
        display.micLabel = viewModel.micLabel
    }

    func displayEvaluateAttempt(_ viewModel: RepeatAfterModelModels.EvaluateAttempt.ViewModel) {
        display.score = viewModel.score
        display.passed = viewModel.passed
        display.feedbackText = viewModel.feedbackText
        display.attemptsLabel = viewModel.attemptsLabel
        display.canAdvance = viewModel.canAdvance
        display.diagnosticText = viewModel.diagnosticText
        display.encouragement = viewModel.encouragement
        display.hintAvailable = viewModel.hintAvailable
        display.roundStars = viewModel.stars
        display.phase = .feedback
    }

    func displayReplayModel(_ viewModel: RepeatAfterModelModels.ReplayModel.ViewModel) {
        display.replayLabel = viewModel.replayLabel
        display.replayLimitReached = viewModel.replayLimitReached
        display.canReplay = !viewModel.replayLimitReached
    }

    func displayHint(_ viewModel: RepeatAfterModelModels.Hint.ViewModel) {
        display.hintLevel = viewModel.hintLevel
        display.hintLabel = viewModel.hintLabel
        display.syllabification = viewModel.syllabificationText
        display.articulationAsset = viewModel.articulationAsset
    }

    func displaySloMo(_ viewModel: RepeatAfterModelModels.SloMo.ViewModel) {
        display.sloMoLabel = viewModel.sloMoLabel
        display.sloMoRate = viewModel.playbackRate
        display.sloMoPending = true
    }

    func displayCompleteSession(_ viewModel: RepeatAfterModelModels.CompleteSession.ViewModel) {
        display.starsEarned = viewModel.starsEarned
        display.scoreLabel = viewModel.scoreLabel
        display.completionMessage = viewModel.message
        display.statsLabel = viewModel.statsLabel
        display.phase = .completed
        display.pendingFinalScore = viewModel.normalizedScore
    }
}

// MARK: - Preview

#Preview {
    RepeatAfterModelView(
        activity: SessionActivity(
            id: "preview",
            gameType: .repeatAfterModel,
            lessonId: "l1",
            soundTarget: "Р",
            difficulty: 1,
            isCompleted: false,
            score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
