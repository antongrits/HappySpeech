import OSLog
import SwiftUI

// MARK: - MinimalPairsViewComponents
//
// Подкомпоненты minimal-pairs: DisplayLogic adapter и Preview.
// Извлечено из `MinimalPairsView.swift` (Block K.12 v16) для удержания LOC ≤700.

// MARK: - MinimalPairsDisplay: DisplayLogic adapter

extension MinimalPairsDisplay: MinimalPairsDisplayLogic {

    func displayLoadSession(_ viewModel: MinimalPairsModels.LoadSession.ViewModel) {
        totalRounds = viewModel.totalRounds
        greeting = viewModel.greeting
    }

    func displayStartRound(_ viewModel: MinimalPairsModels.StartRound.ViewModel) {
        currentPair = viewModel.pair
        progressLabel = viewModel.progressLabel
        promptText = viewModel.promptText
        hintsAvailable = viewModel.hintsAvailable
        isAnswered = false
        selectedIsTarget = nil
        feedbackText = ""
        streakLabel = nil
        isStreakBonus = false
        showHintHighlight = false
        replaysRemaining = 3
        toastMessage = nil
        phase = .round
    }

    func displaySelectOption(_ viewModel: MinimalPairsModels.SelectOption.ViewModel) {
        correct = viewModel.correct
        feedbackText = viewModel.feedbackText
        correctAnswer = viewModel.correctAnswer
        isStreakBonus = viewModel.isStreakBonus
        streakLabel = viewModel.streakLabel
        isAnswered = true
        showHintHighlight = false
        phase = .feedback
        answeredCount += 1
        if viewModel.correct { correctCount += 1 }
    }

    func displayReplayWord(_ viewModel: MinimalPairsModels.ReplayWord.ViewModel) {
        replaysRemaining = viewModel.replaysRemaining
        if let msg = viewModel.toastMessage {
            showToast(msg)
        }
    }

    func displayHint(_ viewModel: MinimalPairsModels.RequestHint.ViewModel) {
        hintsAvailable = viewModel.hintsRemaining
        showToast(viewModel.toastMessage)
        if viewModel.level == .highlight && !viewModel.capReached {
            showHintHighlight = true
            hintHighlightDuration = viewModel.highlightDuration
            Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .seconds(viewModel.highlightDuration))
                self.showHintHighlight = false
            }
        }
    }

    func displayBonusRoundAdded(_ viewModel: MinimalPairsModels.BonusRoundAdded.ViewModel) {
        totalRounds = viewModel.totalRounds
        showToast(viewModel.toastMessage)
    }

    func displayCompleteSession(_ viewModel: MinimalPairsModels.CompleteSession.ViewModel) {
        starsEarned = viewModel.starsEarned
        scoreLabel = viewModel.scoreLabel
        completionMessage = viewModel.message
        pairSummary = viewModel.pairSummary
        phase = .completed
    }

    // MARK: - Toast helper

    private func showToast(_ message: String) {
        toastMessage = message
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(2.5))
            self.toastMessage = nil
        }
    }
}

// MARK: - Preview

#Preview("Round") {
    MinimalPairsView(
        soundContrast: "Р-Л",
        childName: "Саша",
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
