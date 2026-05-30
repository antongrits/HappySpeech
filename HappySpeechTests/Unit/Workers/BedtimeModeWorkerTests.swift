@testable import HappySpeech
import XCTest

// MARK: - BedtimeModeWorkerTests
//
// Фаза E, Волна 7. Покрывает логику выбора истории и параметров дыхания
// BedtimeModeWorker. Narration — тонкая обёртка над AVAudioPlayer (без
// bundled-аудио в тест-таргете), поэтому покрываются только проверки
// валидации входа и безопасного stop без активного плеера.

@MainActor
final class BedtimeModeWorkerTests: XCTestCase {

    private func makeSUT() -> BedtimeModeWorker { BedtimeModeWorker() }

    // MARK: - libraryCount / pickStory

    func test_libraryCount_matchesCorpus() {
        let sut = makeSUT()
        XCTAssertEqual(sut.libraryCount, BedtimeModeCorpus.allStories.count)
    }

    func test_pickStory_withNilExclusion_returnsStoryWhenCorpusNonEmpty() {
        let sut = makeSUT()
        guard !BedtimeModeCorpus.allStories.isEmpty else {
            // В тест-таргете bundled JSON может отсутствовать — корпус пуст.
            XCTAssertNil(sut.pickStory(excluding: nil))
            return
        }
        XCTAssertNotNil(sut.pickStory(excluding: nil))
    }

    func test_pickStory_excludingSingleStory_returnsThatStoryAsFallback() throws {
        let sut = makeSUT()
        // Если в корпусе ровно одна история и её исключают — corpus fallback
        // всё равно отдаёт её (см. BedtimeModeCorpus.randomStory).
        let stories = BedtimeModeCorpus.allStories
        guard stories.count == 1, let only = stories.first else {
            throw XCTSkip("Тест актуален только для корпуса из 1 истории")
        }
        let picked = sut.pickStory(excluding: only.id)
        XCTAssertEqual(picked?.id, only.id)
    }

    func test_pickStory_excludingId_neverReturnsExcludedWhenAlternativesExist() throws {
        let sut = makeSUT()
        let stories = BedtimeModeCorpus.allStories
        guard stories.count >= 2, let first = stories.first else {
            throw XCTSkip("Нужно ≥2 историй в корпусе")
        }
        // Многократный прогон: исключённая история не должна выпадать,
        // пока есть альтернативы.
        for _ in 0..<50 {
            let picked = sut.pickStory(excluding: first.id)
            XCTAssertNotEqual(picked?.id, first.id)
        }
    }

    // MARK: - breathingCycle (методические дефолты 4-4-6, 3 цикла)

    func test_breathingCycle_defaultParameters() {
        let sut = makeSUT()
        let cycle = sut.breathingCycle()
        XCTAssertEqual(cycle.inhaleSeconds, 4)
        XCTAssertEqual(cycle.holdSeconds, 4)
        XCTAssertEqual(cycle.exhaleSeconds, 6)
        XCTAssertEqual(cycle.totalCycles, 3)
    }

    func test_breathingCycle_isEquatableAndStable() {
        let sut = makeSUT()
        XCTAssertEqual(sut.breathingCycle(), sut.breathingCycle())
    }

    // MARK: - narrate input validation / stop safety

    func test_narrate_emptyText_returnsImmediatelyWithoutCrash() async {
        let sut = makeSUT()
        // Пустой текст → ранний return (см. guard в narrate).
        await sut.narrate("", storyId: "story-cloud")
    }

    func test_narrate_unknownStoryId_silentSkipWithoutCrash() async {
        let sut = makeSUT()
        // Неизвестный storyId → нет файла → silent skip (без аудио в тестах).
        await sut.narrate("Спокойной ночи", storyId: "totally-unknown-id")
    }

    func test_stopNarration_withoutActivePlayer_doesNotCrash() {
        let sut = makeSUT()
        sut.stopNarration()
        sut.stopNarration()
    }
}
