import ARKit
import Foundation

// MARK: - ARZonePresentationLogic

@MainActor
protocol ARZonePresentationLogic: AnyObject {
    func presentLoadGames(_ response: ARZoneModels.LoadGames.Response)
    func presentSelectGame(_ response: ARZoneModels.SelectGame.Response)
    func presentSelectFallback(_ response: ARZoneModels.SelectFallback.Response)
    func presentDismissTutorial(_ response: ARZoneModels.DismissTutorial.Response)
    func presentRefreshPlannerAdvice(_ response: ARZoneModels.RefreshPlannerAdvice.Response)
}

// MARK: - ARZonePresenter

@MainActor
final class ARZonePresenter: ARZonePresentationLogic {

    weak var viewModel: (any ARZoneDisplayLogic)?

    // MARK: - presentLoadGames

    func presentLoadGames(_ response: ARZoneModels.LoadGames.Response) {
        let plannerAdvice = response.plannerAdvice

        let cards = response.games.enumerated().map { index, game in
            ARGameCard(
                id: game.id,
                title: String(localized: String.LocalizationValue(game.nameKey)),
                subtitle: String(localized: String.LocalizationValue(game.descriptionKey)),
                iconName: game.iconName,
                difficulty: game.difficulty,
                estimatedMinutes: game.estimatedMinutes,
                accentColorIndex: index,
                destination: game.destination,
                badge: badge(for: game, plannerAdvice: plannerAdvice),
                hasBeenPlayedBefore: false
            )
        }

        let steps = response.instructions.map { seed in
            InstructionStep(
                id: seed.id,
                number: seed.number,
                title: String(localized: String.LocalizationValue(seed.titleKey)),
                body: String(localized: String.LocalizationValue(seed.bodyKey)),
                icon: seed.icon,
                tintIndex: seed.tintIndex
            )
        }

        let tips = response.tips.map { seed in
            ARQuickTip(
                id: seed.id,
                text: String(localized: String.LocalizationValue(seed.textKey)),
                icon: seed.icon
            )
        }

        let isSupported = ARFaceTrackingConfiguration.isSupported
        let phase: ARZonePhase = isSupported ? .ready : .unsupported
        let mascotState: LyalyaAnimation = isSupported ? .waving : .sad

        // Рекомендованная карточка: сначала смотрим на plannerAdvice, иначе — первая лёгкая.
        let recommended: ARGameCard? = buildRecommendedCard(
            cards: cards,
            isSupported: isSupported,
            plannerAdvice: plannerAdvice
        )

        let plannerBanner = plannerBanner(from: plannerAdvice)

        let vm = ARZoneModels.LoadGames.ViewModel(
            cards: cards,
            instructionSteps: steps,
            tips: tips,
            recommendedCard: recommended,
            mascotState: mascotState,
            phase: phase,
            isARSupported: isSupported,
            plannerBanner: plannerBanner
        )
        viewModel?.displayLoadGames(vm)
    }

    // MARK: - presentSelectGame

    func presentSelectGame(_ response: ARZoneModels.SelectGame.Response) {
        // Tutorial пропускается если: явно просили skip, ИЛИ ребёнок уже играл.
        if response.skipTutorial {
            let vm = ARZoneModels.SelectGame.ViewModel(
                destination: response.game.destination,
                tutorial: nil
            )
            viewModel?.displaySelectGame(vm)
        } else {
            // Показываем tutorial sheet перед игрой.
            let localisedTutorial = localise(tutorial: response.tutorial)
            let vm = ARZoneModels.SelectGame.ViewModel(
                destination: response.game.destination,
                tutorial: localisedTutorial
            )
            viewModel?.displayShowTutorial(vm)
        }
    }

    // MARK: - presentSelectFallback

    func presentSelectFallback(_ response: ARZoneModels.SelectFallback.Response) {
        viewModel?.displaySelectFallback(ARZoneModels.SelectFallback.ViewModel())
    }

    // MARK: - presentDismissTutorial

    func presentDismissTutorial(_ response: ARZoneModels.DismissTutorial.Response) {
        let vm = ARZoneModels.DismissTutorial.ViewModel(destination: response.destination)
        viewModel?.displayDismissTutorial(vm)
    }

    // MARK: - presentRefreshPlannerAdvice

    func presentRefreshPlannerAdvice(_ response: ARZoneModels.RefreshPlannerAdvice.Response) {
        let banner = plannerBanner(from: response.advice)
        let vm = ARZoneModels.RefreshPlannerAdvice.ViewModel(banner: banner)
        viewModel?.displayRefreshPlannerAdvice(vm)
    }

    // MARK: - Private helpers

    /// Сопоставляет ARGame с бейджем на основе рекомендации планировщика.
    private func badge(for game: ARGame, plannerAdvice: ARPlannerAdvice?) -> ARGameBadge {
        guard let advice = plannerAdvice else { return .none }
        switch advice.kind {
        case .arRecommended(let recommendedId) where recommendedId == game.id:
            return .recommendedByLyalya
        default:
            return .none
        }
    }

    /// Выбирает рекомендованную карточку с учётом plannerAdvice.
    private func buildRecommendedCard(
        cards: [ARGameCard],
        isSupported: Bool,
        plannerAdvice: ARPlannerAdvice?
    ) -> ARGameCard? {
        guard isSupported else { return nil }

        // Если планировщик рекомендует конкретную игру — отдаём её.
        if case .arRecommended(let gameId) = plannerAdvice?.kind {
            if let card = cards.first(where: { $0.id == gameId }) {
                return card
            }
        }

        // Fallback — первая лёгкая карточка.
        return cards.first(where: { $0.difficulty == 1 }) ?? cards.first
    }

    /// Строит view-модель баннера планировщика.
    private func plannerBanner(from advice: ARPlannerAdvice?) -> ARPlannerBanner? {
        guard let advice else { return nil }
        switch advice.kind {
        case .none:
            return nil

        case .arRecommended(let gameId):
            return ARPlannerBanner(
                id: "planner-recommended-\(gameId)",
                variant: .recommended,
                titleKey: "ar.zone.planner.recommended.title",
                bodyKey: "ar.zone.planner.recommended.body",
                icon: "star.bubble.fill",
                highlightedGameId: gameId
            )

        case .fatigueWarning(let level):
            if level == .tired {
                return ARPlannerBanner(
                    id: "planner-fatigue-tired",
                    variant: .fatigueWarning,
                    titleKey: "ar.zone.planner.fatigue.tired.title",
                    bodyKey: "ar.zone.planner.fatigue.tired.body",
                    icon: "zzz",
                    highlightedGameId: nil
                )
            } else {
                return ARPlannerBanner(
                    id: "planner-fatigue-normal",
                    variant: .fatigueLight,
                    titleKey: "ar.zone.planner.fatigue.normal.title",
                    bodyKey: "ar.zone.planner.fatigue.normal.body",
                    icon: "leaf.fill",
                    highlightedGameId: nil
                )
            }
        }
    }

    /// Локализует ARTutorial — подставляет строки из String Catalog.
    private func localise(tutorial: ARTutorial) -> ARTutorial {
        ARTutorial(
            id: tutorial.id,
            titleKey: tutorial.titleKey,
            bodyKey: tutorial.bodyKey,
            steps: tutorial.steps,
            animationSystemSymbol: tutorial.animationSystemSymbol,
            accentColorIndex: tutorial.accentColorIndex
        )
    }
}
