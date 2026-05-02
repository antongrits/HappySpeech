import Foundation
import Observation

// MARK: - CustomizationDisplayLogic

/// Протокол дисплея для Customization VIP-цепочки.
@MainActor
protocol CustomizationDisplayLogic: AnyObject {
    func displayLoadedCustomization(viewModel: CustomizationViewModel)
    func displaySaveResult(viewModel: CustomizationViewModel)
    func displaySelectionChanged(viewModel: CustomizationViewModel)
    func displayVoicePreviewState(playingVoice: LyalyaVoice?)
    func displayLockedItemAttempt(viewModel: CustomizationViewModel)
}

// MARK: - CustomizationDisplay

/// @Observable class-backed display object.
/// SwiftUI View держит его как @State — изменения автоматически тригерят перерисовку.
@Observable
@MainActor
final class CustomizationDisplay: CustomizationDisplayLogic {

    var viewModel = CustomizationViewModel()

    func displayLoadedCustomization(viewModel: CustomizationViewModel) {
        self.viewModel = viewModel
    }

    func displaySaveResult(viewModel: CustomizationViewModel) {
        self.viewModel = viewModel
    }

    func displaySelectionChanged(viewModel: CustomizationViewModel) {
        self.viewModel = viewModel
    }

    func displayVoicePreviewState(playingVoice: LyalyaVoice?) {
        self.viewModel.playingVoice = playingVoice
    }

    func displayLockedItemAttempt(viewModel: CustomizationViewModel) {
        self.viewModel = viewModel
    }
}
