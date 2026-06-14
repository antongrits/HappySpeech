import CoreHaptics
import Foundation
import Observation
import os
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
    ///
    /// P1-8: ЕДИНЫЙ источник истины — ``ActiveChildStore`` (персистится в
    /// UserDefaults). `currentChildId` — вычисляемый прокси над ним, поэтому
    /// запись из FamilyHome и запись из ChildHome (`ActiveChildStore.set`)
    /// больше не расходятся: оба пишут в одно хранилище. Раньше это были два
    /// независимых источника, и при входе НЕ через FamilyHome `currentChildId`
    /// оставался пустым → уроки с пустым childId (сессии-сироты), диалект `.default`.
    ///
    /// При записи зеркалится в `activeChildIdHolder` — Sendable-снимок,
    /// который читают не-isolated слои (например `LiveEnsembleASRService` при
    /// выборе диалектного ruleset во время скоринга). Пустую строку не
    /// сохраняем как мусор — ``ActiveChildStore`` трактует "" как «очистить».
    public var currentChildId: String {
        get { ActiveChildStore.shared.id ?? "" }
        set {
            ActiveChildStore.shared.set(newValue)
            activeChildIdHolder.set(newValue)
        }
    }

    /// Потокобезопасный снимок активного childId для не-MainActor слоёв.
    /// Заполняется из `currentChildId` setter. Sendable.
    private let activeChildIdHolder = ActiveChildIdHolder()

    // M6.16: ScreeningOutcome repository — lazy, инициализируется при первом обращении.
    private var _screeningOutcomeRepository: (any ScreeningOutcomeRepository)?
    public var screeningOutcomeRepository: any ScreeningOutcomeRepository {
        if let existing = _screeningOutcomeRepository { return existing }
        let new = LiveScreeningOutcomeRepository(realmActor: realmActor)
        _screeningOutcomeRepository = new
        return new
    }

    // v17 «Фонемный паспорт»: PhonemeObservation repository — lazy, DTO-only
    // через RealmActor. Хранит только числа/IPA (без аудио/PII, COPPA-safe).
    private var _phonemeObservationRepository: (any PhonemeObservationRepository)?
    public var phonemeObservationRepository: any PhonemeObservationRepository {
        if let existing = _phonemeObservationRepository { return existing }
        let new = LivePhonemeObservationRepository(realmActor: realmActor)
        _phonemeObservationRepository = new
        return new
    }

    /// Подмена ``phonemeObservationRepository`` для preview / тестов. Должна
    /// вызываться до первого обращения к репозиторию/сервису паспорта.
    public func overridePhonemeObservationRepository(_ repository: any PhonemeObservationRepository) {
        _phonemeObservationRepository = repository
        // Сброс зависимого сервиса, чтобы он пересобрался поверх нового репозитория.
        _phonemeProfileService = nil
    }

    // v17 «Фонемный паспорт»: PhonemeProfileService — lazy actor. Агрегирует
    // GOP-наблюдения в матрицу «фонема × позиция» и оценивает динамику освоения
    // (EWMA + Theil-Sen). Оценка динамики, не диагноз (project guide §11).
    private var _phonemeProfileService: (any PhonemeProfileServiceProtocol)?
    public var phonemeProfileService: any PhonemeProfileServiceProtocol {
        if let existing = _phonemeProfileService { return existing }
        let new = LivePhonemeProfileService(repository: phonemeObservationRepository)
        _phonemeProfileService = new
        return new
    }

    /// Подмена ``phonemeProfileService`` для preview / тестов. Должна вызываться
    /// до первого обращения к сервису.
    public func overridePhonemeProfileService(_ service: any PhonemeProfileServiceProtocol) {
        _phonemeProfileService = service
    }

    // Rewards repository — реальные данные альбома (стикеры/достижения/кошелёк/
    // серия) из сессий, профиля и Realm-инвентаря. Lazy. Может быть переопределён
    // на mock в preview/тестах через `rewardsRepositoryOverride`.
    var rewardsRepositoryOverride: (any RewardsRepository)?
    private var _rewardsRepository: (any RewardsRepository)?
    public var rewardsRepository: any RewardsRepository {
        if let override = rewardsRepositoryOverride { return override }
        if let existing = _rewardsRepository { return existing }
        let new = LiveRewardsRepository(
            realmActor: realmActor,
            childRepository: childRepository,
            sessionRepository: sessionRepository
        )
        _rewardsRepository = new
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
    private var _remoteLLMClient: (any RemoteLLMClientProtocol)?
    private var _offlineQueueManager: OfflineQueueManager?
    /// Offline-first персистентность завершённых сессий + постановка в очередь синка.
    /// Закрывает аудит #2 (сессии не уходили в Firestore). Lazy.
    private var _sessionPersistenceCoordinator: (any SessionPersistenceCoordinating)?
    // Block D: Firebase full services
    private var _remoteConfigService: (any RemoteConfigService)?
    private var _fcmService: (any FCMService)?
    private var _performanceMonitorService: (any PerformanceMonitorService)?

    // Block AA (v17): Firebase missing services
    private var _cloudFunctionsService: (any CloudFunctionsServiceProtocol)?
    private var _installationsService: (any InstallationsServiceProtocol)?
    // Регистрация устройства (Installations + FCM) для адресных push-напоминаний.
    private var _deviceRegistrationService: (any DeviceRegistrationServiceProtocol)?

    // Block U (v18): Firebase full services replacement (Dynamic Links → Universal Links + Firestore)
    private var _familyInviteService: (any FamilyInviteServiceProtocol)?
    private var _realtimeDatabaseService: (any RealtimeDatabaseServiceProtocol)?

    // Со-родительство: локальное хранилище принятых семейных приглашений.
    // Persistence-only — НЕ реплицирует детей кросс-аккаунтно (см. co-parent gap).
    private var _familyMembershipStore: (any FamilyMembershipStoring)?

    // P0-4: персистентный прогресс ребёнка по лестнице коррекции (per-child-per-sound).
    // Источник реальной стартовой стадии сессии и приёмник продвижения вперёд.
    private var _stageProgressStore: (any StageProgressStoring)?

    // Block R.2 (v32): ChatRepository — реальный чат parent ↔ specialist (Firestore).
    // Lazy. Live: FirestoreChatRepository. Preview/Test: MockChatRepository.
    // COPPA: только родительский/специалистский контур.
    private var _chatRepository: (any ChatRepository)?

    // HomeworkRepository — реальный Firestore-синк домашних заданий
    // специалист ↔ родитель/ребёнок. Lazy. Live: FirestoreHomeworkRepository.
    // Preview/Test: MockHomeworkRepository.
    // COPPA: childId без PII; familyId = parent uid; доступ parent-auth-gated.
    private var _homeworkRepository: (any HomeworkRepository)?

    // MethodologyAssistantClient — локальный офлайн RAG по методическому
    // корпусу (BM25 поверх methodology_corpus.json). Lazy.
    // Live: LocalMethodologyAssistantClient. Preview/Test: Mock.
    // COPPA: только parent / specialist контур за parental gate.
    private var _methodologyAssistantClient: (any MethodologyAssistantClientProtocol)?

    // VideoPlayerService — lazy, реестр видео из Videos/video-manifest.json
    // (stories / lessons / achievements / tutorials / cutscenes). Live:
    // VideoPlayerServiceLive. Preview/Test: MockVideoPlayerService.
    private var _videoPlayerService: (any VideoPlayerServiceProtocol)?

    // CutsceneService — lazy, нарративные кат-сцены «Путешествие Ляли».
    // Зависит от videoPlayerService (видео-URL) + hapticService (опц.).
    // Live: CutsceneServiceLive (@Observable, приоритетная очередь, per-child
    // seen-персистентность). Preview/Test: MockCutsceneService (shouldPlay=false).
    private var _cutsceneService: (any CutsceneServiceProtocol)?

    // SoundService — lazy, не требует изменения init
    private var _soundService: (any SoundServiceProtocol)?

    // FaceAnalysisService — lazy, не требует изменения init
    private var _faceAnalysisService: (any FaceAnalysisService)?

    // Block H: KidLLMNarrationService — lazy, использует llmDecisionService.
    // internal visibility for preview() factory access — намеренно не private.
    var kidLLMNarrationServiceStorage: (any KidLLMNarrationServiceProtocol)?

    // Block K: SpotlightIndexer — CoreSpotlight indexing, COPPA-safe (нет имени ребёнка).
    private var _spotlightIndexer: (any SpotlightIndexerProtocol)?

    // F1-016: ReviewSchedulerService — единый планировщик интервальных повторов.
    // internal visibility — live()/preview() инжектят shared-инстанс (тот же,
    // что получает AdaptivePlanner), чтобы все шаблоны писали в одно расписание.
    var reviewSchedulerStorage: (any ReviewSchedulerService)?

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

    // A-08 «Спокойный режим» — singleton источник истины флага (default OFF).
    // Персистится в UserDefaults; Settings-VIP и менеджер читают один ключ.
    public let calmModeManager: CalmModeManager = CalmModeManager()

    // Block D v13: PhonemeAnalysisService — фонемный анализ произношения (DTW + CoreML).
    // Actor-typed, lazy. Требует G2PWorker (словарь 7712 слов) + RussianPhonemeClassifier (1.35 MB).
    private var _phonemeAnalysisService: (any PhonemeAnalysisService)?

    // Block E v13: Wav2Vec2Service — Tier 3 CTC phonemic ASR (Wav2Vec2RuChild.mlmodelc, ~302 MB).
    // Actor-typed, lazy. Загружает модель при первом вызове transcribe. При сбое — throws, не mock.
    private var _wav2Vec2Service: (any Wav2Vec2Service)?

    // v17 «Фонемный паспорт»: PhonemePassportIngestor — фоновый приёмник
    // пофонемных наблюдений поверх Wav2Vec2 forced alignment. Lazy. Запускается
    // только из parent-контура fire-and-forget, гейтится по RAM (модель ~302 MB).
    private var _phonemePassportIngestor: (any PhonemePassportIngesting)?

    // Block C v15: EnsembleASRService — weighted voting Tier A/B.
    private var _ensembleASRService: (any EnsembleASRServiceProtocol)?

    // Block C v15: SpeakerVerificationService — ECAPA d-vector, parent vs child.
    private var _speakerVerificationService: (any SpeakerVerificationServiceProtocol)?

    // Block C v15: EmotionDetectionService — Conv1d-LSTM 4 emotions.
    private var _emotionDetectionService: (any EmotionDetectionServiceProtocol)?

    // Block M (v12): VoiceCloneService — реальный TTS-синтез с трёхуровневым fallback.
    // Live: LiveVoiceCloneService (AVSpeechSynthesizer → m4a, familyVoice, bundledAudio,
    // опц. Personal Voice на en-локалях). Preview/Test: MockVoiceCloneService.
    private var _voiceCloneService: (any VoiceCloneService)?
    public var voiceCloneService: any VoiceCloneService {
        if let existing = _voiceCloneService { return existing }
        let new: any VoiceCloneService = LiveVoiceCloneService()
        _voiceCloneService = new
        return new
    }

    /// Подмена ``voiceCloneService`` для preview / тестов. Должна вызываться до
    /// первого обращения к `voiceCloneService`.
    public func overrideVoiceCloneService(_ service: any VoiceCloneService) {
        _voiceCloneService = service
    }

    // Personal Voice (опциональный приватный TTS «голосом родителя») — lazy.
    // Live: LivePersonalVoiceService (AVSpeechSynthesizer + Apple Personal Voice,
    // graceful fallback на системный ru-RU TTS). Preview/Test: MockPersonalVoiceService.
    // Контур: ТОЛЬКО parent / specialist за ParentalGate (COPPA). См. ADR-V33-PERSONAL-VOICE.
    private var _personalVoiceService: (any PersonalVoiceServicing)?
    public var personalVoiceService: any PersonalVoiceServicing {
        if let existing = _personalVoiceService { return existing }
        let new: any PersonalVoiceServicing = LivePersonalVoiceService()
        _personalVoiceService = new
        return new
    }

    /// Подмена ``personalVoiceService`` для preview / тестов. Должна вызываться до
    /// первого обращения к `personalVoiceService`.
    public func overridePersonalVoiceService(_ service: any PersonalVoiceServicing) {
        _personalVoiceService = service
    }

    // Block V (v21): MLModelWarmupService — параллельный прогрев Pronunciation + ASR + VAD
    // во время онбординга для быстрого старта первой сессии.
    private var _mlWarmupService: (any MLModelWarmupServiceProtocol)?

    // v31 Wave F F-05: DailyUsageTracker — in-app daily usage cap (no Family Controls).
    // Lazy + protocol-injectable. Mock в preview/tests.
    private var _dailyUsageTracker: (any DailyUsageTracking)?

    // v31 Волна D Ф.4: SpeechAnalyzerService — iOS 26 SpeechAnalyzer +
    // WhisperKit fallback для low-latency live transcript.
    private var _speechAnalyzerService: (any SpeechAnalyzerService)?
    private var speechAnalyzerServiceFactory: (@MainActor () -> any SpeechAnalyzerService)?

    /// Lazy access. Если фабрика не передана — собираем LiveSpeechAnalyzerService
    /// над текущим `asrService`. Это позволяет переопределить mock-ом
    /// в preview/тестах через `overrideSpeechAnalyzerService(...)`.
    public var speechAnalyzerService: any SpeechAnalyzerService {
        if let existing = _speechAnalyzerService { return existing }
        let new: any SpeechAnalyzerService
        if let speechAnalyzerServiceFactory {
            new = speechAnalyzerServiceFactory()
        } else {
            new = LiveSpeechAnalyzerService(asrService: self.asrService)
        }
        _speechAnalyzerService = new
        return new
    }

    /// Подмена реализации (для preview / тестов). Должна вызываться до
    /// первого обращения к `speechAnalyzerService`.
    public func overrideSpeechAnalyzerService(_ service: any SpeechAnalyzerService) {
        _speechAnalyzerService = service
    }

    // MARK: - v31 Wave F F-05: DailyUsageTracker

    /// Lazy. Live — `DailyUsageTracker` (UserDefaults + UIApplication lifecycle).
    /// В preview/tests подменяется на `MockDailyUsageTracker`.
    public var dailyUsageTracker: any DailyUsageTracking {
        if let existing = _dailyUsageTracker { return existing }
        let new: any DailyUsageTracking = DailyUsageTracker()
        _dailyUsageTracker = new
        return new
    }

    /// Подмена для preview/tests. Должна вызываться до первого обращения.
    public func overrideDailyUsageTracker(_ tracker: any DailyUsageTracking) {
        _dailyUsageTracker = tracker
    }

    // MARK: - AcousticMirrorService («Акустическое зеркало»)

    /// On-device акустическая артикулометрия сибилянтов (vDSP, без ML-моделей и
    /// сети). Kid-контур, COPPA-safe by construction. Lazy.
    /// Live: ``LiveAcousticMirrorService``. Preview/Test: ``MockAcousticMirrorService``.
    private var _acousticMirrorService: (any AcousticMirrorServicing)?
    public var acousticMirrorService: any AcousticMirrorServicing {
        if let existing = _acousticMirrorService { return existing }
        let new: any AcousticMirrorServicing = LiveAcousticMirrorService()
        _acousticMirrorService = new
        return new
    }

    /// Подмена ``acousticMirrorService`` для preview / тестов. Должна вызываться
    /// до первого обращения к `acousticMirrorService`.
    public func overrideAcousticMirrorService(_ service: any AcousticMirrorServicing) {
        _acousticMirrorService = service
    }

    // MARK: - SyllableRaceService («Скороговорка-ракета» / диадохокинез)

    /// On-device анализ темпа ритмичного повтора слогов (vDSP, без ML-моделей и
    /// сети). Kid-контур, COPPA-safe by construction. Lazy.
    /// Live: ``LiveSyllableRaceService``. Preview/Test: ``MockSyllableRaceService``.
    private var _syllableRaceService: (any SyllableRaceServicing)?
    public var syllableRaceService: any SyllableRaceServicing {
        if let existing = _syllableRaceService { return existing }
        let new: any SyllableRaceServicing = LiveSyllableRaceService()
        _syllableRaceService = new
        return new
    }

    /// Подмена ``syllableRaceService`` для preview / тестов. Должна вызываться
    /// до первого обращения к `syllableRaceService`.
    public func overrideSyllableRaceService(_ service: any SyllableRaceServicing) {
        _syllableRaceService = service
    }

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
    private let remoteLLMClientFactory: () -> any RemoteLLMClientProtocol
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
        remoteLLMClientFactory: @escaping () -> any RemoteLLMClientProtocol,
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
        self.remoteLLMClientFactory = remoteLLMClientFactory
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

    public var remoteLLMClient: any RemoteLLMClientProtocol {
        if let existing = _remoteLLMClient { return existing }
        let new = remoteLLMClientFactory()
        _remoteLLMClient = new
        return new
    }

    public var offlineQueueManager: OfflineQueueManager {
        if let existing = _offlineQueueManager { return existing }
        let new = offlineQueueManagerFactory()
        _offlineQueueManager = new
        return new
    }

    /// Координатор персистентности сессий (сохранение + offline-first синк).
    /// Собирается из уже-сконфигурированных `sessionRepository` / `syncService` /
    /// `authService`. Анонимные аккаунты не синкаются (см. координатор).
    public var sessionPersistenceCoordinator: any SessionPersistenceCoordinating {
        if let existing = _sessionPersistenceCoordinator { return existing }
        let new = LiveSessionPersistenceCoordinator(
            sessionRepository: sessionRepository,
            childRepository: childRepository,
            syncService: syncService,
            authService: authService
        )
        _sessionPersistenceCoordinator = new
        return new
    }

    /// Подмена ``sessionPersistenceCoordinator`` для preview / тестов.
    public func overrideSessionPersistenceCoordinator(_ coordinator: any SessionPersistenceCoordinating) {
        _sessionPersistenceCoordinator = coordinator
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
        performance: (any PerformanceMonitorService)? = nil
    ) {
        if let rc = remoteConfig { _remoteConfigService = rc }
        if let f = fcm { _fcmService = f }
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

    /// Регистрация устройства (Firebase Installations ID + FCM-токен) в Firestore
    /// `users/{uid}/devices/{installationId}` для адресных push-напоминаний.
    /// Только родительский контур (COPPA). См. ``DeviceRegistrationServiceProtocol``.
    public var deviceRegistrationService: any DeviceRegistrationServiceProtocol {
        if let existing = _deviceRegistrationService { return existing }
        let new = LiveDeviceRegistrationService(installations: installationsService)
        _deviceRegistrationService = new
        return new
    }

    /// Позволяет Preview/Tests подменить Block AA сервисы.
    public func overrideBlockAAServices(
        cloudFunctions: (any CloudFunctionsServiceProtocol)? = nil,
        installations: (any InstallationsServiceProtocol)? = nil,
        deviceRegistration: (any DeviceRegistrationServiceProtocol)? = nil
    ) {
        if let cf = cloudFunctions { _cloudFunctionsService = cf }
        if let inst = installations { _installationsService = inst }
        if let dr = deviceRegistration { _deviceRegistrationService = dr }
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

    /// Локальное хранилище принятых семейных приглашений (со-родительство).
    /// Сохраняет факт членства; кросс-аккаунтный доступ к детям — известный gap.
    public var familyMembershipStore: any FamilyMembershipStoring {
        if let existing = _familyMembershipStore { return existing }
        let new = UserDefaultsFamilyMembershipStore()
        _familyMembershipStore = new
        return new
    }

    /// P0-4: персистентный прогресс ребёнка по 10-этапной лестнице коррекции
    /// (per-child-per-sound, UserDefaults). Используется `SessionShellInteractor`
    /// для старта сессии с реальной стадии и продвижения вперёд при освоении.
    public var stageProgressStore: any StageProgressStoring {
        if let existing = _stageProgressStore { return existing }
        let new = UserDefaultsStageProgressStore()
        _stageProgressStore = new
        return new
    }

    /// Подмена ``stageProgressStore`` для preview / тестов.
    public func overrideStageProgressStore(_ store: any StageProgressStoring) {
        _stageProgressStore = store
    }

    /// Позволяет Preview/Tests подменить Block U сервисы.
    public func overrideBlockUServices(
        familyInvite: (any FamilyInviteServiceProtocol)? = nil,
        realtimeDatabase: (any RealtimeDatabaseServiceProtocol)? = nil,
        familyMembershipStore: (any FamilyMembershipStoring)? = nil
    ) {
        if let fi = familyInvite { _familyInviteService = fi }
        if let rdb = realtimeDatabase { _realtimeDatabaseService = rdb }
        if let store = familyMembershipStore { _familyMembershipStore = store }
    }

    // MARK: - Block R.2 (v32): ChatRepository

    /// Репозиторий чата «родитель ↔ логопед» (Firestore, offline-first, real-time).
    /// Только родительский/специалистский контур (COPPA). См. ``ChatRepository``.
    public var chatRepository: any ChatRepository {
        if let existing = _chatRepository { return existing }
        let new: any ChatRepository = FirestoreChatRepository(networkMonitor: networkMonitor)
        _chatRepository = new
        return new
    }

    /// Подмена ``chatRepository`` для preview / тестов. Должна вызываться до
    /// первого обращения к `chatRepository`.
    public func overrideChatRepository(_ repository: any ChatRepository) {
        _chatRepository = repository
    }

    // MARK: - HomeworkRepository

    /// Облачный синк домашних заданий специалист ↔ родитель/ребёнок (Firestore,
    /// offline-first, real-time). Только родительский/специалистский контур (COPPA).
    /// См. ``HomeworkRepository``.
    public var homeworkRepository: any HomeworkRepository {
        if let existing = _homeworkRepository { return existing }
        let new: any HomeworkRepository = FirestoreHomeworkRepository()
        _homeworkRepository = new
        return new
    }

    /// Подмена ``homeworkRepository`` для preview / тестов. Должна вызываться до
    /// первого обращения к `homeworkRepository`.
    public func overrideHomeworkRepository(_ repository: any HomeworkRepository) {
        _homeworkRepository = repository
    }

    // MARK: - MethodologyAssistantClient (локальный офлайн RAG)

    /// Помощник по методике логопедии — **локальный, офлайн, бесплатный**.
    ///
    /// Поиск по забандленному методическому корпусу (`methodology_corpus.json`,
    /// 13 документов) методом BM25. Никаких облачных вызовов и затрат ($0).
    /// Раньше использовался платный Vertex AI Search через Cloud Function —
    /// зависимость убрана.
    ///
    /// Только parent / specialist контур за parental gate (COPPA). Детский
    /// контур НИКОГДА не должен обращаться к этому клиенту.
    public var methodologyAssistantClient: any MethodologyAssistantClientProtocol {
        if let existing = _methodologyAssistantClient { return existing }
        let new: any MethodologyAssistantClientProtocol = LocalMethodologyAssistantClient()
        _methodologyAssistantClient = new
        return new
    }

    /// Подмена ``methodologyAssistantClient`` для preview / тестов. Должна
    /// вызываться до первого обращения к `methodologyAssistantClient`.
    public func overrideMethodologyAssistantClient(_ client: any MethodologyAssistantClientProtocol) {
        _methodologyAssistantClient = client
    }

    /// Реестр видео-роликов из `Videos/video-manifest.json`.
    /// Live: ``VideoPlayerServiceLive``. Preview/Test: ``MockVideoPlayerService``.
    /// Internal — `VideoPlayerServiceProtocol` объявлен internal (один app-target).
    var videoPlayerService: any VideoPlayerServiceProtocol {
        if let existing = _videoPlayerService { return existing }
        let new: any VideoPlayerServiceProtocol = VideoPlayerServiceLive()
        _videoPlayerService = new
        return new
    }

    /// Подмена ``videoPlayerService`` для preview / тестов. Должна вызываться до
    /// первого обращения к `videoPlayerService`.
    func overrideVideoPlayerService(_ service: any VideoPlayerServiceProtocol) {
        _videoPlayerService = service
    }

    /// Сервис нарративных кат-сцен «Путешествие Ляли по Стране Звуков».
    /// Live: ``CutsceneServiceLive`` (приоритетная очередь + per-child seen).
    /// Preview/Test: ``MockCutsceneService`` (по умолчанию `shouldPlay=false`).
    /// Internal — `CutsceneServiceProtocol` объявлен internal (один app-target).
    var cutsceneService: any CutsceneServiceProtocol {
        if let existing = _cutsceneService { return existing }
        let new: any CutsceneServiceProtocol = CutsceneServiceLive(
            videoPlayerService: videoPlayerService,
            hapticService: hapticService
        )
        _cutsceneService = new
        return new
    }

    /// Подмена ``cutsceneService`` для preview / тестов. Должна вызываться до
    /// первого обращения к `cutsceneService`.
    func overrideCutsceneService(_ service: any CutsceneServiceProtocol) {
        _cutsceneService = service
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

    // F1-016: единый планировщик интервальных повторов. Шаблоны упражнений
    // (minimal-pairs, repeat-after-model, articulation, narrative-quest)
    // фиксируют исход каждой попытки через `recordOutcome`; AdaptivePlanner
    // подмешивает due-повторы в дневной маршрут. Lazy fallback на
    // UserDefaults-backed реализацию (`.standard`) совпадает по хранилищу с
    // shared-инстансом, инжектируемым из `live()`/`preview()`.
    public var reviewScheduler: any ReviewSchedulerService {
        if let existing = reviewSchedulerStorage { return existing }
        let new = LiveReviewSchedulerService()
        reviewSchedulerStorage = new
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
    /// Preview/Test: MockPhonemeAnalysisService (задаётся через _phonemeAnalysisService = Mock* в .preview).
    ///
    /// При сбое инициализации в проде выбрасывает ошибку в лог и возвращает unavailable-
    /// состояние через PhonemeAnalysisUnavailableService, а не фиктивный mock-score.
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
            HSLogger.ml.error("AppContainer: PhonemeAnalysisService init failed (\(error.localizedDescription)) — сервис недоступен")
            service = PhonemeAnalysisUnavailableService(reason: error)
        }
        _phonemeAnalysisService = service
        return service
    }

    // MARK: - Block E v13: Wav2Vec2Service

    /// Tier 3 CTC phonemic ASR через Wav2Vec2RuChild.mlmodelc (~302 MB, скомпилирован Xcode из .mlpackage).
    ///
    /// Используется в ``PhonemeAnalysisServiceLive`` при confidence < 0.70 от Tier 1/2.
    /// Модель загружается лениво при первом вызове — без задержки при запуске приложения.
    /// При отсутствии модели в бандле первый вызов transcribe() бросает Wav2Vec2Error.modelNotLoaded.
    public var wav2Vec2Service: any Wav2Vec2Service {
        if let existing = _wav2Vec2Service { return existing }
        let service: any Wav2Vec2Service = Wav2Vec2ServiceLive()
        _wav2Vec2Service = service
        return service
    }

    /// «Фонемный паспорт»: фоновый ингестор пофонемных наблюдений.
    ///
    /// Используется только из parent-контура (`FamilyVoice`) fire-and-forget.
    /// Внутри гейтит по RAM (Wav2Vec2 ≈ 302 MB) — на слабых устройствах тихо
    /// пропускает. Lazy: модель грузится лишь при первом реальном вызове.
    public var phonemePassportIngestor: any PhonemePassportIngesting {
        if let existing = _phonemePassportIngestor { return existing }
        let service = LivePhonemePassportIngestor(
            wav2Vec2: wav2Vec2Service,
            profileService: phonemeProfileService
        )
        _phonemePassportIngestor = service
        return service
    }

    /// Подмена ингестора паспорта для preview / тестов.
    public func overridePhonemePassportIngestor(_ service: any PhonemePassportIngesting) {
        _phonemePassportIngestor = service
    }

    // MARK: - Block C v15: Speech Service Wrappers

    /// Ансамблевый ASR — взвешенное голосование Tier A (on-device) / Tier B (Whisper).
    /// Kid circuit использует только Tier A (COPPA).
    public var ensembleASRService: any EnsembleASRServiceProtocol {
        if let existing = _ensembleASRService { return existing }
        // Tier B (parent/specialist) усилен Wav2Vec2 CTC-декодером как 4-м голосом.
        // Kid circuit использует только Tier A — Wav2Vec2 там не вызывается.
        // Диалект-толерантность скоринга: читаем выбранный диалект активного
        // ребёнка (DialectProfileStore поверх тех же UserDefaults, что пишет
        // DialectAdaptationInteractor) и снимок childId из Sendable-холдера.
        let dialectHolder = activeChildIdHolder
        let service = LiveEnsembleASRService(
            whisperASR: asrService,
            phonemeClassifier: phonemeAnalysisService,
            pronunciationScorer: pronunciationService,
            wav2Vec2: wav2Vec2Service,
            dialectProfileProvider: DialectProfileStore(),
            activeChildIdProvider: { dialectHolder.get() }
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

    // MARK: - ContentEngine (gap #2: генератор вариаций контента)

    private var _contentEngine: ContentEngine?

    /// Движок сборки уроков + рантайм-генератор вариаций контента
    /// (``ContentVariationGenerator`` через `contentEngine.variationGenerator`).
    /// Один shared-инстанс поверх `contentService`. Lazy.
    public var contentEngine: ContentEngine {
        if let existing = _contentEngine { return existing }
        let new = ContentEngine(contentService: contentService)
        _contentEngine = new
        return new
    }

    // MARK: - GuidedTour (VIP — Block I v16)

    private var _guidedTourCoordinator: GuidedTourCoordinator?
    private var _guidedTourInteractor: GuidedTourInteractor?
    private var _guidedTourPresenter: GuidedTourPresenter?
    private var _guidedTourRouter: GuidedTourRouter?

    // P1-5: резидентный слушатель шины достижений. Раньше единственным
    // подписчиком был AchievementsInteractor (жил только пока открыт экран),
    // поэтому события закрытого экрана терялись. Sink живёт всё время работы
    // приложения и персистит разблокированные ачивки в Realm независимо от UI.
    private var _achievementEventSink: AchievementEventSink?

    /// Долгоживущий слушатель шины `.achievementEventOccurred`. Lazy; реально
    /// поднимается в `attachGuidedTourCoordinator` на старте приложения, чтобы
    /// ачивки персистились даже когда экран ачивок закрыт.
    var achievementEventSink: AchievementEventSink {
        if let existing = _achievementEventSink { return existing }
        let sink = AchievementEventSink(
            realmActor: realmActor,
            childRepository: childRepository
        )
        _achievementEventSink = sink
        return sink
    }

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
        // P1-5: поднимаем резидентный слушатель шины достижений на старте
        // приложения, чтобы разблокировки персистились даже при закрытом экране.
        _ = achievementEventSink
        // P1-8: на холодном старте seed'им Sendable-снимок childId для не-isolated
        // ML-слоёв из персистентного источника истины (`ActiveChildStore`). Иначе
        // диалект-ruleset ансамбля оставался бы `.default` до первого входа в
        // детскую главную (которая теперь тоже пишет через `currentChildId`).
        activeChildIdHolder.set(ActiveChildStore.shared.id ?? "")
    }
}

// MARK: - Factory Methods

public extension AppContainer {

    /// Creates the production container with real service implementations.
    static func live() -> AppContainer {
        // Выставляем каноническую конфигурацию Realm (v17 + migrationBlock) как
        // глобальный дефолт СИНХРОННО, до создания RealmActor и до первого рендера.
        // Гарантирует, что любое открытие Realm через `Realm(actor:)` (в т.ч.
        // хелпер, опередивший `bootstrapApp().open()`) использует правильную схему
        // и migration-блок — закрывает гонку cold-start и корень «ошибок с id».
        RealmConfig.installAsDefault()
        let realmActor = RealmActor()
        let childRepo = LiveChildRepository(realmActor: realmActor)
        let sessionRepo = LiveSessionRepository(realmActor: realmActor)
        let theme = ThemeManager()

        // Shared singletons for LLM wiring (one inference actor, one log repo, one local LLM)
        let sharedNetworkMonitor = LiveNetworkMonitor()
        // MLX-backed Qwen2.5-1.5B-Instruct-4bit (~839 MB) is bundled inside the app —
        // Tier A on-device is the active production path. Rule-based service is only
        // engaged as a guarded fallback inside `LiveLLMDecisionService` and is logged
        // explicitly so silent degradation is observable in QA dashboards.
        let sharedLocalLLM: any LocalLLMService = LocalLLMServiceLive()
        let sharedInferenceActor = LLMInferenceActor(localLLM: sharedLocalLLM)
        let sharedLLMLogRepo: any LLMDecisionLogRepository = LiveLLMDecisionLogRepository(realmActor: realmActor)
        // COPPA: HFInferenceClient используется ТОЛЬКО в parent/specialist circuit (Tier B).
        // LiveLLMDecisionService внутри блокирует Tier B для kid context через contextRole проверку.
        // KidLLMNarrationService использует только Tier A (on-device) или Tier C (rule-based).
        // Этот клиент НИКОГДА не должен вызываться напрямую из kid-контекста.
        let sharedHFClient = HFInferenceClient()
        let sharedNetworkClient = NetworkClient()
        let sharedSyncService: any SyncService = LiveSyncService(realmActor: realmActor, networkMonitor: sharedNetworkMonitor)
        // F1-016: единый планировщик интервальных повторов (UserDefaults-backed).
        let sharedReviewScheduler: any ReviewSchedulerService = LiveReviewSchedulerService()
        // v17 «Фонемный паспорт»: профиль-сервис над тем же Realm, что и контейнер
        // (репозиторий — stateless-обёртка, данные живут в Realm). Планировщик
        // читает слабейшую confusion-пару для адресной дифференциации minimal-pairs.
        let sharedPhonemeProfileService: any PhonemeProfileServiceProtocol =
            LivePhonemeProfileService(
                repository: LivePhonemeObservationRepository(realmActor: realmActor)
            )
        // gap #2: рантайм-генератор вариаций контента над тем же `LiveContentService`,
        // что и контент-слой (паки кэшируются внутри генератора-актора). Планировщик
        // наполняет каждый звуковой шаг реальной вариацией, выбранной адаптивно.
        let sharedVariationGenerator: any ContentVariationGenerating =
            ContentVariationGenerator(contentService: LiveContentService())
        // P0-4: персистентная стадия лестницы — источник истины текущего этапа
        // ребёнка по звуку (тот же стор, что пишет `SessionShellInteractor`).
        let sharedStageProgressStore: any StageProgressStoring = UserDefaultsStageProgressStore()

        let container = AppContainer(
            realmActor: realmActor,
            childRepository: childRepo,
            sessionRepository: sessionRepo,
            themeManager: theme,
            authService: LiveAuthService(),
            audioServiceFactory: { LiveAudioService() },
            asrServiceFactory: {
                let asr = LiveASRService()
                // Подключаем пред-проверку речи (реальный VAD Silero v6 + SoundClassifier):
                // коротит WhisperKit только на уверенной тишине, искажённую речь не теряет.
                asr.setPreflightGate(LiveSpeechPreflightGate())
                return asr
            },
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
                    sessionRepository: sessionRepo,
                    reviewScheduler: sharedReviewScheduler,
                    phonemeProfileService: sharedPhonemeProfileService,
                    variationGenerator: sharedVariationGenerator,
                    stageProgressStore: sharedStageProgressStore
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
                LLMModelManager(primaryLLM: sharedLocalLLM)
            },
            whisperKitModelManagerFactory: {
                WhisperKitModelManagerLive(networkMonitor: sharedNetworkMonitor)
            },
            networkClientFactory: { sharedNetworkClient },
            remoteLLMClientFactory: {
                RemoteLLMClient(networkClient: sharedNetworkClient)
            },
            offlineQueueManagerFactory: {
                OfflineQueueManager(
                    realmActor: realmActor,
                    syncService: sharedSyncService,
                    networkMonitor: sharedNetworkMonitor
                )
            }
        )
        // F1-016: тот же планировщик повторов, что получил AdaptivePlanner —
        // шаблоны упражнений пишут в него, планировщик читает due-повторы.
        container.reviewSchedulerStorage = sharedReviewScheduler
        return container
    }

    /// Creates a preview container with mock service implementations.
    /// Использует расширенный seed (`previewList` 2 детей + история сессий)
    /// чтобы screenshot tour / демо не показывали пустые экраны на
    /// Leaderboard, FamilyAchievements, SessionHistory, ComparisonDashboard и т.д.
    static func preview() -> AppContainer {
        // Та же каноническая конфигурация, что и в проде: даже preview/UI-test
        // открытия Realm через `Realm(actor:)` наследуют v17 + migrationBlock.
        RealmConfig.installAsDefault()
        let realmActor = RealmActor()
        let childRepo = MockChildRepository(children: ChildProfileDTO.previewList)
        let sessionRepo = MockSessionRepository.seeded()
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
            remoteLLMClientFactory: { MockRemoteLLMClient() },
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
            installations: MockInstallationsService(),
            deviceRegistration: MockDeviceRegistrationService()
        )
        // Block U (v18): Firebase full services replacement mock — без сети в preview/tests.
        container.overrideBlockUServices(
            familyInvite: MockFamilyInviteService(),
            realtimeDatabase: MockRealtimeDatabaseService()
        )
        // Block V (v21): ML warm-up — no-op в preview/tests, чтобы не грузить CoreML.
        container._mlWarmupService = MockMLModelWarmupService()
        // v31 Волна D Ф.4: SpeechAnalyzerService — mock в preview/tests.
        container.overrideSpeechAnalyzerService(MockSpeechAnalyzerService())
        // v31 Wave F F-05: DailyUsageTracker — mock в preview/tests (без UIApplication).
        container.overrideDailyUsageTracker(MockDailyUsageTracker())
        // Block M (v12): VoiceClone — mock без AVSpeechSynthesizer/файлов в preview/tests.
        container.overrideVoiceCloneService(MockVoiceCloneService())
        // Personal Voice — mock без AVSpeechSynthesizer в preview/tests.
        container.overridePersonalVoiceService(MockPersonalVoiceService())
        // Block R.2 (v32): ChatRepository — seeded mock с подключённым логопедом и
        // переписки, чтобы preview / snapshot чата не показывали пустой экран.
        container.overrideChatRepository(MockChatRepository.previewSeeded())
        // MethodologyAssistant — mock без сети в preview/tests.
        container.overrideMethodologyAssistantClient(MockMethodologyAssistantClient())
        // Cutscenes — mock в preview/tests: кат-сцены не всплывают в превью /
        // снапшотах (shouldPlay=false), видео не грузится.
        container.overrideVideoPlayerService(MockVideoPlayerService())
        container.overrideCutsceneService(MockCutsceneService())
        // HomeworkRepository — mock без Firestore в preview/tests.
        container.overrideHomeworkRepository(MockHomeworkRepository())
        // v17 «Фонемный паспорт» — детерминированный mock без Realm в preview/tests.
        container.overridePhonemeObservationRepository(MockPhonemeObservationRepository())
        container.overridePhonemeProfileService(MockPhonemeProfileService())
        // «Акустическое зеркало» — детерминированный mock без DSP/файлов в preview/tests.
        container.overrideAcousticMirrorService(MockAcousticMirrorService())
        // «Скороговорка-ракета» (диадохокинез) — детерминированный mock в preview/tests.
        container.overrideSyllableRaceService(MockSyllableRaceService())
        return container
    }
}
