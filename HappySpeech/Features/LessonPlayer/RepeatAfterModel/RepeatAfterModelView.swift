import SwiftUI
import OSLog

// MARK: - RepeatAfterModelView
//
// "Повтори за Лялей": plays the reference audio for the target word, then
// enables the record button. The child holds the button and pronounces the
// word. WhisperKit transcribes, PronunciationScorer compares against the
// reference embedding, and the closure fires with a [0.0–1.0] score.
//
// For M6 baseline we ship the UI flow with a mocked scorer so SessionShell
// integration is end-to-end. The real pipeline lives in
// `AudioService` + `ASRService` + `PronunciationScorerService`, all wired
// through `AppContainer`.

struct RepeatAfterModelView: View {

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    @State private var phase: Phase = .idle
    @State private var score: Float?
    @Environment(AppContainer.self) private var container

    private let logger = Logger(subsystem: "ru.happyspeech", category: "RepeatAfterModel")

    enum Phase: Sendable {
        case idle
        case playingReference
        case recording
        case scoring
        case feedback
    }

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            header
            referenceButton
            recordButton
            if case .feedback = phase, let score {
                feedbackView(score: score)
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: SpacingTokens.tiny) {
            Text(String(localized: "Повтори за Лялей"))
                .font(TypographyTokens.title())
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(String(localized: "Звук: \(activity.soundTarget)"))
                .font(TypographyTokens.caption())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    private var referenceButton: some View {
        HSButton(
            String(localized: "Послушать"),
            style: .secondary,
            action: playReference
        )
        .disabled(phase == .playingReference || phase == .recording)
    }

    private var recordButton: some View {
        HSButton(
            phase == .recording ? String(localized: "Остановить") : String(localized: "Записать"),
            style: .primary,
            action: toggleRecording
        )
        .disabled(phase == .playingReference || phase == .scoring)
    }

    private func feedbackView(score: Float) -> some View {
        VStack(spacing: SpacingTokens.tiny) {
            Text(score >= 0.7
                 ? String(localized: "Отлично! 🎉")
                 : String(localized: "Попробуй ещё раз"))
                .font(TypographyTokens.headline())
            HSProgressBar(value: Double(score))
                .frame(height: 8)
                .padding(.horizontal, SpacingTokens.large)
        }
    }

    // MARK: - Actions

    private func playReference() {
        phase = .playingReference
        container.soundService.playUISound(.tap)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            phase = .idle
        }
    }

    private func toggleRecording() {
        switch phase {
        case .idle, .feedback:
            phase = .recording
            container.soundService.playUISound(.tap)
        case .recording:
            phase = .scoring
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.7))
                let mockScore = Float.random(in: 0.55...0.95)
                score = mockScore
                phase = .feedback
                logger.info("RepeatAfterModel score=\(mockScore, privacy: .public)")
                try? await Task.sleep(for: .seconds(1.5))
                onComplete(mockScore)
            }
        default:
            break
        }
    }
}

#Preview {
    RepeatAfterModelView(
        activity: SessionActivity(
            id: "preview", gameType: .repeatAfterModel, lessonId: "l1",
            soundTarget: "Р", difficulty: 1, isCompleted: false, score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
