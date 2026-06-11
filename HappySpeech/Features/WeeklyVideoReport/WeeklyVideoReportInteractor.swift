import Foundation
import OSLog

// MARK: - WeeklyVideoReportInteractor
//
// Тонкий VIP (@Observable). Источник данных — РЕАЛЬНЫЙ недельный агрегат из
// `ProgressDashboardWorker` (`SessionRepository`) + имя ребёнка из
// `ChildRepository`. До загрузки и для ребёнка без сессий — честное пустое
// состояние (`ViewState.empty`), никаких выдуманных чисел в оверлее.

@MainActor
@Observable
final class WeeklyVideoReportInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WeeklyVideoReport"
    )

    var state: WeeklyVideoReportModels.ViewState = .empty

    private let worker: (any ProgressDashboardAggregating)?
    private let childRepository: (any ChildRepository)?

    init(
        worker: (any ProgressDashboardAggregating)? = nil,
        childRepository: (any ChildRepository)? = nil
    ) {
        self.worker = worker
        self.childRepository = childRepository
    }

    func load(childId: String) async {
        guard !childId.isEmpty, let worker else {
            Self.logger.info("load: empty childId or no worker — keep empty state")
            state = .empty
            return
        }

        let aggregate = await worker.aggregate(childId: childId, period: .week)
        let childName = (try? await childRepository?.fetch(id: childId).name) ?? ""

        let response = WeeklyVideoReportModels.Load.Response(
            aggregate: aggregate,
            childName: childName,
            weekLabel: WeeklyVideoReportModels.currentWeekLabel()
        )
        state = WeeklyVideoReportModels.makeState(from: response)
        Self.logger.info(
            "load: empty=\(self.state.isEmpty, privacy: .public) sounds=\(self.state.sounds.count, privacy: .public)"
        )
    }
}
