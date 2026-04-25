import Foundation
import OSLog

// MARK: - DemoPresentationLogic

@MainActor
protocol DemoPresentationLogic: AnyObject {
    func presentLoadDemo(_ response: DemoModels.LoadDemo.Response)
    func presentAdvanceStep(_ response: DemoModels.AdvanceStep.Response)
    func presentGoBack(_ response: DemoModels.GoBack.Response)
    func presentSkipDemo(_ response: DemoModels.SkipDemo.Response)
    func presentCompleteDemo(_ response: DemoModels.CompleteDemo.Response)
}

// MARK: - DemoPresenter

@MainActor
final class DemoPresenter: DemoPresentationLogic {

    // MARK: - Collaborators

    weak var display: (any DemoDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "DemoPresenter")

    // MARK: - PresentationLogic

    func presentLoadDemo(_ response: DemoModels.LoadDemo.Response) {
        let vm = DemoModels.LoadDemo.ViewModel(
            steps: response.steps,
            currentIndex: response.currentIndex,
            totalSteps: response.steps.count,
            progress: progress(currentIndex: response.currentIndex, total: response.steps.count),
            progressLabel: progressLabel(currentIndex: response.currentIndex, total: response.steps.count),
            isFirst: response.currentIndex == 0,
            isLast: response.currentIndex >= response.steps.count - 1,
            backTitle: String(localized: "demo.cta.back"),
            nextTitle: nextTitle(currentIndex: response.currentIndex, total: response.steps.count),
            stepTitle: response.steps[safe: response.currentIndex]?.title ?? "",
            stepDescription: response.steps[safe: response.currentIndex]?.description ?? "",
            mascotText: response.steps[safe: response.currentIndex]?.mascotText ?? "",
            screenEmoji: response.steps[safe: response.currentIndex]?.screenEmoji ?? "📱"
        )
        display?.displayLoadDemo(vm)
    }

    func presentAdvanceStep(_ response: DemoModels.AdvanceStep.Response) {
        let vm = DemoModels.AdvanceStep.ViewModel(
            currentIndex: response.currentIndex,
            totalSteps: response.steps.count,
            progress: progress(currentIndex: response.currentIndex, total: response.steps.count),
            progressLabel: progressLabel(currentIndex: response.currentIndex, total: response.steps.count),
            isFirst: response.currentIndex == 0,
            isLast: response.currentIndex >= response.steps.count - 1,
            backTitle: String(localized: "demo.cta.back"),
            nextTitle: nextTitle(currentIndex: response.currentIndex, total: response.steps.count),
            stepTitle: response.steps[safe: response.currentIndex]?.title ?? "",
            stepDescription: response.steps[safe: response.currentIndex]?.description ?? "",
            mascotText: response.steps[safe: response.currentIndex]?.mascotText ?? "",
            screenEmoji: response.steps[safe: response.currentIndex]?.screenEmoji ?? "📱",
            isCompleted: response.isCompleted
        )
        display?.displayAdvanceStep(vm)
    }

    func presentGoBack(_ response: DemoModels.GoBack.Response) {
        let vm = DemoModels.GoBack.ViewModel(
            currentIndex: response.currentIndex,
            progress: progress(currentIndex: response.currentIndex, total: response.steps.count),
            progressLabel: progressLabel(currentIndex: response.currentIndex, total: response.steps.count),
            isFirst: response.currentIndex == 0,
            isLast: response.currentIndex >= response.steps.count - 1,
            backTitle: String(localized: "demo.cta.back"),
            nextTitle: nextTitle(currentIndex: response.currentIndex, total: response.steps.count),
            stepTitle: response.steps[safe: response.currentIndex]?.title ?? "",
            stepDescription: response.steps[safe: response.currentIndex]?.description ?? "",
            mascotText: response.steps[safe: response.currentIndex]?.mascotText ?? "",
            screenEmoji: response.steps[safe: response.currentIndex]?.screenEmoji ?? "📱"
        )
        display?.displayGoBack(vm)
    }

    func presentSkipDemo(_ response: DemoModels.SkipDemo.Response) {
        display?.displaySkipDemo(.init())
    }

    func presentCompleteDemo(_ response: DemoModels.CompleteDemo.Response) {
        display?.displayCompleteDemo(.init())
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
