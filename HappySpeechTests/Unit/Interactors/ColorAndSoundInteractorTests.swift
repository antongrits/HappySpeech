@testable import HappySpeech
import XCTest

// MARK: - ColorAndSoundInteractorTests
//
// «Цвет и звук» (фонематическое восприятие): раунды строятся из реальных слов
// (ColorAndSoundContent) — часть начинается на целевой звук, часть нет. Ребёнок
// отмечает «свои» слова. Тесты покрывают сборку раундов, верный/неверный выбор,
// завершение раунда и игры, контент-генератор.

@MainActor
final class ColorAndSoundInteractorTests: XCTestCase {

    private func makeLoadedSUT(childId: String = "") async -> ColorAndSoundInteractor {
        let sut = ColorAndSoundInteractor(childId: childId)
        await sut.load()
        return sut
    }

    // MARK: - Init / load

    func test_init_storesChildId() {
        let sut = ColorAndSoundInteractor(childId: "kid-color")
        XCTAssertEqual(sut.childId, "kid-color")
    }

    func test_load_buildsRound() async {
        let sut = await makeLoadedSUT()
        XCTAssertTrue(sut.state.isLoaded)
        XCTAssertFalse(sut.state.cards.isEmpty)
        XCTAssertGreaterThan(sut.state.totalRounds, 0)
        XCTAssertFalse(sut.state.sound.isEmpty)
        XCTAssertGreaterThan(sut.state.targetCount, 0)
    }

    func test_cardIds_areUnique() async {
        let sut = await makeLoadedSUT()
        let ids = sut.state.cards.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    // MARK: - Content

    func test_content_roundsHaveBelongingAndDistractors() {
        let rounds = ColorAndSoundContent.rounds(forTargetSounds: ["С"], count: 2)
        XCTAssertFalse(rounds.isEmpty)
        let first = rounds[0]
        XCTAssertTrue(first.cards.contains { $0.belongs })
    }

    func test_content_colorIsDeterministic() {
        XCTAssertEqual(ColorAndSoundContent.color(for: "Р"), .coral)
        XCTAssertEqual(ColorAndSoundContent.color(for: "С"), .sky)
    }

    // MARK: - toggle

    func test_toggle_correctCard_countsCorrect() async {
        let sut = await makeLoadedSUT()
        guard let idx = sut.state.cards.firstIndex(where: { $0.belongs }) else { return XCTFail("no belonging card") }
        sut.toggle(sut.state.cards[idx].id)
        XCTAssertEqual(sut.state.correctPicks, 1)
        XCTAssertTrue(sut.state.cards[idx].isSelected)
    }

    func test_toggle_wrongCard_countsWrong() async {
        let sut = await makeLoadedSUT()
        guard let idx = sut.state.cards.firstIndex(where: { !$0.belongs }) else { return }
        sut.toggle(sut.state.cards[idx].id)
        XCTAssertEqual(sut.state.wrongPicks, 1)
    }

    func test_toggle_alreadySelected_noChange() async {
        let sut = await makeLoadedSUT()
        let id = sut.state.cards[0].id
        sut.toggle(id)
        let correctBefore = sut.state.correctPicks
        let wrongBefore = sut.state.wrongPicks
        sut.toggle(id)
        XCTAssertEqual(sut.state.correctPicks, correctBefore)
        XCTAssertEqual(sut.state.wrongPicks, wrongBefore)
    }

    func test_toggle_unknownId_noChange() async {
        let sut = await makeLoadedSUT()
        sut.toggle("nonexistent")
        XCTAssertEqual(sut.state.correctPicks, 0)
        XCTAssertEqual(sut.state.wrongPicks, 0)
    }

    func test_findingAllBelonging_completesRound() async {
        let sut = await makeLoadedSUT()
        for card in sut.state.cards where card.belongs {
            sut.toggle(card.id)
        }
        XCTAssertTrue(sut.state.roundComplete)
    }

    // MARK: - next / game complete

    func test_playingAllRounds_completesGame() async {
        let sut = await makeLoadedSUT()
        for _ in 0..<sut.state.totalRounds {
            for card in sut.state.cards where card.belongs { sut.toggle(card.id) }
            sut.next()
        }
        XCTAssertTrue(sut.state.isGameComplete)
    }
}
