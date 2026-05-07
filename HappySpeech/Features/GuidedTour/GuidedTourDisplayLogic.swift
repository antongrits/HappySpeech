import Foundation

// MARK: - GuidedTourPresentationLogic
//
// Block I v16 — VIP protocols.
//
// Поток данных VIP:
//   View (Coordinator) → Interactor → Presenter → Display → ViewModel → Container/Tip View

@MainActor
protocol GuidedTourPresentationLogic: AnyObject {
    func presentLoadTour(_ response: GuidedTourModels.LoadTour.Response)
    func presentNextStep(_ response: GuidedTourModels.NextStep.Response)
    func presentPreviousStep(_ response: GuidedTourModels.PreviousStep.Response)
    func presentSkipTour(_ response: GuidedTourModels.SkipTour.Response)
    func presentCompleteTour(_ response: GuidedTourModels.CompleteTour.Response)
    func presentResetTour(_ response: GuidedTourModels.ResetTour.Response)
    func presentAutoAdvance(_ response: GuidedTourModels.AutoAdvance.Response)
}

// MARK: - GuidedTourDisplayLogic

/// Контракт между Presenter и Coordinator (Coordinator выступает в роли Display
/// одновременно являясь "view-state holder" для SwiftUI через `@Observable`).
@MainActor
protocol GuidedTourDisplayLogic: AnyObject {
    func displayLoadTour(_ viewModel: GuidedTourModels.LoadTour.ViewModel)
    func displayNextStep(_ viewModel: GuidedTourModels.NextStep.ViewModel)
    func displayPreviousStep(_ viewModel: GuidedTourModels.PreviousStep.ViewModel)
    func displaySkipTour(_ viewModel: GuidedTourModels.SkipTour.ViewModel)
    func displayCompleteTour(_ viewModel: GuidedTourModels.CompleteTour.ViewModel)
    func displayResetTour(_ viewModel: GuidedTourModels.ResetTour.ViewModel)
    func displayAutoAdvance(_ viewModel: GuidedTourModels.AutoAdvance.ViewModel)
}

// MARK: - GuidedTourBusinessLogic

/// Контракт Interactor-а (для DI / тестов).
@MainActor
protocol GuidedTourBusinessLogic: AnyObject {
    func loadTour(_ request: GuidedTourModels.LoadTour.Request)
    func nextStep(_ request: GuidedTourModels.NextStep.Request)
    func previousStep(_ request: GuidedTourModels.PreviousStep.Request)
    func skipTour(_ request: GuidedTourModels.SkipTour.Request)
    func completeTour(_ request: GuidedTourModels.CompleteTour.Request)
    func resetTour(_ request: GuidedTourModels.ResetTour.Request)
    func autoAdvance(_ request: GuidedTourModels.AutoAdvance.Request)
}

// MARK: - GuidedTourRoutingLogic

@MainActor
protocol GuidedTourRoutingLogic {
    /// После завершения тура — опциональный переход (например, на ChildHome).
    /// Базовая реализация — no-op (тур закрывается, ничего не навигирует).
    func routeAfterTourCompletion()
    /// На последнем шаге — переход в основной поток (kid home).
    func routeToHome()
}
