import Foundation

// MARK: - ReportsPresentationLogic

@MainActor
protocol ReportsPresentationLogic: AnyObject {
    func presentFetchReport(_ response: ReportsModels.FetchReport.Response) async
    func presentExportReport(_ response: ReportsModels.ExportReport.Response) async
}

// MARK: - ReportsDisplayLogic

@MainActor
protocol ReportsDisplayLogic: AnyObject {
    func displayFetchReport(_ viewModel: ReportsModels.FetchReport.ViewModel)
    func displayExportReport(_ viewModel: ReportsModels.ExportReport.ViewModel)
}

// MARK: - ReportsPresenter

@MainActor
final class ReportsPresenter: ReportsPresentationLogic {

    weak var display: (any ReportsDisplayLogic)?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()

    func presentFetchReport(_ response: ReportsModels.FetchReport.Response) async {
        let summary = response.summary
        let sessionsFormat = String(localized: "reports.metric.sessions.format")
        let minutesFormat = String(localized: "reports.metric.minutes.format")
        let viewModel = ReportsModels.FetchReport.ViewModel(
            titleText: String(localized: "reports.title"),
            rangeLabel: String(localized: "reports.range.last30"),
            totalSessionsText: String(format: sessionsFormat, summary.totalSessions),
            totalMinutesText: String(format: minutesFormat, summary.totalMinutes),
            overallSuccessPercent: Int(summary.overallSuccessRate * 100),
            rows: response.soundBreakdown,
            timeline: response.sessionTimeline
        )
        display?.displayFetchReport(viewModel)
    }

    func presentExportReport(_ response: ReportsModels.ExportReport.Response) async {
        let mb = Double(response.bytes) / 1024.0
        let bytesFormat = String(localized: "reports.size.bytes.format")
        let sizeText = mb < 1
            ? String(format: bytesFormat, response.bytes)
            : String(format: "%.1f KB", mb)
        let vm = ReportsModels.ExportReport.ViewModel(
            shareableURL: response.fileURL,
            sizeText: sizeText
        )
        display?.displayExportReport(vm)
    }
}
