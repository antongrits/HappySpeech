import Foundation
import UIKit

// MARK: - AudioService Protocol

/// Manages AVAudioEngine-based recording at 16kHz mono and audio playback.
public protocol AudioService: Sendable {
    var isPermissionGranted: Bool { get }
    var amplitude: Float { get }
    var isRecording: Bool { get }

    func requestPermission() async -> Bool
    func startRecording() async throws
    func stopRecording() async throws -> URL
    func playAudio(url: URL) async throws
    func stopPlayback()
    func amplitudeBuffer() -> [Float]
}

// MARK: - ASRService Protocol

public protocol ASRService: Sendable {
    var isReady: Bool { get }
    func transcribe(url: URL) async throws -> ASRResult
    func loadModel() async throws
}

public struct ASRResult: Sendable {
    public let transcript: String
    public let confidence: Double
    public let wordTimestamps: [WordTimestamp]

    public struct WordTimestamp: Sendable {
        public let word: String
        public let startTime: Double
        public let endTime: Double
    }
}

// MARK: - ARService Protocol

public protocol ARService: Sendable {
    var isSupported: Bool { get }
    var isCameraPermissionGranted: Bool { get }
    func requestCameraPermission() async -> Bool
}

// MARK: - ContentService Protocol

public protocol ContentService: Sendable {
    func loadPack(id: String) async throws -> ContentPack
    func allPacks() async throws -> [ContentPackMeta]
    func bundledPacks() -> [ContentPackMeta]
}

public struct ContentPack: Sendable {
    public let id: String
    public let soundTarget: String
    public let stage: CorrectionStage
    public let templateType: TemplateType
    public let items: [ContentItem]
}

public struct ContentItem: Sendable, Identifiable {
    public let id: String
    public let word: String
    public let imageAsset: String?
    public let audioAsset: String?
    public let hint: String?
    public let stage: CorrectionStage
    public let difficulty: Int
}

// MARK: - AdaptivePlannerService Protocol

/// Сервис адаптивного планирования ежедневного маршрута обучения.
///
/// `AdaptivePlannerService` формирует персональный дневной маршрут (`AdaptiveRoute`)
/// на основе прогресса ребёнка, алгоритма spaced repetition (SM-2) и уровня усталости.
///
/// ### Логика планирования
/// - Читает последние N сессий из Realm через `RealmActor`
/// - Вычисляет усталость (`FatigueLevel`): 3 подряд сессии с ошибками → короткий маршрут
/// - SM-2 spaced repetition: звук < 80% → повторить через 1 день,
///   80–95% → через 3 дня, > 95% → через 7 дней
/// - Чередование шаблонов: два одинаковых шаблона подряд запрещены
/// - Ограничение по возрасту: 5–6 лет = 7–10 мин, 6–7 = 10–12, 7–8 = 12–15
///
/// ## Пример
/// ```swift
/// let planner: AdaptivePlannerService = LiveAdaptivePlannerService(realm: actor)
/// let route = try await planner.buildDailyRoute(for: childId)
/// for step in route.steps {
///     HSLogger.planner.debug("\(step.targetSound) \(step.templateType)")
/// }
/// ```
///
/// ## See Also
/// - ``AdaptiveRoute``
/// - ``RealmActor``
/// - ``SyncService``
public protocol AdaptivePlannerService: Sendable {
    func buildDailyRoute(for childId: String) async throws -> AdaptiveRoute
    func recordCompletion(sessionId: String, route: AdaptiveRoute) async throws

    /// Применить SM-2 к результату сессии для конкретного звука и сохранить новые параметры.
    /// Если `SoundProgressState` ещё не существует для этого `(childId, soundTarget)` — создаёт стартовое.
    func recordSessionResult(
        childId: String,
        soundTarget: String,
        qualityScore: SM2Quality
    ) async throws

    /// Подсказка UI: стоит ли сделать паузу / завершить сессию.
    /// Вычисляется синхронно, без I/O — можно звать прямо из Interactor'а.
    func shouldTakeBreak(
        consecutiveWrong: Int,
        sessionDurationSec: Int,
        childAge: Int
    ) -> Bool
}

public struct AdaptiveRoute: Sendable {
    public let steps: [RouteStepItem]
    public let maxDurationSec: Int
    public let fatigueLevel: FatigueLevel
}

public struct RouteStepItem: Sendable {
    public let templateType: TemplateType
    public let targetSound: String
    public let stage: CorrectionStage
    public let difficulty: Int
    public let wordCount: Int
    public let durationTargetSec: Int
}

// MARK: - SyncService Protocol

/// Сервис двунаправленной синхронизации Realm ↔ Firestore.
///
/// `SyncService` обеспечивает offline-first работу: все изменения пишутся локально
/// в Realm, затем ставятся в очередь `SyncOperation` и выгружаются в Firestore при
/// наличии сети. Конфликты разрешаются стратегией merge-by-max для числовых полей.
///
/// ### Поток данных
/// ```
/// Realm (local) ──→ SyncQueue ──→ Firestore (cloud)
///                       ↑
///               при наличии сети
/// ```
///
/// ### Состояния (`SyncState`)
/// - `.idle` — нет активной синхронизации
/// - `.syncing(progress:)` — текущий прогресс 0.0–1.0
/// - `.failed(message:)` — последняя синхронизация провалилась
/// - `.completed(itemsSynced:)` — успешно синхронизировано N записей
///
/// ## Пример
/// ```swift
/// // Подписка на состояние (Parent Home banner)
/// for await state in syncService.syncState {
///     switch state {
///     case .syncing(let progress): showProgress(progress)
///     case .completed(let count): showSuccess(count)
///     default: break
///     }
/// }
///
/// // Ручная полная синхронизация
/// try await syncService.syncUserProgress(userId: userId)
/// ```
///
/// ## See Also
/// - ``AdaptivePlannerService``
/// - ``RealmActor``
/// - ``AppError``
public protocol SyncService: Sendable {
    /// Current count of queued items awaiting upload. Asynchronous to support actor-isolated conformers.
    func pendingCount() async -> Int
    /// Whether a drain pass is currently in flight.
    func isSyncing() async -> Bool
    func drainQueue() async throws
    func enqueue(operation: SyncOperation) async throws

    /// Pushes all Realm-stored progress artefacts for a given child/user to the remote store
    /// as a single batched write. Applies merge-by-max conflict resolution on numeric fields.
    /// Intended for full-snapshot resync (first login, manual “sync now”, logout cleanup).
    func syncUserProgress(userId: String) async throws

    /// Live stream of the service state: idle → syncing(progress) → completed(itemsSynced) | failed(message).
    /// Consumers (Parent Home banner, Settings diagnostics) subscribe via `for await state in service.syncState`.
    /// Implementations must guarantee that the stream never finishes for the lifetime of the service.
    var syncState: AsyncStream<SyncState> { get }
}

// MARK: - Default implementations

/// Default no-op implementations so existing conformers (`MockSyncService`) keep compiling
/// without forcing every mock/test double to implement the full live surface.
public extension SyncService {
    func syncUserProgress(userId: String) async throws {
        // Mocks/previews: no-op by default. LiveSyncService overrides with a real Firestore batch.
        _ = userId
    }

    var syncState: AsyncStream<SyncState> {
        AsyncStream { continuation in
            continuation.yield(.idle)
            continuation.finish()
        }
    }
}

public struct SyncOperation: Sendable {
    public let entityType: String
    public let entityId: String
    public let operation: String
    public let payload: String
}

// MARK: - SyncState

/// High-level state of the sync pipeline, observed by UI surfaces (Parent Home banner, Settings).
/// `Sendable`-safe for use in `AsyncStream` crossing actor boundaries.
public enum SyncState: Sendable, Equatable {
    case idle
    case syncing(progress: Double)
    case failed(message: String)
    case completed(itemsSynced: Int)
}

// MARK: - AnalyticsService Protocol

public protocol AnalyticsService: Sendable {
    func track(event: AnalyticsEvent)
}

public struct AnalyticsEvent: Sendable {
    public let name: String
    public let parameters: [String: String]
    public let timestamp: Date

    public init(name: String, parameters: [String: String] = [:]) {
        self.name = name
        self.parameters = parameters
        self.timestamp = Date()
    }
}

// MARK: - PronunciationScorerService Protocol

public protocol PronunciationScorerService: Sendable {
    var isModelLoaded: Bool { get }
    func score(audioURL: URL, targetSound: String) async throws -> PronunciationScore
    func loadModel() async throws
}

// MARK: - LocalLLMService Protocol

public protocol LocalLLMService: Sendable {
    var isModelDownloaded: Bool { get }
    var isModelLoaded: Bool { get }
    func generateParentSummary(request: ParentSummaryRequest) async throws -> ParentSummaryResponse
    func generateRoute(request: RoutePlannerRequest) async throws -> RoutePlannerResponse
    func generateMicroStory(request: MicroStoryRequest) async throws -> MicroStoryResponse
    func downloadModel() async throws
}

public struct ParentSummaryRequest: Codable, Sendable {
    public let childName: String
    public let targetSound: String
    public let stage: String
    public let totalAttempts: Int
    public let correctAttempts: Int
    public let errorWords: [String]
    public let sessionDurationSec: Int
}

public struct ParentSummaryResponse: Codable, Sendable {
    public let parentSummary: String
    public let homeTask: String
}

public struct RoutePlannerRequest: Codable, Sendable {
    public let childId: String
    public let targetSound: String
    public let currentStage: String
    public let recentSuccessRate: Double
    public let fatigueLevel: Int
    public let age: Int
    public let availableTemplates: [String]
}

public struct RoutePlannerResponse: Codable, Sendable {
    public struct RouteItem: Codable, Sendable {
        public let template: String
        public let difficulty: Int
        public let wordCount: Int
        public let durationTargetSec: Int
    }
    public let route: [RouteItem]
    public let sessionMaxDurationSec: Int
}

public struct MicroStoryRequest: Codable, Sendable {
    public let targetSound: String
    public let stage: String
    public let age: Int
    public let wordPool: [String]
}

public struct MicroStoryResponse: Codable, Sendable {
    public struct GapPosition: Codable, Sendable {
        public let sentenceIndex: Int
        public let word: String
        public let imageHint: String
    }
    public let sentences: [String]
    public let gapPositions: [GapPosition]
}

// MARK: - NotificationService Protocol

/// Протокол сервиса локальных уведомлений через UNUserNotificationCenter.
///
/// `NotificationService` управляет ежедневными напоминаниями, стрик-оповещениями
/// и еженедельными отчётами для родителей. Производственная реализация —
/// ``NotificationServiceLive``.
///
/// > Important: В kids-mode (UserDefaults ключ `happyspeech.kidsModeActive = true`)
/// > сервис не планирует уведомления и отменяет все pending запросы.
///
/// ## Пример
/// ```swift
/// let service: NotificationService = NotificationServiceLive()
/// let granted = await service.requestPermission()
/// if granted {
///     try await service.scheduleDailyReminder(at: 17, minute: 0) // 17:00
/// }
/// ```
///
/// ## See Also
/// - ``NotificationServiceLive``
/// - ``HapticService``
public protocol NotificationService: Sendable {
    func scheduleDailyReminder(at hour: Int, minute: Int) async throws
    func cancelAllReminders() async
    func requestPermission() async -> Bool
}

// MARK: - HapticService Protocol

/// Протокол тактильной отдачи через CHHapticEngine с legacy UIKit shim.
///
/// `HapticService` предоставляет 15 именованных AHAP-паттернов и три уровня
/// интенсивности. Производственная реализация — `LiveHapticService` (CoreHaptics);
/// на устройствах без Taptic Engine — `FallbackHapticService` (UIImpactFeedbackGenerator).
///
/// Реализации:
/// - `LiveHapticService` — CHHapticEngine, iPhone 8+, iPad mini 5+
/// - `FallbackHapticService` — UIImpactFeedbackGenerator, старые iPad
/// - `MockHapticService` — тесты и Preview
///
/// ## Пример
/// ```swift
/// let haptic: HapticService = LiveHapticService()
/// await haptic.play(pattern: .celebration)    // при правильном ответе
/// await haptic.play(pattern: .errorBuzz)      // при ошибке
/// haptic.impact(.medium)                       // legacy short tap
/// ```
///
/// ## See Also
/// - ``HapticPattern``
/// - ``HapticIntensityLevel``
/// - ``NotificationService``
public protocol HapticService: Sendable {
    /// Воспроизвести именованный AHAP-паттерн.
    func play(pattern: HapticPattern) async
    /// Масштаб интенсивности: 0.0 = выкл, 0.5 = мягко, 1.0 = полная.
    func setIntensityScale(_ scale: Float)
    /// Остановить текущий паттерн (актуально для длинных breathing паттернов).
    func stop() async
    /// Доступность CoreHaptics на устройстве.
    var isAvailable: Bool { get }

    // MARK: Legacy UIKit shim (backward compat)
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle)
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType)
    func selection()
}

// MARK: - NetworkMonitor Protocol

public protocol NetworkMonitorService: Sendable {
    var isConnected: Bool { get }
    var connectionType: ConnectionType { get }
}

public enum ConnectionType: Sendable {
    case wifi, cellular, none
}

// MARK: - ContentPackMeta

public struct ContentPackMeta: Sendable, Identifiable {
    public let id: String
    public let soundTarget: String
    public let stage: String
    public let templateType: String
    public let version: String
    public let isDownloaded: Bool
    public let isBundled: Bool
    public let storageUrl: String
    public let sizeBytes: Int
}
