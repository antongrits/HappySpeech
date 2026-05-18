import Foundation
import SwiftUI

// MARK: - StutteringRouter

@MainActor
final class StutteringRouter {

    weak var coordinator: AppCoordinator?

    // MARK: - Root Navigation

    func routeToStutteringHome() {
        coordinator?.navigate(to: .stutteringHome)
    }

    func routeToFluencyDiaryParent() {
        coordinator?.navigate(to: .fluencyDiaryParent)
    }

    // MARK: - Sub-feature Routing

    /// Возвращает View для выбранного режима (inline в NavigationStack).
    @ViewBuilder
    func destinationView(for mode: StutteringMode) -> some View {
        switch mode {
        case .metronome:
            MetronomeView()
        case .breathing:
            BreathingTreeView()
        case .softOnset:
            SoftOnsetView()
        case .diary:
            FluencyDiaryView()
        case .pacing:
            PacingView()
        }
    }
}
