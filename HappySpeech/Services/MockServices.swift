import Foundation
import AVFoundation
import UIKit

// MARK: - Mock implementations for Preview and Tests

// MARK: MockAudioService

public final class MockAudioService: AudioService, @unchecked Sendable {
    public var isPermissionGranted: Bool = true
    public var amplitude: Float = 0.0
    public var isRecording: Bool = false

    public func requestPermission() async -> Bool { true }
    public func startRecording() async throws { isRecording = true }
    public func stopRecording() async throws -> URL {
        isRecording = false
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mock_audio.m4a")
    }
    public func playAudio(url: URL) async throws {}
    public func stopPlayback() {}
    public func amplitudeBuffer() -> [Float] { Array(repeating: 0.3, count: 40) }
}

// MARK: MockASRService

public final class MockASRService: ASRService, @unchecked Sendable {
    public var isReady: Bool = true

    public func transcribe(url: URL) async throws -> ASRResult {
        ASRResult(transcript: "рыба", confidence: 0.92, wordTimestamps: [
            .init(word: "рыба", startTime: 0.1, endTime: 0.6)
        ])
    }

    public func loadModel() async throws {}
}

// MARK: MockSyncService

public actor MockSyncService: SyncService {
    private var _pendingCount: Int = 0
    private var _isSyncing: Bool = false

    public init() {}

    public func pendingCount() async -> Int { _pendingCount }
    public func isSyncing() async -> Bool { _isSyncing }

    public func drainQueue() async throws {}
    public func enqueue(operation: SyncOperation) async throws { _pendingCount += 1 }
}

// MARK: MockAnalyticsService

public final class MockAnalyticsService: AnalyticsService, @unchecked Sendable {
    public private(set) var events: [AnalyticsEvent] = []
    public func track(event: AnalyticsEvent) { events.append(event) }
}

// MARK: MockHapticService

public final class MockHapticService: HapticService, @unchecked Sendable {
    public func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {}
    public func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {}
    public func selection() {}
}

// MARK: MockNotificationService

public final class MockNotificationService: NotificationService, @unchecked Sendable {
    public func scheduleDailyReminder(at hour: Int, minute: Int) async throws {}
    public func cancelAllReminders() async {}
    public func requestPermission() async -> Bool { true }
}

// MARK: MockNetworkMonitor

public final class MockNetworkMonitor: NetworkMonitorService, @unchecked Sendable {
    public var isConnected: Bool = true
    public var connectionType: ConnectionType = .wifi
}

// MARK: MockPronunciationScorerService

public final class MockPronunciationScorerService: PronunciationScorerService, @unchecked Sendable {
    public var isModelLoaded: Bool = true

    public func score(audioURL: URL, targetSound: String) async throws -> PronunciationScore {
        PronunciationScore(rawValue: 0.82)
    }

    public func loadModel() async throws {}
}

// MARK: MockLocalLLMService

public final class MockLocalLLMService: LocalLLMService, @unchecked Sendable {
    public var isModelDownloaded: Bool = false
    public var isModelLoaded: Bool = false

    public func generateParentSummary(request: ParentSummaryRequest) async throws -> ParentSummaryResponse {
        ParentSummaryResponse(
            parentSummary: "Миша сегодня отлично поработал! Из 12 слов — 9 правильных (75%).",
            homeTask: "Повторите дома: ворона, гараж."
        )
    }

    public func generateRoute(request: RoutePlannerRequest) async throws -> RoutePlannerResponse {
        RoutePlannerResponse(
            route: [
                .init(template: "listen-and-choose", difficulty: 2, wordCount: 10, durationTargetSec: 180),
                .init(template: "repeat-after-model", difficulty: 2, wordCount: 8, durationTargetSec: 240)
            ],
            sessionMaxDurationSec: 600
        )
    }

    public func generateMicroStory(request: MicroStoryRequest) async throws -> MicroStoryResponse {
        MicroStoryResponse(
            sentences: ["Рома нашёл розу.", "Он взял ракету.", "Рыба плавала в реке."],
            gapPositions: [.init(sentenceIndex: 0, word: "розу", imageHint: "роза")]
        )
    }

    public func downloadModel() async throws {}
}

// MARK: MockARService

public final class MockARService: ARService, @unchecked Sendable {
    public var isSupported: Bool = false
    public var isCameraPermissionGranted: Bool = false

    public func requestCameraPermission() async -> Bool { false }
}

// MARK: MockContentService

public final class MockContentService: ContentService, @unchecked Sendable {
    public func loadPack(id: String) async throws -> ContentPack {
        ContentPack(
            id: id,
            soundTarget: "Р",
            stage: .wordInit,
            templateType: .listenAndChoose,
            items: ContentItem.previewItems
        )
    }

    public func allPacks() async throws -> [ContentPackMeta] { [] }
    public func bundledPacks() -> [ContentPackMeta] { [] }
}

// MARK: MockAdaptivePlannerService

public final class MockAdaptivePlannerService: AdaptivePlannerService, @unchecked Sendable {
    public struct RecordedQuality: Sendable, Equatable {
        public let childId: String
        public let soundTarget: String
        public let quality: SM2Quality
    }

    public var route: AdaptiveRoute
    public var fatigue: FatigueLevel
    public var recordedQualities: [RecordedQuality] = []
    public var forcedBreak: Bool = false

    public init(
        route: AdaptiveRoute? = nil,
        fatigue: FatigueLevel = .fresh
    ) {
        let defaultRoute = AdaptiveRoute(
            steps: [
                RouteStepItem(templateType: .listenAndChoose, targetSound: "Р",
                              stage: .wordInit, difficulty: 2, wordCount: 10, durationTargetSec: 180),
                RouteStepItem(templateType: .repeatAfterModel, targetSound: "Р",
                              stage: .wordInit, difficulty: 2, wordCount: 8, durationTargetSec: 240)
            ],
            maxDurationSec: 600,
            fatigueLevel: fatigue
        )
        self.route = route ?? defaultRoute
        self.fatigue = fatigue
    }

    public func buildDailyRoute(for childId: String) async throws -> AdaptiveRoute { route }

    public func recordCompletion(sessionId: String, route: AdaptiveRoute) async throws {}

    public func recordSessionResult(
        childId: String,
        soundTarget: String,
        qualityScore: SM2Quality
    ) async throws {
        recordedQualities.append(RecordedQuality(childId: childId, soundTarget: soundTarget, quality: qualityScore))
    }

    public func shouldTakeBreak(
        consecutiveWrong: Int,
        sessionDurationSec: Int,
        childAge: Int
    ) -> Bool {
        if forcedBreak { return true }
        return consecutiveWrong >= 3
    }
}

// MARK: MockClaudeAPIClient

public struct MockClaudeAPIClient: ClaudeAPIClientProtocol {
    public let isConfigured: Bool = true
    public init() {}
    public func send(
        circuit: CircuitType,
        system: String?,
        messages: [ClaudeChatMessage],
        maxTokens: Int,
        temperature: Double
    ) async throws -> String {
        if circuit == .kid { throw AppError.notAllowedInChildCircuit }
        return "Mock Claude response for \(messages.count) message(s)."
    }
}

// MARK: MockAuthService

public final class MockAuthService: AuthService, @unchecked Sendable {

    // Configurable behaviour
    public var shouldFail: Bool = false
    public var shouldReturnUnverifiedEmail: Bool = false
    public var simulatedDelayNanoseconds: UInt64 = 0

    // In-memory state
    nonisolated(unsafe) private var _currentUser: AuthUser?
    nonisolated(unsafe) private var listeners: [UUID: @Sendable (AuthUser?) -> Void] = [:]
    private let lock = NSLock()

    public init(initialUser: AuthUser? = nil) {
        self._currentUser = initialUser
    }

    public var currentUser: AuthUser? {
        lock.lock(); defer { lock.unlock() }
        return _currentUser
    }

    public func signIn(email: String, password: String) async throws -> AuthUser {
        try await simulateDelay()
        if shouldFail { throw AppError.authInvalidCredential }
        let user = AuthUser(
            uid: "mock-uid-\(email.hashValue)",
            email: email,
            displayName: "Mock User",
            isAnonymous: false,
            isEmailVerified: !shouldReturnUnverifiedEmail
        )
        setUser(user)
        return user
    }

    public func signUp(email: String, password: String, displayName: String) async throws -> AuthUser {
        try await simulateDelay()
        if shouldFail { throw AppError.authEmailAlreadyInUse }
        let user = AuthUser(
            uid: "mock-signup-\(email.hashValue)",
            email: email,
            displayName: displayName,
            isAnonymous: false,
            isEmailVerified: false
        )
        setUser(user)
        return user
    }

    public func sendPasswordReset(email: String) async throws {
        try await simulateDelay()
        if shouldFail { throw AppError.authUserNotFound }
    }

    public func sendEmailVerification() async throws {
        try await simulateDelay()
        if shouldFail { throw AppError.authSignInFailed("mock verification fail") }
    }

    public func reloadCurrentUser() async throws -> AuthUser? {
        try await simulateDelay()
        return currentUser
    }

    public func signInWithGoogle() async throws -> AuthUser {
        try await simulateDelay()
        if shouldFail { throw AppError.authGoogleCancelled }
        let user = AuthUser(
            uid: "mock-google-uid",
            email: "mock.google@example.com",
            displayName: "Mock Google User",
            isAnonymous: false,
            isEmailVerified: true
        )
        setUser(user)
        return user
    }

    public func signInAnonymously() async throws -> AuthUser {
        try await simulateDelay()
        if shouldFail { throw AppError.authSignInFailed("mock anon fail") }
        let user = AuthUser(
            uid: "mock-anon-\(UUID().uuidString.prefix(8))",
            email: nil,
            displayName: nil,
            isAnonymous: true,
            isEmailVerified: false
        )
        setUser(user)
        return user
    }

    public func linkAnonymousWithEmail(email: String, password: String) async throws -> AuthUser {
        try await simulateDelay()
        if shouldFail { throw AppError.authEmailAlreadyInUse }
        let linked = AuthUser(
            uid: currentUser?.uid ?? "mock-linked-uid",
            email: email,
            displayName: currentUser?.displayName,
            isAnonymous: false,
            isEmailVerified: false
        )
        setUser(linked)
        return linked
    }

    public func signOut() throws {
        if shouldFail { throw AppError.authSignOutFailed }
        setUser(nil)
    }

    public func deleteAccount() async throws {
        try await simulateDelay()
        if shouldFail { throw AppError.authSignInFailed("mock delete fail") }
        setUser(nil)
    }

    @discardableResult
    public func addAuthStateListener(_ listener: @escaping @Sendable (AuthUser?) -> Void) -> Any {
        let id = UUID()
        lock.lock()
        listeners[id] = listener
        let snapshot = _currentUser
        lock.unlock()
        listener(snapshot)
        return id
    }

    public func removeAuthStateListener(_ handle: Any) {
        guard let id = handle as? UUID else { return }
        lock.lock()
        listeners.removeValue(forKey: id)
        lock.unlock()
    }

    // MARK: - Helpers

    private func setUser(_ user: AuthUser?) {
        lock.lock()
        _currentUser = user
        let callbacks = Array(listeners.values)
        lock.unlock()
        for listener in callbacks { listener(user) }
    }

    private func simulateDelay() async throws {
        if simulatedDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: simulatedDelayNanoseconds)
        }
    }
}

// MARK: InMemoryKeychainStore

public final class InMemoryKeychainStore: KeychainStoreProtocol, @unchecked Sendable {
    private var storage: [String: String] = [:]
    public init(seed: [String: String] = [:]) { self.storage = seed }
    public func read(service: String, account: String) -> String? {
        storage["\(service)|\(account)"]
    }
    @discardableResult
    public func write(_ value: String, service: String, account: String) -> Bool {
        storage["\(service)|\(account)"] = value
        return true
    }
    @discardableResult
    public func delete(service: String, account: String) -> Bool {
        storage.removeValue(forKey: "\(service)|\(account)") != nil
    }
}

// MARK: Preview Content Items

public extension ContentItem {
    static let previewItems: [ContentItem] = [
        ContentItem(id: "1", word: "рак", imageAsset: nil, audioAsset: nil, hint: nil, stage: .wordInit, difficulty: 1),
        ContentItem(id: "2", word: "рыба", imageAsset: nil, audioAsset: nil, hint: nil, stage: .wordInit, difficulty: 1),
        ContentItem(id: "3", word: "роза", imageAsset: nil, audioAsset: nil, hint: nil, stage: .wordInit, difficulty: 1),
        ContentItem(id: "4", word: "радуга", imageAsset: nil, audioAsset: nil, hint: nil, stage: .wordInit, difficulty: 2),
        ContentItem(id: "5", word: "ракета", imageAsset: nil, audioAsset: nil, hint: nil, stage: .wordInit, difficulty: 2),
        ContentItem(id: "6", word: "рот", imageAsset: nil, audioAsset: nil, hint: nil, stage: .wordInit, difficulty: 1),
        ContentItem(id: "7", word: "рис", imageAsset: nil, audioAsset: nil, hint: nil, stage: .wordInit, difficulty: 1),
        ContentItem(id: "8", word: "река", imageAsset: nil, audioAsset: nil, hint: nil, stage: .wordInit, difficulty: 2),
    ]
}
