@testable import HappySpeech
import XCTest

// MARK: - KidHintProviderTests
//
// Тестирует KidHintProvider через MockKidLLMNarrationService.
// Проверяет: getHint обновляет currentHint, isLoading цикл,
// loadAndShow и clear.

@MainActor
final class KidHintProviderTests: XCTestCase {

    private var mockService: MockKidLLMNarrationService!
    private var sut: KidHintProvider!

    override func setUp() {
        super.setUp()
        mockService = MockKidLLMNarrationService()
        sut = KidHintProvider(narrationService: mockService)
    }

    override func tearDown() {
        sut = nil
        mockService = nil
        super.tearDown()
    }

    // MARK: - getHint happy path

    func test_getHint_returnsNonEmptyHint() async {
        let hint = await sut.getHint(gameType: "repeat_after_model", step: "1")
        XCTAssertFalse(hint.isEmpty, "getHint должен вернуть непустую строку")
    }

    func test_getHint_updatesCurrentHint() async {
        _ = await sut.getHint(gameType: "bingo", step: "2")
        XCTAssertFalse(sut.currentHint.isEmpty,
                       "currentHint должен обновиться после getHint")
    }

    func test_getHint_callsNarrationService() async {
        _ = await sut.getHint(gameType: "sorting", step: "intro")
        XCTAssertEqual(mockService.hintCallCount, 1,
                       "Сервис нарраций должен быть вызван один раз")
    }

    func test_getHint_multipleCallsIncrementCounter() async {
        _ = await sut.getHint(gameType: "memory", step: "1")
        _ = await sut.getHint(gameType: "memory", step: "2")
        XCTAssertEqual(mockService.hintCallCount, 2)
    }

    // MARK: - isLoading

    func test_getHint_isLoadingFalseAfterCompletion() async {
        XCTAssertFalse(sut.isLoading, "isLoading должен быть false до вызова")
        _ = await sut.getHint(gameType: "listen_and_choose", step: "0")
        XCTAssertFalse(sut.isLoading, "isLoading должен быть false после завершения")
    }

    // MARK: - clear

    func test_clear_resetsCurrentHint() async {
        _ = await sut.getHint(gameType: "narrative_quest", step: "end")
        sut.clear()
        XCTAssertEqual(sut.currentHint, "", "clear() должен обнулить currentHint")
    }

    func test_clear_onEmpty_doesNotCrash() {
        XCTAssertNoThrow(sut.clear())
        XCTAssertEqual(sut.currentHint, "")
    }

    // MARK: - gameType forwarding

    func test_getHint_passesGameTypeToService() async {
        // MockKidLLMNarrationService возвращает PrecannedNarrations.hint(for:) —
        // тест проверяет, что возврат не пустой для любого типа игры.
        let gameTypes = ["bingo", "repeat_after_model", "general", "narrative_quest"]
        for gameType in gameTypes {
            let hint = await sut.getHint(gameType: gameType, step: "1")
            XCTAssertFalse(hint.isEmpty, "hint для gameType=\(gameType) не должен быть пустым")
        }
    }

    // MARK: - loadAndShow (fire-and-forget, не ждём результат)

    func test_loadAndShow_doesNotCrash() {
        XCTAssertNoThrow(sut.loadAndShow(gameType: "bingo", step: "3"))
    }
}
