@testable import HappySpeech
import XCTest

// MARK: - ImitationLabInteractorTests
//
// «Лаборатория подражания» (articulation-imitation): образцы отбираются под
// рабочие звуки ребёнка (ImitationLabContent). Цикл «послушать → повторить →
// отметить». Тесты покрывают сборку набора, проигрывание, отметку «получилось»,
// завершение и сброс.

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

    // MARK: - markPracticed

    func test_markPracticed_marksSample() async {
        let sut = await makeLoadedSUT()
        let id = sut.state.samples[0].id
        sut.markPracticed(id)
        XCTAssertEqual(sut.state.samples.first { $0.id == id }?.isPracticed, true)
        XCTAssertEqual(sut.state.practicedCount, 1)
    }

    func test_markPracticed_twice_idempotent() async {
        let sut = await makeLoadedSUT()
        let id = sut.state.samples[0].id
        sut.markPracticed(id)
        sut.markPracticed(id)
        XCTAssertEqual(sut.state.practicedCount, 1)
    }

    func test_practicingAll_completesAndStars() async {
        let sut = await makeLoadedSUT()
        for sample in sut.state.samples { sut.markPracticed(sample.id) }
        XCTAssertTrue(sut.state.isComplete)
        XCTAssertEqual(sut.state.stars, 3)
    }

    // MARK: - reset

    func test_reset_clearsProgress() async {
        let sut = await makeLoadedSUT()
        let id = sut.state.samples[0].id
        sut.playSample(id)
        sut.markPracticed(id)
        sut.reset()
        XCTAssertNil(sut.state.currentSampleId)
        XCTAssertEqual(sut.state.practicedCount, 0)
        XCTAssertTrue(sut.state.samples.allSatisfy { !$0.isPlayed && !$0.isPracticed })
    }
}
