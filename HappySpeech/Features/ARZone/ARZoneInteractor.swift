import ARKit
import Foundation
import OSLog

// MARK: - ARZoneBusinessLogic

@MainActor
protocol ARZoneBusinessLogic: AnyObject {
    func loadGames(_ request: ARZoneModels.LoadGames.Request)
    func selectGame(_ request: ARZoneModels.SelectGame.Request)
    func selectFallback(_ request: ARZoneModels.SelectFallback.Request)
    func dismissTutorial(_ request: ARZoneModels.DismissTutorial.Request)
    func refreshPlannerAdvice(_ request: ARZoneModels.RefreshPlannerAdvice.Request)
}

// MARK: - ARZoneInteractor

@MainActor
final class ARZoneInteractor: ARZoneBusinessLogic {

    var presenter: (any ARZonePresentationLogic)?

    // MARK: - Dependencies

    /// AdaptivePlannerService — получаем через AppContainer в ARZoneView.bootstrap().
    /// Если nil — деградируем до дефолтного поведения (без рекомендаций).
    var plannerService: (any AdaptivePlannerService)?

    // MARK: - Internal State

    /// Кешируем план на текущую сессию ARZone — не делаем повторных запросов к planner
    /// при каждом появлении экрана (только явный refreshPlannerAdvice).
    private var cachedAdvice: ARPlannerAdvice?

    /// Набор игр, которые пользователь уже запускал за эту сессию приложения.
    /// Используется для пометки `hasBeenPlayedBefore` без запроса к Realm.
    private var playedGameIds: Set<String> = []

    /// Текущий childId — устанавливается в первом loadGames, используется в refresh.
    private var currentChildId: String = ""

    // MARK: - loadGames

    func loadGames(_ request: ARZoneModels.LoadGames.Request) {
        currentChildId = request.childId

        let games = ARGameCatalog.all
        let instructions = InstructionCatalog.seeds
        let tips = InstructionCatalog.tipSeeds

        HSLogger.ar.debug(
            "ARZone loadGames childId=\(request.childId, privacy: .private) games=\(games.count)"
        )

        // Запрашиваем рекомендацию планировщика асинхронно — не блокируем первый рендер.
        Task { [weak self] in
            guard let self else { return }
            let advice = await self.fetchPlannerAdvice(childId: request.childId, games: games)
            self.cachedAdvice = advice

            let response = ARZoneModels.LoadGames.Response(
                games: games,
                instructions: instructions,
                tips: tips,
                plannerAdvice: advice
            )
            self.presenter?.presentLoadGames(response)
        }

        // Немедленно рендерим без advice — пользователь видит игры моментально.
        let immediateResponse = ARZoneModels.LoadGames.Response(
            games: games,
            instructions: instructions,
            tips: tips,
            plannerAdvice: nil
        )
        presenter?.presentLoadGames(immediateResponse)
    }

    // MARK: - selectGame

    func selectGame(_ request: ARZoneModels.SelectGame.Request) {
        guard let game = ARGameCatalog.game(id: request.gameId) else {
            HSLogger.ar.error("Unknown AR game id: \(request.gameId, privacy: .public)")
            return
        }

        let tutorial = ARTutorialCatalog.tutorial(for: request.gameId)
        let hasPlayed = playedGameIds.contains(request.gameId)

        HSLogger.ar.info(
            "ARZone selectGame id=\(request.gameId, privacy: .public) skipTutorial=\(request.skipTutorial) hasPlayed=\(hasPlayed)"
        )

        let response = ARZoneModels.SelectGame.Response(
            game: game,
            tutorial: tutorial,
            skipTutorial: request.skipTutorial || hasPlayed
        )
        presenter?.presentSelectGame(response)
    }

    // MARK: - selectFallback

    /// Пользователь нажал «Открыть 2D-альтернативу» на устройстве без TrueDepth.
    func selectFallback(_ request: ARZoneModels.SelectFallback.Request) {
        HSLogger.ar.info("ARZone fallback CTA tapped — routing back to map.")
        presenter?.presentSelectFallback(ARZoneModels.SelectFallback.Response())
    }

    // MARK: - dismissTutorial

    func dismissTutorial(_ request: ARZoneModels.DismissTutorial.Request) {
        // Отмечаем как «уже играл» — следующий раз tutorial будет пропущен.
        if let game = ARGameCatalog.game(forDestination: request.destination) {
            playedGameIds.insert(game.id)
        }
        HSLogger.ar.info(
            "ARZone dismissTutorial action=\(String(describing: request.action)) dest=\(String(describing: request.destination))"
        )
        let response = ARZoneModels.DismissTutorial.Response(destination: request.destination)
        presenter?.presentDismissTutorial(response)
    }

    // MARK: - refreshPlannerAdvice

    func refreshPlannerAdvice(_ request: ARZoneModels.RefreshPlannerAdvice.Request) {
        Task { [weak self] in
            guard let self else { return }
            let games = ARGameCatalog.all
            let advice = await self.fetchPlannerAdvice(childId: request.childId, games: games)
            self.cachedAdvice = advice
            let response = ARZoneModels.RefreshPlannerAdvice.Response(advice: advice)
            self.presenter?.presentRefreshPlannerAdvice(response)
        }
    }

    // MARK: - Private helpers

    /// Запрашивает рекомендацию AdaptivePlannerService и строит ARPlannerAdvice.
    /// Безопасно деградирует до `.none` если сервис недоступен или упал.
    private func fetchPlannerAdvice(childId: String, games: [ARGame]) async -> ARPlannerAdvice {
        guard let planner = plannerService, !childId.isEmpty else {
            return ARPlannerAdvice(kind: .none)
        }

        do {
            let route = try await planner.buildDailyRoute(for: childId)

            // Проверяем уровень усталости из AdaptiveRoute.
            switch route.fatigueLevel {
            case .tired:
                HSLogger.planner.info("ARZone: fatigue=tired → fatigueWarning")
                return ARPlannerAdvice(kind: .fatigueWarning(level: .tired))
            case .normal:
                // Нормальная усталость — лёгкая подсказка, не блокирующая.
                // Ищем AR-шаг в маршруте, чтобы выдать рекомендацию.
                if let arRecommended = findRecommendedARGame(in: route, games: games) {
                    return ARPlannerAdvice(kind: .arRecommended(gameId: arRecommended.id),
                                          recommendedGameId: arRecommended.id)
                }
                return ARPlannerAdvice(kind: .fatigueWarning(level: .normal))
            case .fresh:
                // Смотрим, есть ли AR в маршруте планировщика.
                if let arRecommended = findRecommendedARGame(in: route, games: games) {
                    HSLogger.planner.info(
                        "ARZone: planner recommends arGame=\(arRecommended.id, privacy: .public)"
                    )
                    return ARPlannerAdvice(kind: .arRecommended(gameId: arRecommended.id),
                                          recommendedGameId: arRecommended.id)
                }
                return ARPlannerAdvice(kind: .none)
            }
        } catch {
            HSLogger.planner.warning(
                "ARZone plannerAdvice error — degrade to .none: \(error.localizedDescription, privacy: .public)"
            )
            return ARPlannerAdvice(kind: .none)
        }
    }

    /// Ищет в маршруте AR-шаблон и находит соответствующую AR-игру.
    /// ARActivity-шаблоны из маршрута не маппируются напрямую на AR-игры —
    /// используем эвристику: первая AR-игра с низкой сложностью.
    private func findRecommendedARGame(in route: AdaptiveRoute, games: [ARGame]) -> ARGame? {
        // 1. Проверяем, есть ли ARActivity в маршруте.
        let hasARActivity = route.steps.contains { $0.templateType == .arActivity }
        guard hasARActivity || !route.steps.isEmpty else { return nil }

        // 2. Выбираем наименее сложную AR-игру (difficulty == 1) — безопаснее для детей.
        return games
            .filter { $0.requiresFaceTracking }
            .min(by: { $0.difficulty < $1.difficulty })
    }
}

// MARK: - ARGameCatalog extension

extension ARGameCatalog {
    /// Находит игру по ARGameDestination.
    static func game(forDestination destination: ARGameDestination) -> ARGame? {
        all.first { $0.destination == destination }
    }
}
