@testable import HappySpeech
import XCTest

// MARK: - ImitationLabInteractorTests
//
// ImitationLabInteractor is a thin VIP MVP variant (@Observable). Its only action
// is playSample(_:), which marks the matching sample as played and records it as
// the current sample. Tests cover the initial seed, the play mutation, the
// unknown-id guard and that previously-played samples stay played.

@MainActor
final class ImitationLabInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> ImitationLabInteractor {
        ImitationLabInteractor(childId: childId)
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-imitate")
        XCTAssertEqual(sut.childId, "kid-imitate")
    }

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_noCurrentSample() {
        let sut = makeSUT()
        XCTAssertNil(sut.state.currentSampleId)
    }

    func test_initialState_noSamplePlayed() {
        let sut = makeSUT()
        XCTAssertTrue(sut.state.samples.allSatisfy { !$0.isPlayed })
    }

    func test_initialState_samplesAreWellFormed() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.samples.isEmpty)
        XCTAssertEqual(Set(sut.state.samples.map(\.id)).count, sut.state.samples.count,
                       "sample ids must be unique")
        for sample in sut.state.samples {
            XCTAssertFalse(sample.name.isEmpty)
            XCTAssertFalse(sample.emoji.isEmpty)
            XCTAssertFalse(sample.onomatopoeia.isEmpty)
        }
    }

    // MARK: - playSample

    func test_playSample_marksSamplePlayed() {
        let sut = makeSUT()
        let id = sut.state.samples[0].id
        sut.playSample(id)
        let played = sut.state.samples.first { $0.id == id }
        XCTAssertEqual(played?.isPlayed, true)
    }

    func test_playSample_setsCurrentSampleId() {
        let sut = makeSUT()
        let id = sut.state.samples[2].id
        sut.playSample(id)
        XCTAssertEqual(sut.state.currentSampleId, id)
    }

    func test_playSample_doesNotAffectOtherSamples() {
        let sut = makeSUT()
        let id = sut.state.samples[0].id
        sut.playSample(id)
        let others = sut.state.samples.filter { $0.id != id }
        XCTAssertTrue(others.allSatisfy { !$0.isPlayed })
    }

    func test_playSample_unknownId_noMutation() {
        let sut = makeSUT()
        sut.playSample("does-not-exist")
        XCTAssertNil(sut.state.currentSampleId)
        XCTAssertTrue(sut.state.samples.allSatisfy { !$0.isPlayed })
    }

    func test_playSample_secondSample_keepsFirstPlayed() {
        let sut = makeSUT()
        let first = sut.state.samples[0].id
        let second = sut.state.samples[1].id
        sut.playSample(first)
        sut.playSample(second)
        XCTAssertEqual(sut.state.samples.first { $0.id == first }?.isPlayed, true)
        XCTAssertEqual(sut.state.samples.first { $0.id == second }?.isPlayed, true)
        XCTAssertEqual(sut.state.currentSampleId, second)
    }

    func test_playSample_sameTwice_remainsPlayed() {
        let sut = makeSUT()
        let id = sut.state.samples[0].id
        sut.playSample(id)
        sut.playSample(id)
        XCTAssertEqual(sut.state.samples.first { $0.id == id }?.isPlayed, true)
        XCTAssertEqual(sut.state.currentSampleId, id)
    }
}
