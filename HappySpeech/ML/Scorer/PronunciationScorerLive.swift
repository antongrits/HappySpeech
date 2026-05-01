import Accelerate
import AVFoundation
import CoreML
import Foundation
import OSLog

// MARK: - LivePronunciationScorerService

/// On-device pronunciation scorer using a CoreML model (.mlpackage).
/// Falls back to acoustic energy heuristic when model is not available.
///
/// Block G v13: MFCC extraction заменён с energy-stub на `RealMFCCExtractor`
/// (vDSP FFT + Mel filterbank + DCT-II + delta + delta-delta, 39-мерный вектор).
public final class LivePronunciationScorerService: PronunciationScorerService, @unchecked Sendable {

    nonisolated(unsafe) private var mlModel: MLModel?
    nonisolated(unsafe) private var _isModelLoaded: Bool = false
    private let mfccExtractor = RealMFCCExtractor()

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
            return try await scoreWithModel(model: model, audioURL: audioURL, targetSound: targetSound)
        } else {
            return await heuristicScore(audioURL: audioURL, targetSound: targetSound)
        }
    }

    // MARK: - Private: ML Inference

    private func scoreWithModel(model: MLModel, audioURL: URL, targetSound: String) async throws -> PronunciationScore {
        let mfccData = try loadAudioData(from: audioURL)
        let frames = try await mfccExtractor.extract(from: mfccData)
        let flatFeatures = try framesToMLMultiArray(frames)
        let input = try MLDictionaryFeatureProvider(dictionary: [
            "mfcc_features": flatFeatures,
            "target_sound": targetSound as NSString
        ])
        let output = try await model.prediction(from: input)
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
            let normalizedScore = min(1.0, Double(rms) * 8.0)
            return PronunciationScore(rawValue: normalizedScore)
        } catch {
            return PronunciationScore(rawValue: 0.5)
        }
    }

    // MARK: - Private: Audio Loading

    /// Загружает аудио файл как сырой Float32 PCM Data для RealMFCCExtractor.
    private func loadAudioData(from url: URL) throws -> Data {
        let audioFile = try AVAudioFile(forReading: url)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: AVAudioFrameCount(audioFile.length)
        ) else { throw AppError.audioFormatUnsupported }
        try audioFile.read(into: buffer)
        guard let channelData = buffer.floatChannelData?[0] else {
            throw AppError.audioFormatUnsupported
        }
        let length = Int(buffer.frameLength)
        return Data(bytes: channelData, count: length * MemoryLayout<Float>.size)
    }

    /// Упаковывает [[Float]] фреймы в плоский MLMultiArray [nFrames * nCoeffs].
    private func framesToMLMultiArray(_ frames: [[Float]]) throws -> MLMultiArray {
        let nFrames = frames.count
        let nCoeffs = frames.first?.count ?? 0
        let total = nFrames * nCoeffs
        let array = try MLMultiArray(shape: [NSNumber(value: total)], dataType: .float32)
        for (t, frame) in frames.enumerated() {
            for (c, val) in frame.enumerated() {
                array[t * nCoeffs + c] = NSNumber(value: val)
            }
        }
        return array
    }
}
