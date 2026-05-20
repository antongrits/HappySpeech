import Foundation

@MainActor
protocol DailyTimeCapDisplayLogic: AnyObject {
    func displayStatus(viewModel: DailyTimeCapModels.Status.ViewModel) async
}
