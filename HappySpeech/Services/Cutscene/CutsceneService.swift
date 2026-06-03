import Foundation
import Observation
import OSLog

// MARK: - CutsceneServiceProtocol

/// Сервис показа нарративных кат-сцен «Путешествие Ляли по Стране Звуков».
///
/// Управляет приоритетной очередью кат-сцен и per-child персистентностью флага
/// «просмотрено» (паттерн `OnboardingState`). Каждая сцена показывается ровно
/// один раз на ребёнка. `pending` — `@Observable`-источник для `fullScreenCover`
/// поверх `AppCoordinatorView`.
@MainActor
protocol CutsceneServiceProtocol: Sendable {

    /// Текущая кат-сцена к показу (голова приоритетной очереди). nil → ничего
    /// не показывается. Observable.
    var pending: Cutscene? { get }

    /// Можно ли показать сцену: `!seen && enabled` и есть видео ИЛИ постер-фолбэк.
    func shouldPlay(_ id: String, childId: String) -> Bool

    /// Кат-сцена для триггера (через каталог), без проверки seen.
    func cutscene(for trigger: CutsceneTrigger) -> Cutscene?

    /// Помечает сцену просмотренной (skip ИЛИ досмотрено до конца) для ребёнка.
    func markSeen(_ id: String, childId: String)

    /// Сбрасывает все seen-флаги ребёнка (повторный просмотр / QA).
    func resetSeen(childId: String)

    /// Маппит триггер→сцену и, если `shouldPlay`, ставит её в очередь по
    /// приоритету. Обновляет `pending`. Повторные enqueue одной сцены игнорятся.
    func enqueue(_ trigger: CutsceneTrigger, childId: String)

    /// Закрывает текущую `pending` (после показа/скипа), помечает её просмотренной
    /// и продвигает очередь к следующей сцене.
    func pop()
}

// MARK: - CutsceneServiceLive

/// Production-реализация. `@Observable` — `pending` наблюдается `AppCoordinatorView`.
/// Очередь сортируется по `priority desc`, при равенстве сохраняется FIFO-порядок.
@MainActor
@Observable
final class CutsceneServiceLive: CutsceneServiceProtocol {

    // MARK: Dependencies

    private let videoPlayerService: any VideoPlayerServiceProtocol
    private let hapticService: (any HapticService)?

    // MARK: State

    /// Приоритетная очередь. Голова (`pending`) — сцена с наибольшим приоритетом.
    private var queue: [Cutscene] = []
    /// `childId` сцены, стоящей в очереди — нужен для `markSeen` при `pop`.
    private var queueChildIds: [String: String] = [:]

    @ObservationIgnored
    private let defaults: UserDefaults
    @ObservationIgnored
    private let logger = Logger(subsystem: "ru.happyspeech", category: "CutsceneService")

    var pending: Cutscene? { queue.first }

    // MARK: Init

    init(
        videoPlayerService: any VideoPlayerServiceProtocol,
        hapticService: (any HapticService)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.videoPlayerService = videoPlayerService
        self.hapticService = hapticService
        self.defaults = defaults
    }

    // MARK: - CutsceneServiceProtocol

    func shouldPlay(_ id: String, childId: String) -> Bool {
        guard let cutscene = CutsceneCatalog.cutscene(id: id) else { return false }
        guard cutscene.enabled else { return false }
        guard !isSeen(id: id, childId: childId) else { return false }
        // Видео ИЛИ постер-фолбэк должны быть доступны. Постер — imageset, его
        // наличие в рантайме гарантировать нельзя дёшево, поэтому показываем,
        // если есть видео ЛИБО декларирован постер (фолбэк graceful в плеере).
        let hasVideo = videoPlayerService.videoURL(for: cutscene.videoResourceName) != nil
        let hasPoster = !cutscene.posterAssetName.isEmpty
        return hasVideo || hasPoster
    }

    func cutscene(for trigger: CutsceneTrigger) -> Cutscene? {
        CutsceneCatalog.cutscene(for: trigger)
    }

    func markSeen(_ id: String, childId: String) {
        defaults.set(true, forKey: Self.seenKey(id: id, childId: childId))
        logger.info("cutscene seen → \(id, privacy: .public)")
    }

    func resetSeen(childId: String) {
        for cutscene in CutsceneCatalog.all {
            defaults.removeObject(forKey: Self.seenKey(id: cutscene.id, childId: childId))
        }
        logger.info("cutscene seen reset for child")
    }

    func enqueue(_ trigger: CutsceneTrigger, childId: String) {
        guard let cutscene = CutsceneCatalog.cutscene(for: trigger) else { return }
        guard shouldPlay(cutscene.id, childId: childId) else { return }
        // Дедупликация: одна сцена в очереди только один раз.
        guard !queue.contains(where: { $0.id == cutscene.id }) else { return }

        queue.append(cutscene)
        queueChildIds[cutscene.id] = childId
        sortQueue()
        logger.info("cutscene enqueued → \(cutscene.id, privacy: .public) priority=\(cutscene.priority, privacy: .public)")

        // Тактильный акцент на триумфе/финале (под доступность плеер сам решит).
        if cutscene.kind == .islandTriumph || cutscene.kind == .finale {
            if let haptic = hapticService {
                Task { await haptic.playLevelUp() }
            }
        }
    }

    func pop() {
        guard !queue.isEmpty else { return }
        let finished = queue.removeFirst()
        if let childId = queueChildIds.removeValue(forKey: finished.id) {
            markSeen(finished.id, childId: childId)
        }
        logger.info("cutscene popped → \(finished.id, privacy: .public)")
    }

    // MARK: - Private

    private func isSeen(id: String, childId: String) -> Bool {
        defaults.bool(forKey: Self.seenKey(id: id, childId: childId))
    }

    /// Сортировка по приоритету (desc), стабильно (равные приоритеты — FIFO).
    private func sortQueue() {
        queue = queue.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.priority != rhs.element.priority {
                    return lhs.element.priority > rhs.element.priority
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// Ключ per-child персистентности: `cutscene.seen.<childId>.<id>`.
    /// childId может быть пустым (standalone / превью) — тогда ключ глобальный.
    private static func seenKey(id: String, childId: String) -> String {
        let child = childId.isEmpty ? "_" : childId
        return "cutscene.seen.\(child).\(id)"
    }
}

// MARK: - MockCutsceneService

/// Мок для preview / тестов. По умолчанию `shouldPlay == false` и очередь пуста —
/// кат-сцены не всплывают в превью / снапшотах. Поведение очереди можно включить
/// флагом `playsEnqueued` для unit-тестов интеграции.
@MainActor
final class MockCutsceneService: CutsceneServiceProtocol {

    private(set) var pending: Cutscene?
    var playsEnqueued: Bool
    private(set) var seenIds: Set<String> = []
    private(set) var enqueuedTriggers: [CutsceneTrigger] = []

    init(playsEnqueued: Bool = false) {
        self.playsEnqueued = playsEnqueued
    }

    func shouldPlay(_ id: String, childId: String) -> Bool {
        playsEnqueued && !seenIds.contains(Self.key(id, childId))
    }

    func cutscene(for trigger: CutsceneTrigger) -> Cutscene? {
        CutsceneCatalog.cutscene(for: trigger)
    }

    func markSeen(_ id: String, childId: String) {
        seenIds.insert(Self.key(id, childId))
    }

    func resetSeen(childId: String) {
        seenIds = seenIds.filter { !$0.hasPrefix("\(childId).") }
    }

    func enqueue(_ trigger: CutsceneTrigger, childId: String) {
        enqueuedTriggers.append(trigger)
        guard playsEnqueued, let cutscene = CutsceneCatalog.cutscene(for: trigger) else { return }
        guard !seenIds.contains(Self.key(cutscene.id, childId)) else { return }
        if pending == nil { pending = cutscene }
    }

    func pop() {
        pending = nil
    }

    private static func key(_ id: String, _ childId: String) -> String {
        "\(childId).\(id)"
    }
}
