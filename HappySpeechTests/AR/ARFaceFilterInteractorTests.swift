@testable import HappySpeech
import XCTest

// MARK: - Spy Presenter

@MainActor
private final class SpyARFaceFilterPresenter: ARFaceFilterPresentationLogic, @unchecked Sendable {
    var setMaskCallCount = 0
    var triggerCallCount = 0

    var lastMask: FaceMaskKind?
    var lastTrigger: ARFaceFilterModels.Trigger.Response?
    var lastTriggerMask: FaceMaskKind?

    func presentSetMask(mask: FaceMaskKind) async {
        setMaskCallCount += 1
        lastMask = mask
    }
    func presentTrigger(
        response: ARFaceFilterModels.Trigger.Response,
        mask: FaceMaskKind
    ) async {
        triggerCallCount += 1
        lastTrigger = response
        lastTriggerMask = mask
    }
}

// MARK: - Tests
//
// Заметка о покрытии AR-кода:
// ARFaceFilterInteractor — VIP-thin. ARSession (2D overlay над live camera)
// и polling-ASR живут во View / ASRService. Покрыта вся VIP-логика:
// setMask (переключение масок), processTranscription (case-insensitive
// trigger-word matching). recognizedText подаётся как фикстура.

@MainActor
final class ARFaceFilterInteractorTests: XCTestCase {

    private func makeSUT() -> (ARFaceFilterInteractor, SpyARFaceFilterPresenter) {
        let sut = ARFaceFilterInteractor()
        let spy = SpyARFaceFilterPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - setMask

    func test_setMask_emitsToPresenter() async {
        let (sut, spy) = makeSUT()
        await sut.setMask(request: .init(mask: .fox))
        XCTAssertEqual(spy.setMaskCallCount, 1)
        XCTAssertEqual(spy.lastMask, .fox)
    }

    func test_setMask_changesCurrentMaskForTrigger() async {
        let (sut, spy) = makeSUT()
        await sut.setMask(request: .init(mask: .crown))
        // crown триггер-слово = "корона"
        await sut.processTranscription(request: .init(recognizedText: "корона"))
        XCTAssertTrue(spy.lastTrigger?.isMatched ?? false)
        XCTAssertEqual(spy.lastTriggerMask, .crown)
    }

    // MARK: - processTranscription

    func test_processTranscription_defaultMaskKitten_matchesKot() async {
        // Дефолтная маска — kitten, триггер "кот"
        let (sut, spy) = makeSUT()
        await sut.processTranscription(request: .init(recognizedText: "кот"))
        XCTAssertEqual(spy.triggerCallCount, 1)
        XCTAssertTrue(spy.lastTrigger?.isMatched ?? false)
        XCTAssertEqual(spy.lastTrigger?.matchedWord, "кот")
    }

    func test_processTranscription_wrongWord_noMatch() async {
        let (sut, spy) = makeSUT()
        await sut.processTranscription(request: .init(recognizedText: "собака"))
        XCTAssertFalse(spy.lastTrigger?.isMatched ?? true)
        XCTAssertEqual(spy.lastTrigger?.matchedWord, "")
    }

    func test_processTranscription_caseInsensitive() async {
        let (sut, spy) = makeSUT()
        await sut.processTranscription(request: .init(recognizedText: "КОТ"))
        XCTAssertTrue(spy.lastTrigger?.isMatched ?? false)
    }

    func test_processTranscription_substringMatch() async {
        // "кот" входит в "котёнок" → совпадение по substring
        let (sut, spy) = makeSUT()
        await sut.processTranscription(request: .init(recognizedText: "это котик"))
        XCTAssertTrue(spy.lastTrigger?.isMatched ?? false)
    }

    func test_processTranscription_whitespaceTrimmed() async {
        let (sut, spy) = makeSUT()
        await sut.processTranscription(request: .init(recognizedText: "  кот  \n"))
        XCTAssertTrue(spy.lastTrigger?.isMatched ?? false)
    }

    func test_processTranscription_emptyText_noMatch() async {
        let (sut, spy) = makeSUT()
        await sut.processTranscription(request: .init(recognizedText: ""))
        XCTAssertEqual(spy.triggerCallCount, 1)
        XCTAssertFalse(spy.lastTrigger?.isMatched ?? true)
    }

    func test_processTranscription_eachMaskTriggerWord() async {
        for mask in FaceMaskKind.allCases {
            let (sut, spy) = makeSUT()
            await sut.setMask(request: .init(mask: mask))
            await sut.processTranscription(request: .init(recognizedText: mask.triggerWord))
            XCTAssertTrue(
                spy.lastTrigger?.isMatched ?? false,
                "Маска \(mask.rawValue) должна совпасть со своим триггер-словом"
            )
        }
    }

    func test_processTranscription_maskMismatch_wrongTriggerWord() async {
        let (sut, spy) = makeSUT()
        await sut.setMask(request: .init(mask: .fox))
        // fox триггер = "лиса", подаём триггер crown
        await sut.processTranscription(request: .init(recognizedText: "корона"))
        XCTAssertFalse(spy.lastTrigger?.isMatched ?? true)
    }

    // MARK: - FaceMaskKind model

    func test_faceMaskKind_triggerWordsNotEmpty() {
        for mask in FaceMaskKind.allCases {
            XCTAssertFalse(mask.triggerWord.isEmpty)
            XCTAssertFalse(mask.symbolName.isEmpty)
            XCTAssertFalse(mask.localizedTitle.isEmpty)
            XCTAssertEqual(mask.emoji, mask.symbolName)
        }
    }

    func test_faceMaskKind_idMatchesRawValue() {
        for mask in FaceMaskKind.allCases {
            XCTAssertEqual(mask.id, mask.rawValue)
        }
    }
}
