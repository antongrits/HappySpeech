import CoreHaptics
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

    // Block AA (v17): Firebase missing services
    private var _cloudFunctionsService: (any CloudFunctionsServiceProtocol)?
    private var _installationsService: (any InstallationsServiceProtocol)?

    // Block U (v18): Firebase full services replacement (Dynamic Links → Universal Links + Firestore)
    private var _familyInviteService: (any FamilyInviteServiceProtocol)?
    private var _realtimeDatabaseService: (any RealtimeDatabaseServiceProtocol)?

    // SoundService — lazy, не требует изменения init
    private var _soundService: (any SoundServiceProtocol)?

    // FaceAnalysisService — lazy, не требует изменения init
    private var _faceAnalysisService: (any FaceAnalysisService)?

    // Block H: KidLLMNarrationService — lazy, использует llmDecisionService.
    // internal visibility for preview() factory access — намеренно не private.
    var kidLLMNarrationServiceStorage: (any KidLLMNarrationServiceProtocol)?

    // Block K: SpotlightIndexer — CoreSpotlight indexing, COPPA-safe (нет имени ребёнка).
    private var _spotlightIndexer: (any SpotlightIndexerProtocol)?

    // Block O (v12): BiometricGateService — Face ID gate для родительских разделов.
    private var _biometricGateService: (any BiometricGateService)?

    // Block N: DailyMissionSyncService — синхронизация виджета через App Group.
    private var _dailyMissionSyncService: (any DailyMissionSyncServiceProtocol)?

    // Block J (v12): HandPoseWorker — Vision-based hand pose detection (iOS 14+, universal).
    // Actor-typed, не требует factory — создаётся on-demand, лёгкий (один VNRequest).
    private var _handPoseWorker: HandPoseWorker?

    // Block K (v12): ObjectDetectionWorker — VNClassifyImageRequest + russian_object_mapping.json.
    // Actor-typed, один экземпляр на приложение. Fallback на MockObjectDetectionWorker при ошибке init.
    private var _objectDetectionWorker: (any ObjectDetectionWorkerProtocol)?

    // MascotLipSyncState — singleton для real-time lip-sync оверлея маскота (Block F)
    public let mascotLipSyncState: MascotLipSyncState = MascotLipSyncState()

    // Block L: MascotEyeContactState — singleton eye contact state (Block L)
    public let mascotEyeContactState: MascotEyeContactState = MascotEyeContactState()

    // Block B v13: LyalyaLipSyncCoordinator — 3D маскот lip-sync через AVAudioPlayer amplitude.
    // Singleton: один координатор на приложение, передаётся во все LyalyaRealityKitView.
    public let lyalyaLipSyncCoordinator: LyalyaLipSyncCoordinator = LyalyaLipSyncCoordinator()

    // Block D v13: PhonemeAnalysisService — фонемный анализ произношения (DTW + CoreML).
    // Actor-typed, lazy. Требует G2PWorker (словарь 7712 слов) + RussianPhonemeClassifier (1.35 MB).
    private var _phonemeAnalysisService: (any PhonemeAnalysisService)?

    // Block E v13: Wav2Vec2Service — Tier 3 CTC phonemic ASR (Wav2Vec2RuChild.mlpackage, ~302 MB).
    // Actor-typed, lazy. Загружает модель при первом вызове transcribe. Graceful fallback на mock.
    private var _wav2Vec2Service: (any Wav2Vec2Service)?

    // Block C v15: EnsembleASRService — weighted voting Tier A/B.
    private var _ensembleASRService: (any EnsembleASRServiceProtocol)?

    // Block C v15: SpeakerVerificationService — ECAPA d-vector, parent vs child.
    private var _speakerVerificationService: (any SpeakerVerificationServiceProtocol)?

    // Block C v15: EmotionDetectionService — Conv1d-LSTM 4 emotions.
    private var _emotionDetectionService: (any EmotionDetectionServiceProtocol)?

    // Block M (v12): VoiceCloneService — placeholder, полная реализация post-v1.0.
    // Не требует factory — VoiceCloneServicePlaceholder легковесный struct без зависимостей.
    private var _voiceCloneService: (any VoiceCloneService)?
    public var voiceCloneService: any VoiceCloneService {
        if let existing = _voiceCloneService { return existing }
        let new = VoiceCloneServicePlaceholder()
        _voiceCloneService = new
        return new
    }

    // Block V (v21): MLModelWarmupService — параллельный прогрев Pronunciation + ASR + VAD
    // во время онбординга для быстрого старта первой сессии.
    private var _mlWarmupService: (any MLModelWarmupServiceProtocol)?

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

    // MARK: - Block AA (v17): Firebase missing services

    /// Cloud Functions callable — серверная оценка произношения и генерация отчётов.
    /// Только родительский / специалистский контур. COPPA: детский контур использует on-device scorer.
    public var cloudFunctionsService: any CloudFunctionsServiceProtocol {
        if let existing = _cloudFunctionsService { return existing }
        let new = LiveCloudFunctionsService()
        _cloudFunctionsService = new
        return new
    }

    /// Firebase Installations — идентификация установки для Anonymous → Auth upgrade flow.
    public var installationsService: any InstallationsServiceProtocol {
        if let existing = _installationsService { return existing }
        let new = LiveInstallationsService()
        _installationsService = new
        return new
    }

    /// Позволяет Preview/Tests подменить Block AA сервисы.
    public func overrideBlockAAServices(
        cloudFunctions: (any CloudFunctionsServiceProtocol)? = nil,
        installations: (any InstallationsServiceProtocol)? = nil
    ) {
        if let cf = cloudFunctions { _cloudFunctionsService = cf }
        if let inst = installations { _installationsService = inst }
    }

    // MARK: - Block U (v18): Firebase full services replacement

    /// Семейные приглашения через Apple Universal Links + Firestore (заменяет deprecated Dynamic Links).
    /// Только родительский контур. См. ADR-V18-U-DYNAMICLINKS-REPLACE.
    public var familyInviteService: any FamilyInviteServiceProtocol {
        if let existing = _familyInviteService { return existing }
        let new = LiveFamilyInviteService(cloudFunctions: cloudFunctionsService)
        _familyInviteService = new
        return new
    }

    /// Firebase Realtime Database — multiplayer SharePlay session sync.
    /// Region: europe-west1 (closest available для eur3).
    public var realtimeDatabaseService: any RealtimeDatabaseServiceProtocol {
        if let existing = _realtimeDatabaseService { return existing }
        let new = LiveRealtimeDatabaseService()
        _realtimeDatabaseService = new
        return new
    }

    /// Позволяет Preview/Tests подменить Block U сервисы.
    public func overrideBlockUServices(
        familyInvite: (any FamilyInviteServiceProtocol)? = nil,
        realtimeDatabase: (any RealtimeDatabaseServiceProtocol)? = nil
    ) {
        if let fi = familyInvite { _familyInviteService = fi }
        if let rdb = realtimeDatabase { _realtimeDatabaseService = rdb }
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
        if let existing = kidLLMNarrationServiceStorage { return existing }
        let new = LiveKidLLMNarrationService(llmService: llmDecisionService)
        kidLLMNarrationServiceStorage = new
        return new
    }

    // Block K: SpotlightIndexer — CoreSpotlight, COPPA-safe.
    public var spotlightIndexer: any SpotlightIndexerProtocol {
        if let existing = _spotlightIndexer { return existing }
        let new = LiveSpotlightIndexer()
        _spotlightIndexer = new
        return new
    }

    // Block O (v12): BiometricGateService — Face ID для родительского gate.
    // Лёгкий: не требует factory — LiveBiometricGateService() не имеет зависимостей.
    public var biometricGateService: any BiometricGateService {
        if let existing = _biometricGateService { return existing }
        let new = LiveBiometricGateService()
        _biometricGateService = new
        return new
    }

    // Block N: DailyMissionSyncService — Widget App Group sync, COPPA-safe.
    public var dailyMissionSyncService: any DailyMissionSyncServiceProtocol {
        if let existing = _dailyMissionSyncService { return existing }
        let new = LiveDailyMissionSyncService()
        _dailyMissionSyncService = new
        return new
    }

    // Block J (v12): HandPoseWorker — lazy singleton, один VNDetectHumanHandPoseRequest на всё приложение.
    public var handPoseWorker: HandPoseWorker {
        if let existing = _handPoseWorker { return existing }
        let new = HandPoseWorker(maxHandCount: 1, confidenceThreshold: 0.6)
        _handPoseWorker = new
        return new
    }

    // Block K (v12): ObjectDetectionWorker — lazy singleton.
    // Live: ObjectDetectionWorker (VNClassifyImageRequest + mapping JSON).
    // Preview/Test: MockObjectDetectionWorker (deterministic, без Vision).
    public var objectDetectionWorker: any ObjectDetectionWorkerProtocol {
        if let existing = _objectDetectionWorker { return existing }
        let worker: any ObjectDetectionWorkerProtocol
        do {
            worker = try ObjectDetectionWorker()
        } catch {
            HSLogger.ar.error("AppContainer: ObjectDetectionWorker init failed (\(error.localizedDescription)), using mock")
            worker = MockObjectDetectionWorker()
        }
        _objectDetectionWorker = worker
        return worker
    }

    // MARK: - Block D v13: PhonemeAnalysisService

    /// Фонемный анализ произношения — DTW alignment + RussianPhonemeClassifier CoreML.
    /// Live: G2PWorker (словарь) + RussianPhonemeClassifierWrapper + MFCCExtractorAdapter.
    /// Preview/Test: MockPhonemeAnalysisService.
    public var phonemeAnalysisService: any PhonemeAnalysisService {
        if let existing = _phonemeAnalysisService { return existing }
        let service: any PhonemeAnalysisService
        do {
            let g2p = try G2PWorker()
            let classifier = try RussianPhonemeClassifierWrapper()
            service = PhonemeAnalysisServiceLive(
                g2p: g2p,
                classifier: classifier,
                mfccExtractor: MFCCExtractorAdapter()
            )
        } catch {
            HSLogger.ml.error("AppContainer: PhonemeAnalysisService init failed (\(error.localizedDescription)), using mock")
            service = MockPhonemeAnalysisService()
        }
        _phonemeAnalysisService = service
        return service
    }

    // MARK: - Block E v13: Wav2Vec2Service

    /// Tier 3 CTC phonemic ASR через Wav2Vec2RuChild.mlpackage (~302 MB).
    ///
    /// Используется в ``PhonemeAnalysisServiceLive`` при confidence < 0.70 от Tier 1/2.
    /// Модель загружается лениво при первом вызове — без задержки при запуске приложения.
    /// Graceful fallback: если модель не найдена в bundle → ``Wav2Vec2ServiceMock``.
    public var wav2Vec2Service: any Wav2Vec2Service {
        if let existing = _wav2Vec2Service { return existing }
        let service: any Wav2Vec2Service = Wav2Vec2ServiceLive()
        _wav2Vec2Service = service
        return service
    }

    // MARK: - Block C v15: Speech Service Wrappers

    /// Ансамблевый ASR — взвешенное голосование Tier A (on-device) / Tier B (Whisper).
    /// Kid circuit использует только Tier A (COPPA).
    public var ensembleASRService: any EnsembleASRServiceProtocol {
        if let existing = _ensembleASRService { return existing }
        let service = LiveEnsembleASRService(
            whisperASR: asrService,
            phonemeClassifier: phonemeAnalysisService,
            pronunciationScorer: pronunciationService
        )
        _ensembleASRService = service
        return service
    }

    /// Верификация говорящего — ECAPA d-vector, parent vs child (COPPA-safe).
    public var speakerVerificationService: any SpeakerVerificationServiceProtocol {
        if let existing = _speakerVerificationService { return existing }
        let service = LiveSpeakerVerificationService()
        _speakerVerificationService = service
        return service
    }

    /// Обнаружение эмоций — Conv1d-LSTM, 4 эмоции (happy/sad/frustrated/neutral).
    /// Используется для адаптивного feedback Ляли в играх.
    public var emotionDetectionService: any EmotionDetectionServiceProtocol {
        if let existing = _emotionDetectionService { return existing }
        let service = LiveEmotionDetectionService()
        _emotionDetectionService = service
        return service
    }

    // MARK: - Block V v21: ML Model Warm-up

    /// Параллельный прогрев Pronunciation + ASR + VAD моделей во время онбординга.
    /// Делает первую игровую сессию быстрее — кэш Core ML уже горячий.
    /// См. ``MLModelWarmupServiceProtocol``.
    public var mlWarmupService: any MLModelWarmupServiceProtocol {
        if let existing = _mlWarmupService { return existing }
        let service = LiveMLModelWarmupService(
            pronunciation: pronunciationService,
            asr: asrService
        )
        _mlWarmupService = service
        return service
    }

    /// Библиотека анимированных историй. Singleton — создаётся один раз для всего приложения.
    public var storyLibrary: StoryLibrary { StoryLibrary.shared }

    // MARK: - GuidedTour (VIP — Block I v16)

    private var _guidedTourCoordinator: GuidedTourCoordinator?
    private var _guidedTourInteractor: GuidedTourInteractor?
    private var _guidedTourPresenter: GuidedTourPresenter?
    private var _guidedTourRouter: GuidedTourRouter?

    /// Lazy global guided-tour coordinator. Single instance per AppContainer so the
    /// 11-step tour state survives navigation between ChildHome / ParentHome / Settings.
    /// Internal visibility — only consumed by feature views within the app target.
    ///
    /// VIP wiring (Block I v16):
    ///   Coordinator (Display) ↔ Interactor → Presenter → Coordinator → SwiftUI
    ///   Router использует AppCoordinator (передаётся позднее, т.к. он создаётся
    ///   уровнем выше в App layer).
    var guidedTourCoordinator: GuidedTourCoordinator {
        if let existing = _guidedTourCoordinator { return existing }

        let presenter = GuidedTourPresenter()
        let router = GuidedTourRouter()
        let interactor = GuidedTourInteractor(
            soundService: soundService,
            analyticsService: analyticsService,
            sessionRepository: sessionRepository
        )
        interactor.presenter = presenter

        let coordinator = GuidedTourCoordinator(
            interactor: interactor,
            router: router,
            steps: TourSteps.all,
            hasCompleted: interactor.hasCompletedCurrentFlavor
        )
        presenter.display = coordinator

        _guidedTourPresenter = presenter
        _guidedTourRouter = router
        _guidedTourInteractor = interactor
        _guidedTourCoordinator = coordinator
        return coordinator
    }

    /// Internal accessor — нужен AppCoordinator-у, чтобы привязать `weak` ref
    /// к Router после создания корневой навигационной координаты.
    func attachGuidedTourCoordinator(_ appCoordinator: AppCoordinator) {
        _ = guidedTourCoordinator // ensure built
        _guidedTourRouter?.coordinator = appCoordinator
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
        // COPPA: HFInferenceClient используется ТОЛЬКО в parent/specialist circuit (Tier B).
        // LiveLLMDecisionService внутри блокирует Tier B для kid context через contextRole проверку.
        // KidLLMNarrationService использует только Tier A (on-device) или Tier C (rule-based).
        // Этот клиент НИКОГДА не должен вызываться напрямую из kid-контекста.
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
            hapticServiceFactory: {
                if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
                    return LiveHapticService()
                } else {
                    return FallbackHapticService()
                }
            },
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
        container.kidLLMNarrationServiceStorage = MockKidLLMNarrationService()
        // Block K: Spotlight mock для preview/tests.
        container._spotlightIndexer = MockSpotlightIndexer()
        // Block N: DailyMissionSync mock для preview/tests.
        container._dailyMissionSyncService = MockDailyMissionSyncService()
        // Block K (v12): ObjectDetectionWorker mock для preview/tests — без Vision.
        container._objectDetectionWorker = MockObjectDetectionWorker()
        // Block O (v12): BiometricGate mock — всегда fallback в preview (нет real device).
        container._biometricGateService = MockBiometricGateService(available: false, result: .fallback)
        // Block D v13: PhonemeAnalysis mock — без CoreML в preview/tests.
        container._phonemeAnalysisService = MockPhonemeAnalysisService()
        // Block C v15: Speech Service Wrappers mock — без CoreML в preview/tests.
        container._ensembleASRService = MockEnsembleASRService()
        container._speakerVerificationService = MockSpeakerVerificationService()
        container._emotionDetectionService = MockEmotionDetectionService()
        // Block AA (v17): Firebase missing services mock — без сети в preview/tests.
        container.overrideBlockAAServices(
            cloudFunctions: MockCloudFunctionsService(),
            installations: MockInstallationsService()
        )
        // Block U (v18): Firebase full services replacement mock — без сети в preview/tests.
        container.overrideBlockUServices(
            familyInvite: MockFamilyInviteService(),
            realtimeDatabase: MockRealtimeDatabaseService()
        )
        // Block V (v21): ML warm-up — no-op в preview/tests, чтобы не грузить CoreML.
        container._mlWarmupService = MockMLModelWarmupService()
        return container
    }
}
