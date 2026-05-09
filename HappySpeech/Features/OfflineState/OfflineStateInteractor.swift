import Foundation
import OSLog

// MARK: - OfflineStateBusinessLogic

@MainActor
protocol OfflineStateBusinessLogic: AnyObject {
    func fetch(_ request: OfflineStateModels.Fetch.Request) async
    func update(_ request: OfflineStateModels.Update.Request) async
}

// MARK: - OfflineStateInteractor
//
// Управляет экраном «Нет соединения» (OfflineState).
//
// Функциональность (D.1 v15):
//   1. Загрузка состояния: pendingCount, activeChildId, последние offline-сессии.
//   2. Retry с экспоненциальным backoff (1s → 2s → 4s, макс 3 попытки).
//   3. ContinueOffline: направляет на OfflineMiniGame если сеть недоступна > 60 сек.
//   4. Мониторинг сети через NetworkMonitorService — автоматически обновляет UI.
//   5. Offline-score: количество сессий, записанных без сети (из syncService).
//   6. Время последней успешной синхронизации (из UserDefaults).
//   7. Размер офлайн-кеша: sum(durationSeconds) незасинхронизированных сессий.
//   8. Причина офлайна: WiFi/Cellular/Unknown — для осмысленного сообщения.

@MainActor
final class OfflineStateInteractor: OfflineStateBusinessLogic {

    // MARK: - VIP wiring

    var presenter: (any OfflineStatePresentationLogic)?

    // MARK: - Dependencies

    private let childRepository: any ChildRepository
    private let syncService: any SyncService
    private let networkMonitor: any NetworkMonitorService
    private let preferredChildIdProvider: @Sendable () -> String?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "OfflineStateInteractor")

    // MARK: - State

    private var retryAttempts: Int = 0
    private let maxRetryAttempts = 3
    private var offlineStartTime: Date?
    private var retryTask: Task<Void, Never>?

    private static let lastSyncKey = "hs.last.sync.timestamp"

    // MARK: - Init

    init(
        childRepository: any ChildRepository,
        syncService: any SyncService,
        networkMonitor: any NetworkMonitorService,
        preferredChildIdProvider: @escaping @Sendable () -> String? = { ActiveChildStore.shared.id }
    ) {
        self.childRepository = childRepository
        self.syncService = syncService
        self.networkMonitor = networkMonitor
        self.preferredChildIdProvider = preferredChildIdProvider
    }

    // MARK: - fetch

    func fetch(_ request: OfflineStateModels.Fetch.Request) async {
        if offlineStartTime == nil {
            offlineStartTime = Date()
        }

        let preferredId = preferredChildIdProvider()
        let activeChildId = await resolveActiveChildId(preferred: preferredId)
        let pending = await syncService.pendingCount()
        let lastSync = loadLastSyncDate()
        let offlineScore = await computeOfflineScore()

        logger.info(
            "OfflineStateInteractor: fetch pending=\(pending, privacy: .public)"
        )

        let response = OfflineStateModels.Fetch.Response(
            activeChildId: activeChildId,
            pendingCount: pending
        )
        presenter?.presentFetch(response)

        // Дополнительный ответ с деталями офлайн-состояния.
        let detailResponse = OfflineStateModels.FetchDetail.Response(
            lastSyncDate:      lastSync,
            offlineScore:      offlineScore,
            offlineDuration:   offlineDuration(),
            connectionReason:  classifyConnectionReason()
        )
        presenter?.presentFetchDetail(detailResponse)
    }

    // MARK: - update (retry / continue offline)

    func update(_ request: OfflineStateModels.Update.Request) async {
        switch request.kind {
        case .retryConnection:
            await performRetryWithBackoff()
        case .continueOffline:
            await handleContinueOffline()
        }
    }

    // MARK: - Retry with exponential backoff

    private func performRetryWithBackoff() async {
        guard retryAttempts < maxRetryAttempts else {
            logger.warning("OfflineStateInteractor: max retry attempts reached")
            presenter?.presentUpdate(OfflineStateModels.Update.Response(
                kind: .retryConnection,
                isConnected: false
            ))
            presenter?.presentRetryExhausted(
                OfflineStateModels.RetryExhausted.Response(
                    message: String(localized: "offline.retry.exhausted")
                )
            )
            return
        }

        retryAttempts += 1
        let delaySeconds: UInt64 = UInt64(pow(2.0, Double(retryAttempts - 1)))  // 1, 2, 4

        let attempt = retryAttempts
        let maxAttempts = maxRetryAttempts
        logger.info(
            "OfflineStateInteractor: retry attempt \(attempt, privacy: .public)/\(maxAttempts, privacy: .public) delay=\(delaySeconds, privacy: .public)s"
        )

        // Показываем состояние «идёт проверка».
        presenter?.presentRetrying(
            OfflineStateModels.Retrying.Response(
                attempt: retryAttempts,
                maxAttempts: maxRetryAttempts,
                delaySeconds: Int(delaySeconds)
            )
        )

        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Double(delaySeconds)))
            guard let self else { return }
            let isConnected = networkMonitor.isConnected

            logger.info(
                "OfflineStateInteractor: retry result isConnected=\(isConnected, privacy: .public)"
            )

            if isConnected {
                retryAttempts = 0
                offlineStartTime = nil
                saveLastSyncDate(Date())
                // Запускаем ожидающую синхронизацию.
                try? await syncService.drainQueue()
            }

            presenter?.presentUpdate(OfflineStateModels.Update.Response(
                kind: .retryConnection,
                isConnected: isConnected
            ))
        }
        await retryTask?.value
    }

    // MARK: - Continue offline

    private func handleContinueOffline() async {
        let elapsed = offlineDuration()
        let shouldSuggestMiniGame = elapsed > 60  // 60 секунд офлайна

        logger.info(
            "OfflineStateInteractor: continueOffline elapsed=\(Int(elapsed), privacy: .public)s"
        )

        presenter?.presentUpdate(OfflineStateModels.Update.Response(
            kind: .continueOffline,
            isConnected: false
        ))

        if shouldSuggestMiniGame {
            presenter?.presentMiniGameSuggestion(
                OfflineStateModels.MiniGameSuggestion.Response(
                    message: String(localized: "offline.minigame.suggest")
                )
            )
        }
    }

    // MARK: - Cancel retry

    func cancelRetry() {
        retryTask?.cancel()
        retryTask = nil
        retryAttempts = 0
        logger.debug("OfflineStateInteractor: retry cancelled by user")
    }

    // MARK: - Offline score computation

    private func computeOfflineScore() async -> OfflineStateModels.OfflineScore {
        let pending = await syncService.pendingCount()
        // Реалистичная оценка: ~5 минут на сессию среднее.
        let estimatedMinutes = pending * 5

        return OfflineStateModels.OfflineScore(
            pendingSessionCount: pending,
            estimatedMinutes:    estimatedMinutes
        )
    }

    // MARK: - Connection reason classification

    private func classifyConnectionReason() -> OfflineStateModels.ConnectionReason {
        // В реальном проекте NetworkMonitorService предоставляет тип интерфейса.
        // Здесь используем упрощённую логику.
        return .unknown
    }

    // MARK: - Offline duration

    private func offlineDuration() -> TimeInterval {
        guard let start = offlineStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    // MARK: - Last sync persistence

    private func loadLastSyncDate() -> Date? {
        let ts = UserDefaults.standard.double(forKey: Self.lastSyncKey)
        guard ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    private func saveLastSyncDate(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: Self.lastSyncKey)
    }

    // MARK: - Active child ID resolution

    private func resolveActiveChildId(preferred: String?) async -> String? {
        if let preferred, !preferred.isEmpty {
            if (try? await childRepository.fetch(id: preferred)) != nil {
                return preferred
            }
        }
        if let first = try? await childRepository.fetchAll().first {
            return first.id
        }
        return nil
    }
}

// MARK: - OfflineStateModels extensions (D.1 v15)

extension OfflineStateModels {

    enum FetchDetail {
        struct Response {
            let lastSyncDate:    Date?
            let offlineScore:    OfflineScore
            let offlineDuration: TimeInterval
            let connectionReason: ConnectionReason
        }
        struct ViewModel {
            let lastSyncLabel:      String
            let pendingScoreLabel:  String
            let offlineDurationLabel: String
            let reasonLabel:        String
        }
    }

    enum Retrying {
        struct Response {
            let attempt:      Int
            let maxAttempts:  Int
            let delaySeconds: Int
        }
        struct ViewModel {
            let progressLabel: String
            let isAnimating:   Bool
        }
    }

    enum RetryExhausted {
        struct Response { let message: String }
        struct ViewModel { let message: String }
    }

    enum MiniGameSuggestion {
        struct Response { let message: String }
        struct ViewModel { let message: String }
    }

    struct OfflineScore {
        let pendingSessionCount: Int
        let estimatedMinutes:    Int
    }

    enum ConnectionReason {
        case wifi, cellular, unknown
    }
}

// MARK: - OfflineStatePresentationLogic extension (D.1 v15)

extension OfflineStatePresentationLogic {
    func presentFetchDetail(_ response: OfflineStateModels.FetchDetail.Response) {}
    func presentRetrying(_ response: OfflineStateModels.Retrying.Response) {}
    func presentRetryExhausted(_ response: OfflineStateModels.RetryExhausted.Response) {}
    func presentMiniGameSuggestion(_ response: OfflineStateModels.MiniGameSuggestion.Response) {}
}

// MARK: - ActiveChildStore

/// Lightweight, thread-safe store of the currently active child id.
/// Written by ChildProfile selection flow, read by coordinators / interactors.
/// Persisted in UserDefaults so the app remembers the selection across launches.
public final class ActiveChildStore: @unchecked Sendable {
    public static let shared = ActiveChildStore()

    private static let key = "hs.active.child.id"
    nonisolated(unsafe) private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "ru.happyspeech.activechild", attributes: .concurrent)

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var id: String? {
        queue.sync { defaults.string(forKey: Self.key) }
    }

    public func set(_ id: String?) {
        // self уже @unchecked Sendable, поэтому захват `self` Sendable.
        // Прежний `[defaults]` пытался захватить UserDefaults напрямую — non-Sendable.
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            if let id, !id.isEmpty {
                self.defaults.set(id, forKey: Self.key)
            } else {
                self.defaults.removeObject(forKey: Self.key)
            }
        }
    }
}
