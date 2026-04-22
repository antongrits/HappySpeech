import Foundation
import CoreML
import AVFoundation
import Accelerate
import OSLog

// MARK: - LivePronunciationScorerService

/// On-device pronunciation scorer using a CoreML model (.mlpackage).
/// Falls back to acoustic energy heuristic when model is not available.
public final class LivePronunciationScorerService: PronunciationScorerService, @unchecked Sendable {

    nonisolated(unsafe) private var mlModel: MLModel?
    nonisolated(unsafe) private var _isModelLoaded: Bool = false

    public var isModelLoaded: Bool { _isModelLoaded }

    public init() {}

    // MARK: - Load Model

    public func loadModel() async throws {
        let modelURL = Bundle.main.url(
            forResource: "PronunciationScorer",
            withExtension: "mlmodelc"
        ) ?? Bundle.main.url(
            forResource: "PronunciationScorer",
            withExtension: "mlpackage"
        )
        guard let url = modelURL else {
            HSLogger.ml.warning("PronunciationScorer model not found — using heuristic fallback")
            _isModelLoaded = false
            return
        }
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        let model = try MLModel(contentsOf: url, configuration: config)
        mlModel = model
        _isModelLoaded = true
        HSLogger.ml.info("PronunciationScorer loaded from \(url.lastPathComponent)")
    }

    // MARK: - Score

    public func score(audioURL: URL, targetSound: String) async throws -> PronunciationScore {
        if let model = mlModel {
            return try scoreWithModel(model: model, audioURL: audioURL, targetSound: targetSound)
        } else {
            return await heuristicScore(audioURL: audioURL, targetSound: targetSound)
        }
    }

    // MARK: - Private: ML Inference (synchronous — CoreML prediction is synchronous)

    private func scoreWithModel(model: MLModel, audioURL: URL, targetSound: String) throws -> PronunciationScore {
        let features = try extractMFCC(from: audioURL)
        let input = try MLDictionaryFeatureProvider(dictionary: [
            "mfcc_features": MLMultiArray(features),
            "target_sound": targetSound as NSString
        ])
        let output = try model.prediction(from: input)
        let scoreValue = output.featureValue(for: "pronunciation_score")?.doubleValue ?? 0.5
        return PronunciationScore(rawValue: max(0, min(1, scoreValue)))
    }

    // MARK: - Private: Heuristic Fallback

    private func heuristicScore(audioURL: URL, targetSound: String) async -> PronunciationScore {
        do {
            let audioFile = try AVAudioFile(forReading: audioURL)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                                frameCapacity: AVAudioFrameCount(audioFile.length)) else {
                return PronunciationScore(rawValue: 0.5)
            }
            try audioFile.read(into: buffer)
            guard let channelData = buffer.floatChannelData?[0] else {
                return PronunciationScore(rawValue: 0.5)
            }
            let frameCount = Int(buffer.frameLength)
            var rms: Float = 0
            vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameCount))
            // Normalize: typical child speech RMS ~0.05–0.2
            let normalizedScore = min(1.0, Double(rms) * 8.0)
            return PronunciationScore(rawValue: normalizedScore)
        } catch {
            return PronunciationScore(rawValue: 0.5)
        }
    }

    // MARK: - Private: MFCC Extraction

    private func extractMFCC(from url: URL) throws -> [Float] {
        let audioFile = try AVAudioFile(forReading: url)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: AVAudioFrameCount(audioFile.length)
        ) else { throw AppError.audioFormatUnsupported }
        try audioFile.read(into: buffer)
        guard let data = buffer.floatChannelData?[0] else {
            throw AppError.audioFormatUnsupported
        }
        let length = Int(buffer.frameLength)
        // Simple energy-based features (40 bins) as placeholder for real MFCC
        let binSize = max(1, length / 40)
        var features: [Float] = []
        for i in 0..<40 {
            let start = i * binSize
            let end = min(start + binSize, length)
            if start >= end { features.append(0); continue }
            var rms: Float = 0
            vDSP_rmsqv(data + start, 1, &rms, vDSP_Length(end - start))
            features.append(rms)
        }
        return features
    }
}
