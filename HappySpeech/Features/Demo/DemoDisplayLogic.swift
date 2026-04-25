import Foundation
import Observation

// MARK: - DemoDisplayLogic

@MainActor
protocol DemoDisplayLogic: AnyObject {
    func displayLoadDemo(_ viewModel: DemoModels.LoadDemo.ViewModel)
    func displayAdvanceStep(_ viewModel: DemoModels.AdvanceStep.ViewModel)
    func displayGoBack(_ viewModel: DemoModels.GoBack.ViewModel)
    func displaySkipDemo(_ viewModel: DemoModels.SkipDemo.ViewModel)
    func displayCompleteDemo(_ viewModel: DemoModels.CompleteDemo.ViewModel)
}

// MARK: - DemoDisplay (Observable Store)

@Observable
@MainActor
final class DemoDisplay: DemoDisplayLogic {

    // Static
    var steps: [DemoStep] = []
    var totalSteps: Int = 0

    // Per-step
    var currentIndex: Int = 0
    var stepTitle: String = ""
    var stepDescription: String = ""
    var mascotText: String = ""
    var screenEmoji: String = "📱"
    var progress: Double = 0
    var progressLabel: String = ""

    // CTA state
    var isFirst: Bool = true
    var isLast: Bool = false
    var backTitle: String = ""
    var nextTitle: String = ""

    // Routing intents
    var pendingSkip: Bool = false
    var pendingCompleted: Bool = false

    // MARK: - DisplayLogic

    func displayLoadDemo(_ viewModel: DemoModels.LoadDemo.ViewModel) {
        steps = viewModel.steps
        totalSteps = viewModel.totalSteps
        applyCommon(
            currentIndex: viewModel.currentIndex,
            progress: viewModel.progress,
            progressLabel: viewModel.progressLabel,
            isFirst: viewModel.isFirst,
            isLast: viewModel.isLast,
            backTitle: viewModel.backTitle,
            nextTitle: viewModel.nextTitle,
            stepTitle: viewModel.stepTitle,
            stepDescription: viewModel.stepDescription,
            mascotText: viewModel.mascotText,
            screenEmoji: viewModel.screenEmoji
        )
    }

    func displayAdvanceStep(_ viewModel: DemoModels.AdvanceStep.ViewModel) {
        applyCommon(
            currentIndex: viewModel.currentIndex,
            progress: viewModel.progress,
            progressLabel: viewModel.progressLabel,
            isFirst: viewModel.isFirst,
            isLast: viewModel.isLast,
            backTitle: viewModel.backTitle,
            nextTitle: viewModel.nextTitle,
            stepTitle: viewModel.stepTitle,
            stepDescription: viewModel.stepDescription,
            mascotText: viewModel.mascotText,
            screenEmoji: viewModel.screenEmoji
        )
        if viewModel.isCompleted { pendingCompleted = true }
    }

    func displayGoBack(_ viewModel: DemoModels.GoBack.ViewModel) {
        applyCommon(
            currentIndex: viewModel.currentIndex,
            progress: viewModel.progress,
            progressLabel: viewModel.progressLabel,
            isFirst: viewModel.isFirst,
            isLast: viewModel.isLast,
            backTitle: viewModel.backTitle,
            nextTitle: viewModel.nextTitle,
            stepTitle: viewModel.stepTitle,
            stepDescription: viewModel.stepDescription,
            mascotText: viewModel.mascotText,
            screenEmoji: viewModel.screenEmoji
        )
    }

    func displaySkipDemo(_ viewModel: DemoModels.SkipDemo.ViewModel) {
        pendingSkip = true
    }

    func displayCompleteDemo(_ viewModel: DemoModels.CompleteDemo.ViewModel) {
        pendingCompleted = true
    }

    // MARK: - View helpers

    func consumeSkip() { pendingSkip = false }
    func consumeCompleted() { pendingCompleted = false }

    // MARK: - Private

    private func applyCommon(
        currentIndex: Int,
        progress: Double,
        progressLabel: String,
        isFirst: Bool,
        isLast: Bool,
        backTitle: String,
        nextTitle: String,
        stepTitle: String,
        stepDescription: String,
        mascotText: String,
        screenEmoji: String
    ) {
        self.currentIndex = currentIndex
        self.progress = progress
        self.progressLabel = progressLabel
        self.isFirst = isFirst
        self.isLast = isLast
        self.backTitle = backTitle
        self.nextTitle = nextTitle
        self.stepTitle = stepTitle
        self.stepDescription = stepDescription
        self.mascotText = mascotText
        self.screenEmoji = screenEmoji
    }
}
