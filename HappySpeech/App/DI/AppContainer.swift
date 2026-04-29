import Foundation
import Observation
import OSLog

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

    /// Идентификатор активного ребёнка — устанавливается после выбора профиля.
    /// Используется ARZoneInteractor → AdaptivePlannerService.
    public var currentChildId: String = ""

    // M6.16: ScreeningOutcome repository — lazy, инициализируется при первом обращении.
    private var _screeningOutcomeRepository: (any ScreeningOutcomeRepository)?
    public var screeningOutcomeRepository: any ScreeningOutcomeRepository {
        if let existing = _screeningOutcomeRepository { return existing }
        let new = LiveScreeningOutcomeRepository(realmActor: realmActor)
        _screeningOutcomeRepository = new
        return new
    }

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
    private var _llmModelManager: (any LLMModelManagerProtocol)?
    private var _whisperKitModelManager: (any WhisperKitModelManagerProtocol)?
    private var _networkClient: NetworkClient?
    private var _claudeAPIClient: (any ClaudeAPIClientProtocol)?
    private var _offlineQueueManager: OfflineQueueManager?
    // Block D: Firebase full services
    private var _remoteConfigService: (any RemoteConfigService)?
    private var _fcmService: (any FCMService)?
    private var _contentPackDownloadService: (any ContentPackDownloadService)?
    private var _performanceMonitorService: (any PerformanceMonitorService)?

    // SoundService — lazy, не требует изменения init
    private var _soundService: (any SoundServiceProtocol)?

    // FaceAnalysisService — lazy, не требует изменения init
    private var _faceAnalysisService: (any FaceAnalysisService)?

    // Block H: KidLLMNarrationService — lazy, использует llmDecisionService
    var _kidLLMNarrationService: (any KidLLMNarrationServiceProtocol)?

    // Block J: HealthKitService — parent opt-in only, COPPA-safe.
    private var _healthKitService: (any HealthKitServiceProtocol)?

    // Block K: SpotlightIndexer — CoreSpotlight indexing, COPPA-safe (нет имени ребёнка).
    private var _spotlightIndexer: (any SpotlightIndexerProtocol)?

    // MascotLipSyncState — singleton для real-time lip-sync оверлея маскота (Block F)
    public let mascotLipSyncState: MascotLipSyncState = MascotLipSyncState()

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
    private let llmModelManagerFactory: () -> any LLMModelManagerProtocol
    private let whisperKitModelManagerFactory: () -> any WhisperKitModelManagerProtocol
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
        llmModelManagerFactory: @escaping () -> any LLMModelManagerProtocol,
        whisperKitModelManagerFactory: @escaping () -> any WhisperKitModelManagerProtocol,
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
        self.llmModelManagerFactory = llmModelManagerFactory
        self.whisperKitModelManagerFactory = whisperKitModelManagerFactory
        self.networkClientFactory = networkClientFactory
        self.claudeAPIClientFactory = claudeAPIClientFactory
        self.offlineQueueManagerFactory = offlineQueueManagerFactory
    }

    // MARK: - Lazy Service Access

    public var audioService: any AudioService {
        if let existing = _audioService { return existing }
        let new = audioServiceFactory()
        _audioService = new
        return new
    }

    public var asrService: any ASRService {
        if let existing = _asrService { return existing }
        let new = asrServiceFactory()
        _asrService = new
        return new
    }

    public var syncService: any SyncService {
        if let existing = _syncService { return existing }
        let new = syncServiceFactory()
        _syncService = new
        return new
    }

    public var analyticsService: any AnalyticsService {
        if let existing = _analyticsService { return existing }
        let new = analyticsServiceFactory()
        _analyticsService = new
        return new
    }

    public var hapticService: any HapticService {
        if let existing = _hapticService { return existing }
        let new = hapticServiceFactory()
        _hapticService = new
        return new
    }

    public var notificationService: any NotificationService {
        if let existing = _notificationService { return existing }
        let new = notificationServiceFactory()
        _notificationService = new
        return new
    }

    public var networkMonitor: any NetworkMonitorService {
        if let existing = _networkMonitor { return existing }
        let new = networkMonitorFactory()
        _networkMonitor = new
        return new
    }

    public var pronunciationService: any PronunciationScorerService {
        if let existing = _pronunciationService { return existing }
        let new = pronunciationServiceFactory()
        _pronunciationService = new
        return new
    }

    public var localLLMService: any LocalLLMService {
        if let existing = _localLLMService { return existing }
        let new = localLLMServiceFactory()
        _localLLMService = new
        return new
    }

    public var arService: any ARService {
        if let existing = _arService { return existing }
        let new = arServiceFactory()
        _arService = new
        return new
    }

    public var contentService: any ContentService {
        if let existing = _contentService { return existing }
        let new = contentServiceFactory()
        _contentService = new
        return new
    }

    public var adaptivePlannerService: any AdaptivePlannerService {
        if let existing = _adaptivePlannerService { return existing }
        let new = adaptivePlannerServiceFactory()
        _adaptivePlannerService = new
        return new
    }

    public var llmDecisionService: any LLMDecisionServiceProtocol {
        if let existing = _llmDecisionService { return existing }
        let new = llmDecisionServiceFactory()
        _llmDecisionService = new
        return new
    }

    public var llmDecisionLogRepository: any LLMDecisionLogRepository {
        if let existing = _llmDecisionLogRepository { return existing }
        let new = llmDecisionLogRepositoryFactory()
        _llmDecisionLogRepository = new
        return new
    }

    public var llmModelManager: any LLMModelManagerProtocol {
        if let existing = _llmModelManager { return existing }
        let new = llmModelManagerFactory()
        _llmModelManager = new
        return new
    }

    public var whisperKitModelManager: any WhisperKitModelManagerProtocol {
        if let existing = _whisperKitModelManager { return existing }
        let new = whisperKitModelManagerFactory()
        _whisperKitModelManager = new
        return new
    }

    public var networkClient: NetworkClient {
        if let existing = _networkClient { return existing }
        let new = networkClientFactory()
        _networkClient = new
        return new
    }

    public var claudeAPIClient: any ClaudeAPIClientProtocol {
        if let existing = _claudeAPIClient { return existing }
        let new = claudeAPIClientFactory()
        _claudeAPIClient = new
        return new
    }

    public var offlineQueueManager: OfflineQueueManager {
        if let existing = _offlineQueueManager { return existing }
        let new = offlineQueueManagerFactory()
        _offlineQueueManager = new
        return new
    }

    // MARK: - Block D: Firebase Full Services

    public var remoteConfigService: any RemoteConfigService {
        if let existing = _remoteConfigService { return existing }
        let new = LiveRemoteConfigService()
        _remoteConfigService = new
        return new
    }

    public var fcmService: any FCMService {
        if let existing = _fcmService { return existing }
        let new = LiveFCMService()
        _fcmService = new
        return new
    }

    public var contentPackDownloadService: any ContentPackDownloadService {
        if let existing = _contentPackDownloadService { return existing }
        let new = LiveContentPackDownloadService()
        _contentPackDownloadService = new
        return new
    }

    public var performanceMonitorService: any PerformanceMonitorService {
        if let existing = _performanceMonitorService { return existing }
        let new = LivePerformanceMonitorService()
        _performanceMonitorService = new
        return new
    }

    /// Позволяет Preview/Tests подменить Block D сервисы без изменения init.
    public func overrideBlockDServices(
        remoteConfig: (any RemoteConfigService)? = nil,
        fcm: (any FCMService)? = nil,
        contentPackDownload: (any ContentPackDownloadService)? = nil,
        performance: (any PerformanceMonitorService)? = nil
    ) {
        if let rc = remoteConfig { _remoteConfigService = rc }
        if let f = fcm { _fcmService = f }
        if let cpd = contentPackDownload { _contentPackDownloadService = cpd }
        if let p = performance { _performanceMonitorService = p }
    }

    public var soundService: any SoundServiceProtocol {
        if let existing = _soundService { return existing }
        let new = LiveSoundService()
        _soundService = new
        return new
    }

    public var faceAnalysisService: any FaceAnalysisService {
        if let existing = _faceAnalysisService { return existing }
        let new = LiveFaceAnalysisService()
        _faceAnalysisService = new
        return new
    }

    // Block H: KidLLMNarrationService — on-demand, wraps llmDecisionService.
    // Live: использует реальный LiveLLMDecisionService (Tier A только).
    // Preview/Test: использует MockKidLLMNarrationService.
    public var kidLLMNarrationService: any KidLLMNarrationServiceProtocol {
        if let existing = _kidLLMNarrationService { return existing }
        let new = LiveKidLLMNarrationService(llmService: llmDecisionService)
        _kidLLMNarrationService = new
        return new
    }

    // Block J: HealthKitService — lazy, write-only mindful sessions (parent opt-in).
    public var healthKitService: any HealthKitServiceProtocol {
        if let existing = _healthKitService { return existing }
        let new = LiveHealthKitService()
        _healthKitService = new
        return new
    }

    // Block K: SpotlightIndexer — CoreSpotlight, COPPA-safe.
    public var spotlightIndexer: any SpotlightIndexerProtocol {
        if let existing = _spotlightIndexer { return existing }
        let new = LiveSpotlightIndexer()
        _spotlightIndexer = new
        return new
    }

    /// Библиотека анимированных историй. Singleton — создаётся один раз для всего приложения.
    public var storyLibrary: StoryLibrary { StoryLibrary.shared }

    // MARK: - GuidedTour

    private var _guidedTourCoordinator: GuidedTourCoordinator?

    /// Lazy global guided-tour coordinator. Single instance per AppContainer so the
    /// 11-step tour state survives navigation between ChildHome / ParentHome / Settings.
    /// Internal visibility — only consumed by feature views within the app target.
    var guidedTourCoordinator: GuidedTourCoordinator {
        if let existing = _guidedTourCoordinator { return existing }
        let new = GuidedTourCoordinator(soundService: soundService)
        _guidedTourCoordinator = new
        return new
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
            notificationServiceFactory: { NotificationServiceLive() },
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
            llmModelManagerFactory: {
                LLMModelManager(primaryLLM: sharedLocalLLM, networkMonitor: sharedNetworkMonitor)
            },
            whisperKitModelManagerFactory: {
                WhisperKitModelManagerLive(networkMonitor: sharedNetworkMonitor)
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

        let container = AppContainer(
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
            llmModelManagerFactory: { MockLLMModelManager() },
            whisperKitModelManagerFactory: { MockWhisperKitModelManager() },
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
        // Block D mocks — override Live implementations for preview/test environments.
        container.overrideBlockDServices(
            remoteConfig: MockRemoteConfigService(),
            fcm: MockFCMService(),
            contentPackDownload: MockContentPackDownloadService(),
            performance: MockPerformanceMonitorService()
        )
        // Block H: использовать Mock для kid narration в preview/tests.
        container._kidLLMNarrationService = MockKidLLMNarrationService()
        // Block J: HealthKit mock для preview/tests.
        container._healthKitService = MockHealthKitService()
        // Block K: Spotlight mock для preview/tests.
        container._spotlightIndexer = MockSpotlightIndexer()
        return container
    }
}
