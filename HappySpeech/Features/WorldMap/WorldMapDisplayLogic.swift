import Foundation
import Observation

// MARK: - WorldMapDisplayLogic

@MainActor
protocol WorldMapDisplayLogic: AnyObject {
    func displayLoadMap(_ viewModel: WorldMapModels.LoadMap.ViewModel)
    func displaySelectZone(_ viewModel: WorldMapModels.SelectZone.ViewModel)
    func displayLoadZoneDetail(_ viewModel: WorldMapModels.LoadZoneDetail.ViewModel)
    func displayRefreshProgress(_ viewModel: WorldMapModels.RefreshProgress.ViewModel)
    func displayFailure(_ viewModel: WorldMapModels.Failure.ViewModel)
    func displayLoading(_ isLoading: Bool)
    func displayVoicePrompt(_ viewModel: WorldMapModels.VoicePrompt.ViewModel)
    func displayCollectTreasure(_ viewModel: WorldMapModels.CollectTreasure.ViewModel)
    func displaySelectLevel(_ viewModel: WorldMapModels.SelectLevel.ViewModel)
    func displayAdaptiveRecommendation(_ viewModel: WorldMapModels.AdaptiveRecommendation.ViewModel)
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
    var lyalyaIslandId: String = MapIslandID.vowels.rawValue
    var recommendedIslandId: String?
    var recommendedLevelId: String?

    var isLoading: Bool = false
    var toastMessage: String?
    var voicePromptViewModel: WorldMapModels.VoicePrompt.ViewModel?
    var isPresentingVoicePrompt: Bool = false
    var pendingLevelNavigation: WorldMapModels.SelectLevel.ViewModel?

    // Детальный sheet зоны — заполняется при loadZoneDetail.
    var zoneDetailViewModel: WorldMapModels.LoadZoneDetail.ViewModel?
    var isZoneDetailSheetPresented: Bool = false

    func displayLoadMap(_ viewModel: WorldMapModels.LoadMap.ViewModel) {
        zones = viewModel.zones
        highlightedZoneId = viewModel.highlightedZoneId
        totalStarsLabel = viewModel.totalStarsLabel
        totalProgressFraction = viewModel.totalProgressFraction
        streakLabel = viewModel.streakLabel
        hasStreak = viewModel.hasStreak
        summaryAccessibilityLabel = viewModel.summaryAccessibilityLabel
        lyalyaIslandId = viewModel.lyalyaIslandId
        recommendedIslandId = viewModel.recommendedIslandId
        recommendedLevelId = viewModel.recommendedLevelId
        isLoading = false
    }

    func displaySelectZone(_ viewModel: WorldMapModels.SelectZone.ViewModel) {
        if let toast = viewModel.toastMessage {
            toastMessage = toast
        }
    }

    func displayLoadZoneDetail(_ viewModel: WorldMapModels.LoadZoneDetail.ViewModel) {
        zoneDetailViewModel = viewModel
        isZoneDetailSheetPresented = true
    }

    func displayRefreshProgress(_ viewModel: WorldMapModels.RefreshProgress.ViewModel) {
        zones = viewModel.zones
        totalStarsLabel = viewModel.totalStarsLabel
        totalProgressFraction = viewModel.totalProgressFraction
        streakLabel = viewModel.streakLabel
        hasStreak = viewModel.hasStreak
        summaryAccessibilityLabel = viewModel.summaryAccessibilityLabel
        isLoading = false
    }

    func displayFailure(_ viewModel: WorldMapModels.Failure.ViewModel) {
        toastMessage = viewModel.toastMessage
        isLoading = false
    }

    func displayLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }

    func displayVoicePrompt(_ viewModel: WorldMapModels.VoicePrompt.ViewModel) {
        voicePromptViewModel = viewModel
        isPresentingVoicePrompt = true
    }

    func displayCollectTreasure(_ viewModel: WorldMapModels.CollectTreasure.ViewModel) {
        totalStarsLabel = viewModel.totalStarsLabel
        toastMessage = viewModel.toastMessage
    }

    func displaySelectLevel(_ viewModel: WorldMapModels.SelectLevel.ViewModel) {
        pendingLevelNavigation = viewModel
    }

    func displayAdaptiveRecommendation(_ viewModel: WorldMapModels.AdaptiveRecommendation.ViewModel) {
        recommendedIslandId = viewModel.recommendedIslandId
        recommendedLevelId = viewModel.recommendedLevelId
        if !viewModel.voiceHint.isEmpty {
            voicePromptViewModel = .init(text: viewModel.voiceHint, isLyalya: false)
        }
    }

    func clearToast() {
        toastMessage = nil
    }

    func dismissVoicePrompt() {
        isPresentingVoicePrompt = false
        voicePromptViewModel = nil
    }

    func dismissZoneDetailSheet() {
        isZoneDetailSheetPresented = false
        zoneDetailViewModel = nil
    }

    func clearLevelNavigation() {
        pendingLevelNavigation = nil
    }
}
