import Foundation
import OSLog

// MARK: - SessionHistoryPresentationLogic

@MainActor
protocol SessionHistoryPresentationLogic: AnyObject {
    func presentLoadHistory(_ response: SessionHistoryModels.LoadHistory.Response)
    func presentApplyFilter(_ response: SessionHistoryModels.ApplyFilter.Response)
    func presentClearFilter(_ response: SessionHistoryModels.ClearFilter.Response)
    func presentOpenSession(_ response: SessionHistoryModels.OpenSession.Response)
    func presentFailure(_ response: SessionHistoryModels.Failure.Response)
}

// MARK: - SessionHistoryPresenter

/// Преобразует `Response` от Interactor'а в `ViewModel`, готовую к показу.
/// Здесь — все локализованные строки, форматирование дат, accessibility-метки,
/// группировка по месяцам.
@MainActor
final class SessionHistoryPresenter: SessionHistoryPresentationLogic {

    // MARK: - Collaborators

    weak var display: (any SessionHistoryDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionHistoryPresenter")

    // MARK: - Formatters (cached)

    private static let monthHeaderFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "LLLL yyyy"
        return df
    }()

    private static let monthKeyFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "yyyy-MM"
        return df
    }()

    private static let monthAbbrFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "LLL"
        return df
    }()

    private static let dayNumberFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "d"
        return df
    }()

    private static let fullDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "d MMMM yyyy 'в' HH:mm"
        return df
    }()

    // MARK: - PresentationLogic

    func presentLoadHistory(_ response: SessionHistoryModels.LoadHistory.Response) {
        let viewModel = makeListViewModel(
            sessions: response.allSessions,
            filter: response.activeFilter
        )
        display?.displayLoadHistory(.init(
            groups: viewModel.groups,
            totalCount: viewModel.totalCount,
            filteredCount: viewModel.filteredCount,
            activeFilter: viewModel.activeFilter,
            activeSoundChips: viewModel.activeSoundChips,
            isEmpty: viewModel.isEmpty,
            emptyKind: viewModel.emptyKind,
            emptyTitle: viewModel.emptyTitle,
            emptyMessage: viewModel.emptyMessage
        ))
    }

    func presentApplyFilter(_ response: SessionHistoryModels.ApplyFilter.Response) {
        let viewModel = makeListViewModel(
            sessions: response.allSessions,
            filter: response.activeFilter
        )
        display?.displayApplyFilter(.init(
            groups: viewModel.groups,
            totalCount: viewModel.totalCount,
            filteredCount: viewModel.filteredCount,
            activeFilter: viewModel.activeFilter,
            activeSoundChips: viewModel.activeSoundChips,
            isEmpty: viewModel.isEmpty,
            emptyKind: viewModel.emptyKind,
            emptyTitle: viewModel.emptyTitle,
            emptyMessage: viewModel.emptyMessage
        ))
    }

    func presentClearFilter(_ response: SessionHistoryModels.ClearFilter.Response) {
        let viewModel = makeListViewModel(
            sessions: response.allSessions,
            filter: .empty
        )
        display?.displayClearFilter(.init(
            groups: viewModel.groups,
            totalCount: viewModel.totalCount,
            filteredCount: viewModel.filteredCount,
            activeFilter: viewModel.activeFilter,
            activeSoundChips: viewModel.activeSoundChips,
            isEmpty: viewModel.isEmpty,
            emptyKind: viewModel.emptyKind,
            emptyTitle: viewModel.emptyTitle,
            emptyMessage: viewModel.emptyMessage
        ))
    }

    func presentOpenSession(_ response: SessionHistoryModels.OpenSession.Response) {
        let detail = makeDetailViewModel(
            session: response.session,
            attempts: response.attempts
        )
        display?.displayOpenSession(.init(detail: detail))
    }

    func presentFailure(_ response: SessionHistoryModels.Failure.Response) {
        logger.error("failure: \(response.message, privacy: .public)")
        display?.displayFailure(.init(toastMessage: response.message))
    }

    // MARK: - List view-model

    private func makeListViewModel(
        sessions: [SessionRecord],
        filter: SessionFilter
    ) -> SessionHistoryModels.LoadHistory.ViewModel {
        let filtered = applyFilter(sessions, filter: filter)
        let groups = groupByMonth(filtered)
        let chips = filter.sounds.sorted().map { $0.uppercased() }

        let isEmpty = groups.isEmpty
        let emptyKind: EmptyKind
        if sessions.isEmpty {
            emptyKind = .noSessions
        } else if isEmpty {
            emptyKind = .noResultsForFilter
        } else {
            emptyKind = .none
        }

        return SessionHistoryModels.LoadHistory.ViewModel(
            groups: groups,
            totalCount: sessions.count,
            filteredCount: filtered.count,
            activeFilter: filter,
            activeSoundChips: chips,
            isEmpty: isEmpty,
            emptyKind: emptyKind,
            emptyTitle: emptyTitle(for: emptyKind),
            emptyMessage: emptyMessage(for: emptyKind)
        )
    }

    private func applyFilter(_ sessions: [SessionRecord], filter: SessionFilter) -> [SessionRecord] {
        guard filter.isActive else { return sessions }
        let calendar = Calendar.current
        return sessions.filter { session in
            if let from = filter.fromDate {
                let fromStart = calendar.startOfDay(for: from)
                let sessStart = calendar.startOfDay(for: session.date)
                if sessStart < fromStart { return false }
            }
            if let to = filter.toDate {
                let toStart = calendar.startOfDay(for: to)
                let sessStart = calendar.startOfDay(for: session.date)
                if sessStart > toStart { return false }
            }
            if !filter.sounds.isEmpty {
                if !filter.sounds.contains(session.soundTarget) { return false }
            }
            return true
        }
    }

    private func groupByMonth(_ sessions: [SessionRecord]) -> [SessionMonthGroup] {
        let sorted = sessions.sorted { $0.date > $1.date }
        var byKey: [String: [SessionRecord]] = [:]
        var orderedKeys: [String] = []
        for session in sorted {
            let key = Self.monthKeyFormatter.string(from: session.date)
            if byKey[key] == nil {
                byKey[key] = []
                orderedKeys.append(key)
            }
            byKey[key]?.append(session)
        }

        return orderedKeys.compactMap { key in
            guard let bucket = byKey[key], let firstDate = bucket.first?.date else { return nil }
            let header = Self.monthHeaderFormatter.string(from: firstDate).capitalized
            let rows = bucket.map { makeRow($0) }
            return SessionMonthGroup(id: key, monthTitle: header, rows: rows)
        }
    }

    private func makeRow(_ session: SessionRecord) -> SessionHistoryRowViewModel {
        let day = Self.dayNumberFormatter.string(from: session.date)
        let monthAbbr = Self.monthAbbrFormatter.string(from: session.date).uppercased()
        let title = session.gameType.displayName
        let durationText = formatDuration(session.durationSec)
        let scoreText = "\(Int(session.score * 100))%"
        let tier = scoreTier(for: session.score)
        let soundLabel: String
        if session.soundTarget == "—" {
            soundLabel = String(localized: "sessionHistory.row.noSound")
        } else {
            soundLabel = String(
                format: String(localized: "sessionHistory.row.soundPattern"),
                session.soundTarget
            )
        }

        let metaLine = String(
            format: String(localized: "sessionHistory.row.metaPattern"),
            durationText,
            session.attempts,
            soundLabel
        )

        let label = String(
            format: String(localized: "sessionHistory.a11y.rowLabelPattern"),
            day,
            monthAbbr.lowercased(),
            title,
            soundLabel,
            Int(session.score * 100)
        )
        let hint = String(localized: "sessionHistory.a11y.rowHint")

        return SessionHistoryRowViewModel(
            id: session.id,
            dayNumber: day,
            monthAbbr: monthAbbr,
            title: title,
            metaLine: metaLine,
            scoreText: scoreText,
            scoreTier: tier,
            gameAccentColorName: gameAccentName(for: session.gameType),
            durationText: durationText,
            accessibilityLabel: label,
            accessibilityHint: hint
        )
    }

    // MARK: - Detail view-model

    private func makeDetailViewModel(
        session: SessionRecord,
        attempts: [SessionAttemptRecord]
    ) -> SessionDetailViewModel {
        let titleLine = session.gameType.displayName
        let dateLine = Self.fullDateFormatter.string(from: session.date)
        let percent = Int(session.score * 100)
        let tier = scoreTier(for: session.score)
        let durationText = formatDuration(session.durationSec)

        let attemptRows = attempts.enumerated().map { index, attempt in
            let attemptPercent = Int(attempt.score * 100)
            let attTier = scoreTier(for: attempt.score)
            let durSec = max(1, attempt.durationMs / 1000)
            let attDuration = String(
                format: String(localized: "sessionHistory.attempt.durationPattern"),
                durSec
            )
            let label = String(
                format: String(localized: "sessionHistory.a11y.attemptPattern"),
                index + 1,
                attempt.word,
                attemptPercent
            )
            return AttemptDetailRowViewModel(
                id: attempt.id,
                index: index + 1,
                word: attempt.word,
                scorePercent: attemptPercent,
                scoreTier: attTier,
                durationText: attDuration,
                isCorrect: attempt.isCorrect,
                accessibilityLabel: label
            )
        }

        let header = String(
            format: String(localized: "sessionHistory.a11y.detailHeaderPattern"),
            titleLine,
            dateLine,
            percent
        )

        return SessionDetailViewModel(
            id: session.id,
            titleLine: titleLine,
            dateLine: dateLine,
            scorePercent: percent,
            scoreTier: tier,
            attemptsCount: session.attempts,
            durationText: durationText,
            attemptRows: attemptRows,
            accessibilityHeader: header
        )
    }

    // MARK: - Helpers

    private func scoreTier(for score: Float) -> ScoreTier {
        if score >= 0.7 { return .excellent }
        if score >= 0.5 { return .ok }
        return .low
    }

    private func gameAccentName(for template: TemplateType) -> String {
        switch template {
        case .listenAndChoose:        return "GameListenAndChoose"
        case .repeatAfterModel:       return "GameRepeatAfterModel"
        case .memory:                 return "GameMemory"
        case .breathing:              return "GameBreathing"
        case .rhythm:                 return "GameRhythm"
        case .sorting:                return "GameSorting"
        case .puzzleReveal:           return "GamePuzzle"
        case .arActivity:             return "GameAR"
        case .articulationImitation:  return "GameAR"
        case .visualAcoustic:         return "GameRhythm"
        case .narrativeQuest:         return "GameMemory"
        case .minimalPairs:           return "GamePuzzle"
        case .bingo:                  return "GameSorting"
        case .soundHunter:            return "GameRepeatAfterModel"
        case .dragAndMatch:           return "GameListenAndChoose"
        case .storyCompletion:        return "GameMemory"
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return String(
            format: String(localized: "sessionHistory.row.minutesPattern"),
            minutes
        )
    }

    private func emptyTitle(for kind: EmptyKind) -> String {
        switch kind {
        case .none, .noSessions:
            return String(localized: "sessionHistory.empty.noSessions.title")
        case .noResultsForFilter:
            return String(localized: "sessionHistory.empty.noResults.title")
        }
    }

    private func emptyMessage(for kind: EmptyKind) -> String {
        switch kind {
        case .none, .noSessions:
            return String(localized: "sessionHistory.empty.noSessions.message")
        case .noResultsForFilter:
            return String(localized: "sessionHistory.empty.noResults.message")
        }
    }
}
