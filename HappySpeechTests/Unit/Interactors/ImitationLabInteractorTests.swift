@testable import HappySpeech
import XCTest

// MARK: - ImitationLabInteractorTests
//
// «Лаборатория подражания» (articulation-imitation): образцы отбираются под
// рабочие звуки ребёнка (ImitationLabContent). Цикл «послушать образец →
// повторить вслух → реальная оценка произношения». Тесты покрывают сборку
// набора, проигрывание, фиксацию РЕАЛЬНОГО результата (recordResult — seam без
// живого микрофона), пороги звёзд по среднему баллу, завершение и сброс.

@MainActor
final class ImitationLabInteractorTests: XCTestCase {

    private func makeLoadedSUT(childId: String = "") async -> ImitationLabInteractor {
        let sut = ImitationLabInteractor(childId: childId)
        await sut.load()
        return sut
    }

    // MARK: - Init / load

    func test_init_storesChildId() {
        let sut = ImitationLabInteractor(childId: "kid-imitate")
        XCTAssertEqual(sut.childId, "kid-imitate")
    }

    func test_load_buildsSamples() async {
        let sut = await makeLoadedSUT()
        XCTAssertTrue(sut.state.isLoaded)
        XCTAssertNil(sut.state.currentSampleId)
        XCTAssertFalse(sut.state.samples.isEmpty)
        XCTAssertTrue(sut.state.samples.allSatisfy { !$0.isPlayed && !$0.isPracticed })
    }

    func test_samples_areWellFormed() async {
        let sut = await makeLoadedSUT()
        XCTAssertEqual(Set(sut.state.samples.map(\.id)).count, sut.state.samples.count)
        for sample in sut.state.samples {
            XCTAssertFalse(sample.name.isEmpty)
            XCTAssertFalse(sample.emoji.isEmpty)
            XCTAssertFalse(sample.onomatopoeia.isEmpty)
            XCTAssertFalse(sample.soundFamily.isEmpty)
        }
    }

    func test_content_prioritisesTargetSounds() {
        let samples = ImitationLabContent.samples(forTargetSounds: ["Ш"])
        XCTAssertEqual(samples.first?.soundFamily, "Ш")
    }

    // MARK: - playSample

    func test_playSample_marksPlayedAndCurrent() async {
        let sut = await makeLoadedSUT()
        let id = sut.state.samples[0].id
        sut.playSample(id)
        XCTAssertEqual(sut.state.samples.first { $0.id == id }?.isPlayed, true)
        XCTAssertEqual(sut.state.currentSampleId, id)
    }

    func test_playSample_unknownId_noMutation() async {
        let sut = await makeLoadedSUT()
        sut.playSample("does-not-exist")
        XCTAssertNil(sut.state.currentSampleId)
        XCTAssertTrue(sut.state.samples.allSatisfy { !$0.isPlayed })
    }

    // MARK: - recordResult (реальная оценка)

    func test_recordResult_passingScore_marksPracticedAndPassed() async {
        let sut = await makeLoadedSUT()
        let id = sut.state.samples[0].id
        sut.recordResult(id: id, score: 0.85)
        let sample = sut.state.samples.first { $0.id == id }
        XCTAssertEqual(sample?.isPracticed, true)
        XCTAssertEqual(sample?.didPass, true)
        XCTAssertEqual(sample?.score, 0.85)
        XCTAssertEqual(sut.state.practicedCount, 1)
        XCTAssertEqual(sut.state.passedCount, 1)
    }

    func test_recordResult_lowScore_practicedButNotPassed() async {
        let sut = await makeLoadedSUT()
        let id = sut.state.samples[0].id
        sut.recordResult(id: id, score: 0.30)
        let sample = sut.state.samples.first { $0.id == id }
        XCTAssertEqual(sample?.isPracticed, true)
        XCTAssertEqual(sample?.didPass, false)
        XCTAssertEqual(sut.state.passedCount, 0)
    }

    func test_recordResult_twice_idempotent() async {
        let sut = await makeLoadedSUT()
        let id = sut.state.samples[0].id
        sut.recordResult(id: id, score: 0.9)
        sut.recordResult(id: id, score: 0.1) // повтор игнорируется
        XCTAssertEqual(sut.state.practicedCount, 1)
        XCTAssertEqual(sut.state.samples.first { $0.id == id }?.score, 0.9)
    }

    // MARK: - Stars по реальному среднему баллу

    func test_stars_threeForHighAverage() async {
        let sut = await makeLoadedSUT()
        for sample in sut.state.samples { sut.recordResult(id: sample.id, score: 0.95) }
        XCTAssertTrue(sut.state.isComplete)
        XCTAssertEqual(sut.state.stars, 3)
    }

    func test_stars_oneForLowAverage() async {
        let sut = await makeLoadedSUT()
        for sample in sut.state.samples { sut.recordResult(id: sample.id, score: 0.45) }
        XCTAssertTrue(sut.state.isComplete)
        XCTAssertEqual(sut.state.stars, 1)
    }

    func test_stars_zeroWhenNoScoredAttempts() async {
        let sut = await makeLoadedSUT()
        // Ничего не отработано (нет входного сигнала) → 0 звёзд, без фабрикации.
        XCTAssertEqual(sut.state.stars, 0)
    }

    func test_recordResult_unknownId_noMutation() async {
        let sut = await makeLoadedSUT()
        sut.recordResult(id: "nope", score: 0.9)
        XCTAssertEqual(sut.state.practicedCount, 0)
    }

    // MARK: - reset

    func test_reset_clearsProgress() async {
        let sut = await makeLoadedSUT()
        let id = sut.state.samples[0].id
        sut.playSample(id)
        sut.recordResult(id: id, score: 0.8)
        sut.reset()
        XCTAssertNil(sut.state.currentSampleId)
        XCTAssertEqual(sut.state.practicedCount, 0)
        XCTAssertEqual(sut.state.passedCount, 0)
        XCTAssertTrue(sut.state.samples.allSatisfy {
            !$0.isPlayed && !$0.isPracticed && $0.score == nil && !$0.didPass
        })
    }
}
