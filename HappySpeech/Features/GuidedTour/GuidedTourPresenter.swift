import Foundation
import OSLog

// MARK: - GuidedTourPresenter
//
// Block I v16 — Presenter преобразует Response (бизнес-результаты) в ViewModel
// (готовые для рендера данные). Никакой бизнес-логики здесь нет — только
// форматирование (progress fraction, step number, isLastStep flag).

@MainActor
final class GuidedTourPresenter: GuidedTourPresentationLogic {

    // MARK: - Collaborators

    weak var display: (any GuidedTourDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "GuidedTourPresenter")

    // MARK: - LoadTour

    func presentLoadTour(_ response: GuidedTourModels.LoadTour.Response) {
        switch response.kind {
        case .started:
            let step = step(at: response.initialIndex, in: response.steps)
            let viewModel = GuidedTourModels.LoadTour.ViewModel(
                isVisible: true,
                currentStep: step,
                stepNumber: response.initialIndex + 1,
                totalSteps: response.steps.count,
                progressFraction: progressFraction(
                    index: response.initialIndex,
                    total: response.steps.count
                ),
                isLastStep: response.initialIndex == response.steps.count - 1
            )
            display?.displayLoadTour(viewModel)

        case .alreadyCompleted:
            logger.debug("presentLoadTour: alreadyCompleted — overlay hidden")
            display?.displayLoadTour(.init(
                isVisible: false,
                currentStep: nil,
                stepNumber: 0,
                totalSteps: response.steps.count,
                progressFraction: 0,
                isLastStep: false
            ))

        case .gatedBySessionCount(let required, let current):
            logger.debug(
                "presentLoadTour: gated required=\(required, privacy: .public) current=\(current, privacy: .public)"
            )
            display?.displayLoadTour(.init(
                isVisible: false,
                currentStep: nil,
                stepNumber: 0,
                totalSteps: response.steps.count,
                progressFraction: 0,
                isLastStep: false
            ))
        }
    }

    // MARK: - NextStep

    func presentNextStep(_ response: GuidedTourModels.NextStep.Response) {
        switch response.kind {
        case .advanced:
            guard let index = response.newIndex else { return }
            let step = self.step(at: index, in: response.steps)
            display?.displayNextStep(.init(
                isVisible: true,
                currentStep: step,
                stepNumber: index + 1,
                totalSteps: response.steps.count,
                progressFraction: progressFraction(index: index, total: response.steps.count),
                isLastStep: index == response.steps.count - 1
            ))

        case .completed:
            display?.displayNextStep(.init(
                isVisible: false,
                currentStep: nil,
                stepNumber: response.steps.count,
                totalSteps: response.steps.count,
                progressFraction: 1.0,
                isLastStep: true
            ))

        case .noop:
            // Тур не активен — ничего не делаем.
            break
        }
    }

    // MARK: - PreviousStep

    func presentPreviousStep(_ response: GuidedTourModels.PreviousStep.Response) {
        switch response.kind {
        case .retreated:
            guard let index = response.newIndex else { return }
            let step = self.step(at: index, in: response.steps)
            display?.displayPreviousStep(.init(
                isVisible: true,
                currentStep: step,
                stepNumber: index + 1,
                totalSteps: response.steps.count,
                progressFraction: progressFraction(index: index, total: response.steps.count),
                isLastStep: index == response.steps.count - 1
            ))

        case .atFirstStep, .noop:
            // На первом шаге — оставляем UI как есть (можно показать haptic feedback,
            // но это уровень View, не Presenter).
            break
        }
    }

    // MARK: - SkipTour

    func presentSkipTour(_ response: GuidedTourModels.SkipTour.Response) {
        logger.info(
            "presentSkipTour at=\(response.skippedAtIndex, privacy: .public)/\(response.totalSteps, privacy: .public)"
        )
        display?.displaySkipTour(.init(isVisible: false))
    }

    // MARK: - CompleteTour

    func presentCompleteTour(_ response: GuidedTourModels.CompleteTour.Response) {
        logger.info("presentCompleteTour reachedFinal=\(response.reachedFinalStep, privacy: .public)")
        display?.displayCompleteTour(.init(isVisible: false))
    }

    // MARK: - ResetTour

    func presentResetTour(_ response: GuidedTourModels.ResetTour.Response) {
        _ = response
        display?.displayResetTour(.init(isVisible: false))
    }

    // MARK: - AutoAdvance

    func presentAutoAdvance(_ response: GuidedTourModels.AutoAdvance.Response) {
        switch response.kind {
        case .advanced:
            guard let index = response.newIndex else { return }
            let step = self.step(at: index, in: response.steps)
            display?.displayAutoAdvance(.init(
                isVisible: true,
                currentStep: step,
                stepNumber: index + 1,
                totalSteps: response.steps.count,
                progressFraction: progressFraction(index: index, total: response.steps.count),
                isLastStep: index == response.steps.count - 1
            ))

        case .completed:
            display?.displayAutoAdvance(.init(
                isVisible: false,
                currentStep: nil,
                stepNumber: response.steps.count,
                totalSteps: response.steps.count,
                progressFraction: 1.0,
                isLastStep: true
            ))

        case .stale:
            // Гонка — пользователь уже двинулся вручную. Игнорируем.
            break
        }
    }

    // MARK: - Helpers

    private func step(at index: Int, in steps: [TourStep]) -> TourStep? {
        guard steps.indices.contains(index) else { return nil }
        return steps[index]
    }

    private func progressFraction(index: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(index + 1) / Double(total)
    }
}
