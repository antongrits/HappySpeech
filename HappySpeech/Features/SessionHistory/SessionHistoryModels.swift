import Foundation

// MARK: - SessionHistory VIP Models

enum SessionHistoryModels {

    // MARK: - LoadHistory

    enum LoadHistory {
        struct Request: Sendable {
            let forceReload: Bool
            init(forceReload: Bool = false) { self.forceReload = forceReload }
        }

        struct Response: Sendable {
            let sessions: [SessionRecord]
            let allSessions: [SessionRecord]
            let activeFilter: SessionHistoryFilter
            let activeSort: SessionHistorySort
            let currentPage: Int
            let isLastPage: Bool
            let isFromCache: Bool
        }

        struct ViewModel: Sendable {
            let groups: [SessionMonthGroup]
            let totalCount: Int
            let filteredCount: Int
            let activeFilter: SessionHistoryFilter
            let activeSort: SessionHistorySort
            let activeSoundChips: [String]
            let isEmpty: Bool
            let emptyKind: EmptyKind
            let emptyTitle: String
            let emptyMessage: String
            let currentPage: Int
            let isLastPage: Bool
        }
    }

    // MARK: - ApplyFilter

    enum ApplyFilter {
        struct Request: Sendable {
            let filter: SessionHistoryFilter
        }

        struct Response: Sendable {
            let sessions: [SessionRecord]
            let allSessions: [SessionRecord]
            let activeFilter: SessionHistoryFilter
            let activeSort: SessionHistorySort
            let currentPage: Int
            let isLastPage: Bool
        }

        struct ViewModel: Sendable {
            let groups: [SessionMonthGroup]
            let totalCount: Int
            let filteredCount: Int
            let activeFilter: SessionHistoryFilter
            let activeSort: SessionHistorySort
            let activeSoundChips: [String]
            let isEmpty: Bool
            let emptyKind: EmptyKind
            let emptyTitle: String
            let emptyMessage: String
            let currentPage: Int
            let isLastPage: Bool
        }
    }

    // MARK: - ClearFilter

    enum ClearFilter {
        struct Request: Sendable {}

        struct Response: Sendable {
            let sessions: [SessionRecord]
            let allSessions: [SessionRecord]
            let activeFilter: SessionHistoryFilter
            let activeSort: SessionHistorySort
            let currentPage: Int
            let isLastPage: Bool
        }

        struct ViewModel: Sendable {
            let groups: [SessionMonthGroup]
            let totalCount: Int
            let filteredCount: Int
            let activeFilter: SessionHistoryFilter
            let activeSort: SessionHistorySort
            let activeSoundChips: [String]
            let isEmpty: Bool
            let emptyKind: EmptyKind
            let emptyTitle: String
            let emptyMessage: String
            let currentPage: Int
            let isLastPage: Bool
        }
    }

    // MARK: - ApplySort

    enum ApplySort {
        struct Request: Sendable {
            let sort: SessionHistorySort
        }

        struct Response: Sendable {
            let sessions: [SessionRecord]
            let allSessions: [SessionRecord]
            let activeFilter: SessionHistoryFilter
            let activeSort: SessionHistorySort
            let currentPage: Int
            let isLastPage: Bool
        }

        struct ViewModel: Sendable {
            let groups: [SessionMonthGroup]
            let totalCount: Int
            let filteredCount: Int
            let activeFilter: SessionHistoryFilter
            let activeSort: SessionHistorySort
            let activeSoundChips: [String]
            let isEmpty: Bool
            let emptyKind: EmptyKind
            let emptyTitle: String
            let emptyMessage: String
            let currentPage: Int
            let isLastPage: Bool
        }
    }

    // MARK: - LoadNextPage

    enum LoadNextPage {
        struct Request: Sendable {}

        struct Response: Sendable {
            let sessions: [SessionRecord]
            let currentPage: Int
            let isLastPage: Bool
            let activeFilter: SessionHistoryFilter
            let activeSort: SessionHistorySort
        }

        struct ViewModel: Sendable {
            let newGroups: [SessionMonthGroup]
            let currentPage: Int
            let isLastPage: Bool
        }
    }

    // MARK: - OpenSession

    enum OpenSession {
        struct Request: Sendable {
            let id: String
        }

        struct Response: Sendable {
            let session: SessionRecord
            let attempts: [SessionAttemptRecord]
            let parentNote: String?
            let hasAudioRecording: Bool
        }

        struct ViewModel: Sendable {
            let detail: SessionDetailViewModel
        }
    }

    // MARK: - AddNote

    enum AddNote {
        struct Request: Sendable {
            let sessionId: String
            let noteText: String
        }

        struct Response: Sendable {
            let sessionId: String
            let noteText: String
        }

        struct ViewModel: Sendable {
            let sessionId: String
            let noteText: String
            let toastMessage: String
        }
    }

    // MARK: - DeleteNote

    enum DeleteNote {
        struct Request: Sendable {
            let sessionId: String
        }

        struct Response: Sendable {
            let sessionId: String
        }

        struct ViewModel: Sendable {
            let sessionId: String
        }
    }

    // MARK: - ExportPDF

    enum ExportPDF {
        struct Request: Sendable {
            let childId: String
            init(childId: String = "") { self.childId = childId }
        }

        struct Response: Sendable {
            let fileURL: URL
            let exportFormat: ExportFormat
            let childId: String
        }

        struct ViewModel: Sendable {
            let shareURL: URL
            let toastMessage: String
        }
    }

    // MARK: - ExportCSV

    enum ExportCSV {
        struct Request: Sendable {
            let childId: String
            init(childId: String = "") { self.childId = childId }
        }

        struct Response: Sendable {
            let fileURL: URL
            let exportFormat: ExportFormat
            let childId: String
        }

        struct ViewModel: Sendable {
            let shareURL: URL
            let toastMessage: String
        }
    }

    // MARK: - ExportJSON

    enum ExportJSON {
        struct Request: Sendable {
            let childId: String
            init(childId: String = "") { self.childId = childId }
        }

        struct Response: Sendable {
            let fileURL: URL
            let exportFormat: ExportFormat
            let childId: String
        }

        struct ViewModel: Sendable {
            let shareURL: URL
            let toastMessage: String
        }
    }

    // MARK: - AudioState

    enum AudioState {
        struct Response: Sendable {
            let sessionId: String
            let isPlaying: Bool
            let progress: Double
            let durationSeconds: Double
        }

        struct ViewModel: Sendable {
            let sessionId: String
            let isPlaying: Bool
            let progressText: String
            let accessibilityLabel: String
        }
    }

    // MARK: - PlayAudio

    enum PlayAudio {
        struct Request: Sendable {
            let sessionId: String
        }
    }

    // MARK: - StopAudio

    enum StopAudio {
        struct Request: Sendable {
            let sessionId: String
            init(sessionId: String = "") { self.sessionId = sessionId }
        }
    }

    // MARK: - LoadStatsSummary

    enum LoadStatsSummary {
        struct Request: Sendable {
            let childId: String
            init(childId: String = "") { self.childId = childId }
        }

        struct Response: Sendable {
            let totalSessions: Int
            let totalMinutes: Int
            let averageScorePercent: Int
            let bestSound: String
            let hardestSound: String
            let weekSessions: Int
            let prevWeekSessions: Int
            let soundBreakdown: [SoundScoreBreakdownItem]
        }

        struct ViewModel: Sendable {
            let totalSessionsText: String
            let totalTimeText: String
            let averageScoreText: String
            let bestSoundText: String
            let hardestSoundText: String
            let weekComparisonText: String
            let soundBreakdown: [SoundScoreBreakdownItem]
            let accessibilityLabel: String
        }
    }

    // MARK: - LoadLyalyaComment

    enum LoadLyalyaComment {
        struct Request: Sendable {
            let childName: String
            init(childName: String = "") { self.childName = childName }
        }

        struct Response: Sendable {
            let commentText: String
        }

        struct ViewModel: Sendable {
            let commentText: String
        }
    }

    // MARK: - Search

    enum Search {
        struct Request: Sendable {
            let query: String
        }

        struct Response: Sendable {
            let sessions: [SessionRecord]
            let allSessions: [SessionRecord]
            let query: String
            let activeFilter: SessionHistoryFilter
            let activeSort: SessionHistorySort
            let currentPage: Int
            let isLastPage: Bool
        }

        struct ViewModel: Sendable {
            let groups: [SessionMonthGroup]
            let totalCount: Int
            let filteredCount: Int
            let query: String
            let isEmpty: Bool
            let emptyKind: EmptyKind
            let emptyTitle: String
            let emptyMessage: String
            let currentPage: Int
            let isLastPage: Bool
        }
    }

    // MARK: - Failure

    enum Failure {
        struct Response: Sendable {
            let message: String
        }

        struct ViewModel: Sendable {
            let toastMessage: String
        }
    }
}

// MARK: - Domain types

/// Запись об одной завершённой логопедической сессии.
struct SessionRecord: Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let date: Date
    let gameType: TemplateType
    let soundTarget: String
    let score: Float
    let durationSec: Int
    let attempts: Int
    let isPassed: Bool
}

/// Одна попытка внутри сессии.
struct SessionAttemptRecord: Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let word: String
    let score: Float
    let isCorrect: Bool
    let durationMs: Int
}

/// Расширенный фильтр истории сессий.
struct SessionHistoryFilter: Sendable, Equatable {
    var fromDate: Date?
    var toDate: Date?
    var sounds: Set<String>
    var gameTypes: Set<TemplateType>
    var scoreRange: ScoreRange

    enum ScoreRange: String, Sendable, Equatable, CaseIterable {
        case all
        case high    // >= 80%
        case medium  // 50–80%
        case low     // < 50%
    }

    static var empty: SessionHistoryFilter {
        SessionHistoryFilter(
            fromDate: nil,
            toDate: nil,
            sounds: [],
            gameTypes: [],
            scoreRange: .all
        )
    }

    var isActive: Bool {
        fromDate != nil
        || toDate != nil
        || !sounds.isEmpty
        || !gameTypes.isEmpty
        || scoreRange != .all
    }
}

/// Сортировка истории сессий.
enum SessionHistorySort: String, Sendable, CaseIterable {
    case byDate
    case byScore
    case bySound
    case byDuration

    var label: String {
        switch self {
        case .byDate:     return String(localized: "sessionHistory.sort.byDate")
        case .byScore:    return String(localized: "sessionHistory.sort.byScore")
        case .bySound:    return String(localized: "sessionHistory.sort.bySound")
        case .byDuration: return String(localized: "sessionHistory.sort.byDuration")
        }
    }
}

/// Строка разбивки по звуку для статистики.
struct SoundScoreBreakdownItem: Sendable, Identifiable, Equatable, Hashable {
    var id: String { sound }
    let sound: String
    let averageScore: Float
    let sessionCount: Int
}

/// Категория пустого состояния.
enum EmptyKind: Sendable, Equatable {
    case none
    case noSessions
    case noResultsForFilter
    case noResultsForSearch
}

// MARK: - View-ready row

struct SessionHistoryRowViewModel: Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let dayNumber: String
    let monthAbbr: String
    let title: String
    let metaLine: String
    let scoreText: String
    let scoreTier: ScoreTier
    let gameAccentColorName: String
    let durationText: String
    let accessibilityLabel: String
    let accessibilityHint: String
}

struct SessionMonthGroup: Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let monthTitle: String
    let rows: [SessionHistoryRowViewModel]
}

enum ScoreTier: Sendable, Equatable {
    case excellent  // >= 0.7
    case ok         // >= 0.5
    case low        // < 0.5
}

struct SessionFilterChip: Sendable, Identifiable, Equatable {
    let id: String
    let label: String
}

// MARK: - Detail view-model

struct SessionDetailViewModel: Sendable, Equatable, Hashable {
    let id: String
    let titleLine: String
    let dateLine: String
    let scorePercent: Int
    let scoreTier: ScoreTier
    let attemptsCount: Int
    let durationText: String
    let attemptRows: [AttemptDetailRowViewModel]
    let parentNote: String?
    let hasAudioRecording: Bool
    let accessibilityHeader: String
}

struct AttemptDetailRowViewModel: Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let index: Int
    let word: String
    let scorePercent: Int
    let scoreTier: ScoreTier
    let durationText: String
    let isCorrect: Bool
    let accessibilityLabel: String
}
