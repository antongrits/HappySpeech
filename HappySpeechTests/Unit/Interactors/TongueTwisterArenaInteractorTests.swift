@testable import HappySpeech
import XCTest

// MARK: - TongueTwisterArenaInteractorTests
//
// TongueTwisterArenaInteractor содержит реальный цикл записи (через сервисы) и
// чистую оценку произношения по перекрытию слов. Юнит-тесты покрывают чистый
// scoring, выбор/возврат и загрузку контента (без аудио-сервисов).

@MainActor
final class TongueTwisterArenaInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> TongueTwisterArenaInteractor {
        TongueTwisterArenaInteractor(childId: childId)
    }

    // MARK: - Pure scoring

    func test_similarity_fullMatch_isOne() {
        let s = TongueTwisterArenaInteractor.similarity(
            transcript: "на дворе трава на траве дрова",
            target: "На дворе трава, на траве дрова."
        )
        XCTAssertEqual(s, 1.0, accuracy: 0.0001)
    }

    func test_similarity_partial() {
        let s = TongueTwisterArenaInteractor.similarity(
            transcript: "на дворе трава",
            target: "На дворе трава, на траве дрова."
        )
        // 3 уникальных целевых слова (длиной >= 2) совпали из 4 уникальных.
        XCTAssertGreaterThan(s, 0.4)
        XCTAssertLessThan(s, 1.0)
    }

    func test_similarity_empty_isZero() {
        let s = TongueTwisterArenaInteractor.similarity(transcript: "", target: "Слон сидит")
        XCTAssertEqual(s, 0.0, accuracy: 0.0001)
    }

    func test_stars_thresholds() {
        XCTAssertEqual(TongueTwisterArenaInteractor.stars(for: 0.1), 1)
        XCTAssertEqual(TongueTwisterArenaInteractor.stars(for: 0.5), 2)
        XCTAssertEqual(TongueTwisterArenaInteractor.stars(for: 0.9), 3)
    }

    // MARK: - Selection / load

    func test_load_populatesTwisters() async {
        let sut = makeSUT()
        await sut.load()
        XCTAssertEqual(sut.state.twisters.count, TongueTwisterContent.all.count)
    }

    func test_select_setsSelectedAndIdlePhase() async {
        let sut = makeSUT()
        await sut.load()
        let twister = sut.state.twisters[0]
        sut.select(twister)
        XCTAssertEqual(sut.state.selected, twister)
        XCTAssertEqual(sut.state.phase, .idle)
    }

    func test_back_clearsSelection() async {
        let sut = makeSUT()
        await sut.load()
        sut.select(sut.state.twisters[0])
        sut.back()
        XCTAssertNil(sut.state.selected)
        XCTAssertEqual(sut.state.phase, .idle)
    }

    func test_canRecord_falseWithoutServices() {
        let sut = makeSUT()
        XCTAssertFalse(sut.canRecord)
    }

    func test_toggleRecord_withoutServices_doesNotEnterRecording() async {
        let sut = makeSUT()
        await sut.load()
        sut.select(sut.state.twisters[0])
        sut.toggleRecord()
        // Без audioService запись не стартует.
        XCTAssertFalse(sut.state.isRecording)
    }

    // MARK: - Content filtering

    func test_content_filtersByTargetSounds() {
        let filtered = TongueTwisterContent.twisters(forTargetSounds: ["Р"])
        XCTAssertEqual(filtered.first?.targetSound.contains("Р"), true)
        XCTAssertEqual(filtered.count, TongueTwisterContent.all.count)
    }
}
