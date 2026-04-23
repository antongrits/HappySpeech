import Foundation

// MARK: - ReportsModels
//
// VIP models for the specialist "Reports" tab. Generates periodic summaries
// of a child's progress for handoff to a parent or another specialist.
//
// Supported export formats:
//   • PDF  — via PDFKit (handled by `SpecialistExportService.generatePDF`)
//   • CSV  — attempt-level tabular dump for spreadsheet analysis

enum ReportsModels {

    // MARK: FetchReport
    enum FetchReport {
        struct Request {
            let childId: String
            let range: DateRange
        }
        struct Response {
            let summary: ReportSummary
            let soundBreakdown: [SoundBreakdownRow]
            let sessionTimeline: [SessionTimelineEntry]
        }
        struct ViewModel: Equatable {
            let titleText: String
            let rangeLabel: String
            let totalSessionsText: String
            let totalMinutesText: String
            let overallSuccessPercent: Int
            let rows: [SoundBreakdownRow]
            let timeline: [SessionTimelineEntry]
        }
    }

    // MARK: ExportReport
    enum ExportReport {
        enum Format: String, Sendable, CaseIterable {
            case pdf
            case csv
        }
        struct Request {
            let childId: String
            let range: DateRange
            let format: Format
        }
        struct Response {
            let fileURL: URL
            let bytes: Int
        }
        struct ViewModel: Equatable {
            let shareableURL: URL
            let sizeText: String
        }
    }
}

// MARK: - Domain

struct DateRange: Sendable, Equatable {
    let start: Date
    let end: Date

    static func lastNDays(_ days: Int, now: Date = Date()) -> DateRange {
        let end = now
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
        return DateRange(start: start, end: end)
    }

    static func last7days(now: Date = Date()) -> DateRange  { .lastNDays(7,  now: now) }
    static func last30days(now: Date = Date()) -> DateRange { .lastNDays(30, now: now) }
}

struct ReportSummary: Sendable, Equatable {
    let totalSessions: Int
    let totalMinutes: Int
    let overallSuccessRate: Double    // 0.0 … 1.0
    let improvedSounds: [String]
    let strugglingSounds: [String]
}

struct SoundBreakdownRow: Identifiable, Sendable, Equatable, Hashable {
    var id: String { sound }
    let sound: String
    let attempts: Int
    let successes: Int
    let averageConfidence: Double     // 0.0 … 1.0
    let currentStageTitle: String
    let weekOverWeekDelta: Double     // +0.05 = +5pp
}

struct SessionTimelineEntry: Identifiable, Sendable, Equatable, Hashable {
    var id: String { "\(date.timeIntervalSince1970)" }
    let date: Date
    let durationMinutes: Int
    let activityCount: Int
    let averageScore: Double
}
