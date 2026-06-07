@testable import HappySpeech
import XCTest

// MARK: - SpecialistScheduleInteractorTests
//
// SpecialistScheduleInteractor loads REAL schedule slots through
// SpecialistScheduleWorker (children from ChildRepository + assigned homework
// due dates). No fabricated slots: `.initial` is empty + loading; load() fills
// from the worker. Tests use a mock worker to cover the empty case, the populated
// case, weekday auto-selection, the slotsFor filter and the select mutation.

@MainActor
final class SpecialistScheduleInteractorTests: XCTestCase {

    private typealias Weekday = SpecialistScheduleModels.Weekday

    // MARK: - Mock worker

    private final class MockScheduleWorker: SpecialistScheduleWorkerProtocol {
        var slots: [SpecialistScheduleModels.Slot] = []
        private(set) var loadCalledWith: String?

        func loadSlots(specialistId: String) async -> [SpecialistScheduleModels.Slot] {
            loadCalledWith = specialistId
            return slots
        }
    }

    private func makeSlot(
        id: String,
        weekday: Weekday,
        name: String,
        topic: String = "Звук Р"
    ) -> SpecialistScheduleModels.Slot {
        // Build a concrete date matching the requested weekday in the current week.
        let calendar = Calendar.current
        let now = Date()
        let interval = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        // weekday.rawValue: mon=1 … sun=7 → offset from week start.
        let date = calendar.date(byAdding: .day, value: weekday.rawValue - 1, to: interval) ?? now
        return SpecialistScheduleModels.Slot(
            id: id,
            weekday: weekday,
            date: date,
            time: "10:00",
            childName: name,
            topic: topic
        )
    }

    private func makeSUT(
        worker: MockScheduleWorker
    ) -> SpecialistScheduleInteractor {
        SpecialistScheduleInteractor(specialistId: "spec-1", worker: worker)
    }

    // MARK: - Init

    func test_init_storesSpecialistId() {
        let sut = makeSUT(worker: MockScheduleWorker())
        XCTAssertEqual(sut.specialistId, "spec-1")
    }

    func test_initialState_isEmptyAndLoading_noFabrication() {
        let sut = makeSUT(worker: MockScheduleWorker())
        XCTAssertTrue(sut.state.slots.isEmpty)
        XCTAssertTrue(sut.state.isLoading)
    }

    // MARK: - load (empty)

    func test_load_emptyWorker_keepsEmptyAndStopsLoading() async {
        let worker = MockScheduleWorker()
        let sut = makeSUT(worker: worker)
        await sut.load()
        XCTAssertTrue(sut.state.slots.isEmpty)
        XCTAssertFalse(sut.state.isLoading)
        XCTAssertEqual(worker.loadCalledWith, "spec-1")
    }

    // MARK: - load (populated)

    func test_load_populatesRealSlots() async {
        let worker = MockScheduleWorker()
        worker.slots = [
            makeSlot(id: "a", weekday: .tue, name: "Real Child"),
            makeSlot(id: "b", weekday: .tue, name: "Real Child 2"),
            makeSlot(id: "c", weekday: .thu, name: "Real Child 3")
        ]
        let sut = makeSUT(worker: worker)
        await sut.load()
        XCTAssertEqual(sut.state.slots.count, 3)
        XCTAssertFalse(sut.state.isLoading)
    }

    func test_load_autoSelectsDayWithSlots_whenSelectedEmpty() async {
        let worker = MockScheduleWorker()
        worker.slots = [makeSlot(id: "a", weekday: .sat, name: "Real Child")]
        let sut = makeSUT(worker: worker)
        await sut.load()
        XCTAssertEqual(sut.state.slotsFor(.sat).count, 1)
        XCTAssertFalse(sut.state.slotsFor(sut.state.selectedWeekday).isEmpty)
    }

    // MARK: - slotsFor

    func test_slotsFor_returnsOnlyThatWeekday() async {
        let worker = MockScheduleWorker()
        worker.slots = [
            makeSlot(id: "a", weekday: .mon, name: "C1"),
            makeSlot(id: "b", weekday: .wed, name: "C2")
        ]
        let sut = makeSUT(worker: worker)
        await sut.load()
        XCTAssertEqual(sut.state.slotsFor(.mon).count, 1)
        XCTAssertTrue(sut.state.slotsFor(.mon).allSatisfy { $0.weekday == .mon })
        XCTAssertTrue(sut.state.slotsFor(.sun).isEmpty)
    }

    func test_slotsFor_partitionCoversAllSlots() async {
        let worker = MockScheduleWorker()
        worker.slots = [
            makeSlot(id: "a", weekday: .mon, name: "C1"),
            makeSlot(id: "b", weekday: .fri, name: "C2"),
            makeSlot(id: "c", weekday: .fri, name: "C3")
        ]
        let sut = makeSUT(worker: worker)
        await sut.load()
        let recombined = Weekday.allCases.flatMap { sut.state.slotsFor($0) }
        XCTAssertEqual(recombined.count, sut.state.slots.count)
    }

    // MARK: - select

    func test_select_updatesSelectedWeekday() {
        let sut = makeSUT(worker: MockScheduleWorker())
        sut.select(.thu)
        XCTAssertEqual(sut.state.selectedWeekday, .thu)
    }

    func test_select_doesNotMutateSlots() async {
        let worker = MockScheduleWorker()
        worker.slots = [makeSlot(id: "a", weekday: .mon, name: "C1")]
        let sut = makeSUT(worker: worker)
        await sut.load()
        let before = sut.state.slots
        sut.select(.fri)
        XCTAssertEqual(sut.state.slots, before)
    }

    func test_select_eachWeekday() {
        let sut = makeSUT(worker: MockScheduleWorker())
        for weekday in Weekday.allCases {
            sut.select(weekday)
            XCTAssertEqual(sut.state.selectedWeekday, weekday)
        }
    }

    // MARK: - Weekday mapping

    func test_weekday_fromCalendarWeekday() {
        XCTAssertEqual(Weekday.from(calendarWeekday: 1), .sun)
        XCTAssertEqual(Weekday.from(calendarWeekday: 2), .mon)
        XCTAssertEqual(Weekday.from(calendarWeekday: 7), .sat)
    }
}
