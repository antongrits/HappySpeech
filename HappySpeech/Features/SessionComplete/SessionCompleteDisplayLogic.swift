import Foundation
import Observation

// MARK: - SessionCompleteDisplayLogic

/// Контракт между Presenter'ом и SwiftUI-store'ом.
/// `display(_:)`-методы — единственный путь обновления UI-состояния.
@MainActor
protocol SessionCompleteDisplayLogic: AnyObject {
    func displayLoadResult(_ viewModel: SessionCompleteModels.LoadResult.ViewModel)
    func displayAdvancePhase(_ viewModel: SessionCompleteModels.AdvancePhase.ViewModel)
    func displayShareResult(_ viewModel: SessionCompleteModels.ShareResult.ViewModel)
    func displayPlayAgain(_ viewModel: SessionCompleteModels.PlayAgain.ViewModel)
    func displayProceedToNext(_ viewModel: SessionCompleteModels.ProceedToNext.ViewModel)
    func displayFailure(_ viewModel: SessionCompleteModels.Failure.ViewModel)
}

// MARK: - SessionCompleteDisplay (Observable Store)

/// Источник истины для SwiftUI-вью SessionCompleteView.
/// Никакой бизнес-логики — только состояние и помощники для view.
@Observable
@MainActor
final class SessionCompleteDisplay: SessionCompleteDisplayLogic {

    // Phase progression
    var currentPhase: SessionCompletePhase = .mascot

    // Score block
    var scoreInt: Int = 0
    var scoreLabel: String = ""
    var starsEarned: Int = 0
    var starsTotal: Int = 3

    // Header
    var gameTitle: String = ""
    var soundLabel: String = ""

    // Summary cards
    var attemptsLabel: String = ""
    var durationLabel: String = ""

    // Next lesson preview
    var nextLessonTitle: String?

    // Mascot bubble
    var mascotTagline: String = ""

    // Share
    var pendingShareText: String?

    // Routing intent
    var pendingPlayAgain: Bool = false
    var pendingProceed: Bool = false
    var pendingHasNext: Bool = false

    // Toast
    var toastMessage: String?

    // A11y
    var accessibilitySummary: String = ""

    // MARK: - SessionCompleteDisplayLogic

    func displayLoadResult(_ viewModel: SessionCompleteModels.LoadResult.ViewModel) {
        scoreInt = viewModel.scoreInt
        scoreLabel = viewModel.scoreLabel
        starsEarned = viewModel.starsEarned
        starsTotal = viewModel.starsTotal
        gameTitle = viewModel.gameTitle
        soundLabel = viewModel.soundLabel
        attemptsLabel = viewModel.attemptsLabel
        durationLabel = viewModel.durationLabel
        nextLessonTitle = viewModel.nextLessonTitle
        mascotTagline = viewModel.mascotTagline
        accessibilitySummary = viewModel.accessibilitySummary
        currentPhase = .mascot
    }

    func displayAdvancePhase(_ viewModel: SessionCompleteModels.AdvancePhase.ViewModel) {
        currentPhase = viewModel.phase
    }

    func displayShareResult(_ viewModel: SessionCompleteModels.ShareResult.ViewModel) {
        pendingShareText = viewModel.shareText
    }

    func displayPlayAgain(_ viewModel: SessionCompleteModels.PlayAgain.ViewModel) {
        pendingPlayAgain = true
    }

    func displayProceedToNext(_ viewModel: SessionCompleteModels.ProceedToNext.ViewModel) {
        pendingProceed = true
        pendingHasNext = viewModel.hasNext
    }

    func displayFailure(_ viewModel: SessionCompleteModels.Failure.ViewModel) {
        toastMessage = viewModel.toastMessage
    }

    // MARK: - View helpers

    func clearToast() { toastMessage = nil }
    func consumeShare() { pendingShareText = nil }
    func consumePlayAgain() { pendingPlayAgain = false }
    func consumeProceed() {
        pendingProceed = false
        pendingHasNext = false
    }

    /// Проверяет, должна ли быть видна указанная фаза.
    func isPhaseVisible(_ phase: SessionCompletePhase) -> Bool {
        currentPhase >= phase
    }
}
