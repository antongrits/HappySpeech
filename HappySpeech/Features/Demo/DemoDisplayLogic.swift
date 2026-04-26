import Foundation
import Observation

// MARK: - DemoDisplayLogic

@MainActor
protocol DemoDisplayLogic: AnyObject {
    func displayLoadDemo(_ viewModel: DemoModels.LoadDemo.ViewModel)
    func displayAdvanceStep(_ viewModel: DemoModels.AdvanceStep.ViewModel)
    func displayGoBack(_ viewModel: DemoModels.GoBack.ViewModel)
    func displayJumpTo(_ viewModel: DemoModels.JumpTo.ViewModel)
    func displayInteractiveTap(_ viewModel: DemoModels.InteractiveTap.ViewModel)
    func displaySkipDemo(_ viewModel: DemoModels.SkipDemo.ViewModel)
    func displayCompleteDemo(_ viewModel: DemoModels.CompleteDemo.ViewModel)
    func displayToggleAutoAdvance(_ viewModel: DemoModels.ToggleAutoAdvance.ViewModel)
    func displayAutoAdvanceTick(_ viewModel: DemoModels.AutoAdvanceTick.ViewModel)
    func displayReplayStep(_ viewModel: DemoModels.ReplayStep.ViewModel)
}

// MARK: - DemoDisplay (Observable Store)
//
// Хранит весь UI-state экрана. Чистая projection стейта Interactor → ViewModel,
// без мутаций бизнес-логики.

@Observable
@MainActor
final class DemoDisplay: DemoDisplayLogic {

    // Static
    var steps: [DemoStep] = []
    var totalSteps: Int = 0

    // Per-step
    var currentIndex: Int = 0
    var stepTitle: String = ""
    var stepSubtitle: String = ""
    var stepDescription: String = ""
    var mascotText: String = ""
    var screenEmoji: String = "📱"
    var illustrationSymbol: String = ""
    var accent: DemoAccentColor = .primary
    var lyalyaState: LyalyaState = .explaining
    var hasInteractive: Bool = false
    var actionTitle: String?
    var progress: Double = 0
    var progressLabel: String = ""

    // CTA state
    var isFirst: Bool = true
    var isLast: Bool = false
    var backTitle: String = ""
    var nextTitle: String = ""

    // Toast (для интерактивного шага «Попробовать!»)
    var toastMessage: String?

    // AutoAdvance
    var autoAdvanceEnabled: Bool = false
    var autoAdvanceLabel: String = ""
    var autoAdvanceToggleLabel: String = ""

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
            stepSubtitle: viewModel.stepSubtitle,
            stepDescription: viewModel.stepDescription,
            mascotText: viewModel.mascotText,
            screenEmoji: viewModel.screenEmoji,
            illustrationSymbol: viewModel.illustrationSymbol,
            accent: viewModel.accent,
            lyalyaState: viewModel.lyalyaState,
            hasInteractive: viewModel.hasInteractive,
            actionTitle: viewModel.actionTitle
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
            stepSubtitle: viewModel.stepSubtitle,
            stepDescription: viewModel.stepDescription,
            mascotText: viewModel.mascotText,
            screenEmoji: viewModel.screenEmoji,
            illustrationSymbol: viewModel.illustrationSymbol,
            accent: viewModel.accent,
            lyalyaState: viewModel.lyalyaState,
            hasInteractive: viewModel.hasInteractive,
            actionTitle: viewModel.actionTitle
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
            stepSubtitle: viewModel.stepSubtitle,
            stepDescription: viewModel.stepDescription,
            mascotText: viewModel.mascotText,
            screenEmoji: viewModel.screenEmoji,
            illustrationSymbol: viewModel.illustrationSymbol,
            accent: viewModel.accent,
            lyalyaState: viewModel.lyalyaState,
            hasInteractive: viewModel.hasInteractive,
            actionTitle: viewModel.actionTitle
        )
    }

    func displayJumpTo(_ viewModel: DemoModels.JumpTo.ViewModel) {
        applyCommon(
            currentIndex: viewModel.currentIndex,
            progress: viewModel.progress,
            progressLabel: viewModel.progressLabel,
            isFirst: viewModel.isFirst,
            isLast: viewModel.isLast,
            backTitle: viewModel.backTitle,
            nextTitle: viewModel.nextTitle,
            stepTitle: viewModel.stepTitle,
            stepSubtitle: viewModel.stepSubtitle,
            stepDescription: viewModel.stepDescription,
            mascotText: viewModel.mascotText,
            screenEmoji: viewModel.screenEmoji,
            illustrationSymbol: viewModel.illustrationSymbol,
            accent: viewModel.accent,
            lyalyaState: viewModel.lyalyaState,
            hasInteractive: viewModel.hasInteractive,
            actionTitle: viewModel.actionTitle
        )
    }

    func displayInteractiveTap(_ viewModel: DemoModels.InteractiveTap.ViewModel) {
        toastMessage = viewModel.toastMessage
    }

    func displaySkipDemo(_ viewModel: DemoModels.SkipDemo.ViewModel) {
        pendingSkip = true
    }

    func displayCompleteDemo(_ viewModel: DemoModels.CompleteDemo.ViewModel) {
        pendingCompleted = true
    }

    func displayToggleAutoAdvance(_ viewModel: DemoModels.ToggleAutoAdvance.ViewModel) {
        autoAdvanceEnabled = viewModel.isEnabled
        autoAdvanceToggleLabel = viewModel.toggleLabel
    }

    func displayAutoAdvanceTick(_ viewModel: DemoModels.AutoAdvanceTick.ViewModel) {
        applyCommon(
            currentIndex: viewModel.currentIndex,
            progress: viewModel.progress,
            progressLabel: viewModel.progressLabel,
            isFirst: viewModel.isFirst,
            isLast: viewModel.isLast,
            backTitle: viewModel.backTitle,
            nextTitle: viewModel.nextTitle,
            stepTitle: viewModel.stepTitle,
            stepSubtitle: viewModel.stepSubtitle,
            stepDescription: viewModel.stepDescription,
            mascotText: viewModel.mascotText,
            screenEmoji: viewModel.screenEmoji,
            illustrationSymbol: viewModel.illustrationSymbol,
            accent: viewModel.accent,
            lyalyaState: viewModel.lyalyaState,
            hasInteractive: viewModel.hasInteractive,
            actionTitle: viewModel.actionTitle
        )
        if viewModel.isCompleted { pendingCompleted = true }
    }

    func displayReplayStep(_ viewModel: DemoModels.ReplayStep.ViewModel) {
        toastMessage = viewModel.toastMessage
    }

    // MARK: - View helpers

    func consumeSkip() { pendingSkip = false }
    func consumeCompleted() { pendingCompleted = false }
    func consumeToast() { toastMessage = nil }

    // MARK: - Private

    // swiftlint:disable:next function_parameter_count
    private func applyCommon(
        currentIndex: Int,
        progress: Double,
        progressLabel: String,
        isFirst: Bool,
        isLast: Bool,
        backTitle: String,
        nextTitle: String,
        stepTitle: String,
        stepSubtitle: String,
        stepDescription: String,
        mascotText: String,
        screenEmoji: String,
        illustrationSymbol: String,
        accent: DemoAccentColor,
        lyalyaState: LyalyaState,
        hasInteractive: Bool,
        actionTitle: String?
    ) {
        self.currentIndex = currentIndex
        self.progress = progress
        self.progressLabel = progressLabel
        self.isFirst = isFirst
        self.isLast = isLast
        self.backTitle = backTitle
        self.nextTitle = nextTitle
        self.stepTitle = stepTitle
        self.stepSubtitle = stepSubtitle
        self.stepDescription = stepDescription
        self.mascotText = mascotText
        self.screenEmoji = screenEmoji
        self.illustrationSymbol = illustrationSymbol
        self.accent = accent
        self.lyalyaState = lyalyaState
        self.hasInteractive = hasInteractive
        self.actionTitle = actionTitle
    }
}
