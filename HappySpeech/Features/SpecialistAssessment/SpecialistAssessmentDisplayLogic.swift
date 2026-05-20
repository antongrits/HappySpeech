import Foundation

// MARK: - SpecialistAssessmentDisplayLogic
//
// v31 Волна D Ф.3 — контракт View ← Presenter.

@MainActor
protocol SpecialistAssessmentDisplayLogic: AnyObject {
    func displayLoad(viewModel: SpecialistAssessmentModels.Load.ViewModel) async
    func displaySubmit(viewModel: SpecialistAssessmentModels.Submit.ViewModel) async
}
