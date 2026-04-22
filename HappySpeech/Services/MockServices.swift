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

public final class MockSyncService: SyncService, @unchecked Sendable {
    public var pendingCount: Int = 0
    public var isSyncing: Bool = false

    public func drainQueue() async throws {}
    public func enqueue(operation: SyncOperation) async throws { pendingCount += 1 }
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
    public func buildDailyRoute(for childId: String) async throws -> AdaptiveRoute {
        AdaptiveRoute(
            steps: [
                RouteStepItem(templateType: .listenAndChoose, targetSound: "Р",
                              stage: .wordInit, difficulty: 2, wordCount: 10, durationTargetSec: 180),
                RouteStepItem(templateType: .repeatAfterModel, targetSound: "Р",
                              stage: .wordInit, difficulty: 2, wordCount: 8, durationTargetSec: 240)
            ],
            maxDurationSec: 600,
            fatigueLevel: .fresh
        )
    }

    public func recordCompletion(sessionId: String, route: AdaptiveRoute) async throws {}
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
