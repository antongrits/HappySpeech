import Foundation
import OSLog

// MARK: - DemoPresentationLogic

@MainActor
protocol DemoPresentationLogic: AnyObject {
    func presentLoadDemo(_ response: DemoModels.LoadDemo.Response)
    func presentAdvanceStep(_ response: DemoModels.AdvanceStep.Response)
    func presentGoBack(_ response: DemoModels.GoBack.Response)
    func presentJumpTo(_ response: DemoModels.JumpTo.Response)
    func presentInteractiveTap(_ response: DemoModels.InteractiveTap.Response)
    func presentSkipDemo(_ response: DemoModels.SkipDemo.Response)
    func presentCompleteDemo(_ response: DemoModels.CompleteDemo.Response)
    func presentToggleAutoAdvance(_ response: DemoModels.ToggleAutoAdvance.Response)
    func presentAutoAdvanceTick(_ response: DemoModels.AutoAdvanceTick.Response)
    func presentReplayStep(_ response: DemoModels.ReplayStep.Response)
}

// MARK: - DemoPresenter
//
// Чистая трансформация Response → ViewModel. Не содержит UIKit/SwiftUI и не
// общается напрямую с Realm — только форматирует тексты и вычисляет
// производные значения вроде `progressFraction`, `nextTitle`, `progressLabel`.

@MainActor
final class DemoPresenter: DemoPresentationLogic {

    // MARK: - Collaborators

    weak var display: (any DemoDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "DemoPresenter")

    // MARK: - PresentationLogic

    func presentLoadDemo(_ response: DemoModels.LoadDemo.Response) {
        let step = response.steps[safe: response.currentIndex]
        let total = response.steps.count
        let vm = DemoModels.LoadDemo.ViewModel(
            steps: response.steps,
            currentIndex: response.currentIndex,
            totalSteps: total,
            progress: progress(currentIndex: response.currentIndex, total: total),
            progressLabel: progressLabel(currentIndex: response.currentIndex, total: total),
            isFirst: response.currentIndex == 0,
            isLast: response.currentIndex >= total - 1,
            backTitle: String(localized: "demo.cta.back"),
            nextTitle: nextTitle(currentIndex: response.currentIndex, total: total),
            stepTitle: step?.title ?? "",
            stepSubtitle: step?.subtitle ?? "",
            stepDescription: step?.description ?? "",
            mascotText: step?.mascotText ?? "",
            screenEmoji: step?.screenEmoji ?? "📱",
            illustrationSymbol: step?.illustrationSymbol ?? "",
            accent: step?.accent ?? .primary,
            lyalyaState: step?.lyalyaState ?? .explaining,
            hasInteractive: step?.hasInteractive ?? false,
            actionTitle: step?.actionTitle
        )
        display?.displayLoadDemo(vm)
    }

    func presentAdvanceStep(_ response: DemoModels.AdvanceStep.Response) {
        let step = response.steps[safe: response.currentIndex]
        let total = response.steps.count
        let vm = DemoModels.AdvanceStep.ViewModel(
            currentIndex: response.currentIndex,
            totalSteps: total,
            progress: progress(currentIndex: response.currentIndex, total: total),
            progressLabel: progressLabel(currentIndex: response.currentIndex, total: total),
            isFirst: response.currentIndex == 0,
            isLast: response.currentIndex >= total - 1,
            backTitle: String(localized: "demo.cta.back"),
            nextTitle: nextTitle(currentIndex: response.currentIndex, total: total),
            stepTitle: step?.title ?? "",
            stepSubtitle: step?.subtitle ?? "",
            stepDescription: step?.description ?? "",
            mascotText: step?.mascotText ?? "",
            screenEmoji: step?.screenEmoji ?? "📱",
            illustrationSymbol: step?.illustrationSymbol ?? "",
            accent: step?.accent ?? .primary,
            lyalyaState: step?.lyalyaState ?? .explaining,
            hasInteractive: step?.hasInteractive ?? false,
            actionTitle: step?.actionTitle,
            isCompleted: response.isCompleted
        )
        display?.displayAdvanceStep(vm)
    }

    func presentGoBack(_ response: DemoModels.GoBack.Response) {
        let step = response.steps[safe: response.currentIndex]
        let total = response.steps.count
        let vm = DemoModels.GoBack.ViewModel(
            currentIndex: response.currentIndex,
            progress: progress(currentIndex: response.currentIndex, total: total),
            progressLabel: progressLabel(currentIndex: response.currentIndex, total: total),
            isFirst: response.currentIndex == 0,
            isLast: response.currentIndex >= total - 1,
            backTitle: String(localized: "demo.cta.back"),
            nextTitle: nextTitle(currentIndex: response.currentIndex, total: total),
            stepTitle: step?.title ?? "",
            stepSubtitle: step?.subtitle ?? "",
            stepDescription: step?.description ?? "",
            mascotText: step?.mascotText ?? "",
            screenEmoji: step?.screenEmoji ?? "📱",
            illustrationSymbol: step?.illustrationSymbol ?? "",
            accent: step?.accent ?? .primary,
            lyalyaState: step?.lyalyaState ?? .explaining,
            hasInteractive: step?.hasInteractive ?? false,
            actionTitle: step?.actionTitle
        )
        display?.displayGoBack(vm)
    }

    func presentJumpTo(_ response: DemoModels.JumpTo.Response) {
        let step = response.steps[safe: response.currentIndex]
        let total = response.steps.count
        let vm = DemoModels.JumpTo.ViewModel(
            currentIndex: response.currentIndex,
            progress: progress(currentIndex: response.currentIndex, total: total),
            progressLabel: progressLabel(currentIndex: response.currentIndex, total: total),
            isFirst: response.currentIndex == 0,
            isLast: response.currentIndex >= total - 1,
            backTitle: String(localized: "demo.cta.back"),
            nextTitle: nextTitle(currentIndex: response.currentIndex, total: total),
            stepTitle: step?.title ?? "",
            stepSubtitle: step?.subtitle ?? "",
            stepDescription: step?.description ?? "",
            mascotText: step?.mascotText ?? "",
            screenEmoji: step?.screenEmoji ?? "📱",
            illustrationSymbol: step?.illustrationSymbol ?? "",
            accent: step?.accent ?? .primary,
            lyalyaState: step?.lyalyaState ?? .explaining,
            hasInteractive: step?.hasInteractive ?? false,
            actionTitle: step?.actionTitle
        )
        display?.displayJumpTo(vm)
    }

    func presentInteractiveTap(_ response: DemoModels.InteractiveTap.Response) {
        let toast = String(
            format: String(localized: "demo.interactive.toast"),
            response.stepTitle
        )
        display?.displayInteractiveTap(.init(
            stepId: response.stepId,
            toastMessage: toast
        ))
    }

    func presentSkipDemo(_ response: DemoModels.SkipDemo.Response) {
        display?.displaySkipDemo(.init())
    }

    func presentCompleteDemo(_ response: DemoModels.CompleteDemo.Response) {
        display?.displayCompleteDemo(.init())
    }

    func presentToggleAutoAdvance(_ response: DemoModels.ToggleAutoAdvance.Response) {
        display?.displayToggleAutoAdvance(.init(
            isEnabled: response.isEnabled,
            toggleLabel: response.toggleLabel
        ))
    }

    func presentAutoAdvanceTick(_ response: DemoModels.AutoAdvanceTick.Response) {
        let step = response.steps[safe: response.currentIndex]
        let total = response.steps.count
        let vm = DemoModels.AutoAdvanceTick.ViewModel(
            currentIndex: response.currentIndex,
            progress: progress(currentIndex: response.currentIndex, total: total),
            progressLabel: progressLabel(currentIndex: response.currentIndex, total: total),
            isFirst: response.currentIndex == 0,
            isLast: response.currentIndex >= total - 1,
            backTitle: String(localized: "demo.cta.back"),
            nextTitle: nextTitle(currentIndex: response.currentIndex, total: total),
            stepTitle: step?.title ?? "",
            stepSubtitle: step?.subtitle ?? "",
            stepDescription: step?.description ?? "",
            mascotText: step?.mascotText ?? "",
            screenEmoji: step?.screenEmoji ?? "📱",
            illustrationSymbol: step?.illustrationSymbol ?? "",
            accent: step?.accent ?? .primary,
            lyalyaState: step?.lyalyaState ?? .explaining,
            hasInteractive: step?.hasInteractive ?? false,
            actionTitle: step?.actionTitle,
            isCompleted: response.isCompleted
        )
        display?.displayAutoAdvanceTick(vm)
    }

    func presentReplayStep(_ response: DemoModels.ReplayStep.Response) {
        let toast = String(
            format: String(localized: "demo.replay.button"),
            response.stepTitle
        )
        display?.displayReplayStep(.init(
            stepId: response.stepId,
            toastMessage: toast
        ))
    }

    // MARK: - Private helpers

    private func progress(currentIndex: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(currentIndex + 1) / Double(total)
    }

    private func progressLabel(currentIndex: Int, total: Int) -> String {
        String(format: String(localized: "demo.progress.label"), currentIndex + 1, total)
    }

    private func nextTitle(currentIndex: Int, total: Int) -> String {
        let isLast = currentIndex >= total - 1
        return isLast
            ? String(localized: "demo.cta.finish")
            : String(localized: "demo.cta.next")
    }
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
