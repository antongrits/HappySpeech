import Foundation
import OSLog

@MainActor
final class DailyTimeCapInteractor {

    private let presenter: DailyTimeCapPresenter
    private let tracker: any DailyUsageTracking
    private let logger = Logger(subsystem: "ru.happyspeech", category: "DailyTimeCap.Interactor")

    init(presenter: DailyTimeCapPresenter, tracker: any DailyUsageTracking) {
        self.presenter = presenter
        self.tracker = tracker
    }

    // MARK: - Read

    func loadStatus() async {
        await emitStatus()
    }

    // MARK: - Mutations

    func setEnabled(_ enabled: Bool) async {
        tracker.isCapEnabled = enabled
        logger.info("setEnabled \(enabled, privacy: .public)")
        await emitStatus()
    }

    func setCap(minutes: Int) async {
        tracker.capMinutes = minutes
        logger.info("setCap minutes=\(minutes, privacy: .public)")
        await emitStatus()
    }

    /// Тестовая утилита — позволяет напрямую записать использование (используется
    /// в Interactor-тестах). В production tracker сам аккумулирует через lifecycle.
    func recordUsage(seconds: TimeInterval) async {
        if let mock = tracker as? MockDailyUsageTracker {
            mock.setUsageSeconds(seconds)
        }
        await emitStatus()
    }

    // MARK: - Status

    /// Текущий снимок use-кейса. Удобно для CapReachedView, которая
    /// читает только статус без mutation.
    func currentStatus() -> DailyTimeCapModels.Status.Response {
        DailyTimeCapModels.Status.Response(
            isEnabled: tracker.isCapEnabled,
            capMinutes: tracker.capMinutes,
            usedSeconds: tracker.todayUsageSeconds()
        )
    }

    // MARK: - Helpers

    private func emitStatus() async {
        await presenter.presentStatus(response: currentStatus())
    }
}
