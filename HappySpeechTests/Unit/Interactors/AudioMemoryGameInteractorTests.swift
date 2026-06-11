@testable import HappySpeech
import XCTest

// MARK: - AudioMemoryGameInteractorTests
//
// «Звуковое мемори»: колода из реальных слов рабочих звуков ребёнка (каждое
// слово — пара карточек). Тесты покрывают первый/второй выбор, совпадение,
// промах (700мс flip-back), счёт ходов, завершение и рестарт. Колода
// перемешана — карточки ищем по pairKey, а ключи берём из самих карточек.

@MainActor
final class AudioMemoryGameInteractorTests: XCTestCase {

    private func makeLoadedSUT(childId: String = "") async -> AudioMemoryGameInteractor {
        let sut = AudioMemoryGameInteractor(childId: childId)
        await sut.load()
        return sut
    }

    /// Уникальные ключи (слова) в текущей колоде.
    private func keys(_ sut: AudioMemoryGameInteractor) -> [String] {
        var seen = Set<String>()
        return sut.tiles.map(\.pairKey).filter { seen.insert($0).inserted }
    }

    /// Индексы двух карточек одной пары.
    private func pairIndices(_ sut: AudioMemoryGameInteractor, key: String) -> (Int, Int) {
        let indices = sut.tiles.indices.filter { sut.tiles[$0].pairKey == key }
        return (indices[0], indices[1])
    }

    private func mismatchIndices(_ sut: AudioMemoryGameInteractor) -> (Int, Int) {
        let firstKey = sut.tiles[0].pairKey
        let other = sut.tiles.indices.first { sut.tiles[$0].pairKey != firstKey }!
        return (0, other)
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = AudioMemoryGameInteractor(childId: "kid-5")
        XCTAssertEqual(sut.childId, "kid-5")
    }

    func test_load_buildsDeckOfPairs() async {
        let sut = await makeLoadedSUT()
        XCTAssertTrue(sut.isLoaded)
        XCTAssertEqual(sut.tiles.count, sut.pairCount * 2)
        XCTAssertGreaterThan(sut.pairCount, 0)
    }

    func test_load_exactlyTwoOfEachPair() async {
        let sut = await makeLoadedSUT()
        for key in keys(sut) {
            XCTAssertEqual(sut.tiles.filter { $0.pairKey == key }.count, 2)
        }
    }

    func test_initialState_noPickNoMovesNotComplete() async {
        let sut = await makeLoadedSUT()
        XCTAssertNil(sut.firstPickIndex)
        XCTAssertEqual(sut.moves, 0)
        XCTAssertEqual(sut.matchedCount, 0)
        XCTAssertFalse(sut.isComplete)
        XCTAssertFalse(sut.isResolving)
    }

    func test_tap_beforeLoad_isIgnored() {
        let sut = AudioMemoryGameInteractor(childId: "")
        sut.tap(at: 0)
        XCTAssertNil(sut.firstPickIndex)
    }

    // MARK: - First pick

    func test_tap_firstPick_flipsTileAndStoresIndex() async {
        let sut = await makeLoadedSUT()
        sut.tap(at: 0)
        XCTAssertTrue(sut.tiles[0].isFlipped)
        XCTAssertEqual(sut.firstPickIndex, 0)
        XCTAssertEqual(sut.moves, 0)
    }

    func test_tap_sameTileTwice_isIgnoredOnSecond() async {
        let sut = await makeLoadedSUT()
        sut.tap(at: 0)
        sut.tap(at: 0)
        XCTAssertEqual(sut.firstPickIndex, 0)
        XCTAssertEqual(sut.moves, 0)
    }

    // MARK: - Matching

    func test_tap_matchingPair_marksMatchedAndCountsMove() async {
        let sut = await makeLoadedSUT()
        let (a, b) = pairIndices(sut, key: keys(sut)[0])
        sut.tap(at: a)
        sut.tap(at: b)
        XCTAssertTrue(sut.tiles[a].isMatched)
        XCTAssertTrue(sut.tiles[b].isMatched)
        XCTAssertEqual(sut.matchedCount, 1)
        XCTAssertEqual(sut.moves, 1)
        XCTAssertNil(sut.firstPickIndex)
        XCTAssertFalse(sut.isResolving)
    }

    // MARK: - Mismatch

    func test_tap_mismatch_entersResolvingThenFlipsBack() async {
        let sut = await makeLoadedSUT()
        let (a, b) = mismatchIndices(sut)
        sut.tap(at: a)
        sut.tap(at: b)
        XCTAssertEqual(sut.moves, 1)
        XCTAssertTrue(sut.isResolving)
        XCTAssertEqual(sut.matchedCount, 0)
        XCTAssertEqual(sut.mismatches, 1)

        // Flip-back наступает через 700мс. Ждём состояние (а не фиксированную
        // задержку) — под нагрузкой симулятора жёсткий sleep даёт флаки.
        await waitUntil(timeout: 3.0) { !sut.isResolving }
        XCTAssertFalse(sut.isResolving)
        XCTAssertFalse(sut.tiles[a].isFlipped)
        XCTAssertFalse(sut.tiles[b].isFlipped)
        XCTAssertNil(sut.firstPickIndex)
    }

    /// Опрашивает условие до выполнения либо до таймаута (шаг 25мс).
    /// Возвращает управление MainActor между проверками, давая unstructured
    /// Task интерактора (`@MainActor`) выполнить flip-back.
    private func waitUntil(
        timeout: TimeInterval,
        _ condition: () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    // MARK: - Completion

    func test_matchingAllPairs_setsComplete() async {
        let sut = await makeLoadedSUT()
        for key in keys(sut) {
            let (a, b) = pairIndices(sut, key: key)
            sut.tap(at: a)
            sut.tap(at: b)
        }
        XCTAssertTrue(sut.isComplete)
        XCTAssertEqual(sut.matchedCount, sut.pairCount)
        XCTAssertEqual(sut.moves, sut.pairCount)
        XCTAssertEqual(sut.stars, 3) // без промахов
    }

    // MARK: - Bounds

    func test_tap_outOfBoundsIndex_isIgnored() async {
        let sut = await makeLoadedSUT()
        sut.tap(at: 999)
        XCTAssertNil(sut.firstPickIndex)
        XCTAssertEqual(sut.moves, 0)
    }

    // MARK: - words()

    func test_words_fallbackWhenNoManifest() {
        let words = AudioMemoryGameInteractor.words(forTargetSounds: [])
        XCTAssertGreaterThanOrEqual(words.count, AudioMemoryGameModels.pairCount)
    }
}
