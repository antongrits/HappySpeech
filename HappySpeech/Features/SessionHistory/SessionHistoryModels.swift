import Foundation
import SwiftUI

// MARK: - SessionHistory VIP Models
//
// Доменные модели + transport-слои Request / Response / ViewModel.
// Контур: parent — список логопедических сессий с фильтрацией и детальным
// просмотром одной попытки. Источник данных на M7.2 — in-memory seed
// (15+ сессий за два месяца, разные звуки/игры/score). На M8 будет
// подключён `SessionRepository` поверх Realm.

enum SessionHistoryModels {

    // MARK: - LoadHistory

    enum LoadHistory {
        struct Request: Sendable {
            /// Игнорировать кэш — заново сгенерировать список (pull-to-refresh).
            let forceReload: Bool
            init(forceReload: Bool = false) { self.forceReload = forceReload }
        }

        struct Response: Sendable {
            let allSessions: [SessionRecord]
            let activeFilter: SessionFilter
            let isFromCache: Bool
        }

        struct ViewModel: Sendable {
            let groups: [SessionMonthGroup]
            let totalCount: Int
            let filteredCount: Int
            let activeFilter: SessionFilter
            let activeSoundChips: [String]
            let isEmpty: Bool
            let emptyKind: EmptyKind
            let emptyTitle: String
            let emptyMessage: String
        }
    }

    // MARK: - ApplyFilter

    enum ApplyFilter {
        struct Request: Sendable {
            let filter: SessionFilter
        }

        struct Response: Sendable {
            let allSessions: [SessionRecord]
            let activeFilter: SessionFilter
        }

        struct ViewModel: Sendable {
            let groups: [SessionMonthGroup]
            let totalCount: Int
            let filteredCount: Int
            let activeFilter: SessionFilter
            let activeSoundChips: [String]
            let isEmpty: Bool
            let emptyKind: EmptyKind
            let emptyTitle: String
            let emptyMessage: String
        }
    }

    // MARK: - ClearFilter

    enum ClearFilter {
        struct Request: Sendable {}
        struct Response: Sendable {
            let allSessions: [SessionRecord]
        }
        struct ViewModel: Sendable {
            let groups: [SessionMonthGroup]
            let totalCount: Int
            let filteredCount: Int
            let activeFilter: SessionFilter
            let activeSoundChips: [String]
            let isEmpty: Bool
            let emptyKind: EmptyKind
            let emptyTitle: String
            let emptyMessage: String
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
        }
        struct ViewModel: Sendable {
            let detail: SessionDetailViewModel
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

/// Запись об одной завершённой логопедической сессии. Хранится локально (Realm)
/// и синхронизируется в Firestore. Используется как первичный источник для
/// аналитики (`ProgressDashboard`) и истории (`SessionHistory`).
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

/// Одна попытка внутри сессии — для детального экрана.
struct SessionAttemptRecord: Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let word: String
    let score: Float
    let isCorrect: Bool
    let durationMs: Int
}

/// Состав фильтра. Передаётся между View ↔ Interactor через `ApplyFilter`.
struct SessionFilter: Sendable, Equatable {
    var fromDate: Date?
    var toDate: Date?
    var sounds: Set<String>

    static var empty: SessionFilter {
        SessionFilter(fromDate: nil, toDate: nil, sounds: [])
    }

    var isActive: Bool {
        fromDate != nil || toDate != nil || !sounds.isEmpty
    }
}

/// Категория пустого состояния — Presenter подбирает текст.
enum EmptyKind: Sendable, Equatable {
    case none
    case noSessions
    case noResultsForFilter
}

// MARK: - View-ready row

/// Готовая для рендера строка в списке. Все строки уже отформатированы Presenter'ом.
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

/// Группа сессий по месяцу — используется как Section header.
struct SessionMonthGroup: Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let monthTitle: String
    let rows: [SessionHistoryRowViewModel]
}

/// Tier для бейджа с цветом. View сам подбирает цвет токена.
enum ScoreTier: Sendable, Equatable {
    case excellent  // ≥ 0.7 — успех
    case ok         // ≥ 0.5 — предупреждение
    case low        // < 0.5 — ошибка
}

/// Чип, отображаемый в фильтр-баре активных значений.
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
