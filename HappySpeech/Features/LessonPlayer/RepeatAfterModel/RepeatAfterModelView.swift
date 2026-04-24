import SwiftUI

// MARK: - RepeatAfterModelView
//
// "Повтори за Лялей": плеер проигрывает эталон, ребёнок жмёт
// микрофон и произносит. Транскрипт + confidence из `ASRService`
// прокидываются в интерактор, тот считает score.
//
// Фазы:
//   loading → wordPreview → recording → feedback → wordPreview → … → completed
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
    @State private var sessionStarted: Bool = false
    @State private var asrTask: Task<Void, Never>?

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
        .onDisappear {
            asrTask?.cancel()
            asrTask = nil
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
        case .recording:
            recordingView
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
            wordCard
            Spacer(minLength: 0)
            wordPreviewBottom
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    @ViewBuilder
    private var wordCard: some View {
        if let word = display.currentWord {
            VStack(spacing: SpacingTokens.medium) {
                Text(word.emoji)
                    .font(.system(size: 96))
                    .accessibilityHidden(true)
                Text(word.word)
                    .font(TypographyTokens.kidDisplay(40))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                Text(display.syllabification)
                    .font(TypographyTokens.body(16))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                Text(display.attemptsLabel)
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Brand.primary)
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
            HSButton(
                String(localized: "repeat.button.listen"),
                style: .secondary,
                icon: "speaker.wave.2.fill"
            ) {
                container.soundService.playUISound(.tap)
            }
            .accessibilityHint(String(localized: "repeat.button.listen.hint"))

            HSButton(
                String(localized: "repeat.button.record"),
                style: .primary,
                icon: "mic.fill"
            ) {
                startRecording()
            }
            .accessibilityHint(String(localized: "repeat.button.record.hint"))
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    // MARK: - Recording

    private var recordingView: some View {
        VStack(spacing: SpacingTokens.large) {
            header
            Spacer(minLength: 0)
            recordingBody
            Spacer(minLength: 0)
            HSButton(
                String(localized: "repeat.button.stop"),
                style: .primary,
                icon: "stop.fill"
            ) {
                stopRecording()
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
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
                    .font(.system(size: 96, weight: .bold))
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

    // MARK: - Feedback

    private var feedbackView: some View {
        VStack(spacing: SpacingTokens.large) {
            header
            Spacer(minLength: 0)
            feedbackBody
            Spacer(minLength: 0)
            feedbackBottom
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    private var feedbackBody: some View {
        VStack(spacing: SpacingTokens.medium) {
            if display.passed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 120, weight: .bold))
                    .foregroundStyle(ColorTokens.Brand.mint)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 96, weight: .bold))
                    .foregroundStyle(ColorTokens.Brand.sky)
                    .accessibilityHidden(true)
            }
            Text(display.feedbackText)
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)

            HSProgressBar(value: Double(display.score))
                .frame(height: 10)
                .padding(.horizontal, SpacingTokens.xLarge)

            Text(display.attemptsLabel)
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(display.feedbackText)
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
                        .font(.system(size: 44, weight: .bold))
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
        case .loading:      return .thinking
        case .wordPreview:  return .explaining
        case .recording:    return .encouraging
        case .feedback:     return display.passed ? .celebrating : .encouraging
        case .completed:    return .happy
        }
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

    // MARK: - Flow helpers

    private func startSessionOnce() {
        guard !sessionStarted else { return }
        sessionStarted = true
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
        display.phase = .feedback
    }

    func displayCompleteSession(_ viewModel: RepeatAfterModelModels.CompleteSession.ViewModel) {
        display.starsEarned = viewModel.starsEarned
        display.scoreLabel = viewModel.scoreLabel
        display.completionMessage = viewModel.message
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
