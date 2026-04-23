import XCTest
@testable import HappySpeech

// MARK: - ReportsAggregatorTests

final class ReportsAggregatorTests: XCTestCase {

    private func makeSession(
        id: String = UUID().uuidString,
        daysAgo: Int,
        sound: String = "Р",
        stage: String = "syllables",
        durationSec: Int = 600,
        total: Int = 10,
        correct: Int = 7,
        attempts: [AttemptDTO] = []
    ) -> SessionDTO {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return SessionDTO(
            id: id, childId: "c1", date: date, templateType: "listenAndChoose",
            targetSound: sound, stage: stage, durationSeconds: durationSec,
            totalAttempts: total, correctAttempts: correct,
            fatigueDetected: false, isSynced: false, attempts: attempts
        )
    }

    // MARK: - summarize

    func test_summarize_emptyList_zeros() {
        let s = ReportsAggregator.summarize(sessions: [])
        XCTAssertEqual(s.totalSessions, 0)
        XCTAssertEqual(s.totalMinutes, 0)
        XCTAssertEqual(s.overallSuccessRate, 0)
        XCTAssertTrue(s.improvedSounds.isEmpty)
    }

    func test_summarize_totalMinutes_divBy60() {
        let sessions = [makeSession(daysAgo: 1, durationSec: 600),
                        makeSession(daysAgo: 0, durationSec: 900)]
        let s = ReportsAggregator.summarize(sessions: sessions)
        XCTAssertEqual(s.totalMinutes, 25)     // 10 + 15
        XCTAssertEqual(s.totalSessions, 2)
    }

    func test_summarize_improvedSound_detected() {
        // Same sound, score improved from 0.3 to 0.9
        let early = makeSession(daysAgo: 10, sound: "Р", total: 10, correct: 3)
        let late  = makeSession(daysAgo: 0,  sound: "Р", total: 10, correct: 9)
        let s = ReportsAggregator.summarize(sessions: [early, late])
        XCTAssertTrue(s.improvedSounds.contains("Р"))
        XCTAssertFalse(s.strugglingSounds.contains("Р"))
    }

    func test_summarize_strugglingSound_detected() {
        let early = makeSession(daysAgo: 10, sound: "Л", total: 10, correct: 8)
        let late  = makeSession(daysAgo: 0,  sound: "Л", total: 10, correct: 4)
        let s = ReportsAggregator.summarize(sessions: [early, late])
        XCTAssertTrue(s.strugglingSounds.contains("Л"))
    }

    // MARK: - soundBreakdown

    func test_soundBreakdown_groupsAndSums() {
        let sessions = [
            makeSession(daysAgo: 2, sound: "Р", total: 5, correct: 3),
            makeSession(daysAgo: 1, sound: "Р", total: 7, correct: 5),
            makeSession(daysAgo: 0, sound: "Ш", total: 4, correct: 3),
        ]
        let rows = ReportsAggregator.soundBreakdown(sessions: sessions)
        XCTAssertEqual(rows.count, 2)
        let r = rows.first { $0.sound == "Р" }!
        XCTAssertEqual(r.attempts, 12)
        XCTAssertEqual(r.successes, 8)
    }

    // MARK: - timeline

    func test_timeline_sortedChronologically() {
        let sessions = [
            makeSession(daysAgo: 5, sound: "Р"),
            makeSession(daysAgo: 1, sound: "Ш"),
            makeSession(daysAgo: 3, sound: "Л"),
        ]
        let timeline = ReportsAggregator.timeline(sessions: sessions)
        XCTAssertEqual(timeline.count, 3)
        for i in 1..<timeline.count {
            XCTAssertLessThanOrEqual(timeline[i - 1].date, timeline[i].date)
        }
    }
}

// MARK: - ReportsDocumentFormatterTests

final class ReportsDocumentFormatterTests: XCTestCase {

    func test_CSV_hasHeader_andRowPerAttempt() {
        let attempt = AttemptDTO(
            id: "a1", word: "рыба", audioLocalPath: "", audioStoragePath: "",
            asrTranscript: "рыба", asrScore: 0.9, pronunciationScore: 0.85,
            manualScore: 0, isCorrect: true, timestamp: Date()
        )
        let session = SessionDTO(
            id: "s1", childId: "c1", date: Date(), templateType: "listenAndChoose",
            targetSound: "Р", stage: "syllables",
            durationSeconds: 600, totalAttempts: 1, correctAttempts: 1,
            fatigueDetected: false, isSynced: false, attempts: [attempt]
        )
        let csv = ReportsDocumentFormatter.makeCSV(sessions: [session])
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines.first!.hasPrefix("session_id,"))
    }

    func test_CSV_escapesCommaInWord() {
        let attempt = AttemptDTO(
            id: "a1", word: "ра,ма", audioLocalPath: "", audioStoragePath: "",
            asrTranscript: "рама", asrScore: 0.8, pronunciationScore: 0.7,
            manualScore: 0, isCorrect: true, timestamp: Date()
        )
        let session = SessionDTO(
            id: "s1", childId: "c1", date: Date(), templateType: "word",
            targetSound: "Р", stage: "words", durationSeconds: 300,
            totalAttempts: 1, correctAttempts: 1, fatigueDetected: false,
            isSynced: false, attempts: [attempt]
        )
        let csv = ReportsDocumentFormatter.makeCSV(sessions: [session])
        XCTAssertTrue(csv.contains("\"ра,ма\""))
    }

    func test_plaintextReport_containsSummaryNumbers() {
        let session = SessionDTO(
            id: "s1", childId: "c1", date: Date(), templateType: "test",
            targetSound: "Р", stage: "words", durationSeconds: 600,
            totalAttempts: 10, correctAttempts: 7, fatigueDetected: false,
            isSynced: false, attempts: []
        )
        let text = ReportsDocumentFormatter.makePlainTextReport(
            childId: "test-child", sessions: [session]
        )
        XCTAssertTrue(text.contains("test-child"))
        XCTAssertTrue(text.contains("Всего сессий: 1"))
    }
}
