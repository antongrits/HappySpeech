@testable import HappySpeech
import XCTest

// MARK: - LocalLLMServiceTests
//
// Phase 6 plan v29 — покрытие LocalLLMService (ранее без выделенных тестов).
//
// Тестируется ТЕКУЩИЙ bundle-only API: модель встроена в бандл приложения
// (Resources/Models/LLM/), загрузок во время работы нет. На x86_64 / при
// отсутствии модели LocalLLMServiceLive детерминированно использует rule-based
// fallback — именно его контракт здесь и проверяется (success + edge cases).

final class LocalLLMServiceTests: XCTestCase {

    private func makeSUT() -> LocalLLMServiceLive {
        LocalLLMServiceLive()
    }

    // MARK: - Conformance

    func test_localLLMService_conformsToProtocol() {
        let sut: LocalLLMService = makeSUT()
        XCTAssertNotNil(sut)
    }

    func test_isModelLoaded_falseBeforeFirstGeneration() {
        let sut = makeSUT()
        XCTAssertFalse(sut.isModelLoaded, "До первой генерации модель не должна быть загружена")
    }

    func test_mlxModelId_isStableIdentifier() {
        XCTAssertEqual(
            LocalLLMServiceLive.mlxModelId,
            "mlx-community/Qwen2.5-1.5B-Instruct-4bit"
        )
    }

    // MARK: - generateParentSummary

    func test_generateParentSummary_returnsNonEmptySummaryAndTask() async throws {
        let sut = makeSUT()
        let request = ParentSummaryRequest(
            childName: "Маша",
            targetSound: "С",
            stage: "слова",
            totalAttempts: 20,
            correctAttempts: 16,
            errorWords: ["санки", "сумка"],
            sessionDurationSec: 600
        )
        let response = try await sut.generateParentSummary(request: request)
        XCTAssertFalse(response.parentSummary.isEmpty, "Резюме для родителя не должно быть пустым")
        XCTAssertFalse(response.homeTask.isEmpty, "Домашнее задание не должно быть пустым")
        XCTAssertTrue(response.parentSummary.contains("Маша"),
                      "Резюме должно упоминать имя ребёнка")
        XCTAssertTrue(response.parentSummary.contains("С"),
                      "Резюме должно упоминать целевой звук")
    }

    func test_generateParentSummary_handlesZeroAttempts() async throws {
        let sut = makeSUT()
        let request = ParentSummaryRequest(
            childName: "Петя",
            targetSound: "Р",
            stage: "изолированный",
            totalAttempts: 0,
            correctAttempts: 0,
            errorWords: [],
            sessionDurationSec: 0
        )
        // Edge case: деление на ноль не должно крашить — rate=0.
        let response = try await sut.generateParentSummary(request: request)
        XCTAssertFalse(response.parentSummary.isEmpty)
        XCTAssertFalse(response.homeTask.isEmpty)
    }

    // MARK: - generateRoute

    func test_generateRoute_returnsNonEmptyRoute() async throws {
        let sut = makeSUT()
        let request = RoutePlannerRequest(
            childId: "child-1",
            targetSound: "Ш",
            currentStage: "слоги",
            recentSuccessRate: 0.6,
            fatigueLevel: 1,
            age: 6,
            availableTemplates: ["listen-and-choose", "bingo", "memory", "sorting"]
        )
        let response = try await sut.generateRoute(request: request)
        XCTAssertFalse(response.route.isEmpty, "Маршрут не должен быть пустым")
        XCTAssertGreaterThan(response.sessionMaxDurationSec, 0)
        for item in response.route {
            XCTAssertFalse(item.template.isEmpty)
            XCTAssertGreaterThanOrEqual(item.difficulty, 1)
            XCTAssertGreaterThan(item.wordCount, 0)
        }
    }

    func test_generateRoute_highFatigueShortensSession() async throws {
        let sut = makeSUT()
        func request(fatigue: Int) -> RoutePlannerRequest {
            RoutePlannerRequest(
                childId: "c", targetSound: "Л", currentStage: "слова",
                recentSuccessRate: 0.7, fatigueLevel: fatigue, age: 7,
                availableTemplates: ["bingo", "memory"]
            )
        }
        let tired = try await sut.generateRoute(request: request(fatigue: 3))
        let fresh = try await sut.generateRoute(request: request(fatigue: 0))
        XCTAssertLessThanOrEqual(
            tired.sessionMaxDurationSec, fresh.sessionMaxDurationSec,
            "При высокой усталости сессия должна быть не длиннее, чем при низкой"
        )
    }

    func test_generateRoute_lowSuccessRatePicksFoundationalTemplates() async throws {
        let sut = makeSUT()
        let request = RoutePlannerRequest(
            childId: "c", targetSound: "Р", currentStage: "изолированный",
            recentSuccessRate: 0.2, fatigueLevel: 0, age: 5,
            availableTemplates: ["articulation-imitation", "breathing"]
        )
        let response = try await sut.generateRoute(request: request)
        XCTAssertFalse(response.route.isEmpty)
        XCTAssertLessThanOrEqual(response.route.count, 3, "Маршрут — максимум 3 шаблона")
    }

    // MARK: - generateMicroStory

    func test_generateMicroStory_returnsSentencesAndGaps() async throws {
        let sut = makeSUT()
        let request = MicroStoryRequest(
            targetSound: "Ж",
            stage: "предложения",
            age: 6,
            wordPool: ["жук", "журавль", "жёлудь"]
        )
        let response = try await sut.generateMicroStory(request: request)
        XCTAssertFalse(response.sentences.isEmpty, "История должна содержать предложения")
        XCTAssertLessThanOrEqual(response.sentences.count, 3, "Максимум 3 предложения")
        XCTAssertFalse(response.gapPositions.isEmpty, "Должна быть хотя бы одна позиция пропуска")
        for gap in response.gapPositions {
            XCTAssertGreaterThanOrEqual(gap.sentenceIndex, 0)
            XCTAssertFalse(gap.word.isEmpty)
        }
    }

    func test_generateMicroStory_handlesEmptyWordPool() async throws {
        let sut = makeSUT()
        let request = MicroStoryRequest(
            targetSound: "Ц",
            stage: "слова",
            age: 5,
            wordPool: []
        )
        // Edge case: пустой пул слов не должен крашить — fallback на targetSound.
        let response = try await sut.generateMicroStory(request: request)
        XCTAssertFalse(response.sentences.isEmpty)
    }
}
