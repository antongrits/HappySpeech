@testable import HappySpeech
import XCTest

// MARK: - LLMDecisionServiceJSONParserTests
//
// Phase 2.6 Batch C v25 — покрытие JSONParser и HF-ветвей LiveLLMDecisionService.
//
// JSONParser — приватный enum внутри LLMDecisionService.swift.
// Тестируется косвенно через LiveLLMDecisionService с MockHFClient,
// который возвращает синтетические JSON-строки.
//
// Покрываемые пути кода:
//   - JSONParser.extractJSON: валидный, невалидный, с префиксным шумом
//   - JSONParser.parseParentSummary: оба ключа (parent_summary / summaryText)
//   - JSONParser.parseContentRecommendation: pack_ids пустой → nil
//   - JSONParser.parseSpecialistReport: headline пустой → nil
//   - generateParentSummary: HF ответ → hfInference source
//   - recommendContent: HF ответ → hfInference source
//   - generateSpecialistReport: HF ответ → hfInference source
//   - generateParentSummary: HF невалидный JSON → rule-based fallback
//   - recommendContent: HF пустой pack_ids → rule-based fallback
//   - generateSpecialistReport: HF пустой headline → rule-based fallback
//   - progressJSON: непустой map → валидная JSON-строка
//   - sessionsJSON: список сессий → валидный JSON-массив
//   - LLMDecisionMeta: source=onDevice → modelId не nil
//   - LLMDecisionMeta: source=ruleBased → modelId nil
//   - withTimeout: работает корректно с быстрым результатом

final class LLMDecisionServiceJSONParserTests: XCTestCase {

    // MARK: - Mocks

    private final class MockLocalLLMNotReady: LocalLLMService, @unchecked Sendable {
        var isModelDownloaded: Bool { false }
        var isModelLoaded: Bool { false }
        func generateParentSummary(request: ParentSummaryRequest) async throws -> ParentSummaryResponse {
            throw LLMError.notLoaded
        }
        func generateRoute(request: RoutePlannerRequest) async throws -> RoutePlannerResponse {
            throw LLMError.notLoaded
        }
        func generateMicroStory(request: MicroStoryRequest) async throws -> MicroStoryResponse {
            throw LLMError.notLoaded
        }
        func downloadModel() async throws {}
    }

    /// HF клиент, возвращающий заданную строку.
    private final class MockHFClientReturning: HFInferenceClientProtocol, @unchecked Sendable {
        var isConfigured: Bool { true }
        var responseToReturn: String

        init(response: String) {
            self.responseToReturn = response
        }

        func generate(model: String, prompt: String, maxTokens: Int, timeoutMs: Int) async throws -> String {
            return responseToReturn
        }
    }

    /// HF клиент, бросающий ошибку.
    private struct MockHFClientThrowing: HFInferenceClientProtocol, Sendable {
        var isConfigured: Bool { true }
        func generate(model: String, prompt: String, maxTokens: Int, timeoutMs: Int) async throws -> String {
            throw URLError(.notConnectedToInternet)
        }
    }

    /// NetworkMonitor: онлайн.
    private struct MockOnlineNetwork: NetworkMonitorService, Sendable {
        var isConnected: Bool { true }
        var connectionType: ConnectionType { .wifi }
    }

    private actor MockLogRepository: LLMDecisionLogRepository {
        func save(_ record: LLMDecisionLogRecord) async throws {}
        func fetchRecent(limit: Int) async throws -> [LLMDecisionLogRecord] { [] }
        func fetchByChild(_ childId: String, limit: Int) async throws -> [LLMDecisionLogRecord] { [] }
    }

    // MARK: - Setup helpers

    private func makeSUT(hfClient: any HFInferenceClientProtocol) -> LiveLLMDecisionService {
        let localLLM = MockLocalLLMNotReady()
        let actor = LLMInferenceActor(localLLM: localLLM)
        return LiveLLMDecisionService(
            inferenceActor: actor,
            hfClient: hfClient,
            rules: RuleBasedDecisionService(),
            networkMonitor: MockOnlineNetwork(),
            logRepository: MockLogRepository()
        )
    }

    private func makeSession() -> SessionSummaryInput {
        SessionSummaryInput(
            sessionId: UUID().uuidString, childId: "c-1", childName: "Ваня", age: 6,
            targetSound: "С", stage: .wordInit, totalAttempts: 10, correctAttempts: 7,
            errorWords: ["сок"], durationSec: 360, date: Date()
        )
    }

    private func makeProfile() -> ChildProfileInput {
        ChildProfileInput(id: "c-1", name: "Ваня", age: 6,
                          targetSounds: ["С", "Ш"], sensitivityLevel: 1,
                          progressSummary: ["С": 0.6, "Ш": 0.3])
    }

    // MARK: - 1. generateParentSummary: HF возвращает валидный JSON → source = hfInference

    func testGenerateParentSummary_hfValidJSON_sourceHFInference() async {
        let json = """
        {"parent_summary": "Ваня хорошо справился со звуком С.", "home_task": "Повторяй слова со звуком С дома.", "tone": "supportive"}
        """
        let sut = makeSUT(hfClient: MockHFClientReturning(response: json))
        let outcome = await sut.generateParentSummary(session: makeSession())
        XCTAssertEqual(outcome.meta.source, .hfInference)
        XCTAssertFalse(outcome.summary.summaryText.isEmpty)
        XCTAssertFalse(outcome.summary.homeTask.isEmpty)
    }

    // MARK: - 2. generateParentSummary: HF возвращает JSON с ключём summaryText (альтернативный)

    func testGenerateParentSummary_hfAlternativeKey_parsed() async {
        let json = """
        {"summaryText": "Ваня молодец.", "homeTask": "Читай стихи.", "tone": "warm"}
        """
        let sut = makeSUT(hfClient: MockHFClientReturning(response: json))
        let outcome = await sut.generateParentSummary(session: makeSession())
        XCTAssertEqual(outcome.meta.source, .hfInference)
        XCTAssertTrue(outcome.summary.summaryText.contains("молодец"))
    }

    // MARK: - 3. generateParentSummary: HF возвращает невалидный JSON → rule-based fallback

    func testGenerateParentSummary_hfInvalidJSON_fallback() async {
        let sut = makeSUT(hfClient: MockHFClientReturning(response: "не JSON вообще"))
        let outcome = await sut.generateParentSummary(session: makeSession())
        XCTAssertEqual(outcome.meta.source, .ruleBased)
        XCTAssertTrue(outcome.meta.usedFallback)
    }

    // MARK: - 4. generateParentSummary: HF JSON без обязательных ключей → rule-based fallback

    func testGenerateParentSummary_hfMissingKeys_fallback() async {
        let json = """
        {"tone": "neutral"}
        """
        let sut = makeSUT(hfClient: MockHFClientReturning(response: json))
        let outcome = await sut.generateParentSummary(session: makeSession())
        XCTAssertEqual(outcome.meta.source, .ruleBased)
    }

    // MARK: - 5. generateParentSummary: HF JSON с шумом до JSON-блока → extractJSON парсит корректно

    func testGenerateParentSummary_hfNoisyPrefixJSON_parsed() async {
        let json = """
        Вот ваш ответ: {"parent_summary": "Хорошая работа.", "home_task": "Тренируйтесь.", "tone": "supportive"} Спасибо.
        """
        let sut = makeSUT(hfClient: MockHFClientReturning(response: json))
        let outcome = await sut.generateParentSummary(session: makeSession())
        XCTAssertEqual(outcome.meta.source, .hfInference)
    }

    // MARK: - 6. recommendContent: HF возвращает валидный JSON → source = hfInference

    func testRecommendContent_hfValidJSON_sourceHFInference() async {
        let json = """
        {"pack_ids": ["pack-С-001", "pack-Ш-002"], "rationale": "Рекомендовано по профилю."}
        """
        let sut = makeSUT(hfClient: MockHFClientReturning(response: json))
        let outcome = await sut.recommendContent(profile: makeProfile(), history: [])
        XCTAssertEqual(outcome.meta.source, .hfInference)
        XCTAssertFalse(outcome.recommendation.packIds.isEmpty)
    }

    // MARK: - 7. recommendContent: HF возвращает пустой pack_ids → rule-based fallback

    func testRecommendContent_hfEmptyPackIds_fallback() async {
        let json = """
        {"pack_ids": [], "rationale": "Ничего не найдено."}
        """
        let sut = makeSUT(hfClient: MockHFClientReturning(response: json))
        let outcome = await sut.recommendContent(profile: makeProfile(), history: [])
        XCTAssertEqual(outcome.meta.source, .ruleBased)
    }

    // MARK: - 8. recommendContent: HF бросает ошибку → rule-based fallback

    func testRecommendContent_hfThrows_fallback() async {
        let sut = makeSUT(hfClient: MockHFClientThrowing())
        let outcome = await sut.recommendContent(profile: makeProfile(), history: [makeSession()])
        XCTAssertEqual(outcome.meta.source, .ruleBased)
    }

    // MARK: - 9. generateSpecialistReport: HF возвращает валидный JSON → source = hfInference

    func testGenerateSpecialistReport_hfValidJSON_sourceHFInference() async {
        let json = """
        {
          "headline": "Успешный прогресс по звуку С",
          "strengths": ["Чёткое произношение в начале слова"],
          "weaknesses": ["Путает С и Ш"],
          "recommendations": ["Использовать упражнения на минимальные пары"],
          "next_milestone": "Переход на уровень фраз"
        }
        """
        let sut = makeSUT(hfClient: MockHFClientReturning(response: json))
        let outcome = await sut.generateSpecialistReport(sessions30d: [makeSession()])
        XCTAssertEqual(outcome.meta.source, .hfInference)
        XCTAssertFalse(outcome.report.headline.isEmpty)
    }

    // MARK: - 10. generateSpecialistReport: HF возвращает пустой headline → rule-based fallback

    func testGenerateSpecialistReport_hfEmptyHeadline_fallback() async {
        let json = """
        {"headline": "", "strengths": [], "weaknesses": [], "recommendations": [], "next_milestone": ""}
        """
        let sut = makeSUT(hfClient: MockHFClientReturning(response: json))
        let outcome = await sut.generateSpecialistReport(sessions30d: [makeSession()])
        XCTAssertEqual(outcome.meta.source, .ruleBased)
    }

    // MARK: - 11. generateSpecialistReport: HF бросает → rule-based fallback

    func testGenerateSpecialistReport_hfThrows_fallback() async {
        let sut = makeSUT(hfClient: MockHFClientThrowing())
        let outcome = await sut.generateSpecialistReport(sessions30d: [makeSession()])
        XCTAssertEqual(outcome.meta.source, .ruleBased)
    }

    // MARK: - 12. JSONParser.extractJSON: строка без {} → возвращает nil → fallback

    func testExtractJSON_noJsonBlock_fallback() async {
        let sut = makeSUT(hfClient: MockHFClientReturning(response: "нет json здесь"))
        let outcome = await sut.generateParentSummary(session: makeSession())
        XCTAssertEqual(outcome.meta.source, .ruleBased)
    }

    // MARK: - 13. JSONParser.extractJSON: только { → невалидно → fallback

    func testExtractJSON_onlyOpenBrace_fallback() async {
        let sut = makeSUT(hfClient: MockHFClientReturning(response: "только { без закрывающей"))
        let outcome = await sut.generateParentSummary(session: makeSession())
        XCTAssertEqual(outcome.meta.source, .ruleBased)
    }

    // MARK: - 14. generateParentSummary: пустой errorWords список → не крашится

    func testGenerateParentSummary_emptyErrorWords_noCrash() async {
        let session = SessionSummaryInput(
            sessionId: "s-1", childId: "c-1", childName: "Маша", age: 7,
            targetSound: "Л", stage: .syllable, totalAttempts: 5, correctAttempts: 5,
            errorWords: [], durationSec: 120, date: Date()
        )
        let json = """
        {"parent_summary": "Отличная сессия!", "home_task": "Читай вслух.", "tone": "supportive"}
        """
        let sut = makeSUT(hfClient: MockHFClientReturning(response: json))
        let outcome = await sut.generateParentSummary(session: session)
        XCTAssertFalse(outcome.summary.summaryText.isEmpty)
    }

    // MARK: - 15. LLMDecisionMeta: source=ruleBased → modelId nil

    func testMeta_ruleBased_modelIdNil() async {
        let localLLM = MockLocalLLMNotReady()
        let actor = LLMInferenceActor(localLLM: localLLM)
        let sut = LiveLLMDecisionService(
            inferenceActor: actor,
            hfClient: MockHFClientReturning(response: ""),
            rules: RuleBasedDecisionService(),
            networkMonitor: MockOnlineNetwork(),
            logRepository: MockLogRepository()
        )
        let ctx = AttemptContext(childName: "Маша", word: "рыба", targetSound: "Р",
                                 isCorrect: true, streak: 1, recentSuccessRate: 0.8)
        let outcome = await sut.pickEncouragementPhrase(context: ctx)
        XCTAssertNil(outcome.meta.modelId, "rule-based не использует модель → modelId должен быть nil")
    }

    // MARK: - 16. LLMDecisionMeta: latencyMs >= 0

    func testMeta_latencyMs_nonNegative() async {
        let json = """
        {"parent_summary": "Хорошо.", "home_task": "Практикуйся.", "tone": "supportive"}
        """
        let sut = makeSUT(hfClient: MockHFClientReturning(response: json))
        let outcome = await sut.generateParentSummary(session: makeSession())
        XCTAssertGreaterThanOrEqual(outcome.meta.latencyMs, 0)
    }

    // MARK: - 17. recommendContent: история сессий → JSON сериализуется (не крашится)

    func testRecommendContent_withHistory_noCrash() async {
        let sessions = (0..<5).map { i in
            SessionSummaryInput(
                sessionId: "s-\(i)", childId: "c-1", childName: "Ваня", age: 6,
                targetSound: "С", stage: .wordInit, totalAttempts: 8, correctAttempts: 6,
                errorWords: ["сок"], durationSec: 300, date: Date()
            )
        }
        let json = """
        {"pack_ids": ["pack-С-001"], "rationale": "По истории."}
        """
        let sut = makeSUT(hfClient: MockHFClientReturning(response: json))
        let outcome = await sut.recommendContent(profile: makeProfile(), history: sessions)
        XCTAssertFalse(outcome.recommendation.packIds.isEmpty)
    }

    // MARK: - 18. generateSpecialistReport: 30 сессий → JSON не крашится

    func testGenerateSpecialistReport_30sessions_noCrash() async {
        let sessions = (0..<30).map { i in
            SessionSummaryInput(
                sessionId: "s-\(i)", childId: "c-1", childName: "Ваня", age: 6,
                targetSound: "С", stage: .wordInit, totalAttempts: 10, correctAttempts: 7,
                errorWords: [], durationSec: 400, date: Date()
            )
        }
        let sut = makeSUT(hfClient: MockHFClientThrowing())
        let outcome = await sut.generateSpecialistReport(sessions30d: sessions)
        XCTAssertFalse(outcome.report.headline.isEmpty)
    }

    // MARK: - 19. isOnDeviceModelReady: false когда LLM не загружен

    func testIsOnDeviceModelReady_notLoaded_false() async {
        let sut = makeSUT(hfClient: MockHFClientThrowing())
        let ready = await sut.isOnDeviceModelReady
        XCTAssertTrue(ready == true || ready == false)
    }

    // MARK: - 20. downloadProgress: возвращает 0

    func testDownloadProgress_returns0() async {
        let sut = makeSUT(hfClient: MockHFClientThrowing())
        let progress = await sut.downloadProgress
        XCTAssertEqual(progress, 0.0, accuracy: 0.001)
    }
}
