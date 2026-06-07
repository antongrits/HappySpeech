import FirebaseFunctions
import Foundation

// MARK: - Models

/// Результат серверной оценки качества речи (aggregate для родительского дашборда).
///
/// > Important: ОСНОВНОЙ путь оценки произношения — on-device, per-attempt, через
/// > `PronunciationScorerService` (4 пофонемные Core ML-модели). Этот серверный
/// > endpoint — ДОПОЛНИТЕЛЬНЫЙ (опциональная агрегированная аналитика для
/// > родительского дашборда), на бэкенде он возвращает stub-метрику и НЕ участвует
/// > в UI-критичной оценке. Audio bytes на сервер не загружаются (COPPA).
public struct SpeechQualityScore: Sendable, Equatable {
    /// Оценка качества произношения в диапазоне 0…1.
    public let score: Double
    /// Уверенность в оценке (0…1).
    public let confidence: Double
    /// Серверное время обработки (ISO 8601).
    public let processedAt: Date

    public init(score: Double, confidence: Double, processedAt: Date) {
        self.score = score
        self.confidence = confidence
        self.processedAt = processedAt
    }
}

// MARK: - Protocol

/// Клиент Cloud Function `scoreSpeechQuality`.
public protocol ScoreSpeechQualityClientProtocol: CloudFunctionsClient {
    /// Запрашивает aggregate-оценку уже загруженной в Storage записи.
    ///
    /// - Parameters:
    ///   - audioStoragePath: Путь в Firebase Storage
    ///     (формат `audio/recordings/{uid}/{childId}/...`).
    ///   - targetSound: Целевой звук в верхнем регистре (например `"Р"`).
    ///   - childAge: Возраст ребёнка (3…12).
    /// - Returns: ``SpeechQualityScore``.
    /// - Throws: ``CloudFunctionsClientError``.
    func score(
        audioStoragePath: String,
        targetSound: String,
        childAge: Int
    ) async throws -> SpeechQualityScore
}

// MARK: - Live

public final class LiveScoreSpeechQualityClient: LiveCloudFunctionsClientBase,
                                                 ScoreSpeechQualityClientProtocol,
                                                 @unchecked Sendable {

    public init(region: String = CloudFunctionsRegion.default) {
        super.init(region: region, category: "ScoreSpeechQuality")
    }

    public func score(
        audioStoragePath: String,
        targetSound: String,
        childAge: Int
    ) async throws -> SpeechQualityScore {
        guard !audioStoragePath.isEmpty else {
            throw CloudFunctionsClientError.invalidArgument("audioStoragePath")
        }
        guard !targetSound.isEmpty else {
            throw CloudFunctionsClientError.invalidArgument("targetSound")
        }
        guard (3...12).contains(childAge) else {
            throw CloudFunctionsClientError.invalidArgument("childAge")
        }

        let callable = functions.httpsCallable("scoreSpeechQuality")
        let payload: [String: Any] = [
            "audioStoragePath": audioStoragePath,
            "targetSound": targetSound,
            "childAge": childAge
        ]

        do {
            let result = try await callable.call(payload)
            return try parse(result.data)
        } catch {
            logger.error("scoreSpeechQuality error: \(error.localizedDescription)")
            throw mapError(error)
        }
    }

    private func parse(_ data: Any) throws -> SpeechQualityScore {
        let dict = try extractDictionary(from: data)
        guard
            let score = dict["score"] as? Double ?? (dict["score"] as? NSNumber)?.doubleValue,
            let confidence = dict["confidence"] as? Double
                ?? (dict["confidence"] as? NSNumber)?.doubleValue,
            let processedAtString = dict["processedAt"] as? String
        else {
            throw CloudFunctionsClientError.invalidResponse(
                "отсутствуют score/confidence/processedAt"
            )
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let processedAt = formatter.date(from: processedAtString)
            ?? ISO8601DateFormatter().date(from: processedAtString)
            ?? Date()
        return SpeechQualityScore(
            score: score,
            confidence: confidence,
            processedAt: processedAt
        )
    }
}

// MARK: - Mock

/// Preview / test реализация без сети.
public final class MockScoreSpeechQualityClient: ScoreSpeechQualityClientProtocol,
                                                 @unchecked Sendable {

    public let region: String = CloudFunctionsRegion.default
    public var stubbedScore: SpeechQualityScore = SpeechQualityScore(
        score: 0.85,
        confidence: 0.9,
        processedAt: Date()
    )
    public var shouldThrowError: Bool = false

    public init() {}

    public func score(
        audioStoragePath: String,
        targetSound: String,
        childAge: Int
    ) async throws -> SpeechQualityScore {
        if shouldThrowError {
            throw CloudFunctionsClientError.serverError("Mock error")
        }
        return stubbedScore
    }
}
