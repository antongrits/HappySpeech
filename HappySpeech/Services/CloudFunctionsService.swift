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

/// Результат серверной верификации детского голоса.
///
/// Возвращается Cloud Function `validateChildVoice` как fallback для
/// on-device `SpeakerVerificationService`. В stub-реализации функция
/// всегда возвращает `isChildVoice = true`, чтобы не блокировать UX.
public struct ChildVoiceValidationResult: Sendable, Equatable {
    /// Признак того, что аудио принадлежит ребёнку.
    public let isChildVoice: Bool
    /// Уровень уверенности модели в диапазоне [0.0, 1.0].
    public let confidence: Double

    public init(isChildVoice: Bool, confidence: Double) {
        self.isChildVoice = isChildVoice
        self.confidence = confidence
    }
}

/// Тренды по группе звуков, возвращаемые `analyzeSpeechProgress`.
public struct SpeechProgressTrend: Sendable, Equatable {
    /// Название группы звуков на русском: "шипящие", "свистящие", "соноры".
    public let soundGroup: String
    /// Направление тренда: "up" | "down" | "flat".
    public let direction: String
    /// Изменение в процентах относительно предыдущего периода.
    public let changePercent: Int

    public init(soundGroup: String, direction: String, changePercent: Int) {
        self.soundGroup = soundGroup
        self.direction = direction
        self.changePercent = changePercent
    }
}

/// Результат серверного анализа прогресса (`analyzeSpeechProgress`).
///
/// Отличается от `calculateProgress` тем, что фокусируется на
/// нейролингвистических трендах: сильные стороны, пробелы, динамика.
public struct SpeechProgressAnalysis: Sendable, Equatable {
    /// Тренды по группам звуков.
    public let trends: [SpeechProgressTrend]
    /// Сильные стороны произношения.
    public let strengths: [String]
    /// Звуки/области, требующие доработки.
    public let gaps: [String]

    public init(trends: [SpeechProgressTrend], strengths: [String], gaps: [String]) {
        self.trends = trends
        self.strengths = strengths
        self.gaps = gaps
    }
}

/// Результат генерации специалистского отчёта (`generateSpecialistReport`).
///
/// `downloadUrl` равен `nil` если PDF-генерация выполняется на устройстве
/// через `SpecialistExportService` (текущая реализация).
public struct SpecialistReportResult: Sendable, Equatable {
    /// Уникальный идентификатор отчёта.
    public let reportId: String
    /// Формат экспорта: "json" | "pdf".
    public let format: String
    /// URL для скачивания готового файла, либо `nil` для on-device fallback.
    public let downloadUrl: URL?
    /// Опциональное сообщение для UI (например, причина отсутствия URL).
    public let message: String?

    public init(reportId: String, format: String, downloadUrl: URL?, message: String?) {
        self.reportId = reportId
        self.format = format
        self.downloadUrl = downloadUrl
        self.message = message
    }
}

/// Токен семейного приглашения, заменяющий deprecated Firebase Dynamic Links.
///
/// Создаётся через Cloud Function `createFamilyInviteToken`. Документ хранится
/// в Firestore (`/family_invites/{token}`), а ссылка резолвится через Apple
/// Universal Links (Associated Domains).
///
/// См. `FamilyInviteService` и ADR-V18-U-DYNAMICLINKS-REPLACE.
public struct FamilyInviteToken: Sendable, Equatable {
    /// Технический токен (32 символа hex) — primary key документа в Firestore.
    public let token: String
    /// Короткий 6-символьный код для ручного ввода (например "K7M2X9").
    public let shortCode: String
    /// Время истечения (Unix timestamp в секундах).
    public let expiresAt: Date
    /// Universal Link URL для ShareSheet.
    public let deepLinkURL: URL

    public init(token: String, shortCode: String, expiresAt: Date, deepLinkURL: URL) {
        self.token = token
        self.shortCode = shortCode
        self.expiresAt = expiresAt
        self.deepLinkURL = deepLinkURL
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
/// // result.overallScore == 0.87
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

    /// Серверная верификация что аудио принадлежит ребёнку.
    ///
    /// Используется как fallback для on-device `SpeakerVerificationService`
    /// (например, когда ML-модель не загружена). В stub-реализации всегда
    /// возвращает `isChildVoice = true`.
    ///
    /// - Parameter audio: PCM-данные 16kHz mono.
    /// - Returns: `ChildVoiceValidationResult`.
    /// - Throws: `CloudFunctionsError`.
    func validateChildVoice(audio: Data) async throws -> ChildVoiceValidationResult

    /// Анализирует прогресс ребёнка с нейролингвистической точки зрения.
    ///
    /// Возвращает тренды по группам звуков, сильные стороны и области для
    /// доработки. Дополняет, а не заменяет `calculateProgress` (агрегация).
    ///
    /// - Parameter childId: Идентификатор профиля ребёнка.
    /// - Returns: `SpeechProgressAnalysis`.
    /// - Throws: `CloudFunctionsError`.
    func analyzeSpeechProgress(childId: String) async throws -> SpeechProgressAnalysis

    /// Генерирует специалистский отчёт (PDF/JSON).
    ///
    /// В текущей реализации сервер возвращает `downloadUrl = nil`, и iOS
    /// клиент производит экспорт локально через `SpecialistExportService`.
    ///
    /// - Parameters:
    ///   - childId: Идентификатор профиля ребёнка.
    ///   - format: Формат отчёта: "json" | "pdf".
    /// - Returns: `SpecialistReportResult`.
    /// - Throws: `CloudFunctionsError`.
    func generateSpecialistReport(childId: String, format: String) async throws -> SpecialistReportResult

    /// Создаёт токен семейного приглашения через Firestore.
    ///
    /// Заменяет deprecated Firebase Dynamic Links (sunset 2025-08-25).
    /// Создаёт single-use Firestore document (`/family_invites/{token}`)
    /// и возвращает Universal Link для ShareSheet.
    ///
    /// - Parameters:
    ///   - parentId: Идентификатор родителя (должен совпадать с auth uid).
    ///   - role: Роль приглашённого: `.secondary` | `.observer`.
    ///   - durationHours: Срок жизни в часах (1-168, дефолт 24).
    /// - Returns: `FamilyInviteToken` с токеном, коротким кодом и URL.
    /// - Throws: `CloudFunctionsError`.
    func createFamilyInviteToken(
        parentId: String,
        role: ParentRole,
        durationHours: Int
    ) async throws -> FamilyInviteToken
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

    public func validateChildVoice(audio: Data) async throws -> ChildVoiceValidationResult {
        guard !audio.isEmpty else {
            logger.error("validateChildVoice: empty audio data")
            throw CloudFunctionsError.audioEncodingFailed
        }

        let callable = functions.httpsCallable("validateChildVoice")
        let payload: [String: Any] = [
            "audioBase64": audio.base64EncodedString()
        ]

        do {
            let result = try await callable.call(payload)
            return try parseChildVoiceResult(result.data)
        } catch {
            logger.error("validateChildVoice error: \(error.localizedDescription)")
            throw mapError(error)
        }
    }

    public func analyzeSpeechProgress(childId: String) async throws -> SpeechProgressAnalysis {
        guard !childId.isEmpty else {
            throw CloudFunctionsError.invalidResponse("childId не может быть пустым")
        }

        let callable = functions.httpsCallable("analyzeSpeechProgress")
        let payload: [String: Any] = [
            "childId": childId
        ]

        do {
            let result = try await callable.call(payload)
            return try parseProgressAnalysis(result.data)
        } catch {
            logger.error("analyzeSpeechProgress error: \(error.localizedDescription)")
            throw mapError(error)
        }
    }

    public func generateSpecialistReport(
        childId: String,
        format: String
    ) async throws -> SpecialistReportResult {
        guard !childId.isEmpty else {
            throw CloudFunctionsError.invalidResponse("childId не может быть пустым")
        }
        let validFormats = Set(["json", "pdf"])
        let resolvedFormat = validFormats.contains(format) ? format : "json"

        let callable = functions.httpsCallable("generateSpecialistReport")
        let payload: [String: Any] = [
            "childId": childId,
            "format": resolvedFormat
        ]

        do {
            let result = try await callable.call(payload)
            return try parseSpecialistReport(result.data)
        } catch {
            logger.error("generateSpecialistReport error: \(error.localizedDescription)")
            throw mapError(error)
        }
    }

    public func createFamilyInviteToken(
        parentId: String,
        role: ParentRole,
        durationHours: Int
    ) async throws -> FamilyInviteToken {
        guard !parentId.isEmpty else {
            throw CloudFunctionsError.invalidResponse("parentId не может быть пустым")
        }
        let resolvedDuration = max(1, min(durationHours, 168))

        let callable = functions.httpsCallable("createFamilyInviteToken")
        let payload: [String: Any] = [
            "parentId": parentId,
            "role": role.rawValue,
            "durationHours": resolvedDuration
        ]

        do {
            let result = try await callable.call(payload)
            return try parseInviteToken(result.data)
        } catch {
            logger.error("createFamilyInviteToken error: \(error.localizedDescription)")
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

    private func parseChildVoiceResult(_ data: Any) throws -> ChildVoiceValidationResult {
        guard let dict = data as? [String: Any] else {
            throw CloudFunctionsError.invalidResponse("ожидался объект, получено: \(type(of: data))")
        }
        let isChildVoice = (dict["isChildVoice"] as? Bool) ?? true
        let confidence = (dict["confidence"] as? Double) ?? 0.0
        logger.info("validateChildVoice result: isChild=\(isChildVoice)")
        return ChildVoiceValidationResult(
            isChildVoice: isChildVoice,
            confidence: min(max(confidence, 0.0), 1.0)
        )
    }

    private func parseProgressAnalysis(_ data: Any) throws -> SpeechProgressAnalysis {
        guard let dict = data as? [String: Any] else {
            throw CloudFunctionsError.invalidResponse("ожидался объект, получено: \(type(of: data))")
        }
        let trendsRaw = (dict["trends"] as? [[String: Any]]) ?? []
        let trends: [SpeechProgressTrend] = trendsRaw.compactMap { item in
            guard
                let group = item["soundGroup"] as? String,
                let direction = item["direction"] as? String
            else { return nil }
            let change = (item["changePercent"] as? Int) ??
                Int((item["changePercent"] as? Double) ?? 0)
            return SpeechProgressTrend(
                soundGroup: group,
                direction: direction,
                changePercent: change
            )
        }
        let strengths = (dict["strengths"] as? [String]) ?? []
        let gaps = (dict["gaps"] as? [String]) ?? []
        logger.info("analyzeSpeechProgress result: trends=\(trends.count), strengths=\(strengths.count), gaps=\(gaps.count)")
        return SpeechProgressAnalysis(trends: trends, strengths: strengths, gaps: gaps)
    }

    private func parseSpecialistReport(_ data: Any) throws -> SpecialistReportResult {
        guard let dict = data as? [String: Any] else {
            throw CloudFunctionsError.invalidResponse("ожидался объект, получено: \(type(of: data))")
        }
        guard let reportId = dict["reportId"] as? String else {
            throw CloudFunctionsError.invalidResponse("отсутствует обязательное поле reportId")
        }
        let format = (dict["format"] as? String) ?? "json"
        let downloadUrl = (dict["downloadUrl"] as? String).flatMap(URL.init(string:))
        let message = dict["message"] as? String

        logger.info("generateSpecialistReport result: reportId=\(reportId, privacy: .private), format=\(format), hasURL=\(downloadUrl != nil)")
        return SpecialistReportResult(
            reportId: reportId,
            format: format,
            downloadUrl: downloadUrl,
            message: message
        )
    }

    private func parseInviteToken(_ data: Any) throws -> FamilyInviteToken {
        guard let dict = data as? [String: Any] else {
            throw CloudFunctionsError.invalidResponse("ожидался объект, получено: \(type(of: data))")
        }
        guard
            let token = dict["token"] as? String,
            let shortCode = dict["shortCode"] as? String,
            let urlString = dict["deepLinkURL"] as? String,
            let url = URL(string: urlString)
        else {
            throw CloudFunctionsError.invalidResponse("отсутствуют обязательные поля токена")
        }
        let expiresTimestamp: Double
        if let value = dict["expiresAt"] as? Double {
            expiresTimestamp = value
        } else if let value = dict["expiresAt"] as? Int {
            expiresTimestamp = Double(value)
        } else {
            expiresTimestamp = Date().addingTimeInterval(24 * 3600).timeIntervalSince1970
        }
        let expiresAt = Date(timeIntervalSince1970: expiresTimestamp)

        logger.info("createFamilyInviteToken result: shortCode=\(shortCode), expiresAt=\(expiresAt.description)")
        return FamilyInviteToken(
            token: token,
            shortCode: shortCode,
            expiresAt: expiresAt,
            deepLinkURL: url
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

    public var stubbedChildVoice: ChildVoiceValidationResult = ChildVoiceValidationResult(
        isChildVoice: true,
        confidence: 0.92
    )

    public var stubbedProgressAnalysis: SpeechProgressAnalysis = SpeechProgressAnalysis(
        trends: [
            SpeechProgressTrend(soundGroup: "шипящие", direction: "up", changePercent: 18),
            SpeechProgressTrend(soundGroup: "свистящие", direction: "up", changePercent: 12),
            SpeechProgressTrend(soundGroup: "соноры", direction: "flat", changePercent: 3)
        ],
        strengths: [
            "Чёткое произношение Ш, Ж",
            "Хороший темп речи"
        ],
        gaps: [
            "Звук Р требует доработки"
        ]
    )

    public var stubbedSpecialistReport: SpecialistReportResult = SpecialistReportResult(
        reportId: "mock-spec-report-001",
        format: "json",
        downloadUrl: nil,
        message: "PDF-экспорт временно выполняется на устройстве."
    )

    public var stubbedInviteToken: FamilyInviteToken = FamilyInviteToken(
        token: "mock-token-deadbeef00000000deadbeef00000000",
        shortCode: "ABCD23",
        expiresAt: Date().addingTimeInterval(24 * 3600),
        // swiftlint:disable:next force_unwrapping
        deepLinkURL: URL(string: "https://happyspeech.mmf.bsu.app/invite?token=mock&code=ABCD23")!
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

    public func validateChildVoice(audio: Data) async throws -> ChildVoiceValidationResult {
        if shouldThrowError { throw CloudFunctionsError.serverError("Mock error") }
        return stubbedChildVoice
    }

    public func analyzeSpeechProgress(childId: String) async throws -> SpeechProgressAnalysis {
        if shouldThrowError { throw CloudFunctionsError.serverError("Mock error") }
        return stubbedProgressAnalysis
    }

    public func generateSpecialistReport(
        childId: String,
        format: String
    ) async throws -> SpecialistReportResult {
        if shouldThrowError { throw CloudFunctionsError.serverError("Mock error") }
        return stubbedSpecialistReport
    }

    public func createFamilyInviteToken(
        parentId: String,
        role: ParentRole,
        durationHours: Int
    ) async throws -> FamilyInviteToken {
        if shouldThrowError { throw CloudFunctionsError.serverError("Mock error") }
        return stubbedInviteToken
    }
}
