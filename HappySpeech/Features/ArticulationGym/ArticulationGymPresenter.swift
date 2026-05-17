import Foundation
import OSLog

// MARK: - ArticulationGymPresentationLogic

@MainActor
protocol ArticulationGymPresentationLogic: AnyObject {
    func presentLoad(response: ArticulationGymModels.Load.Response) async
    func presentTimerTick(response: ArticulationGymModels.TimerTick.Response, duration: Int) async
    func presentNext(response: ArticulationGymModels.Next.Response, totalCount: Int) async
    func presentComplete(response: ArticulationGymModels.Complete.Response) async
}

// MARK: - ArticulationGymDisplayLogic

@MainActor
protocol ArticulationGymDisplayLogic: AnyObject {
    func displayLoad(viewModel: ArticulationGymModels.Load.ViewModel) async
    func displayTimerTick(viewModel: ArticulationGymModels.TimerTick.ViewModel) async
    func displayNext(viewModel: ArticulationGymModels.Next.ViewModel) async
    func displayComplete(viewModel: ArticulationGymModels.Complete.ViewModel) async
}

// MARK: - ArticulationGymPresenter (Clean Swift: Presenter)
//
// F-302 v25 — мапит Response → ViewModel.
// Все строки — через `String(localized:)`.

@MainActor
final class ArticulationGymPresenter: ArticulationGymPresentationLogic {

    weak var displayLogic: (any ArticulationGymDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ArticulationGym.Presenter"
    )

    init(displayLogic: (any ArticulationGymDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load

    func presentLoad(response: ArticulationGymModels.Load.Response) async {
        let groupLabel = String(localized: String.LocalizationValue(response.soundGroup.titleKey))
        let exercises = response.exercises.map { item in
            ExerciseViewModel(
                id: item.id,
                title: String(localized: String.LocalizationValue(item.titleKey)),
                instruction: String(localized: String.LocalizationValue(item.instructionKey)),
                illustrationSymbol: item.illustrationSymbol,
                durationSeconds: item.durationSeconds
            )
        }
        let viewModel = ArticulationGymModels.Load.ViewModel(
            soundGroupLabel: groupLabel,
            exercises: exercises,
            totalCount: exercises.count
        )
        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    // MARK: - TimerTick

    func presentTimerTick(
        response: ArticulationGymModels.TimerTick.Response,
        duration: Int
    ) async {
        let timerText = String(response.secondsRemaining)
        let a11y = String.localizedStringWithFormat(
            String(localized: "articulationGym.timer.a11y"),
            response.secondsRemaining
        )
        let progress: Double = duration > 0
            ? Double(duration - response.secondsRemaining) / Double(duration)
            : 0
        let viewModel = ArticulationGymModels.TimerTick.ViewModel(
            timerText: timerText,
            timerAccessibilityLabel: a11y,
            ringProgress: min(1, max(0, progress)),
            shouldAdvance: response.shouldAdvance
        )
        await displayLogic?.displayTimerTick(viewModel: viewModel)
    }

    // MARK: - Next

    func presentNext(
        response: ArticulationGymModels.Next.Response,
        totalCount: Int
    ) async {
        let progress: Double = totalCount > 0
            ? Double(min(response.nextIndex, totalCount)) / Double(totalCount)
            : 0
        let viewModel = ArticulationGymModels.Next.ViewModel(
            nextIndex: response.nextIndex,
            showCompletion: response.isLast,
            progress: progress
        )
        await displayLogic?.displayNext(viewModel: viewModel)
    }

    // MARK: - Complete

    func presentComplete(response: ArticulationGymModels.Complete.Response) async {
        let text = String(localized: "articulationGym.completion.text")
        let viewModel = ArticulationGymModels.Complete.ViewModel(celebrationText: text)
        await displayLogic?.displayComplete(viewModel: viewModel)
    }
}
