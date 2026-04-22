import Foundation
import OSLog
import Observation

// MARK: - AppContainer

/// Single dependency injection entry point.
/// Features receive dependencies only through this container via their initialisers.
/// Two configurations: `.live` (production) and `.preview` (mocks for SwiftUI previews and tests).
@Observable
@MainActor
public final class AppContainer {

    // MARK: - Shared Instances

    public let realmActor: RealmActor
    public let childRepository: any ChildRepository
    public let sessionRepository: any SessionRepository
    public let themeManager: ThemeManager
    public let authService: any AuthService

    // Services (lazy-init via closures to avoid startup latency)
    private var _audioService: (any AudioService)?
    private var _asrService: (any ASRService)?
    private var _syncService: (any SyncService)?
    private var _analyticsService: (any AnalyticsService)?
    private var _hapticService: (any HapticService)?
    private var _notificationService: (any NotificationService)?
    private var _networkMonitor: (any NetworkMonitorService)?
    private var _pronunciationService: (any PronunciationScorerService)?
    private var _localLLMService: (any LocalLLMService)?
    private var _arService: (any ARService)?
    private var _contentService: (any ContentService)?
    private var _adaptivePlannerService: (any AdaptivePlannerService)?
    private var _llmDecisionService: (any LLMDecisionServiceProtocol)?
    private var _llmDecisionLogRepository: (any LLMDecisionLogRepository)?
    private var _llmDownloadManager: LLMModelDownloadManager?
    private var _networkClient: NetworkClient?
    private var _claudeAPIClient: (any ClaudeAPIClientProtocol)?
    private var _offlineQueueManager: OfflineQueueManager?
    // SoundService — lazy, не требует изменения init
    private var _soundService: (any SoundServiceProtocol)?

    // Factory closures (injected at init)
    private let audioServiceFactory: () -> any AudioService
    private let asrServiceFactory: () -> any ASRService
    private let syncServiceFactory: () -> any SyncService
    private let analyticsServiceFactory: () -> any AnalyticsService
    private let hapticServiceFactory: () -> any HapticService
    private let notificationServiceFactory: () -> any NotificationService
    private let networkMonitorFactory: () -> any NetworkMonitorService
    private let pronunciationServiceFactory: () -> any PronunciationScorerService
    private let localLLMServiceFactory: () -> any LocalLLMService
    private let arServiceFactory: () -> any ARService
    private let contentServiceFactory: () -> any ContentService
    private let adaptivePlannerServiceFactory: () -> any AdaptivePlannerService
    private let llmDecisionServiceFactory: () -> any LLMDecisionServiceProtocol
    private let llmDecisionLogRepositoryFactory: () -> any LLMDecisionLogRepository
    private let llmDownloadManagerFactory: @MainActor () -> LLMModelDownloadManager
    private let networkClientFactory: () -> NetworkClient
    private let claudeAPIClientFactory: () -> any ClaudeAPIClientProtocol
    private let offlineQueueManagerFactory: @MainActor () -> OfflineQueueManager

    // MARK: - Init

    public init(
        realmActor: RealmActor,
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository,
        themeManager: ThemeManager,
        authService: any AuthService,
        audioServiceFactory: @escaping () -> any AudioService,
        asrServiceFactory: @escaping () -> any ASRService,
        syncServiceFactory: @escaping () -> any SyncService,
        analyticsServiceFactory: @escaping () -> any AnalyticsService,
        hapticServiceFactory: @escaping () -> any HapticService,
        notificationServiceFactory: @escaping () -> any NotificationService,
        networkMonitorFactory: @escaping () -> any NetworkMonitorService,
        pronunciationServiceFactory: @escaping () -> any PronunciationScorerService,
        localLLMServiceFactory: @escaping () -> any LocalLLMService,
        arServiceFactory: @escaping () -> any ARService,
        contentServiceFactory: @escaping () -> any ContentService,
        adaptivePlannerServiceFactory: @escaping () -> any AdaptivePlannerService,
        llmDecisionServiceFactory: @escaping () -> any LLMDecisionServiceProtocol,
        llmDecisionLogRepositoryFactory: @escaping () -> any LLMDecisionLogRepository,
        llmDownloadManagerFactory: @escaping @MainActor () -> LLMModelDownloadManager,
        networkClientFactory: @escaping () -> NetworkClient,
        claudeAPIClientFactory: @escaping () -> any ClaudeAPIClientProtocol,
        offlineQueueManagerFactory: @escaping @MainActor () -> OfflineQueueManager
    ) {
        self.realmActor = realmActor
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
        self.themeManager = themeManager
        self.authService = authService
        self.audioServiceFactory = audioServiceFactory
        self.asrServiceFactory = asrServiceFactory
        self.syncServiceFactory = syncServiceFactory
        self.analyticsServiceFactory = analyticsServiceFactory
        self.hapticServiceFactory = hapticServiceFactory
        self.notificationServiceFactory = notificationServiceFactory
        self.networkMonitorFactory = networkMonitorFactory
        self.pronunciationServiceFactory = pronunciationServiceFactory
        self.localLLMServiceFactory = localLLMServiceFactory
        self.arServiceFactory = arServiceFactory
        self.contentServiceFactory = contentServiceFactory
        self.adaptivePlannerServiceFactory = adaptivePlannerServiceFactory
        self.llmDecisionServiceFactory = llmDecisionServiceFactory
        self.llmDecisionLogRepositoryFactory = llmDecisionLogRepositoryFactory
        self.llmDownloadManagerFactory = llmDownloadManagerFactory
        self.networkClientFactory = networkClientFactory
        self.claudeAPIClientFactory = claudeAPIClientFactory
        self.offlineQueueManagerFactory = offlineQueueManagerFactory
    }

    // MARK: - Lazy Service Access

    public var audioService: any AudioService {
        if _audioService == nil { _audioService = audioServiceFactory() }
        return _audioService!
    }

    public var asrService: any ASRService {
        if _asrService == nil { _asrService = asrServiceFactory() }
        return _asrService!
    }

    public var syncService: any SyncService {
        if _syncService == nil { _syncService = syncServiceFactory() }
        return _syncService!
    }

    public var analyticsService: any AnalyticsService {
        if _analyticsService == nil { _analyticsService = analyticsServiceFactory() }
        return _analyticsService!
    }

    public var hapticService: any HapticService {
        if _hapticService == nil { _hapticService = hapticServiceFactory() }
        return _hapticService!
    }

    public var notificationService: any NotificationService {
        if _notificationService == nil { _notificationService = notificationServiceFactory() }
        return _notificationService!
    }

    public var networkMonitor: any NetworkMonitorService {
        if _networkMonitor == nil { _networkMonitor = networkMonitorFactory() }
        return _networkMonitor!
    }

    public var pronunciationService: any PronunciationScorerService {
        if _pronunciationService == nil { _pronunciationService = pronunciationServiceFactory() }
        return _pronunciationService!
    }

    public var localLLMService: any LocalLLMService {
        if _localLLMService == nil { _localLLMService = localLLMServiceFactory() }
        return _localLLMService!
    }

    public var arService: any ARService {
        if _arService == nil { _arService = arServiceFactory() }
        return _arService!
    }

    public var contentService: any ContentService {
        if _contentService == nil { _contentService = contentServiceFactory() }
        return _contentService!
    }

    public var adaptivePlannerService: any AdaptivePlannerService {
        if _adaptivePlannerService == nil { _adaptivePlannerService = adaptivePlannerServiceFactory() }
        return _adaptivePlannerService!
    }

    public var llmDecisionService: any LLMDecisionServiceProtocol {
        if _llmDecisionService == nil { _llmDecisionService = llmDecisionServiceFactory() }
        return _llmDecisionService!
    }

    public var llmDecisionLogRepository: any LLMDecisionLogRepository {
        if _llmDecisionLogRepository == nil { _llmDecisionLogRepository = llmDecisionLogRepositoryFactory() }
        return _llmDecisionLogRepository!
    }

    public var llmDownloadManager: LLMModelDownloadManager {
        if _llmDownloadManager == nil { _llmDownloadManager = llmDownloadManagerFactory() }
        return _llmDownloadManager!
    }

    public var networkClient: NetworkClient {
        if _networkClient == nil { _networkClient = networkClientFactory() }
        return _networkClient!
    }

    public var claudeAPIClient: any ClaudeAPIClientProtocol {
        if _claudeAPIClient == nil { _claudeAPIClient = claudeAPIClientFactory() }
        return _claudeAPIClient!
    }

    public var offlineQueueManager: OfflineQueueManager {
        if _offlineQueueManager == nil { _offlineQueueManager = offlineQueueManagerFactory() }
        return _offlineQueueManager!
    }

    public var soundService: any SoundServiceProtocol {
        if _soundService == nil { _soundService = LiveSoundService() }
        return _soundService!
    }
}

// MARK: - Factory Methods

public extension AppContainer {

    /// Creates the production container with real service implementations.
    static func live() -> AppContainer {
        let realmActor = RealmActor()
        let childRepo = LiveChildRepository(realmActor: realmActor)
        let sessionRepo = LiveSessionRepository(realmActor: realmActor)
        let theme = ThemeManager()

        // Shared singletons for LLM wiring (one inference actor, one log repo, one local LLM)
        let sharedNetworkMonitor = LiveNetworkMonitor()
        let sharedLocalLLM = LiveLocalLLMService()
        let sharedInferenceActor = LLMInferenceActor(localLLM: sharedLocalLLM)
        let sharedLLMLogRepo: any LLMDecisionLogRepository = LiveLLMDecisionLogRepository(realmActor: realmActor)
        let sharedHFClient = HFInferenceClient()
        let sharedNetworkClient = NetworkClient()
        let sharedSyncService: any SyncService = LiveSyncService(realmActor: realmActor, networkMonitor: sharedNetworkMonitor)

        return AppContainer(
            realmActor: realmActor,
            childRepository: childRepo,
            sessionRepository: sessionRepo,
            themeManager: theme,
            authService: LiveAuthService(),
            audioServiceFactory: { LiveAudioService() },
            asrServiceFactory: { LiveASRService() },
            syncServiceFactory: { sharedSyncService },
            analyticsServiceFactory: { LocalAnalyticsService() },
            hapticServiceFactory: { LiveHapticService() },
            notificationServiceFactory: { LiveNotificationService() },
            networkMonitorFactory: { sharedNetworkMonitor },
            pronunciationServiceFactory: { LivePronunciationScorerService() },
            localLLMServiceFactory: { sharedLocalLLM },
            arServiceFactory: { LiveARService() },
            contentServiceFactory: { LiveContentService() },
            adaptivePlannerServiceFactory: {
                LiveAdaptivePlannerService(
                    childRepository: childRepo,
                    sessionRepository: sessionRepo
                )
            },
            llmDecisionServiceFactory: {
                LiveLLMDecisionService(
                    inferenceActor: sharedInferenceActor,
                    hfClient: sharedHFClient,
                    networkMonitor: sharedNetworkMonitor,
                    logRepository: sharedLLMLogRepo
                )
            },
            llmDecisionLogRepositoryFactory: { sharedLLMLogRepo },
            llmDownloadManagerFactory: {
                LLMModelDownloadManager(localLLM: sharedLocalLLM, networkMonitor: sharedNetworkMonitor)
            },
            networkClientFactory: { sharedNetworkClient },
            claudeAPIClientFactory: {
                ClaudeAPIClient(networkClient: sharedNetworkClient)
            },
            offlineQueueManagerFactory: {
                OfflineQueueManager(
                    realmActor: realmActor,
                    syncService: sharedSyncService,
                    networkMonitor: sharedNetworkMonitor
                )
            }
        )
    }

    /// Creates a preview container with mock service implementations.
    static func preview() -> AppContainer {
        let realmActor = RealmActor()
        let childRepo = MockChildRepository()
        let sessionRepo = MockSessionRepository()
        let theme = ThemeManager()

        let sharedNetworkMonitor = MockNetworkMonitor()
        let sharedLocalLLM = MockLocalLLMService()
        let sharedNetworkClient = NetworkClient()
        let sharedSyncService: any SyncService = MockSyncService()

        return AppContainer(
            realmActor: realmActor,
            childRepository: childRepo,
            sessionRepository: sessionRepo,
            themeManager: theme,
            authService: MockAuthService(),
            audioServiceFactory: { MockAudioService() },
            asrServiceFactory: { MockASRService() },
            syncServiceFactory: { sharedSyncService },
            analyticsServiceFactory: { MockAnalyticsService() },
            hapticServiceFactory: { MockHapticService() },
            notificationServiceFactory: { MockNotificationService() },
            networkMonitorFactory: { sharedNetworkMonitor },
            pronunciationServiceFactory: { MockPronunciationScorerService() },
            localLLMServiceFactory: { sharedLocalLLM },
            arServiceFactory: { MockARService() },
            contentServiceFactory: { MockContentService() },
            adaptivePlannerServiceFactory: { MockAdaptivePlannerService() },
            llmDecisionServiceFactory: { MockLLMDecisionService() },
            llmDecisionLogRepositoryFactory: { InMemoryLLMDecisionLogRepository() },
            llmDownloadManagerFactory: {
                LLMModelDownloadManager(localLLM: sharedLocalLLM, networkMonitor: sharedNetworkMonitor)
            },
            networkClientFactory: { sharedNetworkClient },
            claudeAPIClientFactory: { MockClaudeAPIClient() },
            offlineQueueManagerFactory: {
                OfflineQueueManager(
                    realmActor: realmActor,
                    syncService: sharedSyncService,
                    networkMonitor: sharedNetworkMonitor
                )
            }
        )
    }
}
