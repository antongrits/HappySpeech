import OSLog
import SwiftUI

// MARK: - SortingViewComponents
//
// Подкомпоненты sorting-game: DisplayLogic adapter и Preview.
// Извлечено из `SortingView.swift` (Block K.9 v16) для удержания LOC ≤700.

// MARK: - Display: DisplayLogic adapter

extension SortingDisplay: SortingDisplayLogic {

    func displayLoadSession(_ viewModel: SortingModels.LoadSession.ViewModel) {
        setTitle = viewModel.setTitle
        taskDescription = viewModel.taskDescription
        taskType = viewModel.taskType
        words = viewModel.words
        categories = viewModel.categories
        greeting = viewModel.greeting
        timeLimit = viewModel.timeLimit
        classifiedWords = [:]
        correctWords = []
        incorrectWords = []
        autoPlacedWords = []
        highlightedCategoryId = nil
        currentWordIndex = 0
        currentStreak = 0
        streakBadgeVisible = false
        feedbackText = ""
        lastClassificationCorrect = nil
        hintText = ""
        hintVisible = false
        hintLevel = 0
        phase = .classifying
    }

    func displayClassifyWord(_ viewModel: SortingModels.ClassifyWord.ViewModel) {
        highlightedCategoryId = nil
        hintVisible = false
        if viewModel.correct {
            correctWords.insert(viewModel.wordId)
            incorrectWords.remove(viewModel.wordId)
            currentStreak += 1
        } else {
            incorrectWords.insert(viewModel.wordId)
            correctWords.remove(viewModel.wordId)
            currentStreak = 0
        }
        feedbackText = viewModel.feedbackText
        lastClassificationCorrect = viewModel.correct
        streakBadgeVisible = viewModel.streakBadgeVisible
        classifiedWords[viewModel.wordId] = viewModel.categoryId
        phase = .feedback

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard let self else { return }
            if phase == .feedback {
                if currentWordIndex < words.count - 1 {
                    currentWordIndex += 1
                }
                phase = .classifying
                lastClassificationCorrect = nil
                streakBadgeVisible = false
            }
        }
    }

    func displayHint(_ viewModel: SortingModels.RequestHint.ViewModel) {
        hintLevel = viewModel.hintLevel
        hintText = viewModel.hintText
        hintVisible = true
        if viewModel.hintLevel == 1 {
            highlightedCategoryId = viewModel.highlightCategoryId
        }
        // Скрыть подсказку через 3 секунды.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self else { return }
            hintVisible = false
            if hintLevel == 1 {
                highlightedCategoryId = nil
            }
        }
    }

    func displayAutoPlace(_ viewModel: SortingModels.AutoPlace.ViewModel) {
        classifiedWords[viewModel.wordId] = viewModel.categoryId
        correctWords.insert(viewModel.wordId)
        autoPlacedWords.insert(viewModel.wordId)
        highlightedCategoryId = nil
        hintVisible = false
        if currentWordIndex < words.count - 1 {
            currentWordIndex += 1
        }
    }

    func displayStreakBonus(_ viewModel: SortingModels.StreakBonus.ViewModel) {
        feedbackText = viewModel.bonusText
        streakBadgeVisible = true
    }

    func displayTimerTick(_ viewModel: SortingModels.TimerTick.ViewModel) {
        timerLabel = viewModel.timerLabel
        timerColor = viewModel.timerColor
    }

    func displayCompleteSession(_ viewModel: SortingModels.CompleteSession.ViewModel) {
        starsEarned = viewModel.starsEarned
        scoreLabel = viewModel.scoreLabel
        completionMessage = viewModel.message
        finalScore = viewModel.finalScore
        categoryBreakdown = viewModel.categoryBreakdown
        bestCategoryTitle = viewModel.bestCategoryTitle
        worstCategoryTitle = viewModel.worstCategoryTitle
        autoPlacedCount = viewModel.autoPlacedCount
        phase = .completed
    }
}

// MARK: - Preview

#Preview("Playing") {
    SortingView(
        soundGroup: "whistling",
        childName: "Саша",
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
