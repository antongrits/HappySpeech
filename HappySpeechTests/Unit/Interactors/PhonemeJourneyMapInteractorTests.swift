@testable import HappySpeech
import XCTest

// MARK: - PhonemeJourneyMapInteractorTests
//
// Прогресс по этапам — РЕАЛЬНЫЙ (worker + репозитории). Тесты проверяют:
// честное пустое стартовое состояние, загрузку реального прогресса и чистое
// сопоставление CorrectionStage → стадии экрана (без фабрикации/toggle).

@MainActor
final class PhonemeJourneyMapInteractorTests: XCTestCase {

    private func session(
        id: String, child: String, sound: String, stage: CorrectionStage,
        total: Int, correct: Int
    ) -> SessionDTO {
        SessionDTO(
            id: id, childId: child, date: Date(),
            templateType: TemplateType.repeatAfterModel.rawValue, targetSound: sound,
            stage: stage.rawValue, durationSeconds: 200,
            totalAttempts: total, correctAttempts: correct, fatigueDetected: false,
            isSynced: false, attempts: []
        )
    }

    private func makeWorker(
        child: ChildProfileDTO,
        sessions: [SessionDTO]
    ) -> PhonemeJourneyMapWorker {
        let childRepo = MockChildRepository(children: [child])
        let sessionRepo = MockSessionRepository(sessions: sessions)
        return PhonemeJourneyMapWorker(sessionRepository: sessionRepo, childRepository: childRepo)
    }

    private func awaitLoad(_ sut: PhonemeJourneyMapInteractor) async {
        sut.load()
        // load() запускает Task; ждём отражения в state.
        for _ in 0..<40 where sut.state.targetSound.isEmpty {
            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    // MARK: - Initial state (честный empty)

    func test_initialState_isEmpty_noFabricatedProgress() {
        let sut = PhonemeJourneyMapInteractor(childId: "child-1")
        XCTAssertEqual(sut.state.progress, 0.0, accuracy: 0.0001)
        XCTAssertTrue(sut.state.stages.allSatisfy { !$0.isComplete })
    }

    func test_initialState_fiveStages() {
        let sut = PhonemeJourneyMapInteractor(childId: "child-1")
        XCTAssertEqual(sut.state.stages.count, PhonemeJourneyMapModels.Stage.allCases.count)
    }

    // MARK: - Real progress loading

    func test_load_realProgress_marksReachedStages() async {
        let child = ChildProfileDTO(
            id: "c1", name: "Миша", age: 6, targetSounds: ["Р"],
            parentId: "p1", progressSummary: ["Р": 0.5], currentStreak: 0
        )
        // Успешные сессии до этапа «слова» (wordInit) по звуку Р.
        let sessions = [
            session(id: "s1", child: "c1", sound: "Р", stage: .isolated, total: 10, correct: 9),
            session(id: "s2", child: "c1", sound: "Р", stage: .syllable, total: 10, correct: 8),
            session(id: "s3", child: "c1", sound: "Р", stage: .wordInit, total: 10, correct: 8)
        ]
        let worker = makeWorker(child: child, sessions: sessions)
        let sut = PhonemeJourneyMapInteractor(childId: "c1", worker: worker)
        await awaitLoad(sut)

        XCTAssertEqual(sut.state.targetSound, "Р")
        // isolated, syllables, words пройдены; phrases/freeSpeech — нет.
        func done(_ s: PhonemeJourneyMapModels.Stage) -> Bool {
            sut.state.stages.first { $0.id == s }?.isComplete ?? false
        }
        XCTAssertTrue(done(.isolated))
        XCTAssertTrue(done(.syllables))
        XCTAssertTrue(done(.words))
        XCTAssertFalse(done(.phrases))
        XCTAssertFalse(done(.freeSpeech))
    }

    func test_load_noSuccessfulSessions_allIncomplete() async {
        let child = ChildProfileDTO(
            id: "c1", name: "Соня", age: 5, targetSounds: ["С"],
            parentId: "p1", progressSummary: [:], currentStreak: 0
        )
        // Сессия с низкой точностью (< 70%) — этап НЕ засчитывается.
        let sessions = [session(id: "s1", child: "c1", sound: "С", stage: .syllable, total: 10, correct: 3)]
        let worker = makeWorker(child: child, sessions: sessions)
        let sut = PhonemeJourneyMapInteractor(childId: "c1", worker: worker)
        await awaitLoad(sut)
        XCTAssertTrue(sut.state.stages.allSatisfy { !$0.isComplete })
    }

    // MARK: - Pure mapping

    func test_completedStages_laterStageImpliesEarlier() {
        let sessions = [session(id: "s1", child: "c1", sound: "Л", stage: .phrase, total: 10, correct: 9)]
        let map = PhonemeJourneyMapWorker.completedStages(sessions: sessions, sound: "Л")
        // Достигнут этап «фразы» → все более ранние тоже пройдены.
        XCTAssertEqual(map[.isolated], true)
        XCTAssertEqual(map[.syllables], true)
        XCTAssertEqual(map[.words], true)
        XCTAssertEqual(map[.phrases], true)
        XCTAssertEqual(map[.freeSpeech], false)
    }

    func test_completedStages_otherSoundIgnored() {
        let sessions = [session(id: "s1", child: "c1", sound: "Ш", stage: .story, total: 10, correct: 10)]
        let map = PhonemeJourneyMapWorker.completedStages(sessions: sessions, sound: "Р")
        XCTAssertTrue(map.values.allSatisfy { $0 == false })
    }

    // MARK: - Stage model

    func test_stage_titleCaptionIcon_nonEmpty() {
        for stage in PhonemeJourneyMapModels.Stage.allCases {
            XCTAssertFalse(stage.title.isEmpty)
            XCTAssertFalse(stage.caption.isEmpty)
            XCTAssertFalse(stage.iconSystemName.isEmpty)
        }
    }
}
