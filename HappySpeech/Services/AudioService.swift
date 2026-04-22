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

public protocol AdaptivePlannerService: Sendable {
    func buildDailyRoute(for childId: String) async throws -> AdaptiveRoute
    func recordCompletion(sessionId: String, route: AdaptiveRoute) async throws
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

public protocol SyncService: Sendable {
    var pendingCount: Int { get }
    var isSyncing: Bool { get }
    func drainQueue() async throws
    func enqueue(operation: SyncOperation) async throws
}

public struct SyncOperation: Sendable {
    public let entityType: String
    public let entityId: String
    public let operation: String
    public let payload: String
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

public protocol NotificationService: Sendable {
    func scheduleDailyReminder(at hour: Int, minute: Int) async throws
    func cancelAllReminders() async
    func requestPermission() async -> Bool
}

// MARK: - HapticService Protocol

public protocol HapticService: Sendable {
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
