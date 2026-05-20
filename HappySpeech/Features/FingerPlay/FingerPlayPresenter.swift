import Foundation

// MARK: - FingerPlayPresenter

@MainActor
final class FingerPlayPresenter {

    weak var displayLogic: (any FingerPlayDisplayLogic)?

    init(displayLogic: any FingerPlayDisplayLogic) {
        self.displayLogic = displayLogic
    }

    // MARK: - Start

    func presentStart(
        response: FingerPlayModels.Start.Response,
        currentIndex: Int,
        stageIndex: Int,
        permissionDenied: Bool
    ) async {
        let exercise = response.exercise
        let stage = exercise.stages[min(stageIndex, exercise.stages.count - 1)]
        let viewModel = FingerPlayModels.Start.ViewModel(
            exerciseTitle: exercise.title,
            stageDescription: stage.description,
            targetGestureSymbol: stage.symbol,
            targetPoseRaw: stage.targetPose,
            totalExercises: response.totalExercises,
            currentIndex: currentIndex,
            stageIndex: stageIndex,
            isPermissionDenied: permissionDenied,
            accessibilityLabel: "Упражнение: \(exercise.title). \(stage.description)"
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - HandPoseUpdate

    func presentHandPoseUpdate(response: FingerPlayModels.HandPoseUpdate.Response) async {
        let viewModel = FingerPlayModels.HandPoseUpdate.ViewModel(
            detectedPoseSymbol: symbol(for: response.detectedPose),
            matchesTarget: response.matchesTarget,
            confidencePercent: Int((response.confidence * 100).rounded())
        )
        await displayLogic?.displayHandPoseUpdate(viewModel: viewModel)
    }

    // MARK: - Advance

    func presentAdvance(
        response: FingerPlayModels.Advance.Response,
        permissionDenied: Bool,
        currentIndex: Int,
        stageIndex: Int
    ) async {
        if let next = response.nextExercise {
            let nextStartVM = FingerPlayModels.Start.ViewModel(
                exerciseTitle: next.title,
                stageDescription: next.stages[response.nextStage].description,
                targetGestureSymbol: next.stages[response.nextStage].symbol,
                targetPoseRaw: next.stages[response.nextStage].targetPose,
                totalExercises: response.completedCount + 1,
                currentIndex: currentIndex,
                stageIndex: stageIndex,
                isPermissionDenied: permissionDenied,
                accessibilityLabel: "Упражнение: \(next.title)."
            )
            let viewModel = FingerPlayModels.Advance.ViewModel(
                nextStartVM: nextStartVM,
                isSessionFinished: false,
                completedCount: response.completedCount,
                summaryMessage: nil
            )
            await displayLogic?.displayAdvance(viewModel: viewModel)
        } else {
            let viewModel = FingerPlayModels.Advance.ViewModel(
                nextStartVM: nil,
                isSessionFinished: true,
                completedCount: response.completedCount,
                summaryMessage: "Молодец! Ты выполнил \(response.completedCount) упражнений."
            )
            await displayLogic?.displayAdvance(viewModel: viewModel)
        }
    }

    // MARK: - Helpers

    private func symbol(for pose: String) -> String {
        switch pose {
        case "fist":      return "hand.raised.fingers.spread.fill"
        case "open_palm": return "hand.raised.fill"
        case "point":     return "hand.point.up.left.fill"
        case "pinch":     return "hand.pinch.fill"
        case "thumbs_up": return "hand.thumbsup.fill"
        case "wave":      return "hand.wave.fill"
        default:          return "questionmark.circle"
        }
    }
}
