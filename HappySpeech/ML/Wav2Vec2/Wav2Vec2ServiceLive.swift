import Accelerate
import AVFoundation
@preconcurrency import CoreML
import Foundation
import os.signpost
import OSLog

// MARK: - Wav2Vec2ServiceLive

/// Живая реализация Wav2Vec2 CTC сервиса через ``Wav2Vec2RuChild.mlpackage``.
///
/// ## Pipeline инференса:
/// 1. Принять Data (сырые Float32 @ 16 kHz mono).
/// 2. Нормализовать длину: pad/trim до `fixedSamples` (48 000 = 3 сек).
/// 3. Peak-нормализация до 0 dBFS.
/// 4. Инференс CoreML → logits `[1, T, 37]`.
/// 5. CTC greedy decode → ``CTCDecodeResult``.
///
/// ## Ограничения v13:
/// - Фиксированный вход 48 000 сэмплов (3 сек). Более короткие паддятся, длинные обрезаются.
/// - Монофоническое аудио 16 kHz Float32. Для других форматов нужна конвертация в `AudioService`.
/// - Модель ~302 MB — загружается при первом вызове `transcribe`, а не при `init`.
///
/// ## Производительность (цель):
/// - iPhone 17 Pro (A19): < 200 ms
/// - iPhone SE 3 (A15): < 500 ms
/// - Memory peak: < 100 MB
public actor Wav2Vec2ServiceLive: Wav2Vec2Service {

    // MARK: - Constants

    private static let fixedSamples = 48_000
    private static let sampleRate: Double = 16_000
    private static let modelName = "Wav2Vec2RuChild"

    // MARK: - Private

    private let logger = Logger(subsystem: "HappySpeech", category: "Wav2Vec2Service")
    private var model: MLModel?
    private var isLoaded = false

    // MARK: - Init

    /// Инициализирует сервис. Модель загружается лениво при первом вызове ``transcribe(audio:)``.
    public init() {}

    // MARK: - Wav2Vec2Service

    public func transcribe(audio: Data) async throws -> CTCDecodeResult {
        // Plan v22 Block 1.4 — Points of Interest signpost для Instruments.
        os_signpost(.begin, log: HSSignpost.pointsOfInterest, name: "Wav2Vec2Inference")
        defer { os_signpost(.end, log: HSSignpost.pointsOfInterest, name: "Wav2Vec2Inference") }

        let logitsArray = try await runInference(audio: audio)

        // CTC decode
        let result = CTCDecoder.decode(logitsArray: logitsArray)
        logger.debug("Wav2Vec2: декодировано '\(result.decodedText)' (avgConf=\(String(format: "%.2f", result.averageConfidence)))")

        return result
    }

    public func logits(audio: Data) async throws -> [[Float]] {
        os_signpost(.begin, log: HSSignpost.pointsOfInterest, name: "Wav2Vec2Logits")
        defer { os_signpost(.end, log: HSSignpost.pointsOfInterest, name: "Wav2Vec2Logits") }

        let logitsArray = try await runInference(audio: audio)
        return Self.multiArrayToMatrix(logitsArray)
    }

    // MARK: - Inference (общая часть transcribe / logits)

    /// Прогоняет общий инференс модели и возвращает сырой `MLMultiArray` логитов
    /// формы `[1, T, 37]`. Переиспользуется и ``transcribe(audio:)``, и
    /// ``logits(audio:)`` — модель загружается один раз, без дублирования.
    private func runInference(audio: Data) async throws -> MLMultiArray {
        let model = try loadModelIfNeeded()

        // 1. Data -> [Float]
        let samples = try convertToSamples(data: audio)

        // 2. Normalize length (pad / trim) to fixedSamples
        let normalized = normalizeSampleLength(samples)

        // 3. Peak normalization
        let peaked = peakNormalize(normalized)

        // 4. CoreML input
        let mlArray = try makeMlArray(from: peaked)

        // 5. Predict
        let input = try MLDictionaryFeatureProvider(dictionary: ["audio": mlArray])
        let output: MLFeatureProvider
        do {
            output = try await model.prediction(from: input)
        } catch {
            throw Wav2Vec2Error.predictionFailed(error.localizedDescription)
        }

        // 6. Extract logits
        guard let logitsValue = output.featureValue(for: "logits"),
              let logitsArray = logitsValue.multiArrayValue
        else {
            throw Wav2Vec2Error.predictionFailed("Выход 'logits' не найден в ответе модели")
        }
        return logitsArray
    }

    /// Конвертирует `MLMultiArray` логитов формы `[1, T, C]` (или `[T, C]`) в
    /// матрицу `T × C` (`T` строк по `C` значений) row-major. Читает через
    /// `strides`, поэтому корректна для любого layout, выдаваемого Core ML.
    static func multiArrayToMatrix(_ array: MLMultiArray) -> [[Float]] {
        let shape = array.shape.map(\.intValue)
        // Поддерживаем [1, T, C] и [T, C].
        let timeSteps: Int
        let vocab: Int
        let timeAxis: Int
        let vocabAxis: Int
        if shape.count == 3 {
            timeSteps = shape[1]
            vocab = shape[2]
            timeAxis = 1
            vocabAxis = 2
        } else if shape.count == 2 {
            timeSteps = shape[0]
            vocab = shape[1]
            timeAxis = 0
            vocabAxis = 1
        } else {
            return []
        }
        guard timeSteps > 0, vocab > 0 else { return [] }

        let strides = array.strides.map(\.intValue)
        let timeStride = strides[timeAxis]
        let vocabStride = strides[vocabAxis]

        var matrix = [[Float]](repeating: [Float](repeating: 0, count: vocab), count: timeSteps)

        // Быстрый путь для float32 (наиболее частый layout логитов): читаем через
        // типизированный указатель. Для других dataType — безопасный subscript.
        if array.dataType == .float32 {
            let basePtr = array.dataPointer.bindMemory(to: Float.self, capacity: array.count)
            for t in 0 ..< timeSteps {
                let rowBase = t * timeStride
                for c in 0 ..< vocab {
                    matrix[t][c] = basePtr[rowBase + c * vocabStride]
                }
            }
        } else {
            for t in 0 ..< timeSteps {
                let rowBase = t * timeStride
                for c in 0 ..< vocab {
                    matrix[t][c] = array[rowBase + c * vocabStride].floatValue
                }
            }
        }
        return matrix
    }

    // MARK: - Model Loading

    private func loadModelIfNeeded() throws -> MLModel {
        if let model { return model }

        logger.info("Wav2Vec2: загрузка модели '\(Self.modelName)'...")

        guard let modelURL = Bundle.main.url(
            forResource: Self.modelName,
            withExtension: "mlpackage"
        ) else {
            logger.error("Wav2Vec2: модель '\(Self.modelName).mlpackage' не найдена в bundle")
            throw Wav2Vec2Error.modelNotLoaded
        }

        let config = MLModelConfiguration()
        config.computeUnits = .all

        do {
            let loaded = try MLModel(contentsOf: modelURL, configuration: config)
            model = loaded
            logger.info("Wav2Vec2: модель загружена")
            return loaded
        } catch {
            logger.error("Wav2Vec2: ошибка загрузки модели — \(error.localizedDescription)")
            throw Wav2Vec2Error.modelNotLoaded
        }
    }

    // MARK: - Audio Processing

    /// Конвертирует Data → [Float], предполагая Little-Endian Float32 PCM.
    private func convertToSamples(data: Data) throws -> [Float] {
        guard data.count >= MemoryLayout<Float>.size else {
            throw Wav2Vec2Error.audioTooShort(data.count)
        }
        let sampleCount = data.count / MemoryLayout<Float>.size
        if sampleCount < 8_000 {
            throw Wav2Vec2Error.audioTooShort(sampleCount)
        }
        return data.withUnsafeBytes { ptr in
            Array(ptr.bindMemory(to: Float.self))
        }
    }

    /// Паддит нулями или обрезает до `fixedSamples`.
    private func normalizeSampleLength(_ samples: [Float]) -> [Float] {
        let target = Self.fixedSamples
        if samples.count >= target {
            return Array(samples.prefix(target))
        }
        var padded = samples
        padded.append(contentsOf: [Float](repeating: 0, count: target - samples.count))
        return padded
    }

    /// Peak-нормализация: делит на максимум амплитуды (если ненулевой).
    private func peakNormalize(_ samples: [Float]) -> [Float] {
        var maxVal: Float = 0
        vDSP_maxmgv(samples, 1, &maxVal, vDSP_Length(samples.count))
        guard maxVal > Float.leastNormalMagnitude else { return samples }

        var result = [Float](repeating: 0, count: samples.count)
        var divisor = maxVal
        vDSP_vsdiv(samples, 1, &divisor, &result, 1, vDSP_Length(samples.count))
        return result
    }

    /// Создаёт MLMultiArray из [Float] с формой [1, fixedSamples].
    private func makeMlArray(from samples: [Float]) throws -> MLMultiArray {
        let shape: [NSNumber] = [1, NSNumber(value: Self.fixedSamples)]
        guard let array = try? MLMultiArray(shape: shape, dataType: .float32) else {
            throw Wav2Vec2Error.audioConversionFailed
        }
        samples.withUnsafeBufferPointer { ptr in
            guard let src = ptr.baseAddress else { return }
            let dst = array.dataPointer.bindMemory(
                to: Float.self,
                capacity: Self.fixedSamples
            )
            dst.update(from: src, count: Self.fixedSamples)
        }
        return array
    }
}

// MARK: - Wav2Vec2ServiceMock

/// Mock-реализация для unit-тестов и SwiftUI Preview.
///
/// Возвращает детерминированный ``CTCDecodeResult`` без обращения к CoreML модели.
public actor Wav2Vec2ServiceMock: Wav2Vec2Service {

    public var simulatedText: String
    public var simulatedConfidence: Double
    public var shouldThrow: Bool

    /// Явная матрица логитов `T × C`. Если задана — ``logits(audio:)`` возвращает
    /// её как есть (для детерминированных тестов alignment/GOP). Если `nil` —
    /// логиты синтезируются из ``simulatedText`` (каждый символ доминирует в своём
    /// фрейм-спане, между фонемами — blank).
    public var simulatedLogits: [[Float]]?

    public init(
        text: String = "кот",
        confidence: Double = 0.82,
        shouldThrow: Bool = false,
        logits: [[Float]]? = nil
    ) {
        self.simulatedText = text
        self.simulatedConfidence = confidence
        self.shouldThrow = shouldThrow
        self.simulatedLogits = logits
    }

    public func transcribe(audio: Data) async throws -> CTCDecodeResult {
        if shouldThrow {
            throw Wav2Vec2Error.modelNotLoaded
        }
        let mockPhonemes = simulatedText.enumerated().compactMap { idx, char -> PhonemeLogit? in
            guard let phoneIdx = Wav2Vec2Vocabulary.index(of: String(char)) else { return nil }
            return PhonemeLogit(
                timestep: idx * 5,
                phonemeIndex: phoneIdx,
                confidence: simulatedConfidence
            )
        }
        return CTCDecodeResult(
            phonemes: mockPhonemes,
            decodedText: simulatedText,
            averageConfidence: simulatedConfidence
        )
    }

    public func logits(audio: Data) async throws -> [[Float]] {
        if shouldThrow {
            throw Wav2Vec2Error.modelNotLoaded
        }
        if let simulatedLogits {
            return simulatedLogits
        }
        return Self.synthesizeLogits(for: simulatedText)
    }

    /// Синтезирует матрицу логитов `T × C` из кириллической строки: каждая буква,
    /// присутствующая в словаре модели, доминирует в собственном спане кадров,
    /// разделённом blank-кадром. Высокие логиты у целевого класса, низкие — у
    /// остальных. Достаточно для прохождения forced-alignment + GOP в тестах.
    static func synthesizeLogits(for text: String) -> [[Float]] {
        let vocabSize = Wav2Vec2Vocabulary.size
        let blankId = Wav2Vec2Vocabulary.blankIndex
        let classIds = text.compactMap { Wav2Vec2Vocabulary.index(of: String($0)) }
        guard !classIds.isEmpty else { return [] }

        let framesPerPhoneme = 4
        let high: Float = 6.0
        let low: Float = -2.0

        func row(dominant: Int) -> [Float] {
            var values = [Float](repeating: low, count: vocabSize)
            if dominant >= 0, dominant < vocabSize { values[dominant] = high }
            return values
        }

        var matrix: [[Float]] = []
        // Ведущий blank-кадр.
        matrix.append(row(dominant: blankId))
        for classId in classIds {
            for _ in 0 ..< framesPerPhoneme {
                matrix.append(row(dominant: classId))
            }
            // blank-разделитель между фонемами.
            matrix.append(row(dominant: blankId))
        }
        return matrix
    }
}
