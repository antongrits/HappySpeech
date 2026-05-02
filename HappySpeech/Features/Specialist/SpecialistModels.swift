import Foundation

// MARK: - Specialist VIP Models
// A.20 v14: deep VIP — multi-child caseload, exports, LLM recommendations, notes

enum SpecialistModels {

    // MARK: - Fetch (загрузка списка детей)
    enum Fetch {
        struct Request {
            enum SortOrder: String, CaseIterable, Sendable {
                case byLastActivity = "По активности"
                case byName         = "По имени"
                case byProgress     = "По прогрессу"
            }
            var sortOrder: SortOrder = .byLastActivity
            var searchQuery: String  = ""
        }
        struct Response {
            let children: [ChildCaseEntry]
        }
        struct ViewModel: Equatable {
            struct ChildRow: Identifiable, Equatable {
                let id: String
                let name: String
                let ageLine: String
                let targetSounds: [String]
                let lastSessionLabel: String
                let overallProgressPercent: Int
                let needsAttentionSounds: [String]
            }
            let rows: [ChildRow]
            let sortLabel: String
        }
    }

    // MARK: - Update
    enum Update {
        struct Request {}
        struct Response {}
        struct ViewModel {}
    }

    // MARK: - FetchChildDashboard
    enum FetchChildDashboard {
        struct Request {
            let childId: String
        }
        struct Response {
            let child: ChildProfileDTO
            let recentSessions: [SessionDTO]
            let soundBreakdown: [SoundBreakdownRow]
            let summary: ReportSummary
            let llmReport: SpecialistReport?
        }
        struct ViewModel: Equatable {
            let childName: String
            let childAgeLine: String
            let totalSessionsText: String
            let totalMinutesText: String
            let overallPercentText: String
            let soundRows: [SoundProgressRow]
            let llmHeadline: String
            let llmStrengths: [String]
            let llmWeaknesses: [String]
            let llmRecommendations: [String]
            let nextMilestoneText: String

            struct SoundProgressRow: Identifiable, Equatable {
                let id: String
                let sound: String
                let percentText: String
                let deltaText: String
                let isStruggling: Bool
            }
        }
    }

    // MARK: - SaveNote
    enum SaveNote {
        struct Request {
            let childId: String
            let text: String
        }
        struct Response {
            let success: Bool
            let note: SpecialistNote
        }
        struct ViewModel: Equatable {
            let confirmationText: String
            let notePreview: String
        }
    }

    // MARK: - FetchNotes
    enum FetchNotes {
        struct Request {
            let childId: String
        }
        struct Response {
            let notes: [SpecialistNote]
        }
        struct ViewModel: Equatable {
            struct NoteRow: Identifiable, Equatable {
                let id: String
                let dateLabel: String
                let preview: String
            }
            let rows: [NoteRow]
            let emptyStateText: String
        }
    }

    // MARK: - RequestExport
    enum RequestExport {
        struct Request {
            let childId: String
            let format: ExportFormat
            let range: DateRange
        }
        struct Response {
            let fileURL: URL
            let sizeBytes: Int
            let format: ExportFormat
        }
        struct ViewModel: Equatable {
            let shareURL: URL
            let sizeLabel: String
            let successMessage: String
        }
        enum ExportFormat: String, CaseIterable, Sendable, Equatable {
            case pdf = "PDF"
            case csv = "CSV"
        }
    }

    // MARK: - SendParentMessage
    enum SendParentMessage {
        struct Request {
            let childId: String
            let parentId: String
            let message: String
        }
        struct Response {
            let delivered: Bool
            let timestamp: Date
        }
        struct ViewModel: Equatable {
            let statusText: String
            let isError: Bool
        }
    }

    // MARK: - DeleteNote
    enum DeleteNote {
        struct Request {
            let noteId: String
            let childId: String
        }
        struct Response {
            let success: Bool
        }
        struct ViewModel: Equatable {
            let feedbackText: String
        }
    }
}

// MARK: - Domain Types

struct ChildCaseEntry: Identifiable, Sendable {
    let id: String
    let name: String
    let age: Int
    let targetSounds: [String]
    let lastSessionAt: Date?
    let overallSuccessRate: Double
    let parentId: String
}

struct SpecialistNote: Identifiable, Sendable, Equatable {
    let id: String
    let childId: String
    let specialistId: String
    let text: String
    let createdAt: Date
}
