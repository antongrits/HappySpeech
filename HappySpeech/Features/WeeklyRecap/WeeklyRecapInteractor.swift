import Foundation
import OSLog

// MARK: - WeeklyRecapInteractor

/// Тонкий VIP (@Observable). Источник данных — РЕАЛЬНЫЙ недельный агрегат
/// из `ProgressDashboardWorker` (`SessionRepository` + `ChildRepository`).
///
/// До загрузки и для ребёнка без сессий — честное пустое состояние
/// (`ViewState.empty`), никаких выдуманных KPI. `share()` для пустого
/// состояния отдаёт нейтральный текст, а не вымысел.
@MainActor
@Observable
final class WeeklyRecapInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WeeklyRecap"
    )

    var state: WeeklyRecapModels.ViewState = .empty

    private let worker: (any ProgressDashboardAggregating)?

    init(worker: (any ProgressDashboardAggregating)? = nil) {
        self.worker = worker
    }

    /// Загрузить реальные агрегаты за неделю.
    func load(childId: String) async {
        guard !childId.isEmpty else {
            Self.logger.info("load: empty childId — keep empty state")
            state = .empty
            return
        }
        guard let worker else {
            Self.logger.info("load: no worker — keep empty state")
            state = .empty
            return
        }
        let aggregate = await worker.aggregate(childId: childId, period: .week)
        state = WeeklyRecapModels.makeState(from: aggregate)
        Self.logger.info("load: kpis=\(self.state.kpis.count, privacy: .public) empty=\(self.state.isEmpty, privacy: .public)")
    }

    func share() -> String {
        Self.logger.info("Weekly recap share requested")
        return WeeklyRecapModels.shareText(state)
    }
}
