import Foundation
import Observation
import OSLog

// MARK: - GuidedTourCoordinator
//
// Block I v16 — Coordinator переписан как DisplayLogic над VIP-стэком.
//
// Архитектура (Clean Swift VIP):
//   View / Container     → Coordinator (Display)  — рендерит ViewModel
//   Coordinator (Intent) → Interactor             — отправляет Request
//   Interactor           → Presenter              — формирует Response
//   Presenter            → Coordinator (Display)  — выдаёт ViewModel
//
// Coordinator одновременно:
//   1. Принимает intents от UI (start/next/skip).
//   2. Реализует GuidedTourDisplayLogic — обновляет @Observable state.
//
// Этот двойной hat — устоявшийся pattern в проекте (см. также Onboarding).
// Альтернатива (отдельный Display-объект) даёт лишний indirection без
// практической пользы для overlay-flow.
//
// Persistence, gating, analytics, side-effects → перенесены в Interactor.
// Coordinator теперь stateless по отношению к persistence — просто кеширует
// текущее ViewModel для SwiftUI binding.

/// Orchestrates the guided-tour overlay state by relaying user intents to
/// `GuidedTourInteractor` and projecting `ViewModel` updates into a
/// SwiftUI-observable state.
///
/// `@Observable` + `@MainActor` — соответствует convention проекта.
@MainActor
@Observable
final class GuidedTourCoordinator: GuidedTourDisplayLogic {

    // MARK: - State (UI-уровень, derived from ViewModel)

    /// Полный список шагов (как в текущем flavor). Кешируется при load.
    private(set) var steps: [TourStep]

    /// Индекс текущего шага. `nil` пока тур не активен.
    private(set) var currentIndex: Int?

    /// Виден ли overlay прямо сейчас.
    private(set) var isActive: Bool = false

    /// Был ли тур уже пройден (для UI Settings: показывать кнопку "Снова").
    private(set) var hasCompleted: Bool

    // MARK: - VIP collaborators

    private let interactor: any GuidedTourBusinessLogic
    private let router: any GuidedTourRoutingLogic

    private let logger = Logger(subsystem: "ru.happyspeech", category: "GuidedTour")

    // MARK: - Init

    init(
        interactor: any GuidedTourBusinessLogic,
        router: any GuidedTourRoutingLogic,
        steps: [TourStep] = TourSteps.all,
        hasCompleted: Bool = false
    ) {
        self.interactor = interactor
        self.router = router
        self.steps = steps
        self.hasCompleted = hasCompleted
    }

    // MARK: - Derived

    var currentStep: TourStep? {
        guard let index = currentIndex, steps.indices.contains(index) else { return nil }
        return steps[index]
    }

    var progressFraction: Double {
        guard !steps.isEmpty, let index = currentIndex else { return 0 }
        return Double(index + 1) / Double(steps.count)
    }

    var isOnLastStep: Bool {
        guard let index = currentIndex else { return false }
        return index == steps.count - 1
    }

    // MARK: - Intents (UI → Interactor)

    /// Старт тура. `force=true` запускает повторно даже после `complete()`.
    /// `childId` нужен для session-count gating; `nil` — пропустить gating.
    func start(force: Bool = false, childId: String? = nil) {
        logger.info("intent: start force=\(force, privacy: .public)")
        interactor.loadTour(.init(force: force, childId: childId))
    }

    func next() {
        logger.debug("intent: next from index=\(self.currentIndex ?? -1, privacy: .public)")
        interactor.nextStep(.init())
    }

    func previous() {
        logger.debug("intent: previous from index=\(self.currentIndex ?? -1, privacy: .public)")
        interactor.previousStep(.init())
    }

    func skip() {
        logger.info("intent: skip at=\(self.currentIndex ?? -1, privacy: .public)")
        interactor.skipTour(.init())
    }

    /// Сбросить флаг прохождения (QA / Settings re-trigger).
    func resetForTesting() {
        logger.info("intent: reset")
        interactor.resetTour(.init())
    }

    // MARK: - DisplayLogic

    func displayLoadTour(_ viewModel: GuidedTourModels.LoadTour.ViewModel) {
        applyViewModel(
            isVisible: viewModel.isVisible,
            currentStep: viewModel.currentStep,
            stepNumber: viewModel.stepNumber
        )
    }

    func displayNextStep(_ viewModel: GuidedTourModels.NextStep.ViewModel) {
        applyViewModel(
            isVisible: viewModel.isVisible,
            currentStep: viewModel.currentStep,
            stepNumber: viewModel.stepNumber
        )
        if !viewModel.isVisible {
            hasCompleted = true
            router.routeAfterTourCompletion()
        }
    }

    func displayPreviousStep(_ viewModel: GuidedTourModels.PreviousStep.ViewModel) {
        applyViewModel(
            isVisible: viewModel.isVisible,
            currentStep: viewModel.currentStep,
            stepNumber: viewModel.stepNumber
        )
    }

    func displaySkipTour(_ viewModel: GuidedTourModels.SkipTour.ViewModel) {
        isActive = viewModel.isVisible
        currentIndex = nil
        hasCompleted = true
        router.routeAfterTourCompletion()
    }

    func displayCompleteTour(_ viewModel: GuidedTourModels.CompleteTour.ViewModel) {
        isActive = viewModel.isVisible
        currentIndex = nil
        hasCompleted = true
        router.routeAfterTourCompletion()
    }

    func displayResetTour(_ viewModel: GuidedTourModels.ResetTour.ViewModel) {
        isActive = viewModel.isVisible
        currentIndex = nil
        hasCompleted = false
    }

    func displayAutoAdvance(_ viewModel: GuidedTourModels.AutoAdvance.ViewModel) {
        applyViewModel(
            isVisible: viewModel.isVisible,
            currentStep: viewModel.currentStep,
            stepNumber: viewModel.stepNumber
        )
        if !viewModel.isVisible {
            hasCompleted = true
            router.routeAfterTourCompletion()
        }
    }

    // MARK: - Private

    private func applyViewModel(
        isVisible: Bool,
        currentStep: TourStep?,
        stepNumber: Int
    ) {
        isActive = isVisible
        if let currentStep, let index = steps.firstIndex(of: currentStep) {
            currentIndex = index
        } else if isVisible, stepNumber > 0 {
            // Fallback: stepNumber 1-based.
            currentIndex = max(0, min(stepNumber - 1, steps.count - 1))
        } else {
            currentIndex = nil
        }
    }
}
