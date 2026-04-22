import Foundation
import AVFoundation
import UIKit
import OSLog
import UserNotifications

// MARK: - LiveAudioService
// AVAudioEngine is used on main thread — @unchecked Sendable.

public final class LiveAudioService: AudioService, @unchecked Sendable {

    nonisolated(unsafe) private let engine = AVAudioEngine()
    nonisolated(unsafe) private var audioFile: AVAudioFile?
    nonisolated(unsafe) private var recordingURL: URL?
    nonisolated(unsafe) private let playerNode = AVAudioPlayerNode()
    nonisolated(unsafe) private var _amplitude: Float = 0
    nonisolated(unsafe) private var _isRecording: Bool = false
    nonisolated(unsafe) private var amplitudeHistory: [Float] = Array(repeating: 0, count: 60)
    nonisolated(unsafe) private var historyIndex: Int = 0

    public var amplitude: Float { _amplitude }
    public var isRecording: Bool { _isRecording }

    public var isPermissionGranted: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    public func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    public func startRecording() async throws {
        guard isPermissionGranted else { throw AppError.audioPermissionDenied }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        recordingURL = url

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard let recordFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw AppError.audioFormatUnsupported
        }

        audioFile = try AVAudioFile(forWriting: url, settings: recordFormat.settings)

        let converter = AVAudioConverter(from: format, to: recordFormat)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self, let converter, let audioFile = self.audioFile else { return }

            let channelData = buffer.floatChannelData?[0]
            let frameCount = Int(buffer.frameLength)
            if let data = channelData {
                let amp = (0..<frameCount).map { abs(data[$0]) }.max() ?? 0
                self._amplitude = amp
                self.amplitudeHistory[self.historyIndex % 60] = amp
                self.historyIndex += 1
            }

            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: recordFormat,
                frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * (16000.0 / format.sampleRate))
            ) else { return }

            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, status in
                status.pointee = .haveData
                return buffer
            }

            try? audioFile.write(from: convertedBuffer)
        }

        try engine.start()
        _isRecording = true
        HSLogger.audio.info("Recording started at 16kHz mono")
    }

    public func stopRecording() async throws -> URL {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil
        _isRecording = false
        _amplitude = 0
        guard let url = recordingURL else {
            throw AppError.audioRecordingFailed("Recording URL missing")
        }
        HSLogger.audio.info("Recording stopped: \(url.lastPathComponent)")
        return url
    }

    public func playAudio(url: URL) async throws {
        let file = try AVAudioFile(forReading: url)
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: file.processingFormat)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            playerNode.scheduleFile(file, at: nil) {
                continuation.resume()
            }
        }
        try engine.start()
        playerNode.play()
    }

    public func stopPlayback() {
        playerNode.stop()
    }

    public func amplitudeBuffer() -> [Float] {
        var result = Array(amplitudeHistory[historyIndex % 60 ..< 60])
        result += Array(amplitudeHistory[0 ..< historyIndex % 60])
        return result
    }
}

// MARK: - LiveHapticService

public final class LiveHapticService: HapticService, @unchecked Sendable {
    public func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        DispatchQueue.main.async {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }

    public func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        DispatchQueue.main.async {
            UINotificationFeedbackGenerator().notificationOccurred(type)
        }
    }

    public func selection() {
        DispatchQueue.main.async {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

// MARK: - LiveNotificationService

public final class LiveNotificationService: NotificationService, @unchecked Sendable {
    nonisolated(unsafe) private let center = UNUserNotificationCenter.current()

    public func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            HSLogger.app.error("Notification permission error: \(error)")
            return false
        }
    }

    public func scheduleDailyReminder(at hour: Int, minute: Int) async throws {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Время заниматься!")
        content.body = String(localized: "Ляля ждёт тебя для новых упражнений")
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "hs.daily.reminder",
            content: content,
            trigger: trigger
        )
        try await center.add(request)
        HSLogger.app.info("Daily reminder scheduled at \(hour):\(String(format: "%02d", minute))")
    }

    public func cancelAllReminders() async {
        center.removePendingNotificationRequests(withIdentifiers: ["hs.daily.reminder"])
    }
}

// MARK: - LocalAnalyticsService

public final class LocalAnalyticsService: AnalyticsService, @unchecked Sendable {
    nonisolated(unsafe) private var events: [AnalyticsEvent] = []
    private let maxEvents = 1000

    public func track(event: AnalyticsEvent) {
        if events.count >= maxEvents { events.removeFirst() }
        events.append(event)
        HSLogger.analytics.debug("Event: \(event.name) \(event.parameters)")
    }
}

// MARK: - LiveLocalLLMService

public final class LiveLocalLLMService: LocalLLMService, @unchecked Sendable {
    nonisolated(unsafe) public var isModelDownloaded: Bool = false
    nonisolated(unsafe) public var isModelLoaded: Bool = false

    public func downloadModel() async throws {
        HSLogger.llm.info("Qwen2.5-1.5B download — Sprint 11")
    }

    public func generateParentSummary(request: ParentSummaryRequest) async throws -> ParentSummaryResponse {
        throw AppError.llmNotDownloaded
    }

    public func generateRoute(request: RoutePlannerRequest) async throws -> RoutePlannerResponse {
        throw AppError.llmNotDownloaded
    }

    public func generateMicroStory(request: MicroStoryRequest) async throws -> MicroStoryResponse {
        throw AppError.llmNotDownloaded
    }
}

// MARK: - LiveARService

public final class LiveARService: ARService {
    public var isSupported: Bool { true }

    public var isCameraPermissionGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    public func requestCameraPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}

// MARK: - LiveContentService

/// Loads content packs from the bundled `Content/Seed/*.json` resources.
public final class LiveContentService: ContentService, @unchecked Sendable {

    private let decoder: JSONDecoder

    public init() {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        self.decoder = decoder
    }

    public func loadPack(id: String) async throws -> ContentPack {
        // Pack id format: "sound-<letter>-<stage>-<template>-v1" or "sound_<letter>_v1" for bundled file name.
        // Strategy: map to bundled file "sound_<letter>_pack" and filter by stage+template inside ContentEngine.
        let soundLetter = Self.extractSoundLetter(from: id)
        let fileName = "sound_\(soundLetter)_pack"
        guard let url = Self.resolveResourceURL(fileName: fileName, ext: "json") else {
            HSLogger.content.error("Pack resource missing: \(fileName).json")
            throw AppError.contentPackNotFound(id)
        }
        do {
            let data = try Data(contentsOf: url)
            let raw = try decoder.decode(RawContentPack.self, from: data)
            return raw.toContentPack(requestedID: id)
        } catch let error as AppError {
            throw error
        } catch {
            HSLogger.content.error("Pack decode failed for \(id): \(error)")
            throw AppError.contentPackNotFound(id)
        }
    }

    public func allPacks() async throws -> [ContentPackMeta] {
        bundledPacks()
    }

    public func bundledPacks() -> [ContentPackMeta] {
        ["s", "sh", "r", "l", "k"].compactMap { letter -> ContentPackMeta? in
            guard let url = Self.resolveResourceURL(fileName: "sound_\(letter)_pack", ext: "json") else { return nil }
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            return ContentPackMeta(
                id: "sound_\(letter)_v1",
                soundTarget: letter.uppercased(),
                stage: CorrectionStage.wordInit.rawValue,
                templateType: TemplateType.listenAndChoose.rawValue,
                version: "1",
                isDownloaded: true,
                isBundled: true,
                storageUrl: url.absoluteString,
                sizeBytes: size
            )
        }
    }

    // MARK: - Private

    private static func extractSoundLetter(from id: String) -> String {
        // Accepts "С-wordInit-listen-and-choose-v1" or "sound_s_v1".
        if id.hasPrefix("sound_") {
            let parts = id.split(separator: "_")
            return parts.count >= 2 ? String(parts[1]) : "s"
        }
        guard let first = id.split(separator: "-").first else { return "s" }
        return romanize(first)
    }

    private static func romanize(_ cyrillic: Substring) -> String {
        switch cyrillic.lowercased() {
        case "с": return "s"
        case "ш": return "sh"
        case "р": return "r"
        case "л": return "l"
        case "к": return "k"
        case "з": return "z"
        case "ц": return "ts"
        case "ж": return "zh"
        case "ч": return "ch"
        case "щ": return "sch"
        case "г": return "g"
        case "х": return "h"
        default: return String(cyrillic)
        }
    }

    private static func resolveResourceURL(fileName: String, ext: String) -> URL? {
        // Try several likely subpaths — we ship seed packs inside the source tree, they may end up flat in the bundle.
        let bundle = Bundle.main
        if let url = bundle.url(forResource: fileName, withExtension: ext) { return url }
        if let url = bundle.url(forResource: fileName, withExtension: ext, subdirectory: "Content/Seed") { return url }
        if let url = bundle.url(forResource: fileName, withExtension: ext, subdirectory: "Seed") { return url }
        return nil
    }
}

// MARK: - RawContentPack (decoding helper for JSON seed files)

private struct RawContentPack: Decodable {
    let id: String
    let soundTarget: String
    let group: String
    let version: Int
    let stages: [String: RawStage]

    func toContentPack(requestedID: String) -> ContentPack {
        // Pick stage items — flatten all stages, preserving stage info.
        let allItems: [ContentItem] = stages.flatMap { (stageKey, rawStage) -> [ContentItem] in
            let stageEnum = CorrectionStage(rawValue: stageKey) ?? .isolated
            return rawStage.items.map { raw in
                ContentItem(
                    id: raw.id,
                    word: raw.word,
                    imageAsset: raw.imageAsset,
                    audioAsset: raw.audioAsset,
                    hint: raw.hint,
                    stage: stageEnum,
                    difficulty: raw.difficulty
                )
            }
        }
        // Deterministic template/stage inference from requestedID if parsable, fallback otherwise.
        let (stage, template) = Self.parseStageTemplate(from: requestedID)
        return ContentPack(
            id: id,
            soundTarget: soundTarget,
            stage: stage,
            templateType: template,
            items: allItems.filter { $0.stage == stage || stage == .isolated }
        )
    }

    private static func parseStageTemplate(from id: String) -> (CorrectionStage, TemplateType) {
        let parts = id.split(separator: "-")
        guard parts.count >= 3 else { return (.isolated, .listenAndChoose) }
        let stage = CorrectionStage(rawValue: String(parts[1])) ?? .isolated
        let template = TemplateType(rawValue: String(parts[2])) ?? .listenAndChoose
        return (stage, template)
    }
}

private struct RawStage: Decodable {
    let stageId: String
    let note: String?
    let items: [RawItem]
}

private struct RawItem: Decodable {
    let id: String
    let word: String
    let imageAsset: String?
    let audioAsset: String?
    let hint: String?
    let difficulty: Int
}

// MARK: - LiveAdaptivePlannerService

/// Rule-based adaptive planner: returns a 3–5 step daily route derived from
/// (soundTarget × stage × fatigueLevel). Deterministic — stable across app launches.
public final class LiveAdaptivePlannerService: AdaptivePlannerService, @unchecked Sendable {

    public init() {}

    public func buildDailyRoute(for childId: String) async throws -> AdaptiveRoute {
        // In production the planner reads the child profile from repository.
        // For now we return a conservative default route for sound [С], stage wordInit, fatigue fresh.
        let fatigue: FatigueLevel = .fresh
        let steps = Self.composeRoute(soundTarget: "С", stage: .wordInit, fatigue: fatigue)
        let total = steps.reduce(0) { $0 + $1.durationTargetSec }
        HSLogger.app.info("AdaptiveRoute childId=\(childId, privacy: .private) steps=\(steps.count) total=\(total)s")
        return AdaptiveRoute(steps: steps, maxDurationSec: min(total, 600), fatigueLevel: fatigue)
    }

    public func recordCompletion(sessionId: String, route: AdaptiveRoute) async throws {
        HSLogger.app.info("Route completed session=\(sessionId, privacy: .private) steps=\(route.steps.count)")
    }

    // MARK: - Rule-based matrix

    /// Core decision matrix: produces a 3–5 step sequence for a daily session.
    /// Principles:
    /// - Start gentle (warm-up or low-cognitive template).
    /// - Core drill uses the template most suited for the stage.
    /// - If fatigue is high, prefer puzzle-reveal / breathing near the end.
    /// - Always cap at ~10 minutes total.
    public static func composeRoute(
        soundTarget: String,
        stage: CorrectionStage,
        fatigue: FatigueLevel
    ) -> [RouteStepItem] {
        let difficulty: Int = {
            switch stage {
            case .prep, .isolated: return 1
            case .syllable, .wordInit: return 2
            case .wordMed, .wordFinal, .phrase: return 3
            case .sentence, .story, .diff: return 4
            }
        }()

        let warmUp = RouteStepItem(
            templateType: .breathing,
            targetSound: soundTarget,
            stage: .prep,
            difficulty: 1,
            wordCount: 1,
            durationTargetSec: 90
        )

        let coreTemplate: TemplateType = primaryTemplate(for: stage)
        let core = RouteStepItem(
            templateType: coreTemplate,
            targetSound: soundTarget,
            stage: stage,
            difficulty: difficulty,
            wordCount: stage >= .wordInit ? 8 : 6,
            durationTargetSec: fatigue == .tired ? 150 : 210
        )

        let consolidation = RouteStepItem(
            templateType: consolidationTemplate(for: stage, fatigue: fatigue),
            targetSound: soundTarget,
            stage: stage,
            difficulty: max(1, difficulty - 1),
            wordCount: 6,
            durationTargetSec: 120
        )

        let reward = RouteStepItem(
            templateType: .puzzleReveal,
            targetSound: soundTarget,
            stage: stage,
            difficulty: 1,
            wordCount: 4,
            durationTargetSec: 90
        )

        switch fatigue {
        case .fresh:
            return [warmUp, core, consolidation, reward]
        case .normal:
            return [warmUp, core, reward]
        case .tired:
            return [warmUp, reward]
        }
    }

    private static func primaryTemplate(for stage: CorrectionStage) -> TemplateType {
        switch stage {
        case .prep: return .articulationImitation
        case .isolated: return .repeatAfterModel
        case .syllable: return .repeatAfterModel
        case .wordInit, .wordMed, .wordFinal: return .listenAndChoose
        case .phrase: return .storyCompletion
        case .sentence: return .storyCompletion
        case .story: return .narrativeQuest
        case .diff: return .minimalPairs
        }
    }

    private static func consolidationTemplate(for stage: CorrectionStage, fatigue: FatigueLevel) -> TemplateType {
        if fatigue == .tired { return .puzzleReveal }
        switch stage {
        case .prep: return .breathing
        case .isolated: return .sorting
        case .syllable: return .bingo
        case .wordInit, .wordMed, .wordFinal: return .dragAndMatch
        case .phrase, .sentence: return .sorting
        case .story: return .storyCompletion
        case .diff: return .memory
        }
    }
}
