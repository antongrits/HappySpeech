@testable import HappySpeech
import XCTest

// MARK: - MusicalSoundDrumsInteractorTests
//
// Логоритмическая игра «Звуковые барабаны»: Ляля показывает рисунок из слогов
// рабочего звука, ребёнок повторяет, нажимая барабаны по громкости. Тесты
// покрывают сборку рисунка, верный/неверный удар, прогресс по рисунку,
// завершение раунда/игры и контент-генератор.

@MainActor
final class MusicalSoundDrumsInteractorTests: XCTestCase {

    private func makeLoadedSUT(childId: String = "") async -> MusicalSoundDrumsInteractor {
        let sut = MusicalSoundDrumsInteractor(childId: childId)
        await sut.load()
        return sut
    }

    // MARK: - Init / load

    func test_init_storesChildId() {
        let sut = MusicalSoundDrumsInteractor(childId: "kid-drum")
        XCTAssertEqual(sut.childId, "kid-drum")
    }

    func test_load_buildsPattern() async {
        let sut = await makeLoadedSUT()
        XCTAssertTrue(sut.state.isLoaded)
        XCTAssertFalse(sut.state.pattern.isEmpty)
        XCTAssertEqual(sut.state.progressIndex, 0)
        XCTAssertFalse(sut.state.patternText.isEmpty)
    }

    // MARK: - Content generator

    func test_content_patternMatchesSound() {
        let pattern = MusicalSoundDrumsContent.pattern(for: "С", length: 3)
        XCTAssertEqual(pattern.count, 3)
        XCTAssertTrue(pattern.allSatisfy { $0.text.uppercased().hasPrefix("С") })
    }

    func test_content_lengthGrowsByRound() {
        XCTAssertEqual(MusicalSoundDrumsContent.length(forRound: 0), 3)
        XCTAssertEqual(MusicalSoundDrumsContent.length(forRound: 2), 4)
        XCTAssertEqual(MusicalSoundDrumsContent.length(forRound: 3), 5)
    }

    // MARK: - tap

    func test_tap_correctDrum_advancesProgress() async {
        let sut = await makeLoadedSUT()
        let expected = sut.expectedSyllable!.drum
        sut.tap(expected)
        XCTAssertEqual(sut.state.progressIndex, 1)
        XCTAssertEqual(sut.state.correctTaps, 1)
        XCTAssertEqual(sut.state.lastDrumId, expected)
    }

    func test_tap_wrongDrum_doesNotAdvance() async {
        let sut = await makeLoadedSUT()
        let expected = sut.expectedSyllable!.drum
        let wrong = MusicalSoundDrumsModels.DrumId.allCases.first { $0 != expected }!
        sut.tap(wrong)
        XCTAssertEqual(sut.state.progressIndex, 0)
        XCTAssertEqual(sut.state.correctTaps, 0)
        XCTAssertEqual(sut.state.totalTaps, 1)
    }

    func test_tap_completesRound() async {
        let sut = await makeLoadedSUT()
        // Проходим весь рисунок верными ударами.
        while let exp = sut.expectedSyllable {
            sut.tap(exp.drum)
        }
        XCTAssertTrue(sut.state.roundComplete)
        XCTAssertEqual(sut.state.roundsPlayed, 1)
    }

    // MARK: - nextRound

    func test_nextRound_loadsNewPattern() async {
        let sut = await makeLoadedSUT()
        while let exp = sut.expectedSyllable { sut.tap(exp.drum) }
        sut.nextRound()
        XCTAssertFalse(sut.state.roundComplete)
        XCTAssertEqual(sut.state.progressIndex, 0)
        XCTAssertFalse(sut.state.pattern.isEmpty)
    }

    func test_playingAllRounds_completesGame() async {
        let sut = await makeLoadedSUT()
        for _ in 0..<MusicalSoundDrumsInteractor.totalRounds {
            while let exp = sut.expectedSyllable { sut.tap(exp.drum) }
            if !sut.isGameComplete { sut.nextRound() }
        }
        XCTAssertTrue(sut.isGameComplete)
        XCTAssertEqual(sut.state.roundsPlayed, MusicalSoundDrumsInteractor.totalRounds)
    }

    // MARK: - reset

    func test_reset_restartsPattern() async {
        let sut = await makeLoadedSUT()
        sut.tap(sut.expectedSyllable!.drum)
        sut.reset()
        XCTAssertEqual(sut.state.progressIndex, 0)
        XCTAssertEqual(sut.state.roundsPlayed, 0)
        XCTAssertEqual(sut.state.totalTaps, 0)
    }
}
