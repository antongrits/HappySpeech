import Foundation
import Observation

// MARK: - WorldMapDisplayLogic

@MainActor
protocol WorldMapDisplayLogic: AnyObject {
    func displayLoadMap(_ viewModel: WorldMapModels.LoadMap.ViewModel)
    func displaySelectZone(_ viewModel: WorldMapModels.SelectZone.ViewModel)
    func displayFailure(_ viewModel: WorldMapModels.Failure.ViewModel)
    func displayLoading(_ isLoading: Bool)
}

// MARK: - WorldMapDisplay

/// Источник истины SwiftUI-вью карты звуков.
@Observable
@MainActor
final class WorldMapDisplay: WorldMapDisplayLogic {

    var zones: [WorldZoneCard] = []
    var highlightedZoneId: String?
    var totalStarsLabel: String = ""
    var totalProgressFraction: Double = 0
    var streakLabel: String = ""
    var hasStreak: Bool = false
    var summaryAccessibilityLabel: String = ""

    var isLoading: Bool = false
    var toastMessage: String?

    func displayLoadMap(_ viewModel: WorldMapModels.LoadMap.ViewModel) {
        zones = viewModel.zones
        highlightedZoneId = viewModel.highlightedZoneId
        totalStarsLabel = viewModel.totalStarsLabel
        totalProgressFraction = viewModel.totalProgressFraction
        streakLabel = viewModel.streakLabel
        hasStreak = viewModel.hasStreak
        summaryAccessibilityLabel = viewModel.summaryAccessibilityLabel
        isLoading = false
    }

    func displaySelectZone(_ viewModel: WorldMapModels.SelectZone.ViewModel) {
        if let toast = viewModel.toastMessage {
            toastMessage = toast
        }
    }

    func displayFailure(_ viewModel: WorldMapModels.Failure.ViewModel) {
        toastMessage = viewModel.toastMessage
        isLoading = false
    }

    func displayLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }

    func clearToast() {
        toastMessage = nil
    }
}
