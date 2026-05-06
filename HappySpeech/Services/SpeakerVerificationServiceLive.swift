import Accelerate
import AVFoundation
@preconcurrency import CoreML
import Foundation
import OSLog

// MARK: - Note: AVAudioPCMBuffer не является Sendable (Swift 6 strict concurrency).
// Все публичные API сервиса принимают Data (Float32 PCM, 16kHz mono).
// Конвертацию буфера в Data выполняет вызывающий код ДО async-границы:
//   guard let ch = buffer.floatChannelData?[0] else { return }
//   let pcmData = Data(bytes: ch, count: Int(buffer.frameLength) * MemoryLayout<Float>.size)

// MARK: - SpeakerType

/// Тип говорящего, определённый через d-vector сравнение.
public enum SpeakerType: String, Sendable {
    /// Голос совпал с зарегистрированным родительским профилем.
    case parent
    /// Голос не совпал с родительским профилем — вероятно ребёнок.
    case child
    /// Недостаточная уверенность для классификации.
    case unknown
}

// MARK: - VoiceProfile

/// Зарегистрированный голосовой профиль (d-vector эмбеддинг).
///
/// Создаётся при онбординге родителя. Хранится на устройстве.
/// Не содержит аудиозаписи — только нормализованный 64-мерный вектор.
///
/// ## COPPA
/// Профиль родителя хранится локально, никогда не покидает устройство.
public struct VoiceProfile: Sendable, Codable {
    /// 64-мерный d-vector эмбеддинг (ECAPA-TDNN).
    public let embedding: [Float]
    /// Идентификатор владельца (parent userId, не имя ребёнка).
    public let ownerId: String
    /// Дата создания профиля.
    public let createdAt: Date

    public init(embedding: [Float], ownerId: String, createdAt: Date = .now) {
        self.embedding = embedding
        self.ownerId = ownerId
        self.createdAt = createdAt
    }
}

// MARK: - SpeakerVerificationResult

/// Результат верификации голоса говорящего.
public struct SpeakerVerificationResult: Sendable {
    /// Совпал ли голос с эталонным профилем (cosine similarity > threshold).
    public let isMatch: Bool
    /// Косинусное сходство (0.0 — полностью разные, 1.0 — идентичны).
    public let similarity: Float
    /// Определённый тип говорящего.
    public let speakerType: SpeakerType
}

// MARK: - SpeakerVerificationServiceProtocol

/// Протокол верификации голоса говорящего.
///
/// Принимает Float32 PCM Data (16kHz, mono) вместо AVAudioPCMBuffer
/// для совместимости с Swift 6 strict concurrency (AVAudioPCMBuffer не Sendable).
///
/// Основной use case — различать голос родителя и ребёнка (COPPA-требование):
/// функции только для родителей недоступны, если верификация не пройдена.
///
/// ## Пример использования
/// ```swift
/// guard let ch = buffer.floatChannelData?[0] else { return }
/// let pcmData = Data(bytes: ch, count: Int(buffer.frameLength) * MemoryLayout<Float>.size)
/// let result = await speakerVerificationService.verify(pcmData: pcmData, referenceVoice: parentProfile)
/// if result.isMatch && result.speakerType == .parent { ... }
/// ```
public protocol SpeakerVerificationServiceProtocol: Sendable {

    /// Верифицирует аудио (Float32 PCM Data, 16kHz mono) относительно эталонного профиля.
    /// - Parameters:
    ///   - pcmData: Float32 PCM Data (16kHz mono), скопированная из AVAudioPCMBuffer ДО async-вызова
    ///   - referenceVoice: зарегистрированный голосовой профиль
    /// - Returns: результат верификации с cosine similarity и типом говорящего
    func verify(pcmData: Data, referenceVoice: VoiceProfile) async -> SpeakerVerificationResult

    /// Создаёт голосовой профиль из аудио PCM Data.
    /// Вызывается при онбординге родителя для регистрации эталонного голоса.
    /// - Parameters:
    ///   - pcmData: Float32 PCM Data (16kHz mono, ≥3 сек)
    ///   - ownerId: идентификатор владельца профиля
    /// - Returns: голосовой профиль с 64-мерным d-vector эмбеддингом
    func enroll(pcmData: Data, ownerId: String) async throws -> VoiceProfile
}

// MARK: - LiveSpeakerVerificationService

/// Живая реализация верификации голоса через ECAPA d-vector модель.
///
/// Модель: `SpeakerVerification.mlpackage`
/// Входной тензор: `[1, 40, 150]` — 40 MFCC коэффициентов, 150 фреймов (1.5 сек, 16kHz)
/// Выходной тензор: `[1, 64]` — 64-мерный d-vector эмбеддинг
///
/// Порог косинусного сходства: 0.70
/// - Выше 0.70 → isMatch = true, speakerType = .parent
/// - 0.50–0.70 → isMatch = false, speakerType = .child
/// - Ниже 0.50 → speakerType = .unknown
public actor LiveSpeakerVerificationService: SpeakerVerificationServiceProtocol {

    // MARK: - Constants

    private static let modelName = "SpeakerVerification"
    private static let inputName = "mfcc"
    private static let outputName = "embedding"
    private static let embeddingDimension = 64
    private static let matchThreshold: Float = 0.70
    private static let unknownThreshold: Float = 0.50
    private static let nMFCC = 40
    private static let nFrames = 150

    // MARK: - State

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SpeakerVerification")
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
            logger.error("SpeakerVerification: модель не найдена в бандле")
            return
        }
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            model = try MLModel(contentsOf: url, configuration: config)
            logger.info("SpeakerVerification: модель загружена из \(url.lastPathComponent)")
        } catch {
            logger.error("SpeakerVerification: ошибка загрузки: \(error.localizedDescription)")
        }
    }

    // MARK: - SpeakerVerificationServiceProtocol

    public func verify(pcmData: Data, referenceVoice: VoiceProfile) async -> SpeakerVerificationResult {
        guard let model else {
            logger.warning("SpeakerVerification: модель не загружена — возвращаем unknown")
            return SpeakerVerificationResult(isMatch: false, similarity: 0.0, speakerType: .unknown)
        }

        do {
            let queryEmbedding = try await computeEmbedding(from: pcmData, model: model)
            let similarity = cosineSimilarity(queryEmbedding, referenceVoice.embedding)

            let speakerType: SpeakerType
            let isMatch: Bool
            if similarity >= Self.matchThreshold {
                speakerType = .parent
                isMatch = true
            } else if similarity >= Self.unknownThreshold {
                speakerType = .child
                isMatch = false
            } else {
                speakerType = .unknown
                isMatch = false
            }

            logger.debug("SpeakerVerification: similarity=\(similarity, format: .fixed(precision: 3)), type=\(speakerType.rawValue)")
            return SpeakerVerificationResult(
                isMatch: isMatch,
                similarity: similarity,
                speakerType: speakerType
            )
        } catch {
            logger.error("SpeakerVerification: ошибка inference: \(error.localizedDescription)")
            return SpeakerVerificationResult(isMatch: false, similarity: 0.0, speakerType: .unknown)
        }
    }

    public func enroll(pcmData: Data, ownerId: String) async throws -> VoiceProfile {
        guard let model else {
            throw AppError.mlModelNotFound("SpeakerVerification")
        }
        let embedding = try await computeEmbedding(from: pcmData, model: model)
        logger.info("SpeakerVerification: зарегистрирован профиль для ownerId=\(ownerId.prefix(8), privacy: .private)")
        return VoiceProfile(embedding: embedding, ownerId: ownerId)
    }

    // MARK: - Private: Embedding Computation

    private func computeEmbedding(from pcmData: Data, model: MLModel) async throws -> [Float] {
        let mfccFrames = try await mfccExtractor.extract(from: pcmData)
        let inputArray = try buildMFCCArray(frames: mfccFrames)
        let input = try MLDictionaryFeatureProvider(dictionary: [Self.inputName: inputArray])
        let output = try await model.prediction(from: input)
        return try extractEmbedding(from: output)
    }

    /// Строит MLMultiArray [1, nMFCC, nFrames] из MFCC фреймов.
    private func buildMFCCArray(frames: [[Float]]) throws -> MLMultiArray {
        let shape: [NSNumber] = [1, NSNumber(value: Self.nMFCC), NSNumber(value: Self.nFrames)]
        let array = try MLMultiArray(shape: shape, dataType: .float32)

        let usedFrames = min(frames.count, Self.nFrames)
        for frameIdx in 0..<usedFrames {
            let frame = frames[frameIdx]
            let usedCoeffs = min(frame.count, Self.nMFCC)
            for coeffIdx in 0..<usedCoeffs {
                let index = [0, coeffIdx, frameIdx] as [NSNumber]
                array[index] = NSNumber(value: frame[coeffIdx])
            }
        }
        return array
    }

    /// Извлекает embedding вектор из выхода модели.
    private func extractEmbedding(from output: MLFeatureProvider) throws -> [Float] {
        guard let embeddingFeature = output.featureValue(for: Self.outputName),
              let multiArray = embeddingFeature.multiArrayValue else {
            throw AppError.mlModelNotFound("SpeakerVerification output")
        }
        let count = min(multiArray.count, Self.embeddingDimension)
        var result = [Float](repeating: 0, count: count)
        for i in 0..<count {
            result[i] = multiArray[i].floatValue
        }
        return l2Normalize(result)
    }

    // MARK: - Private: Math

    /// Вычисляет косинусное сходство двух нормализованных векторов (dot product).
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        let len = min(a.count, b.count)
        guard len > 0 else { return 0 }
        var result: Float = 0
        vDSP_dotpr(a, 1, b, 1, &result, vDSP_Length(len))
        return max(-1, min(1, result))
    }

    /// L2-нормализует вектор.
    private func l2Normalize(_ vector: [Float]) -> [Float] {
        var norm: Float = 0
        vDSP_svesq(vector, 1, &norm, vDSP_Length(vector.count))
        norm = sqrt(norm)
        guard norm > 1e-8 else { return vector }
        return vector.map { $0 / norm }
    }
}

// MARK: - MockSpeakerVerificationService

/// Mock-реализация для unit-тестов и SwiftUI Preview.
///
/// По умолчанию всегда возвращает SpeakerType.child (безопасный дефолт).
/// Для тестирования родительского потока используйте `isParent = true`.
public final class MockSpeakerVerificationService: SpeakerVerificationServiceProtocol, @unchecked Sendable {

    public var isParent: Bool
    public var mockSimilarity: Float

    public init(isParent: Bool = false, similarity: Float = 0.3) {
        self.isParent = isParent
        self.mockSimilarity = similarity
    }

    public func verify(pcmData: Data, referenceVoice: VoiceProfile) async -> SpeakerVerificationResult {
        SpeakerVerificationResult(
            isMatch: isParent,
            similarity: isParent ? max(mockSimilarity, 0.75) : min(mockSimilarity, 0.45),
            speakerType: isParent ? .parent : .child
        )
    }

    public func enroll(pcmData: Data, ownerId: String) async throws -> VoiceProfile {
        let mockEmbedding = Array(repeating: Float(1.0 / 8.0), count: 64)
        return VoiceProfile(embedding: mockEmbedding, ownerId: ownerId)
    }
}
