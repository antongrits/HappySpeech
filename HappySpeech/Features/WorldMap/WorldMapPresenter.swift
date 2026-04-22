import Foundation

// MARK: - WorldMapPresentationLogic

@MainActor
protocol WorldMapPresentationLogic: AnyObject {
    func presentFetch(_ response: WorldMapModels.Fetch.Response)
    func presentUpdate(_ response: WorldMapModels.Update.Response)
}

// MARK: - WorldMapPresenter

@MainActor
final class WorldMapPresenter: WorldMapPresentationLogic {

    weak var viewModel: (any WorldMapDisplayLogic)?

    func presentFetch(_ response: WorldMapModels.Fetch.Response) {
        let vm = WorldMapModels.Fetch.ViewModel()
        viewModel?.displayFetch(vm)
    }

    func presentUpdate(_ response: WorldMapModels.Update.Response) {
        let vm = WorldMapModels.Update.ViewModel()
        viewModel?.displayUpdate(vm)
    }
}
