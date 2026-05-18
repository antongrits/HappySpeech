import Foundation
import OSLog

// MARK: - BreatheAndSpeakPresentationLogic

@MainActor
protocol BreatheAndSpeakPresentationLogic: AnyObject {
    func presentStart(response: BreatheAndSpeakModels.Start.Response) async
    func presentAdvance(response: BreatheAndSpeakModels.Advance.Response) async
}

// MARK: - BreatheAndSpeakPresenter (Clean Swift: Presenter)
//
// v29 Фаза 8, Функция 10 «Дыши и говори».
//
// Строит ViewModel шагов комплекса: название упражнения, инструкцию,
// прогресс, итоговую сводку. Тон тёплый, поддерживающий (детский контур).

@MainActor
final class BreatheAndSpeakPresenter: BreatheAndSpeakPresentationLogic {

    weak var displayLogic: (any BreatheAndSpeakDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "BreatheAndSpeak.Presenter"
    )

    init(displayLogic: (any BreatheAndSpeakDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Start

    func presentStart(response: BreatheAndSpeakModels.Start.Response) async {
        let exercises = response.complex.exercises
        guard let firstExercise = exercises.first else {
            Self.logger.error("Start with empty complex")
            return
        }
        let viewModel = BreatheAndSpeakModels.Start.ViewModel(
            title: String(localized: "breatheAndSpeak.title"),
            complexTitle: response.complex.title,
            totalSteps: exercises.count,
            firstStep: Self.makeStepVM(firstExercise, index: 0, total: exercises.count)
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - Advance

    func presentAdvance(response: BreatheAndSpeakModels.Advance.Response) async {
        let nextVM: BreatheAndSpeakModels.Start.StepViewModel?
        if let nextStep = response.nextStep, let nextIndex = response.nextStepIndex {
            nextVM = Self.makeStepVM(nextStep, index: nextIndex, total: response.totalSteps)
        } else {
            nextVM = nil
        }

        let summary: BreatheAndSpeakModels.Advance.SummaryViewModel?
        if response.isFinished {
            summary = .init(
                title: String(localized: "breatheAndSpeak.summary.title"),
                completedSteps: response.completedSteps,
                totalSteps: response.totalSteps,
                encouragement: String(localized: "breatheAndSpeak.summary.encouragement")
            )
        } else {
            summary = nil
        }

        let viewModel = BreatheAndSpeakModels.Advance.ViewModel(
            isFinished: response.isFinished,
            nextStep: nextVM,
            summary: summary
        )
        await displayLogic?.displayAdvance(viewModel: viewModel)
    }

    // MARK: - Helpers

    static func makeStepVM(
        _ exercise: ComplexExercise,
        index: Int,
        total: Int
    ) -> BreatheAndSpeakModels.Start.StepViewModel {
        let humanIndex = index + 1
        let stepLabel = String(
            format: String(localized: "breatheAndSpeak.step"),
            humanIndex,
            total
        )
        let fraction = total > 0 ? Double(humanIndex) / Double(total) : 0
        let kindLabel = exercise.kind == .breathing
            ? String(localized: "breatheAndSpeak.kind.breathing")
            : String(localized: "breatheAndSpeak.kind.articulation")
        return .init(
            id: exercise.id,
            kind: exercise.kind,
            name: exercise.name,
            instruction: exercise.instruction,
            symbolName: exercise.symbolName,
            holdSeconds: exercise.holdSeconds,
            stepLabel: stepLabel,
            progressFraction: fraction,
            accessibilityLabel: String(
                format: String(localized: "breatheAndSpeak.step.a11y"),
                kindLabel,
                exercise.name,
                exercise.instruction
            )
        )
    }
}
