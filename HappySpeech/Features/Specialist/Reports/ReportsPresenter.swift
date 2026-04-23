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
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }()

    func presentFetchReport(_ response: ReportsModels.FetchReport.Response) async {
        let s = response.summary
        let vm = ReportsModels.FetchReport.ViewModel(
            titleText: String(localized: "reports.title"),
            rangeLabel: String(localized: "reports.range.last30"),
            totalSessionsText: String(localized: "reports.metric.sessions.\(s.totalSessions)"),
            totalMinutesText: String(localized: "reports.metric.minutes.\(s.totalMinutes)"),
            overallSuccessPercent: Int(s.overallSuccessRate * 100),
            rows: response.soundBreakdown,
            timeline: response.sessionTimeline
        )
        display?.displayFetchReport(vm)
    }

    func presentExportReport(_ response: ReportsModels.ExportReport.Response) async {
        let mb = Double(response.bytes) / 1024.0
        let sizeText = mb < 1
            ? String(localized: "reports.size.bytes.\(response.bytes)")
            : String(format: "%.1f KB", mb)
        let vm = ReportsModels.ExportReport.ViewModel(
            shareableURL: response.fileURL,
            sizeText: sizeText
        )
        display?.displayExportReport(vm)
    }
}
