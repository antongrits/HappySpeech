import OSLog
import SwiftUI
import UniformTypeIdentifiers

// MARK: - DragAndMatchViewComponents
//
// Подкомпоненты «перетащи в коробку»: DisplayLogic adapter, символ/картинка
// item-вью и Preview. Извлечено из `DragAndMatchView.swift` (Block K.7
// v16) для удержания LOC ≤700.

// MARK: - Display: DisplayLogic adapter

extension DragAndMatchDisplay: DragAndMatchDisplayLogic {

    func displayLoadSession(_ viewModel: DragAndMatchModels.LoadSession.ViewModel) {
        words = viewModel.words
        buckets = viewModel.buckets
        greeting = viewModel.greeting
        roundLabel = viewModel.roundLabel
        confusedPairLabel = viewModel.confusedPairLabel
        placedWords = [:]
        correctWords = []
        incorrectWords = []
        feedbackText = ""
        hintHighlightBucketId = nil
        showRoundComplete = false
        phase = .playing
    }

    func displayDropWord(_ viewModel: DragAndMatchModels.DropWord.ViewModel) {
        // `placedWords` уже обновлён в View до вызова Interactor, здесь мы
        // только маркируем слово как correct/incorrect для бордера.
        if viewModel.correct {
            correctWords.insert(viewModel.wordId)
            incorrectWords.remove(viewModel.wordId)
        } else {
            incorrectWords.insert(viewModel.wordId)
            correctWords.remove(viewModel.wordId)
        }
        feedbackText = viewModel.feedbackText
        hintHighlightBucketId = viewModel.hintBucketId

        showStreakBonus = viewModel.showStreakBonus
        streakBonusLabel = viewModel.streakLabel
    }

    func displayHint(_ viewModel: DragAndMatchModels.RequestHint.ViewModel) {
        // Уровень 1: подсветка корзины.
        hintHighlightBucketId = viewModel.targetBucketId

        // Уровень 2: голосовой промпт — озвучиваем через LessonVoiceWorker.
        if let text = viewModel.voicePromptText {
            Task { @MainActor in
                await LessonVoiceWorker.shared.speak(text, lessonType: "drag_and_match")
            }
        }

        // Уровень 3: авто-решение — применяем размещение в display.
        if let wordId = viewModel.autoSolvedWordId,
           let bucketId = viewModel.autoSolvedBucketId {
            placedWords[wordId] = bucketId
            correctWords.insert(wordId)
            incorrectWords.remove(wordId)
            hintHighlightBucketId = nil
        }

        feedbackText = viewModel.hintsRemainingLabel
    }

    func displayCompleteRound(_ viewModel: DragAndMatchModels.CompleteRound.ViewModel) {
        roundCompleteAccuracyLabel = viewModel.accuracyLabel
        roundCompleteHintsLabel = viewModel.hintsLabel
        roundCompleteDurationLabel = viewModel.durationLabel
        roundCompleteHasNext = viewModel.hasNextRound
        roundCompleteCtaLabel = viewModel.ctaLabel
        showRoundComplete = true
    }

    func displayCompleteSession(_ viewModel: DragAndMatchModels.CompleteSession.ViewModel) {
        starsEarned = viewModel.starsEarned
        scoreLabel = viewModel.scoreLabel
        completionMessage = viewModel.message
        accuracyPercent = viewModel.accuracyPercent
        hintsUsedLabel = viewModel.hintsUsedLabel
        durationLabel = viewModel.durationLabel
        showRoundComplete = false
        phase = .completed
    }
}

// MARK: - DragMatchSymbolOrImage
//
// Block D v16: bucket.emoji string может быть SF Symbol name (точка-разделитель,
// напр. "checkmark.circle.fill") или Asset name (без точки, напр. "word_fish").
// Helper view выбирает правильный рендеринг.

struct DragMatchSymbolOrImage: View {
    let name: String
    let size: CGFloat

    var body: some View {
        if name.contains(".") || isKnownSFSymbolKeyword(name) {
            Image(systemName: name)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(ColorTokens.Brand.primary)
                .accessibilityHidden(true)
        } else {
            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size + 4, height: size + 4)
                .accessibilityHidden(true)
        }
    }

    private func isKnownSFSymbolKeyword(_ s: String) -> Bool {
        // Single-word SF Symbols без точек, использующиеся в Block D mapping.
        ["sparkles", "questionmark", "calendar", "magnifyingglass"].contains(s)
    }
}

// MARK: - Preview

#Preview("Playing") {
    DragAndMatchView(
        soundGroup: "whistling",
        childName: "Саша",
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
