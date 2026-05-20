import Foundation

// MARK: - ObjectDescriptionMapDisplayLogic

/// Контракт между Presenter и View (Holder).
@MainActor
protocol ObjectDescriptionMapDisplayLogic: AnyObject {
    func displayLoadObjects(viewModel: ObjectDescriptionMapModels.LoadObjects.ViewModel) async
    func displaySelectObject(viewModel: ObjectDescriptionMapModels.SelectObject.ViewModel) async
    func displayRecordResult(viewModel: ObjectDescriptionMapModels.RecordResult.ViewModel) async
}
