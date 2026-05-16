@testable import HappySpeech
import XCTest

// MARK: - FAQRepositoryWorkerTests
//
// Покрывает: loadFAQ, loadVideos, videoExists.
// Данные — статический HelpCenterCorpus, без внешних зависимостей.

@MainActor
final class FAQRepositoryWorkerTests: XCTestCase {

    private var sut: FAQRepositoryWorker!

    override func setUp() {
        super.setUp()
        sut = FAQRepositoryWorker()
    }

    // MARK: - loadFAQ

    func test_loadFAQ_returnsNonEmptyList() async {
        let faqs = await sut.loadFAQ()
        XCTAssertFalse(faqs.isEmpty, "loadFAQ должен возвращать непустой список FAQ")
    }

    func test_loadFAQ_returnsAllCorpusFAQs() async {
        let faqs = await sut.loadFAQ()
        XCTAssertEqual(faqs.count, HelpCenterCorpus.faqs.count,
                       "Количество FAQ должно совпадать с корпусом")
    }

    func test_loadFAQ_entriesHaveNonEmptyIds() async {
        let faqs = await sut.loadFAQ()
        for entry in faqs {
            XCTAssertFalse(entry.id.isEmpty, "id FAQ не должен быть пустым: \(entry.questionKey)")
        }
    }

    func test_loadFAQ_entriesHaveNonEmptyQuestionKeys() async {
        let faqs = await sut.loadFAQ()
        for entry in faqs {
            XCTAssertFalse(entry.questionKey.isEmpty,
                           "questionKey не должен быть пустым для \(entry.id)")
        }
    }

    func test_loadFAQ_entriesHaveNonEmptyAnswerKeys() async {
        let faqs = await sut.loadFAQ()
        for entry in faqs {
            XCTAssertFalse(entry.answerKey.isEmpty,
                           "answerKey не должен быть пустым для \(entry.id)")
        }
    }

    func test_loadFAQ_categoriesCoverAllExpectedValues() async {
        let faqs = await sut.loadFAQ()
        let categories = Set(faqs.map { $0.category })
        XCTAssertTrue(categories.contains(.gettingStarted),
                      "Должна быть хотя бы одна запись gettingStarted")
        XCTAssertTrue(categories.contains(.voiceRecognition),
                      "Должна быть хотя бы одна запись voiceRecognition")
    }

    // MARK: - loadVideos

    func test_loadVideos_returnsSubsetOfCorpusVideos() async {
        let videos = await sut.loadVideos()
        // В тесте bundle нет видео, поэтому 0 или меньше полного корпуса — оба случая валидны.
        XCTAssertLessThanOrEqual(videos.count, HelpCenterCorpus.videos.count,
                                  "loadVideos должен вернуть не больше записей чем в корпусе")
    }

    func test_loadVideos_onlyIncludesVideosExistingInBundle() async {
        // Если бы несуществующий файл попадал — это баг.
        let videos = await sut.loadVideos()
        for video in videos {
            XCTAssertTrue(sut.videoExists(video.resourceName),
                          "Возвращённое видео должно существовать в bundle: \(video.resourceName)")
        }
    }

    // MARK: - videoExists

    func test_videoExists_returnsFalseForNonexistentResource() {
        let exists = sut.videoExists("nonexistent_video_xyz_12345")
        XCTAssertFalse(exists,
                       "Несуществующий ресурс не должен найтись в bundle")
    }

    func test_videoExists_returnsBoolForAnyString() {
        // Проверяем, что метод не крашит и возвращает bool для любой строки.
        let result = sut.videoExists("")
        // Результат зависит от bundle — проверяем только тип (Bool).
        _ = result as Bool
    }

    func test_videoExists_returnsFalseForAnotherInvalidResource() {
        let exists = sut.videoExists("tutorial_fake_00")
        XCTAssertFalse(exists)
    }
}
