import Foundation

// MARK: - KaraokePitchDisplayLogic
//
// Контракт между Presenter и View. Все методы — @MainActor isolated через
// SwiftUI @Observable holder в KaraokePitchView.swift.

@MainActor
protocol KaraokePitchDisplayLogic: AnyObject {
    func displayStart(viewModel: KaraokePitchModels.Start.ViewModel) async
    func displayLiveSample(viewModel: KaraokePitchModels.LiveSample.ViewModel) async
    func displayScore(viewModel: KaraokePitchModels.Score.ViewModel) async
}
