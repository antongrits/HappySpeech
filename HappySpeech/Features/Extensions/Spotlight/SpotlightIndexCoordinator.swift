import Foundation
import OSLog

// MARK: - SpotlightIndexCoordinator

/// Координирует когда и что индексировать в CoreSpotlight.
///
/// Стратегия re-index:
///   - При старте приложения — вызов start() → indexAll()
///   - Throttle: не чаще одного раза в 5 минут (kMinReindexInterval)
///   - Polling: каждые 30 минут в фоне через Task.sleep
///
/// COPPA-safe: не передаёт имя ребёнка в SpotlightIndexer.
@MainActor
public final class SpotlightIndexCoordinator {

    // MARK: - Constants

    private let kMinReindexInterval: TimeInterval = 5 * 60      // 5 минут
    private let kPollingInterval: TimeInterval    = 30 * 60     // 30 минут

    // MARK: - Dependencies

    private let indexer: any SpotlightIndexerProtocol
    private let contentService: any ContentService
    private let sessionRepository: any SessionRepository

    // MARK: - State

    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "SpotlightCoordinator")
    private var lastIndexDate: Date?
    private var pollingTask: Task<Void, Never>?

    // MARK: - Init

    public init(
        indexer: any SpotlightIndexerProtocol,
        contentService: any ContentService,
        sessionRepository: any SessionRepository
    ) {
        self.indexer = indexer
        self.contentService = contentService
        self.sessionRepository = sessionRepository
    }

    // MARK: - Public API

    /// Запускает одноразовую индексацию (throttled) и фоновый polling.
    public func start() {
        Task { await indexAllThrottled() }
        startPolling()
    }

    /// Останавливает фоновый polling (вызывается при scenePhase == .background).
    public func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Принудительная индексация без throttle.
    public func forceReindex() async {
        await indexAll()
    }

    // MARK: - Private

    private func indexAllThrottled() async {
        if let last = lastIndexDate, Date().timeIntervalSince(last) < kMinReindexInterval {
            logger.debug("Spotlight: throttle активен, пропускаем re-index")
            return
        }
        await indexAll()
    }

    private func indexAll() async {
        logger.info("Spotlight: запуск полной индексации")
        lastIndexDate = Date()

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.indexLessons() }
            group.addTask { await self.indexSessions() }
        }

        logger.info("Spotlight: индексация завершена")
    }

    private func indexLessons() async {
        do {
            let metas = try await contentService.allPacks()
            var items: [SpotlightLessonItem] = []

            for meta in metas {
                let displayTitle = spotlightTitle(for: meta.soundTarget, stage: meta.stage)
                let item = SpotlightLessonItem(
                    id: meta.id,
                    title: displayTitle,
                    soundId: meta.soundTarget,
                    description: String(
                        format: String(localized: "spotlight.lesson.description %@ %@"),
                        meta.soundTarget,
                        meta.stage
                    ),
                    keywords: buildKeywords(for: meta.soundTarget)
                )
                items.append(item)
            }

            try await indexer.indexLessons(items)
        } catch {
            logger.error("Spotlight: ошибка индексации уроков — \(error.localizedDescription)")
        }
    }

    private func indexSessions() async {
        do {
            // SessionRepository.fetchAll не принимает limit напрямую — используем fetchRecent.
            // childId "" означает «все дети» (coordinator не знает текущего childId COPPA-safe).
            // Реальный childId инжектируется при необходимости через indexRecentSessionsForChild.
            let sessions = try await sessionRepository.fetchRecent(childId: "", limit: 30)
            let items = sessions.map { session in
                SpotlightSessionItem(
                    id: session.id,
                    soundId: session.targetSound,
                    date: session.date,
                    score: session.totalAttempts > 0
                        ? Int(Double(session.correctAttempts) / Double(session.totalAttempts) * 100)
                        : 0
                )
            }
            try await indexer.indexRecentSessions(items)
        } catch {
            logger.error("Spotlight: ошибка индексации сессий — \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func spotlightTitle(for soundId: String, stage: String) -> String {
        let soundName = localizedSoundName(soundId)
        return String(format: String(localized: "spotlight.lesson.title %@"), soundName)
    }

    private func localizedSoundName(_ soundId: String) -> String {
        let map: [String: String] = [
            "С": "С", "З": "З", "Ц": "Ц",
            "Ш": "Ш", "Ж": "Ж", "Ч": "Ч", "Щ": "Щ",
            "Р": "Р", "Рь": "Рь", "Л": "Л", "Ль": "Ль",
            "К": "К", "Г": "Г", "Х": "Х"
        ]
        return map[soundId] ?? soundId
    }

    private func buildKeywords(for soundId: String) -> [String] {
        let base = ["звук", soundId, "логопедия", "упражнение", "занятие", "HappySpeech"]
        let soundGroupKeywords: [String: [String]] = [
            "С":  ["свист", "свистящий"],
            "З":  ["свист", "свистящий"],
            "Ц":  ["свист", "свистящий"],
            "Ш":  ["шипящий"],
            "Ж":  ["шипящий"],
            "Ч":  ["шипящий"],
            "Щ":  ["шипящий"],
            "Р":  ["сонор", "раскатистый"],
            "Рь": ["сонор", "мягкий"],
            "Л":  ["сонор"],
            "Ль": ["сонор", "мягкий"],
            "К":  ["заднеязычный"],
            "Г":  ["заднеязычный"],
            "Х":  ["заднеязычный"]
        ]
        return base + (soundGroupKeywords[soundId] ?? [])
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(kPollingInterval))
                } catch {
                    break
                }
                guard !Task.isCancelled else { break }
                await indexAllThrottled()
            }
        }
    }
}
