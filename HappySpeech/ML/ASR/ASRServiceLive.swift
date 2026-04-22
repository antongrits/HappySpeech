import Foundation
import WhisperKit
import OSLog

// MARK: - LiveASRService

/// WhisperKit-based ASR service. Downloads tiny model on first load.
/// Transcribes 16kHz mono WAV/M4A to Russian text.
public final class LiveASRService: ASRService, @unchecked Sendable {

    nonisolated(unsafe) private var whisper: WhisperKit?
    nonisolated(unsafe) private var _isReady: Bool = false

    public var isReady: Bool { _isReady }

    public init() {}

    public func loadModel() async throws {
        HSLogger.asr.info("Loading WhisperKit model...")
        let kit = try await WhisperKit(model: "openai/whisper-tiny", verbose: false)
        whisper = kit
        _isReady = true
        HSLogger.asr.info("WhisperKit ready")
    }

    public func transcribe(url: URL) async throws -> ASRResult {
        guard let whisper, _isReady else {
            throw AppError.asrModelNotLoaded
        }
        let options = DecodingOptions(
            task: .transcribe,
            language: "ru",
            temperatureFallbackCount: 2
        )
        let results = try await whisper.transcribe(audioPath: url.path, decodeOptions: options)
        let texts = results.compactMap { $0.text }
        let text = texts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        let confidence: Double
        if let firstSegment = results.first?.segments.first {
            confidence = min(1.0, exp(Double(firstSegment.avgLogprob)))
        } else {
            confidence = 0.8
        }
        let timestamps: [ASRResult.WordTimestamp] = results.first?.segments.flatMap { seg -> [ASRResult.WordTimestamp] in
            guard let words = seg.words else { return [] }
            return words.map { w in
                ASRResult.WordTimestamp(
                    word: w.word,
                    startTime: Double(w.start),
                    endTime: Double(w.end)
                )
            }
        } ?? []
        return ASRResult(transcript: text, confidence: confidence, wordTimestamps: timestamps)
    }
}
