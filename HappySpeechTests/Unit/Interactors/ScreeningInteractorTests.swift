@testable import HappySpeech
import XCTest

// MARK: - ScreeningInteractorTests
//
// M10.1 — 6 тестов для ScreeningInteractor.
// Покрывает: startScreening, submitAnswer (not last / last),
// finishScreening, completeScreening без Realm, возраст 6 строит промпты.

@MainActor
final class ScreeningInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: ScreeningPresentationLogic {
        var startCalled = false
        var submitCalled = false
        var finishCalled = false

        var lastStartResponse: ScreeningModels.StartScreening.Response?
        var lastSubmitResponse: ScreeningModels.SubmitAnswer.Response?
        var lastFinishResponse: ScreeningModels.FinishScreening.Response?

        func presentStartScreening(_ response: ScreeningModels.StartScreening.Response) async {
            startCalled = true
            lastStartResponse = response
        }
        func presentSubmitAnswer(_ response: ScreeningModels.SubmitAnswer.Response) async {
            submitCalled = true
            lastSubmitResponse = response
        }
        func presentFinishScreening(_ response: ScreeningModels.FinishScreening.Response) async {
            finishCalled = true
            lastFinishResponse = response
        }
    }

    private func makeSUT() -> (ScreeningInteractor, SpyPresenter) {
        let sut = ScreeningInteractor(realmActor: nil)
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. startScreening заполняет промпты для возраста 6

    func test_startScreening_age6_populatesPrompts() async {
        let (sut, spy) = makeSUT()
        await sut.startScreening(.init(childId: "child-1", childAge: 6))
        XCTAssertTrue(spy.startCalled)
        XCTAssertGreaterThan(spy.lastStartResponse?.prompts.count ?? 0, 0)
    }

    // MARK: - 2. startScreening возраст 5 строит промпты

    func test_startScreening_age5_populatesPrompts() async {
        let (sut, spy) = makeSUT()
        await sut.startScreening(.init(childId: "child-2", childAge: 5))
        XCTAssertGreaterThan(spy.lastStartResponse?.prompts.count ?? 0, 0)
    }

    // MARK: - 3. submitAnswer на первом промпте — isScreeningComplete = false

    func test_submitAnswer_firstPrompt_isNotComplete() async {
        let (sut, spy) = makeSUT()
        await sut.startScreening(.init(childId: "child-1", childAge: 6))
        let prompts = spy.lastStartResponse?.prompts ?? []
        guard let firstPrompt = prompts.first else {
            return XCTFail("Нет промптов для скрининга")
        }
        await sut.submitAnswer(.init(promptId: firstPrompt.id, score: 0.8, attemptCount: 1))
        // Первый промпт — не последний → isScreeningComplete = false
        XCTAssertEqual(spy.lastSubmitResponse?.isScreeningComplete, false)
    }

    // MARK: - 4. submitAnswer на последнем промпте — isScreeningComplete = true

    func test_submitAnswer_lastPrompt_isComplete() async {
        let (sut, spy) = makeSUT()
        await sut.startScreening(.init(childId: "child-1", childAge: 6))
        let prompts = spy.lastStartResponse?.prompts ?? []
        guard let lastPrompt = prompts.last else {
            return XCTFail("Нет промптов для скрининга")
        }
        // Заполняем все промпты кроме последнего.
        for prompt in prompts.dropLast() {
            await sut.submitAnswer(.init(promptId: prompt.id, score: 0.75, attemptCount: 1))
        }
        await sut.submitAnswer(.init(promptId: lastPrompt.id, score: 0.9, attemptCount: 1))
        XCTAssertEqual(spy.lastSubmitResponse?.isScreeningComplete, true)
    }

    // MARK: - 5. finishScreening вызывает presentFinishScreening

    func test_finishScreening_callsPresenter() async {
        let (sut, spy) = makeSUT()
        await sut.startScreening(.init(childId: "child-1", childAge: 6))
        await sut.finishScreening(.init(childId: "child-1"))
        XCTAssertTrue(spy.finishCalled)
    }

    // MARK: - 6. completeScreening без Realm не крашится

    func test_completeScreening_withoutRealm_doesNotCrash() async {
        let (sut, _) = makeSUT()
        await sut.startScreening(.init(childId: "child-1", childAge: 6))
        await sut.finishScreening(.init(childId: "child-1"))
        let completeReq = ScreeningModels.CompleteRequest(
            childId: "child-1",
            severity: "mild",
            problematicSounds: [],
            recommendedPacks: [],
            notes: ""
        )
        await XCTAsyncNoThrow {
            await sut.completeScreening(completeReq)
        }
    }
}

// MARK: - Async helper

func XCTAsyncNoThrow(_ block: @Sendable () async throws -> Void) async {
    do {
        try await block()
    } catch {
        XCTFail("Ожидалось отсутствие ошибки, получено: \(error)")
    }
}
