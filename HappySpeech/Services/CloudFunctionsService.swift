import FirebaseFunctions
import Foundation
import OSLog

// MARK: - Result Models

/// Результат оценки качества произношения звука, возвращаемый Cloud Function `scoreSpeechQuality`.
///
/// Все числовые поля нормализованы в диапазон [0.0, 1.0].
/// `label` соответствует строковым значениям на стороне функции: "excellent", "good", "fair", "poor".
public struct ScoringResult: Sendable, Equatable {
    /// Итоговый балл произношения (0.0 — неверно, 1.0 — идеально).
    public let overallScore: Double
    /// Детализация по отдельным фонемам: ["р": 0.85, "ра": 0.72, ...].
    public let phonemeScores: [String: Double]
    /// Текстовая метка уровня: "excellent" | "good" | "fair" | "poor".
    public let label: String
    /// Опциональный логопедический комментарий от модели (родительский контур, не отображается детям).
    public let specialistNote: String?

    public init(
        overallScore: Double,
        phonemeScores: [String: Double],
        label: String,
        specialistNote: String?
    ) {
        self.overallScore = overallScore
        self.phonemeScores = phonemeScores
        self.label = label
        self.specialistNote = specialistNote
    }
}

/// Нейролингвистическая сводка прогресса ребёнка за период.
///
/// Генерируется Cloud Function `generateNeurolinguistSummary` на основе
/// агрегированных данных сессий из Firestore.
public struct NeurolinguistSummary: Sendable, Equatable {
    /// Уникальный идентификатор сводки (хранится в Firestore /reports/{reportId}).
    public let reportId: String
    /// Текстовое резюме прогресса на русском языке.
    public let summary: String
    /// Список рекомендаций логопеда: ["Уделить внимание звуку Р в начале слова", ...].
    public let recommendations: [String]
    /// Данные для графиков: {"Р": [0.3, 0.5, 0.7], "Ш": [0.6, 0.8]}.
    public let chartsData: [String: [Double]]
    /// Дата и время генерации отчёта.
    public let generatedAt: Date

    public init(
        reportId: String,
        summary: String,
        recommendations: [String],
        chartsData: [String: [Double]],
        generatedAt: Date
    ) {
        self.reportId = reportId
        self.summary = summary
        self.recommendations = recommendations
        self.chartsData = chartsData
        self.generatedAt = generatedAt
    }
}

// MARK: - Protocol

/// Вызов облачных функций Firebase для тяжёлых вычислений на стороне сервера.
///
/// Все функции задеплоены в регион `europe-west3` (ближайший к RU-аудитории).
/// Каждый вызов защищён App Check — запросы без валидной аттестации отклоняются.
///
/// > Important: `CloudFunctionsService` используется **только** в родительском
/// > и специалистском контуре. В детском контуре произношение оценивается
/// > локально через `PronunciationScorerService` (COPPA).
///
/// ## Пример
/// ```swift
/// let result = try await cloudFunctions.scoreSpeechQuality(
///     audio: pcmData,
///     targetSound: "р"
/// )
/// print(result.overallScore) // 0.87
///
/// let summary = try await cloudFunctions.generateNeurolinguistSummary(
///     childId: child.id,
///     period: "week"
/// )
/// ```
///
/// ## See Also
/// - ``PronunciationScorerService`` — on-device оценка для детского контура
/// - ``RemoteConfigService`` — флаги для включения/отключения серверных функций
public protocol CloudFunctionsServiceProtocol: AnyObject, Sendable {

    /// Оценивает качество произношения через серверную ML-модель.
    ///
    /// Аудио передаётся как base64 в теле запроса.
    /// Функция запускает специализированную русскоязычную модель произношения,
    /// которая не помещается на устройстве (>2 GB).
    ///
    /// - Parameters:
    ///   - audio: PCM-данные в формате 16kHz mono Int16.
    ///   - targetSound: Целевой звук, например "р", "ш", "ц".
    /// - Returns: `ScoringResult` с детализацией по фонемам.
    /// - Throws: `CloudFunctionsError` при сетевой ошибке или отказе App Check.
    func scoreSpeechQuality(audio: Data, targetSound: String) async throws -> ScoringResult

    /// Генерирует нейролингвистическую сводку прогресса ребёнка.
    ///
    /// Функция агрегирует данные из Firestore за указанный период и
    /// строит рекомендации через GPT-based модель на стороне сервера.
    ///
    /// - Parameters:
    ///   - childId: Идентификатор профиля ребёнка.
    ///   - period: Период отчёта: "week" | "month" | "quarter".
    /// - Returns: `NeurolinguistSummary` с рекомендациями и данными графиков.
    /// - Throws: `CloudFunctionsError`.
    func generateNeurolinguistSummary(childId: String, period: String) async throws -> NeurolinguistSummary
}

// MARK: - Errors

public enum CloudFunctionsError: LocalizedError, Sendable {
    case appCheckFailed
    case invalidResponse(String)
    case serverError(String)
    case networkUnavailable
    case audioEncodingFailed

    public var errorDescription: String? {
        switch self {
        case .appCheckFailed:
            return "Проверка устройства не прошла. Попробуйте позже."
        case .invalidResponse(let detail):
            return "Неверный ответ сервера: \(detail)"
        case .serverError(let message):
            return "Ошибка сервера: \(message)"
        case .networkUnavailable:
            return "Нет соединения с интернетом."
        case .audioEncodingFailed:
            return "Не удалось обработать аудиозапись."
        }
    }
}

// MARK: - Live Implementation

/// Продакшн-реализация `CloudFunctionsServiceProtocol`.
///
/// Использует `Functions.functions(region:)` с регионом `europe-west3`.
/// App Check enforcement активируется автоматически если в `FirebaseApp.configure()`
/// настроен `AppCheck` провайдер (`DeviceCheckProvider` / `AppAttestProvider`).
///
/// Аудио кодируется в base64 перед передачей — Cloud Function декодирует
/// и передаёт в серверный ASR+scorer pipeline.
public final class LiveCloudFunctionsService: CloudFunctionsServiceProtocol, @unchecked Sendable {

    private let logger = Logger(subsystem: "com.happyspeech", category: "CloudFunctions")
    private let functions: Functions

    /// - Parameter region: Регион Cloud Functions. Дефолт: `europe-west3`.
    public init(region: String = "europe-west3") {
        self.functions = Functions.functions(region: region)
    }

    // MARK: - CloudFunctionsServiceProtocol

    public func scoreSpeechQuality(audio: Data, targetSound: String) async throws -> ScoringResult {
        guard !audio.isEmpty else {
            logger.error("scoreSpeechQuality: empty audio data")
            throw CloudFunctionsError.audioEncodingFailed
        }

        let audioBase64 = audio.base64EncodedString()
        let callable = functions.httpsCallable("scoreSpeechQuality")

        let payload: [String: Any] = [
            "audioBase64": audioBase64,
            "targetSound": targetSound,
            "sampleRate": 16000,
            "encoding": "PCM_16BIT"
        ]

        do {
            let result = try await callable.call(payload)
            return try parseScoreResult(result.data)
        } catch {
            logger.error("scoreSpeechQuality error: \(error.localizedDescription)")
            throw mapError(error)
        }
    }

    public func generateNeurolinguistSummary(
        childId: String,
        period: String
    ) async throws -> NeurolinguistSummary {
        guard !childId.isEmpty else {
            throw CloudFunctionsError.invalidResponse("childId не может быть пустым")
        }
        let validPeriods = Set(["week", "month", "quarter"])
        let resolvedPeriod = validPeriods.contains(period) ? period : "week"

        let callable = functions.httpsCallable("generateNeurolinguistSummary")
        let payload: [String: Any] = [
            "childId": childId,
            "period": resolvedPeriod
        ]

        do {
            let result = try await callable.call(payload)
            return try parseSummaryResult(result.data)
        } catch {
            logger.error("generateNeurolinguistSummary error: \(error.localizedDescription)")
            throw mapError(error)
        }
    }

    // MARK: - Private Helpers

    private func parseScoreResult(_ data: Any) throws -> ScoringResult {
        guard let dict = data as? [String: Any] else {
            throw CloudFunctionsError.invalidResponse("ожидался объект, получено: \(type(of: data))")
        }
        guard
            let overallScore = dict["overallScore"] as? Double,
            let label = dict["label"] as? String
        else {
            throw CloudFunctionsError.invalidResponse("отсутствуют обязательные поля overallScore/label")
        }
        let phonemeScores = (dict["phonemeScores"] as? [String: Double]) ?? [:]
        let specialistNote = dict["specialistNote"] as? String

        logger.info("scoreSpeechQuality result: score=\(overallScore, format: .fixed(precision: 2)), label=\(label)")
        return ScoringResult(
            overallScore: min(max(overallScore, 0.0), 1.0),
            phonemeScores: phonemeScores,
            label: label,
            specialistNote: specialistNote
        )
    }

    private func parseSummaryResult(_ data: Any) throws -> NeurolinguistSummary {
        guard let dict = data as? [String: Any] else {
            throw CloudFunctionsError.invalidResponse("ожидался объект, получено: \(type(of: data))")
        }
        guard
            let reportId = dict["reportId"] as? String,
            let summary = dict["summary"] as? String
        else {
            throw CloudFunctionsError.invalidResponse("отсутствуют обязательные поля reportId/summary")
        }
        let recommendations = (dict["recommendations"] as? [String]) ?? []
        let chartsData = (dict["chartsData"] as? [String: [Double]]) ?? [:]
        let generatedAtTimestamp = (dict["generatedAt"] as? Double) ?? Date().timeIntervalSince1970
        let generatedAt = Date(timeIntervalSince1970: generatedAtTimestamp)

        logger.info("generateNeurolinguistSummary result: reportId=\(reportId, privacy: .private)")
        return NeurolinguistSummary(
            reportId: reportId,
            summary: summary,
            recommendations: recommendations,
            chartsData: chartsData,
            generatedAt: generatedAt
        )
    }

    private func mapError(_ error: Error) -> CloudFunctionsError {
        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain else {
            return .serverError(error.localizedDescription)
        }
        let code = FunctionsErrorCode(rawValue: nsError.code) ?? .internal
        switch code {
        case .unauthenticated, .permissionDenied:
            return .appCheckFailed
        case .unavailable, .deadlineExceeded:
            return .networkUnavailable
        default:
            return .serverError(nsError.localizedDescription)
        }
    }
}

// MARK: - Mock

/// Preview / test реализация. Детерминированные ответы без сети.
public final class MockCloudFunctionsService: CloudFunctionsServiceProtocol, @unchecked Sendable {

    public var stubbedScoringResult: ScoringResult = ScoringResult(
        overallScore: 0.82,
        phonemeScores: ["р": 0.85, "ра": 0.78],
        label: "good",
        specialistNote: "Хороший прогресс по звуку Р"
    )

    public var stubbedSummary: NeurolinguistSummary = NeurolinguistSummary(
        reportId: "mock-report-001",
        summary: "Ребёнок демонстрирует стабильный прогресс по целевым звукам.",
        recommendations: [
            "Уделить внимание звуку Р в начале слова",
            "Продолжить упражнения на дифференциацию Р/Л"
        ],
        chartsData: ["Р": [0.3, 0.5, 0.7, 0.82], "Ш": [0.6, 0.75, 0.85]],
        generatedAt: Date()
    )

    public var shouldThrowError: Bool = false

    public init() {}

    public func scoreSpeechQuality(audio: Data, targetSound: String) async throws -> ScoringResult {
        if shouldThrowError { throw CloudFunctionsError.networkUnavailable }
        return stubbedScoringResult
    }

    public func generateNeurolinguistSummary(
        childId: String,
        period: String
    ) async throws -> NeurolinguistSummary {
        if shouldThrowError { throw CloudFunctionsError.serverError("Mock error") }
        return stubbedSummary
    }
}
