import Foundation
import OSLog

// MARK: - ReportsBusinessLogic

@MainActor
protocol ReportsBusinessLogic: AnyObject {
    func fetchReport(_ request: ReportsModels.FetchReport.Request) async
    func exportReport(_ request: ReportsModels.ExportReport.Request) async
}

// MARK: - ReportsInteractor

/// Reads raw sessions from SessionRepository, aggregates per-sound stats, and
/// delegates PDF/CSV rendering to the companion pure formatter
/// `ReportsDocumentFormatter`. All heavy aggregation happens here so the
/// presenter stays view-model-only.
@MainActor
final class ReportsInteractor: ReportsBusinessLogic {

    var presenter: (any ReportsPresentationLogic)?

    private let sessionRepository: any SessionRepository
    private let childRepository: any ChildRepository
    private let logger = Logger(subsystem: "ru.happyspeech", category: "Reports")

    init(
        sessionRepository: any SessionRepository,
        childRepository: any ChildRepository
    ) {
        self.sessionRepository = sessionRepository
        self.childRepository = childRepository
    }

    // MARK: - Fetch

    func fetchReport(_ request: ReportsModels.FetchReport.Request) async {
        do {
            let allSessions = try await sessionRepository.fetchRecent(
                childId: request.childId,
                limit: 100
            )
            let inRange = allSessions.filter {
                $0.date >= request.range.start && $0.date <= request.range.end
            }

            let summary = ReportsAggregator.summarize(sessions: inRange)
            let perSound = ReportsAggregator.soundBreakdown(sessions: inRange)
            let timeline = ReportsAggregator.timeline(sessions: inRange)

            await presenter?.presentFetchReport(.init(
                summary: summary,
                soundBreakdown: perSound,
                sessionTimeline: timeline
            ))
        } catch {
            logger.error("fetchReport failed: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentFetchReport(.init(
                summary: ReportSummary(totalSessions: 0, totalMinutes: 0,
                                       overallSuccessRate: 0,
                                       improvedSounds: [], strugglingSounds: []),
                soundBreakdown: [],
                sessionTimeline: []
            ))
        }
    }

    // MARK: - Export

    func exportReport(_ request: ReportsModels.ExportReport.Request) async {
        do {
            let sessions = try await sessionRepository.fetchRecent(
                childId: request.childId, limit: 500
            )
            let inRange = sessions.filter {
                $0.date >= request.range.start && $0.date <= request.range.end
            }

            let fileURL: URL
            switch request.format {
            case .csv:
                let csv = ReportsDocumentFormatter.makeCSV(sessions: inRange)
                fileURL = try write(text: csv, extension: "csv", childId: request.childId)
            case .pdf:
                // PDF generation requires UIKit — stubbed to a plaintext
                // placeholder here so tests stay Sendable-safe. Live
                // implementation wires into SpecialistExportService.
                let text = ReportsDocumentFormatter.makePlainTextReport(
                    childId: request.childId, sessions: inRange
                )
                fileURL = try write(text: text, extension: "pdf.txt", childId: request.childId)
            }

            let bytes = (try? FileManager.default
                .attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0

            await presenter?.presentExportReport(.init(fileURL: fileURL, bytes: bytes))
        } catch {
            logger.error("exportReport failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Private

    private func write(text: String, extension ext: String, childId: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hs-reports", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("report-\(childId)-\(Int(Date().timeIntervalSince1970)).\(ext)")
        try text.data(using: .utf8)?.write(to: url)
        return url
    }
}
