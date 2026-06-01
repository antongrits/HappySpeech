@testable import HappySpeech
import XCTest

// MARK: - SentenceBuilderKidInteractorTests
//
// «Собери предложение»: предложения берутся из SentenceBuilderKidContent под
// рабочий звук ребёнка; игра многораундовая. Тесты покрывают перемещение чипов,
// проверку порядка (isCorrect/isFull), переход к следующему предложению, сброс
// и контент-каталог.

@MainActor
final class SentenceBuilderKidInteractorTests: XCTestCase {

    private func makeLoadedSUT(childId: String = "") async -> SentenceBuilderKidInteractor {
        let sut = SentenceBuilderKidInteractor(childId: childId)
        await sut.load()
        return sut
    }

    /// Собирает предложение в правильном порядке независимо от перемешивания.
    private func assembleInCorrectOrder(_ sut: SentenceBuilderKidInteractor) {
        let total = sut.state.correctCount
        for slot in 0..<total {
            guard let chip = sut.state.available.first(where: { $0.order == slot }) else { continue }
            sut.pickFromAvailable(chip.id)
        }
    }

    // MARK: - Init / load

    func test_init_storesChildId() {
        let sut = SentenceBuilderKidInteractor(childId: "kid-99")
        XCTAssertEqual(sut.childId, "kid-99")
    }

    func test_load_buildsFirstSentence() async {
        let sut = await makeLoadedSUT()
        XCTAssertTrue(sut.state.isLoaded)
        XCTAssertTrue(sut.state.assembled.isEmpty)
        XCTAssertFalse(sut.state.available.isEmpty)
        XCTAssertGreaterThan(sut.state.totalSentences, 0)
        XCTAssertFalse(sut.state.isFull)
        XCTAssertFalse(sut.state.isCorrect)
    }

    // MARK: - Content

    func test_content_sentencesMatchSound() {
        let sentences = SentenceBuilderKidContent.sentences(for: "Р", count: 4)
        XCTAssertFalse(sentences.isEmpty)
        XCTAssertEqual(sentences.first?.sound.uppercased(), "Р")
        XCTAssertFalse(sentences.first?.words.isEmpty ?? true)
    }

    // MARK: - pick / remove

    func test_pick_movesChipFromAvailableToAssembled() async {
        let sut = await makeLoadedSUT()
        let chip = sut.state.available[0]
        sut.pickFromAvailable(chip.id)
        XCTAssertFalse(sut.state.available.contains(chip))
        XCTAssertEqual(sut.state.assembled.last, chip)
    }

    func test_pick_unknownId_noChange() async {
        let sut = await makeLoadedSUT()
        let beforeAvailable = sut.state.available.count
        sut.pickFromAvailable(UUID())
        XCTAssertEqual(sut.state.available.count, beforeAvailable)
        XCTAssertTrue(sut.state.assembled.isEmpty)
    }

    func test_remove_movesChipBackToAvailable() async {
        let sut = await makeLoadedSUT()
        let chip = sut.state.available[0]
        sut.pickFromAvailable(chip.id)
        sut.removeFromAssembled(chip.id)
        XCTAssertTrue(sut.state.available.contains(chip))
        XCTAssertFalse(sut.state.assembled.contains(chip))
    }

    // MARK: - isFull / isCorrect

    func test_isCorrect_trueWhenAssembledInRightOrder() async {
        let sut = await makeLoadedSUT()
        assembleInCorrectOrder(sut)
        XCTAssertTrue(sut.state.isFull)
        XCTAssertTrue(sut.state.isCorrect)
        XCTAssertEqual(sut.state.solvedCount, 1)
    }

    func test_isCorrect_falseWhenReversed() async {
        let sut = await makeLoadedSUT()
        let total = sut.state.correctCount
        guard total > 1 else { return }
        for slot in stride(from: total - 1, through: 0, by: -1) {
            if let chip = sut.state.available.first(where: { $0.order == slot }) {
                sut.pickFromAvailable(chip.id)
            }
        }
        XCTAssertTrue(sut.state.isFull)
        XCTAssertFalse(sut.state.isCorrect)
    }

    // MARK: - next

    func test_next_advancesSentence() async {
        let sut = await makeLoadedSUT()
        guard sut.state.totalSentences > 1 else { return }
        assembleInCorrectOrder(sut)
        sut.next()
        XCTAssertEqual(sut.state.sentenceIndex, 1)
        XCTAssertTrue(sut.state.assembled.isEmpty)
    }

    func test_playingAllSentences_completesGame() async {
        let sut = await makeLoadedSUT()
        for _ in 0..<sut.state.totalSentences {
            assembleInCorrectOrder(sut)
            sut.next()
        }
        XCTAssertTrue(sut.state.isGameComplete)
    }

    // MARK: - reset

    func test_reset_clearsAssembled() async {
        let sut = await makeLoadedSUT()
        assembleInCorrectOrder(sut)
        sut.reset()
        XCTAssertTrue(sut.state.assembled.isEmpty)
        XCTAssertFalse(sut.state.available.isEmpty)
    }
}
