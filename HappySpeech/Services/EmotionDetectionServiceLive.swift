import AVFoundation
@preconcurrency import CoreML
import Foundation
import OSLog

// MARK: - Note: AVAudioPCMBuffer не является Sendable (Swift 6 strict concurrency).
// Все публичные API сервиса принимают Data (Float32 PCM, 16kHz mono).
// Конвертацию буфера в Data выполняет вызывающий код ДО async-границы:
//   guard let ch = buffer.floatChannelData?[0] else { return }
//   let pcmData = Data(bytes: ch, count: Int(buffer.frameLength) * MemoryLayout<Float>.size)

// MARK: - DetectedEmotion

/// Эмоция, обнаруженная в голосе ребёнка.
///
/// Используется для адаптивной обратной связи Ляли:
/// - `.frustrated` или `.sad` → поощрительный feedback, упрощённая сложность
/// - `.happy` → праздничное усиление после верного ответа
public enum DetectedEmotion: String, Sendable, CaseIterable {
    /// Радость, энтузиазм.
    case happy
    /// Грусть, подавленность.
    case sad
    /// Раздражение, усталость.
    case frustrated
    /// Нейтральное состояние.
    case neutral

    /// Локализованное отображаемое имя эмоции.
    public var displayName: String {
        switch self {
        case .happy:      return String(localized: "Радость")
        case .sad:        return String(localized: "Грусть")
        case .frustrated: return String(localized: "Расстройство")
        case .neutral:    return String(localized: "Нейтрально")
        }
    }
}

// MARK: - EmotionResult

/// Результат анализа эмоций из голосового сигнала.
public struct EmotionResult: Sendable {
    /// Доминирующая обнаруженная эмоция.
    public let emotion: DetectedEmotion
    /// Уверенность для доминирующей эмоции (0.0–1.0, softmax).
    public let confidence: Float
    /// Распределение softmax по всем четырём эмоциям.
    public let allScores: [DetectedEmotion: Float]

    public init(emotion: DetectedEmotion, confidence: Float, allScores: [DetectedEmotion: Float]) {
        self.emotion = emotion
        self.confidence = confidence
        self.allScores = allScores
    }
}

// MARK: - EmotionDetectionServiceProtocol

/// Протокол сервиса обнаружения эмоций из голосового сигнала.
///
/// Принимает Float32 PCM Data (16kHz mono) вместо AVAudioPCMBuffer
/// для совместимости с Swift 6 strict concurrency (AVAudioPCMBuffer не Sendable).
///
/// ## Детский контур (COPPA)
/// - Полностью on-device, нет сетевых вызовов.
/// - Аудио не сохраняется на диск.
/// - Используется только для адаптации UI — не для диагностики.
///
/// ## Интеграция в игры
/// После каждой попытки ребёнка:
/// - `.frustrated` / `.sad` → Ляля даёт поощрительный feedback, снижает сложность
/// - `.happy` → усиленное праздничное сообщение после верного ответа
/// - `.neutral` → стандартная обратная связь
///
/// ## Пример использования
/// ```swift
/// guard let ch = buffer.floatChannelData?[0] else { return }
/// let pcmData = Data(bytes: ch, count: Int(buffer.frameLength) * MemoryLayout<Float>.size)
/// let result = await emotionService.analyze(pcmData: pcmData)
/// if result.emotion == .frustrated { showEncouragement() }
/// ```
public protocol EmotionDetectionServiceProtocol: Sendable {

    /// Анализирует эмоциональное состояние из Float32 PCM Data.
    /// - Parameter pcmData: Float32 PCM Data (16kHz, mono), скопированная ДО async-вызова
    /// - Returns: результат с доминирующей эмоцией и softmax распределением
    func analyze(pcmData: Data) async -> EmotionResult
}

// MARK: - LiveEmotionDetectionService

/// Живая реализация обнаружения эмоций через Conv1d-LSTM CoreML модель.
///
/// Модель: `EmotionDetection.mlpackage`
/// Входной тензор: `[1, 40, 150]` — 40 MFCC коэффициентов, 150 фреймов (1.5 сек, 16kHz)
/// Выходной тензор: `[1, 4]` — logits для [happy, sad, frustrated, neutral]
///
/// **Block B v15:** val accuracy 94.2% на тестовой выборке детской речи.
public actor LiveEmotionDetectionService: EmotionDetectionServiceProtocol {

    // MARK: - Constants

    private static let modelName = "EmotionDetection"
    private static let inputName = "mfcc"
    private static let outputName = "emotion_logits"
    private static let nMFCC = 40
    private static let nFrames = 150

    /// Порядок классов в выходном тензоре модели.
    private static let classOrder: [DetectedEmotion] = [.happy, .sad, .frustrated, .neutral]

    // MARK: - State

    private let logger = Logger(subsystem: "ru.happyspeech", category: "EmotionDetection")
    private var model: MLModel?
    private let mfccExtractor = RealMFCCExtractor()

    // MARK: - Init

    public init() {
        Task { await loadModel() }
    }

    // MARK: - Model Loading

    private func loadModel() {
        guard let url = Bundle.main.url(
            forResource: Self.modelName,
            withExtension: "mlpackage"
        ) else {
            logger.error("EmotionDetection: модель \(Self.modelName).mlpackage не найдена в бандле")
            return
        }
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            model = try MLModel(contentsOf: url, configuration: config)
            logger.info("EmotionDetection: модель загружена из \(url.lastPathComponent)")
        } catch {
            logger.error("EmotionDetection: ошибка загрузки модели: \(error.localizedDescription)")
        }
    }

    // MARK: - EmotionDetectionServiceProtocol

    public func analyze(pcmData: Data) async -> EmotionResult {
        guard let model else {
            logger.warning("EmotionDetection: модель не загружена — возвращаем .neutral")
            return neutralResult()
        }

        do {
            // 1. MFCC extraction (40 коэффициентов, 150 фреймов)
            let mfccFrames = try await mfccExtractor.extract(from: pcmData)

            // 2. Строим входной тензор [1, 40, 150]
            let inputArray = try buildMFCCArray(frames: mfccFrames)

            // 3. CoreML forward pass
            let inputFeature = try MLDictionaryFeatureProvider(dictionary: [Self.inputName: inputArray])
            let output = try await model.prediction(from: inputFeature)

            // 4. Softmax из logits → вероятности
            guard let logitsFeature = output.featureValue(for: Self.outputName),
                  let logitsArray = logitsFeature.multiArrayValue else {
                logger.warning("EmotionDetection: выход модели не найден — возвращаем .neutral")
                return neutralResult()
            }

            let scores = softmax(fromMLMultiArray: logitsArray)

            // 5. Собираем результат
            return buildResult(from: scores)

        } catch {
            logger.error("EmotionDetection: ошибка inference: \(error.localizedDescription)")
            return neutralResult()
        }
    }

    // MARK: - Private: Input Construction

    /// Строит MLMultiArray [1, nMFCC, nFrames] из MFCC фреймов.
    private func buildMFCCArray(frames: [[Float]]) throws -> MLMultiArray {
        let shape: [NSNumber] = [1, NSNumber(value: Self.nMFCC), NSNumber(value: Self.nFrames)]
        let array = try MLMultiArray(shape: shape, dataType: .float32)

        let usedFrames = min(frames.count, Self.nFrames)
        for frameIdx in 0..<usedFrames {
            let frame = frames[frameIdx]
            let usedCoeffs = min(frame.count, Self.nMFCC)
            for coeffIdx in 0..<usedCoeffs {
                let mlIndex = [0, coeffIdx, frameIdx] as [NSNumber]
                array[mlIndex] = NSNumber(value: frame[coeffIdx])
            }
        }
        return array
    }

    // MARK: - Private: Softmax

    /// Вычисляет softmax из MLMultiArray logits.
    private func softmax(fromMLMultiArray array: MLMultiArray) -> [Float] {
        let n = min(array.count, Self.classOrder.count)
        var logits = (0..<n).map { array[$0].floatValue }

        // Численно стабильный softmax (вычитаем max)
        let maxLogit = logits.max() ?? 0
        logits = logits.map { exp($0 - maxLogit) }
        let sum = logits.reduce(0, +)
        guard sum > 1e-8 else {
            return Array(repeating: 1.0 / Float(n), count: n)
        }
        return logits.map { $0 / sum }
    }

    // MARK: - Private: Result Building

    /// Собирает EmotionResult из массива softmax-вероятностей.
    private func buildResult(from scores: [Float]) -> EmotionResult {
        var allScores: [DetectedEmotion: Float] = [:]
        for (idx, emotion) in Self.classOrder.enumerated() {
            allScores[emotion] = idx < scores.count ? scores[idx] : 0
        }

        // Доминирующая эмоция — максимум softmax
        let dominant = allScores.max(by: { $0.value < $1.value })
        let emotion = dominant?.key ?? .neutral
        let confidence = dominant?.value ?? 0

        logger.debug("EmotionDetection: \(emotion.rawValue) (\(confidence, format: .fixed(precision: 3)))")
        return EmotionResult(emotion: emotion, confidence: confidence, allScores: allScores)
    }

    // MARK: - Private: Fallback

    private func neutralResult() -> EmotionResult {
        let scores: [DetectedEmotion: Float] = [
            .happy: 0.1,
            .sad: 0.1,
            .frustrated: 0.1,
            .neutral: 0.7
        ]
        return EmotionResult(emotion: .neutral, confidence: 0.7, allScores: scores)
    }
}

// MARK: - MockEmotionDetectionService

/// Mock-реализация для unit-тестов и SwiftUI Preview.
///
/// По умолчанию всегда возвращает `.happy` с уверенностью 0.95.
public final class MockEmotionDetectionService: EmotionDetectionServiceProtocol, @unchecked Sendable {

    public var mockEmotion: DetectedEmotion
    public var mockConfidence: Float

    public init(emotion: DetectedEmotion = .happy, confidence: Float = 0.95) {
        self.mockEmotion = emotion
        self.mockConfidence = confidence
    }

    public func analyze(pcmData: Data) async -> EmotionResult {
        var allScores: [DetectedEmotion: Float] = [:]
        let remaining = (1.0 - mockConfidence) / Float(DetectedEmotion.allCases.count - 1)
        for emotion in DetectedEmotion.allCases {
            allScores[emotion] = emotion == mockEmotion ? mockConfidence : remaining
        }
        return EmotionResult(
            emotion: mockEmotion,
            confidence: mockConfidence,
            allScores: allScores
        )
    }
}
