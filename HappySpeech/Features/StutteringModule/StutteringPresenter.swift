import Foundation

// MARK: - StutteringPresentationLogic

@MainActor
protocol StutteringPresentationLogic: AnyObject {
    func presentLoadScreen(_ response: StutteringModels.LoadScreen.Response)
    func presentSelectMode(_ response: StutteringModels.SelectMode.Response)
    func presentLoadProgress(_ response: StutteringModels.LoadProgress.Response)
    func presentAdaptiveRecommendation(_ response: StutteringModels.LoadAdaptiveRecommendation.Response)
}

// MARK: - StutteringPresenter

@MainActor
final class StutteringPresenter: StutteringPresentationLogic {

    weak var view: (any StutteringDisplayLogic)?

    // MARK: - Load Screen

    func presentLoadScreen(_ response: StutteringModels.LoadScreen.Response) {
        let cards = response.cards.map { card in
            ExerciseCardViewModel(
                mode: card.mode,
                title: localizedTitle(for: card.mode),
                subtitle: localizedSubtitle(for: card.mode),
                symbol: card.symbol,
                symbolColor: card.symbolColor,
                duration: card.duration,
                accessibilityLabel: "\(localizedTitle(for: card.mode)), \(card.duration)",
                isRecommended: false,
                completedToday: false,
                streak: 0
            )
        }
        let viewModel = StutteringModels.LoadScreen.ViewModel(
            cards: cards,
            showWelcomeSheet: !response.hasSeenWelcome
        )
        view?.displayLoadScreen(viewModel)
    }

    func presentSelectMode(_ response: StutteringModels.SelectMode.Response) {
        view?.displaySelectMode(.init(mode: response.mode))
    }

    // MARK: - Load Progress

    func presentLoadProgress(_ response: StutteringModels.LoadProgress.Response) {
        let rows: [FeatureProgressViewModel] = StutteringMode.allCases.compactMap { mode in
            guard let progress = response.featureProgress[mode] else { return nil }
            let streakLabel: String
            if progress.streak == 0 {
                streakLabel = String(localized: "stuttering.progress.streak.none")
            } else {
                streakLabel = "\(progress.streak) \(String(localized: "stuttering.progress.streak.days"))"
            }
            return FeatureProgressViewModel(
                mode: mode,
                modeTitle: localizedTitle(for: mode),
                streakLabel: streakLabel,
                completedToday: progress.completedToday,
                streakAccessibilityLabel: "\(localizedTitle(for: mode)), \(streakLabel)"
            )
        }
        let sessionsLabel = "\(response.totalSessions) \(String(localized: "stuttering.progress.sessions"))"
        let pct = Int(response.fluencyImprovementPct * 100)
        let fluencyLabel = "\(pct)% \(String(localized: "stuttering.progress.fluency"))"
        let vm = StutteringModels.LoadProgress.ViewModel(
            featureRows: rows,
            totalSessionsLabel: sessionsLabel,
            fluencyLabel: fluencyLabel
        )
        view?.displayLoadProgress(vm)
    }

    // MARK: - Adaptive Recommendation

    func presentAdaptiveRecommendation(_ response: StutteringModels.LoadAdaptiveRecommendation.Response) {
        let vm = StutteringModels.LoadAdaptiveRecommendation.ViewModel(
            recommendedMode: response.recommendedMode,
            voicePromptText: response.voicePromptText,
            showGlowAnimation: response.shouldShowGlow
        )
        view?.displayAdaptiveRecommendation(vm)
    }

    // MARK: - Helpers

    private func localizedTitle(for mode: StutteringMode) -> String {
        switch mode {
        case .metronome:       return String(localized: "stuttering.exercise.metronome.title")
        case .breathing:       return String(localized: "stuttering.exercise.breathing.title")
        case .softOnset:       return String(localized: "stuttering.exercise.soft_start.title")
        case .diary:           return String(localized: "stuttering.exercise.diary.title")
        case .pacing:          return String(localized: "stuttering.exercise.pacing.title")
        }
    }

    private func localizedSubtitle(for mode: StutteringMode) -> String {
        switch mode {
        case .metronome:       return String(localized: "stuttering.exercise.metronome.subtitle")
        case .breathing:       return String(localized: "stuttering.exercise.breathing.subtitle")
        case .softOnset:       return String(localized: "stuttering.exercise.soft_start.subtitle")
        case .diary:           return String(localized: "stuttering.exercise.diary.subtitle")
        case .pacing:          return String(localized: "stuttering.exercise.pacing.subtitle")
        }
    }
}
