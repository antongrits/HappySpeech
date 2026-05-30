@testable import HappySpeech
import XCTest

// MARK: - SpecialistScheduleInteractorTests
//
// SpecialistScheduleInteractor is a thin VIP MVP variant (@Observable). It holds a
// fixed weekly slot list and a selected weekday; select(_:) updates the selection.
// Tests cover the seed (well-formedness, weekday coverage), the selection mutation
// and the slotsFor(_:) filter (incl. an empty weekday).
// (Weekday.shortTitle map is purely presentational — intentionally skipped.)

@MainActor
final class SpecialistScheduleInteractorTests: XCTestCase {

    private typealias Weekday = SpecialistScheduleModels.Weekday

    private func makeSUT() -> SpecialistScheduleInteractor {
        SpecialistScheduleInteractor(specialistId: "spec-1")
    }

    // MARK: - Init / seed

    func test_init_storesSpecialistId() {
        let sut = SpecialistScheduleInteractor(specialistId: "s-77")
        XCTAssertEqual(sut.specialistId, "s-77")
    }

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
        XCTAssertEqual(sut.state.selectedWeekday, .mon)
    }

    func test_initialState_slotsWellFormed() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.slots.isEmpty)
        XCTAssertEqual(Set(sut.state.slots.map(\.id)).count, sut.state.slots.count)
        for slot in sut.state.slots {
            XCTAssertFalse(slot.time.isEmpty)
            XCTAssertFalse(slot.childName.isEmpty)
            XCTAssertFalse(slot.topic.isEmpty)
        }
    }

    // MARK: - select

    func test_select_updatesSelectedWeekday() {
        let sut = makeSUT()
        sut.select(.thu)
        XCTAssertEqual(sut.state.selectedWeekday, .thu)
    }

    func test_select_doesNotMutateSlots() {
        let sut = makeSUT()
        let before = sut.state.slots
        sut.select(.fri)
        XCTAssertEqual(sut.state.slots, before)
    }

    func test_select_eachWeekday() {
        let sut = makeSUT()
        for weekday in Weekday.allCases {
            sut.select(weekday)
            XCTAssertEqual(sut.state.selectedWeekday, weekday)
        }
    }

    // MARK: - slotsFor

    func test_slotsFor_returnsOnlyThatWeekday() {
        let sut = makeSUT()
        for weekday in Weekday.allCases {
            let subset = sut.state.slotsFor(weekday)
            XCTAssertTrue(subset.allSatisfy { $0.weekday == weekday })
        }
    }

    func test_slotsFor_emptyWeekday_returnsEmpty() {
        let sut = makeSUT()
        // No slots are seeded for Sunday in the initial schedule.
        XCTAssertTrue(sut.state.slotsFor(.sun).isEmpty)
    }

    func test_slotsFor_partitionCoversAllSlots() {
        let sut = makeSUT()
        let recombined = Weekday.allCases.flatMap { sut.state.slotsFor($0) }
        XCTAssertEqual(recombined.count, sut.state.slots.count)
    }

    func test_slotsFor_mondayHasMultiple() {
        let sut = makeSUT()
        XCTAssertGreaterThan(sut.state.slotsFor(.mon).count, 1)
    }
}
