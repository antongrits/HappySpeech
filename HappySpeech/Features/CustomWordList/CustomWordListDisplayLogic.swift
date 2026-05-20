import Foundation

// MARK: - CustomWordListDisplayLogic

@MainActor
protocol CustomWordListDisplayLogic: AnyObject {
    func displayLoad(viewModel: CustomWordListModels.Load.ViewModel) async
    func displaySaveSuccess(viewModel: CustomWordListModels.Save.ViewModel) async
    func displaySaveFailure(viewModel: CustomWordListModels.Save.FailureViewModel) async
    func displayDelete(removedId: String) async
    func displayPreview(viewModel: CustomWordListModels.Preview.ViewModel) async
}

// MARK: - CustomWordListPresentationLogic

@MainActor
protocol CustomWordListPresentationLogic: AnyObject {
    func presentLoad(response: CustomWordListModels.Load.Response) async
    func presentSaveSuccess(response: CustomWordListModels.Save.Response) async
    func presentSaveFailure(response: CustomWordListModels.Save.FailureResponse) async
    func presentDelete(response: CustomWordListModels.Delete.Response) async
    func presentPreview(response: CustomWordListModels.Preview.Response) async
}
