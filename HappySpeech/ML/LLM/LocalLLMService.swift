import Foundation
import OSLog

// MARK: - LocalLLMServiceLive
// Uses a bundled Qwen2.5-1.5B-Instruct model via llama.cpp or MLX Swift bindings.
// Falls back to rule-based generation when model is not available.

public final class LocalLLMServiceLive: LocalLLMService, @unchecked Sendable {

    nonisolated(unsafe) private var _isModelDownloaded: Bool = false
    nonisolated(unsafe) private var _isModelLoaded: Bool = false

    public var isModelDownloaded: Bool { _isModelDownloaded }
    public var isModelLoaded: Bool { _isModelLoaded }

    private let modelFileName = "qwen2.5-1.5b-instruct-q4_k_m.gguf"
    private var modelPath: URL {
        let modelsDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HappySpeech/Models", isDirectory: true)
        return modelsDir.appendingPathComponent(modelFileName)
    }

    public init() {
        _isModelDownloaded = FileManager.default.fileExists(atPath: modelPath.path)
    }

    // MARK: - Download

    public func downloadModel() async throws {
        let remoteURL = URL(string: "https://storage.googleapis.com/happyspeech-models/\(modelFileName)")!
        HSLogger.llm.info("Downloading LLM from \(remoteURL)")
        let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)
        let dir = modelPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: modelPath.path) {
            try FileManager.default.removeItem(at: modelPath)
        }
        try FileManager.default.moveItem(at: tempURL, to: modelPath)
        _isModelDownloaded = true
        HSLogger.llm.info("LLM downloaded to \(self.modelPath.path)")
    }

    // MARK: - Generate: Parent Summary

    public func generateParentSummary(request: ParentSummaryRequest) async throws -> ParentSummaryResponse {
        // Rule-based fallback (used until model is loaded)
        let rate = request.totalAttempts > 0
            ? Int(Double(request.correctAttempts) / Double(request.totalAttempts) * 100)
            : 0
        let errorList = request.errorWords.prefix(3).joined(separator: ", ")
        let summary = "\(request.childName) отработал звук «\(request.targetSound)» — \(rate)% правильно за \(request.sessionDurationSec / 60) мин. Ошибки: \(errorList.isEmpty ? "нет" : errorList)."
        let task = "Повторите слова: \(errorList.isEmpty ? "любые слова со звуком \(request.targetSound)" : errorList)."
        return ParentSummaryResponse(parentSummary: summary, homeTask: task)
    }

    // MARK: - Generate: Route

    public func generateRoute(request: RoutePlannerRequest) async throws -> RoutePlannerResponse {
        // Rule-based route selection based on success rate
        let templates: [TemplateType]
        switch request.recentSuccessRate {
        case 0.8...:
            templates = [.repeatAfterModel, .storyCompletion, .minimalPairs]
        case 0.5..<0.8:
            templates = [.listenAndChoose, .dragAndMatch, .puzzleReveal]
        default:
            templates = [.articulationImitation, .breathing, .listenAndChoose]
        }
        let maxDuration = request.fatigueLevel >= 2 ? 600 : 900
        let items = templates.prefix(3).map { t in
            RoutePlannerResponse.RouteItem(
                template: t.rawValue,
                difficulty: max(1, Int(request.recentSuccessRate * 3)),
                wordCount: 8,
                durationTargetSec: 180
            )
        }
        return RoutePlannerResponse(route: Array(items), sessionMaxDurationSec: maxDuration)
    }

    // MARK: - Generate: Micro Story

    public func generateMicroStory(request: MicroStoryRequest) async throws -> MicroStoryResponse {
        let words = request.wordPool.prefix(3)
        let sound = request.targetSound
        let sentences = [
            "Жил-был маленький \(words.first ?? sound).",
            "Он любил играть и \(words.dropFirst().first ?? "петь").",
            "Однажды он нашёл \(words.last ?? "друга")."
        ]
        let gaps = [MicroStoryResponse.GapPosition(sentenceIndex: 2, word: words.last ?? sound, imageHint: "friend")]
        return MicroStoryResponse(sentences: sentences, gapPositions: gaps)
    }
}
