import Foundation
import OSLog

// MARK: - SpecialistScheduleInteractor (Clean Swift: Interactor)
//
// Бизнес-логика расписания специалиста. Реальные данные грузятся через
// `SpecialistScheduleWorker` (дети из ChildRepository + назначенные задания);
// без фабрикации слотов.

@MainActor
@Observable
final class SpecialistScheduleInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpecialistSchedule"
    )

    let specialistId: String
    var state: SpecialistScheduleModels.ViewState

    private let worker: any SpecialistScheduleWorkerProtocol

    init(
        specialistId: String,
        worker: any SpecialistScheduleWorkerProtocol
    ) {
        self.specialistId = specialistId
        self.worker = worker
        self.state = .initial
    }

    func load() async {
        state.isLoading = true
        let slots = await worker.loadSlots(specialistId: specialistId)
        state.slots = slots
        state.isLoading = false
        // Если в выбранном дне пусто, но занятия есть — переключиться на
        // ближайший день с занятиями (для осмысленного первого кадра).
        if state.slotsFor(state.selectedWeekday).isEmpty,
           let firstDay = SpecialistScheduleModels.Weekday.allCases
               .first(where: { !state.slotsFor($0).isEmpty }) {
            state.selectedWeekday = firstDay
        }
        Self.logger.info("Loaded \(slots.count) real schedule slots")
    }

    func select(_ weekday: SpecialistScheduleModels.Weekday) {
        state.selectedWeekday = weekday
        Self.logger.info("select weekday \(weekday.rawValue)")
    }
}
