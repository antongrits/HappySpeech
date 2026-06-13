import SwiftUI

// MARK: - RepeatAfterModelViewComponents
//
// Подкомпоненты «Повтори за Лялей»: визуализация букв, recording-кнопка,
// store-bridge и Preview. Извлечено из `RepeatAfterModelView.swift`
// (Block K.2 v16) для удержания LOC ≤700.

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
        display.attemptsLeft = viewModel.attemptsLeft
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
        // Фаза записи теперь приходит из Interactor (пайплайн записи/ASR
        // вынесен из View): .recording при старте, .processing на время ASR.
        // .idle — нейтральная фаза, не трогаем текущий экран.
        switch viewModel.phase {
        case .recording:  display.phase = .recording
        case .processing: display.phase = .processing
        case .idle:       break
        }
    }

    func displayEvaluateAttempt(_ viewModel: RepeatAfterModelModels.EvaluateAttempt.ViewModel) {
        display.score = viewModel.score
        display.passed = viewModel.passed
        display.feedbackText = viewModel.feedbackText
        display.attemptsLabel = viewModel.attemptsLabel
        display.attemptsLeft = viewModel.attemptsLeft
        display.canAdvance = viewModel.canAdvance
        display.diagnosticText = viewModel.diagnosticText
        display.encouragement = viewModel.encouragement
        display.hintAvailable = viewModel.hintAvailable
        display.roundStars = viewModel.stars
        display.phase = .feedback
    }

    func displayNoInput(_ viewModel: RepeatAfterModelModels.NoInput.ViewModel) {
        // Нет реального ввода: НЕ показываем звёзды/оценку, возвращаемся в готовность
        // к повторной записи с мягким сообщением. Балл не начислен, попытка не списана.
        display.attemptsLeft = viewModel.attemptsLeft
        display.feedbackText = viewModel.message
        display.micLabel = viewModel.message
        display.score = 0
        display.passed = false
        display.canAdvance = false
        display.roundStars = 0
        display.isRecording = false
        display.diagnosticText = nil
        display.encouragement = nil
        display.phase = .waiting
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
