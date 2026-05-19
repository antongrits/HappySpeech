@preconcurrency import CoreML
import Foundation
import os.signpost
import OSLog

// MARK: - RussianPhonemeClassifierWrapper

/// Обёртка над CoreML моделью `RussianPhonemeClassifier.mlpackage`.
///
/// **Модель:** v30 — 49 IPA фонем, Conv1d-BiLSTM (780K params), 2.75 MB,
/// held-out test accuracy 97.0% (per-frame, synthetic dataset).
/// **Вход:** `mfcc [1, 39, 150]` — 39 MFCC коэффициентов, 150 фреймов (1.5 сек при 16kHz).
/// **Выход:** `phoneme_logits [1, 150, 49]` — логиты для 49 фонем на каждом фрейме.
///
/// **ADR-V13-PHONEME-CLASSIFIER-PARTIAL:** confidence threshold logit > 2.0.
/// При низкой уверенности PhonemeAnalysisServiceLive использует G2P dictionary.
///
/// ## See Also
/// - ``PhonemeAnalysisService``
/// - ``RussianPhonemeInventory``
public actor RussianPhonemeClassifierWrapper {

    private let logger = Logger(subsystem: "HappySpeech", category: "PhonemeClassifier")

    /// CoreML модель (nil если не удалось загрузить).
    private let model: MLModel?

    /// Имя входного тензора модели.
    private static let inputName = "mfcc"
    /// Имя выходного тензора модели.
    private static let outputName = "phoneme_logits"
    /// Количество MFCC коэффициентов (соответствует модели).
    public static let nMFCC = 39
    /// Количество временных фреймов.
    public static let nFrames = 150
    /// Количество фонемных классов.
    public static let nClasses = 49
    /// Confidence threshold (logit > 2.0 → high confidence, per ADR-V13-PHONEME-CLASSIFIER-PARTIAL).
    public static let confidenceLogitThreshold: Float = 2.0

    // MARK: - Init

    /// Загружает модель `RussianPhonemeClassifier.mlpackage` из Bundle.
    /// - Throws: ``PhonemeAnalysisError/modelNotLoaded`` если mlpackage не найден
    public init() throws {
        guard let modelURL = Bundle.main.url(
            forResource: "RussianPhonemeClassifier",
            withExtension: "mlpackage"
        ) else {
            throw PhonemeAnalysisError.modelNotLoaded
        }

        let config = MLModelConfiguration()
        config.computeUnits = .all

        do {
            self.model = try MLModel(contentsOf: modelURL, configuration: config)
        } catch {
            throw PhonemeAnalysisError.predictionFailed("Ошибка загрузки модели: \(error.localizedDescription)")
        }
    }

    /// Инициализирует обёртку без модели (для mock/тестов).
    public init(mockMode: Bool) {
        self.model = nil
    }

    // MARK: - Prediction

    /// Запускает инференс модели на MFCC фреймах.
    /// - Parameter mfcc: массив фреймов [[Float]], каждый — вектор 39 коэффициентов
    /// - Returns: массив ``PhonemeAlignment`` — предсказание для каждого фрейма
    /// - Throws: ``PhonemeAnalysisError`` при ошибке модели
    public func predict(mfcc: [[Float]]) async throws -> [PhonemeAlignment] {
        guard let model else {
            throw PhonemeAnalysisError.modelNotLoaded
        }

        // Plan v22 Block 1.4 — Points of Interest signpost для Instruments.
        os_signpost(.begin, log: HSSignpost.pointsOfInterest, name: "PhonemeInference")
        defer { os_signpost(.end, log: HSSignpost.pointsOfInterest, name: "PhonemeInference") }

        // Pad/truncate до 150 фреймов
        let paddedFrames = padOrTruncate(mfcc, target: Self.nFrames)

        // Преобразуем в MLMultiArray shape [1, 39, 150]
        let inputArray = try mfccToMLMultiArray(paddedFrames)
        let inputFeatures = try MLDictionaryFeatureProvider(
            dictionary: [Self.inputName: inputArray]
        )

        // Инференс
        let output = try await model.prediction(from: inputFeatures)

        // Извлекаем логиты [1, 150, 49]
        guard let logitsFeature = output.featureValue(for: Self.outputName),
              let logitsArray = logitsFeature.multiArrayValue else {
            throw PhonemeAnalysisError.predictionFailed("Отсутствует выходная фича '\(Self.outputName)'")
        }

        return extractAlignments(from: logitsArray)
    }

    // MARK: - Private helpers

    /// Дополняет нулями или обрезает массив фреймов до нужного размера.
    private func padOrTruncate(_ frames: [[Float]], target: Int) -> [[Float]] {
        if frames.count >= target {
            return Array(frames.prefix(target))
        }
        let zeroPad = Array(
            repeating: Array(repeating: Float(0), count: Self.nMFCC),
            count: target - frames.count
        )
        return frames + zeroPad
    }

    /// Конвертирует массив MFCC фреймов в MLMultiArray shape [1, nMFCC, nFrames].
    private func mfccToMLMultiArray(_ frames: [[Float]]) throws -> MLMultiArray {
        let array = try MLMultiArray(
            shape: [1, NSNumber(value: Self.nMFCC), NSNumber(value: Self.nFrames)],
            dataType: .float32
        )

        for frameIdx in 0 ..< Self.nFrames {
            let frame = frameIdx < frames.count ? frames[frameIdx] : Array(repeating: 0.0, count: Self.nMFCC)
            for coeffIdx in 0 ..< Self.nMFCC {
                let value = coeffIdx < frame.count ? frame[coeffIdx] : Float(0)
                array[[0, coeffIdx, frameIdx] as [NSNumber]] = NSNumber(value: value)
            }
        }

        return array
    }

    /// Извлекает предсказанные фонемы из тензора логитов [1, 150, 49].
    /// Для каждого фрейма: argmax → IPA символ + softmax confidence.
    private func extractAlignments(from logits: MLMultiArray) -> [PhonemeAlignment] {
        var alignments: [PhonemeAlignment] = []
        alignments.reserveCapacity(Self.nFrames)

        for frameIdx in 0 ..< Self.nFrames {
            // Собираем логиты для текущего фрейма
            var frameLogits = [Float](repeating: 0, count: Self.nClasses)
            for classIdx in 0 ..< Self.nClasses {
                frameLogits[classIdx] = logits[[0, frameIdx, classIdx] as [NSNumber]].floatValue
            }

            // Argmax
            let maxVal = frameLogits.max() ?? 0
            let argmax = frameLogits.firstIndex(of: maxVal) ?? 0

            // Softmax (numerically stable)
            let expValues = frameLogits.map { expf($0 - maxVal) }
            let sumExp = expValues.reduce(0, +)
            let softmaxMax = sumExp > 0 ? Double(expValues[argmax] / sumExp) : 0.0

            let predictedIPA = RussianPhonemeInventory.phoneme(at: argmax) ?? "?"
            alignments.append(PhonemeAlignment(
                frameIndex: frameIdx,
                predictedIPA: predictedIPA,
                confidence: softmaxMax
            ))
        }

        return alignments
    }
}
