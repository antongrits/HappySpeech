@testable import HappySpeech
import XCTest

// MARK: - ReadAloudStoryWorkerTests
//
// Фаза E, Волна 8. Покрывает чистый выбор истории: pickStory(excluding:) =
// делегат к ReadAloudStoryCorpus.randomStory (исключение указанного id), и
// libraryCount = размер корпуса. speakSentence / stopSpeaking — тонкая обёртка
// над AVAudioPlayer (hardware/bundle audio side): покрываем лишь безопасный
// no-op для пустого текста (ранний return до обращения к аудио), отмечено ниже.
// Озвучивание реального файла в unit-тестах не запускается.

@MainActor
final class ReadAloudStoryWorkerTests: XCTestCase {

    private func makeSUT() -> ReadAloudStoryWorker {
        ReadAloudStoryWorker()
    }

    // MARK: - libraryCount

    func test_libraryCount_matchesCorpus() {
        let sut = makeSUT()
        XCTAssertEqual(sut.libraryCount, ReadAloudStoryCorpus.allStories.count)
    }

    func test_libraryCount_isNonNegative() {
        let sut = makeSUT()
        XCTAssertGreaterThanOrEqual(sut.libraryCount, 0)
    }

    // MARK: - pickStory

    func test_pickStory_returnsCorpusStoryOrNilWhenEmpty() {
        let sut = makeSUT()
        let story = sut.pickStory(excluding: nil)
        if ReadAloudStoryCorpus.allStories.isEmpty {
            XCTAssertNil(story, "Пустой корпус → nil")
        } else {
            XCTAssertNotNil(story)
            XCTAssertNotNil(ReadAloudStoryCorpus.story(id: story!.id),
                            "Выбранная история принадлежит корпусу")
        }
    }

    func test_pickStory_excludingAvoidsIdWhenAlternativesExist() throws {
        let sut = makeSUT()
        let stories = ReadAloudStoryCorpus.allStories
        // Имеет смысл только при ≥2 историях: тогда исключённую можно избежать.
        guard stories.count >= 2, let excluded = stories.first?.id else {
            throw XCTSkip("Недостаточно историй в корпусе для проверки исключения")
        }
        for _ in 0..<20 {
            let picked = sut.pickStory(excluding: excluded)
            XCTAssertNotEqual(picked?.id, excluded,
                              "При наличии альтернатив исключённая история не выбирается")
        }
    }

    // MARK: - speakSentence (thin wrapper — only safe no-op path)

    func test_speakSentence_emptyText_isNoOp() async {
        // Пустой текст → ранний return до обращения к аудиосессии/файлу.
        // Тонкая обёртка над AVAudioPlayer не вызывается; тест лишь
        // подтверждает безопасный быстрый выход без падения.
        let sut = makeSUT()
        await sut.speakSentence("", storyId: "any", sentenceIndex: 1)
        sut.stopSpeaking() // повторный stop без активного плеера безопасен
    }

    // MARK: - ReadAloudStoryCorpus

    func test_corpus_storyIdsAreUnique() {
        let ids = ReadAloudStoryCorpus.allStories.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_corpus_randomStory_excludingSingleReturnsFallbackFirst() throws {
        // randomStory исключает id, но при пустом пуле падает на allStories.first.
        let stories = ReadAloudStoryCorpus.allStories
        guard stories.count == 1, let only = stories.first else {
            throw XCTSkip("Тест актуален только для корпуса из 1 истории")
        }
        XCTAssertEqual(ReadAloudStoryCorpus.randomStory(excluding: only.id)?.id, only.id)
    }

    func test_corpus_story_unknownIdReturnsNil() {
        XCTAssertNil(ReadAloudStoryCorpus.story(id: "no-such-id"))
    }
}
