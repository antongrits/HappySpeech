@testable import HappySpeech
import XCTest
import UIKit

// MARK: - Test Doubles

private final class WBMockHapticService: HapticService, @unchecked Sendable {
    var impactCount = 0
    var selectionCount = 0
    var notificationCount = 0
    var isAvailable: Bool { true }

    func play(pattern: HapticPattern) async {}
    func setIntensityScale(_ scale: Float) {}
    func stop() async {}
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) { impactCount += 1 }
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) { notificationCount += 1 }
    func selection() { selectionCount += 1 }
    func playLevelUp() async {}
}

private struct WBMockWorker: WordBankWorkerProtocol {
    var stats: [BankWordStat]
    var shouldFail = false

    func fetchWordStats(childId: String) async throws -> [BankWordStat] {
        if shouldFail { throw AppError.entityNotFound(childId) }
        return stats
    }
}

@MainActor
private final class WBSpyPresenter: WordBankPresentationLogic {
    var loadCalled = false
    var filterCalled = false
    var selectWordCalled = false
    var practiceCalled = false

    var lastLoad: WordBankModels.Load.Response?
    var lastFilter: WordBankModels.Filter.Response?
    var lastSelect: WordBankModels.SelectWord.Response?
    var lastPractice: WordBankModels.Practice.Request?

    func presentLoad(response: WordBankModels.Load.Response) async {
        loadCalled = true
        lastLoad = response
    }
    func presentFilter(response: WordBankModels.Filter.Response) async {
        filterCalled = true
        lastFilter = response
    }
    func presentSelectWord(response: WordBankModels.SelectWord.Response) async {
        selectWordCalled = true
        lastSelect = response
    }
    func presentPractice(request: WordBankModels.Practice.Request) async {
        practiceCalled = true
        lastPractice = request
    }
}

// MARK: - Builders

private func wbStat(
    word: String,
    sound: String,
    score: Double,
    attempts: Int = 3,
    correct: Int = 2
) -> BankWordStat {
    BankWordStat(
        id: word + "_" + sound,
        word: word,
        targetSound: sound,
        avgScore: score,
        attemptCount: attempts,
        lastPracticedAt: Date(),
        isCorrectCount: correct
    )
}

private func wbAttempt(word: String, correct: Bool, score: Double) -> AttemptDTO {
    AttemptDTO(
        id: UUID().uuidString, word: word, audioLocalPath: "", audioStoragePath: "",
        asrTranscript: word, asrScore: score, pronunciationScore: -1, manualScore: -1,
        isCorrect: correct, timestamp: Date()
    )
}

private func wbSession(sound: String, attempts: [AttemptDTO]) -> SessionDTO {
    SessionDTO(
        id: UUID().uuidString, childId: "child-1", date: Date(), templateType: "bingo",
        targetSound: sound, stage: "wordInit", durationSeconds: 300,
        totalAttempts: attempts.count, correctAttempts: attempts.filter(\.isCorrect).count,
        fatigueDetected: false, isSynced: false, attempts: attempts
    )
}

// MARK: - Tests

@MainActor
final class WordBankInteractorTests: XCTestCase {

    private func makeSUT(
        stats: [BankWordStat] = [],
        shouldFail: Bool = false
    ) -> (WordBankInteractor, WBSpyPresenter, MockAnalyticsService, WBMockHapticService) {
        let analytics = MockAnalyticsService()
        let haptic = WBMockHapticService()
        let sut = WordBankInteractor(
            childId: "child-1",
            worker: WBMockWorker(stats: stats, shouldFail: shouldFail),
            analyticsService: analytics,
            hapticService: haptic
        )
        let spy = WBSpyPresenter()
        sut.presenter = spy
        return (sut, spy, analytics, haptic)
    }

    // MARK: loadBank

    func test_loadBank_callsPresenter() async {
        let (sut, spy, _, _) = makeSUT(stats: [wbStat(word: "шапка", sound: "Ш", score: 0.9)])
        await sut.loadBank(request: .init(childId: "child-1"))
        XCTAssertTrue(spy.loadCalled)
        XCTAssertEqual(spy.lastLoad?.wordStats.count, 1)
    }

    func test_loadBank_storesStats() async {
        let (sut, _, _, _) = makeSUT(stats: [
            wbStat(word: "шапка", sound: "Ш", score: 0.9),
            wbStat(word: "роза", sound: "Р", score: 0.7)
        ])
        await sut.loadBank(request: .init(childId: "child-1"))
        XCTAssertEqual(sut.allStats.count, 2)
    }

    func test_loadBank_tracksOpenedEvent() async {
        let (sut, _, analytics, _) = makeSUT()
        await sut.loadBank(request: .init(childId: "child-1"))
        XCTAssertTrue(analytics.events.contains { $0.name == "word_bank_opened" })
    }

    func test_loadBank_failure_returnsEmpty() async {
        let (sut, spy, _, _) = makeSUT(stats: [wbStat(word: "x", sound: "Ш", score: 0.9)], shouldFail: true)
        await sut.loadBank(request: .init(childId: "child-1"))
        XCTAssertTrue(spy.loadCalled)
        XCTAssertEqual(spy.lastLoad?.wordStats.count, 0)
        XCTAssertTrue(sut.allStats.isEmpty)
    }

    // MARK: filterBySound

    func test_filterBySound_nil_returnsAll() async {
        let (sut, spy, _, _) = makeSUT(stats: [
            wbStat(word: "шапка", sound: "Ш", score: 0.9),
            wbStat(word: "роза", sound: "Р", score: 0.7)
        ])
        await sut.loadBank(request: .init(childId: "child-1"))
        await sut.filterBySound(request: .init(soundTarget: nil))
        XCTAssertEqual(spy.lastFilter?.filtered.count, 2)
    }

    func test_filterBySound_specificSound_filters() async {
        let (sut, spy, _, _) = makeSUT(stats: [
            wbStat(word: "шапка", sound: "Ш", score: 0.9),
            wbStat(word: "шуба", sound: "Ш", score: 0.6),
            wbStat(word: "роза", sound: "Р", score: 0.7)
        ])
        await sut.loadBank(request: .init(childId: "child-1"))
        await sut.filterBySound(request: .init(soundTarget: "Ш"))
        XCTAssertEqual(spy.lastFilter?.filtered.count, 2)
        XCTAssertTrue(spy.lastFilter?.filtered.allSatisfy { $0.targetSound == "Ш" } ?? false)
    }

    func test_filterBySound_storesSelectedFilter() async {
        let (sut, _, _, _) = makeSUT(stats: [wbStat(word: "роза", sound: "Р", score: 0.7)])
        await sut.loadBank(request: .init(childId: "child-1"))
        await sut.filterBySound(request: .init(soundTarget: "Р"))
        XCTAssertEqual(sut.selectedFilter, "Р")
    }

    // MARK: selectWord

    func test_selectWord_unknownId_ignored() async {
        let (sut, spy, _, _) = makeSUT(stats: [wbStat(word: "шапка", sound: "Ш", score: 0.9)])
        await sut.loadBank(request: .init(childId: "child-1"))
        await sut.selectWord(request: .init(wordId: "nonexistent"))
        XCTAssertFalse(spy.selectWordCalled)
    }

    func test_selectWord_validId_callsPresenter() async {
        let stat = wbStat(word: "шапка", sound: "Ш", score: 0.9)
        let (sut, spy, _, _) = makeSUT(stats: [stat])
        await sut.loadBank(request: .init(childId: "child-1"))
        await sut.selectWord(request: .init(wordId: stat.id))
        XCTAssertTrue(spy.selectWordCalled)
        XCTAssertEqual(spy.lastSelect?.stat.word, "шапка")
    }

    func test_selectWord_threeStars_firesMediumImpact() async {
        let stat = wbStat(word: "шапка", sound: "Ш", score: 0.9) // ≥0.8 → 3 звезды
        let (sut, _, _, haptic) = makeSUT(stats: [stat])
        await sut.loadBank(request: .init(childId: "child-1"))
        await sut.selectWord(request: .init(wordId: stat.id))
        XCTAssertEqual(haptic.impactCount, 1)
        XCTAssertEqual(haptic.selectionCount, 0)
    }

    func test_selectWord_lowStars_firesSelection() async {
        let stat = wbStat(word: "шуба", sound: "Ш", score: 0.5) // <0.6 → 1 звезда
        let (sut, _, _, haptic) = makeSUT(stats: [stat])
        await sut.loadBank(request: .init(childId: "child-1"))
        await sut.selectWord(request: .init(wordId: stat.id))
        XCTAssertEqual(haptic.selectionCount, 1)
        XCTAssertEqual(haptic.impactCount, 0)
    }

    // MARK: practiceWord

    func test_practiceWord_callsPresenter() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.practiceWord(request: .init(word: "шапка", targetSound: "Ш"))
        XCTAssertTrue(spy.practiceCalled)
        XCTAssertEqual(spy.lastPractice?.word, "шапка")
    }

    func test_practiceWord_tracksEvent() async {
        let (sut, _, analytics, _) = makeSUT()
        await sut.practiceWord(request: .init(word: "роза", targetSound: "Р"))
        let event = analytics.events.first { $0.name == "word_practiced_from_bank" }
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.parameters["targetSound"], "Р")
    }

    // MARK: Worker aggregation (static)

    func test_aggregate_groupsByWordAndSound() {
        let session = wbSession(sound: "Ш", attempts: [
            wbAttempt(word: "шапка", correct: true, score: 0.8),
            wbAttempt(word: "шапка", correct: true, score: 0.6),
            wbAttempt(word: "шуба", correct: true, score: 0.9)
        ])
        let stats = WordBankWorker.aggregate(sessions: [session])
        XCTAssertEqual(stats.count, 2)
        let shapka = stats.first { $0.word == "шапка" }
        XCTAssertEqual(shapka?.attemptCount, 2)
        XCTAssertEqual(shapka?.avgScore ?? 0, 0.7, accuracy: 0.001)
    }

    func test_aggregate_excludesWordsWithoutCorrectAttempt() {
        let session = wbSession(sound: "Ш", attempts: [
            wbAttempt(word: "шуба", correct: false, score: 0.4),
            wbAttempt(word: "шуба", correct: false, score: 0.3)
        ])
        let stats = WordBankWorker.aggregate(sessions: [session])
        XCTAssertTrue(stats.isEmpty)
    }

    func test_aggregate_includesWordWithAtLeastOneCorrect() {
        let session = wbSession(sound: "Ш", attempts: [
            wbAttempt(word: "шуба", correct: false, score: 0.4),
            wbAttempt(word: "шуба", correct: true, score: 0.9)
        ])
        let stats = WordBankWorker.aggregate(sessions: [session])
        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats.first?.isCorrectCount, 1)
        XCTAssertEqual(stats.first?.attemptCount, 2)
    }

    func test_aggregate_ignoresEmptyWords() {
        let session = wbSession(sound: "Ш", attempts: [
            wbAttempt(word: "", correct: true, score: 0.9)
        ])
        let stats = WordBankWorker.aggregate(sessions: [session])
        XCTAssertTrue(stats.isEmpty)
    }

    func test_aggregate_sameWordDifferentSounds_separateBuckets() {
        let s1 = wbSession(sound: "Ш", attempts: [wbAttempt(word: "коса", correct: true, score: 0.8)])
        let s2 = wbSession(sound: "С", attempts: [wbAttempt(word: "коса", correct: true, score: 0.9)])
        let stats = WordBankWorker.aggregate(sessions: [s1, s2])
        XCTAssertEqual(stats.count, 2)
    }

    func test_aggregate_lastPracticedIsMaxTimestamp() {
        let early = AttemptDTO(
            id: "1", word: "роза", audioLocalPath: "", audioStoragePath: "",
            asrTranscript: "роза", asrScore: 0.8, pronunciationScore: -1, manualScore: -1,
            isCorrect: true, timestamp: Date(timeIntervalSince1970: 1_000)
        )
        let late = AttemptDTO(
            id: "2", word: "роза", audioLocalPath: "", audioStoragePath: "",
            asrTranscript: "роза", asrScore: 0.9, pronunciationScore: -1, manualScore: -1,
            isCorrect: true, timestamp: Date(timeIntervalSince1970: 9_000)
        )
        let session = wbSession(sound: "Р", attempts: [early, late])
        let stats = WordBankWorker.aggregate(sessions: [session])
        XCTAssertEqual(stats.first?.lastPracticedAt, Date(timeIntervalSince1970: 9_000))
    }
}
