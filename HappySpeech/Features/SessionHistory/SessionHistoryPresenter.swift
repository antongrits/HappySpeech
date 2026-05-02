import Foundation
import OSLog

// MARK: - SessionHistoryPresentationLogic

@MainActor
protocol SessionHistoryPresentationLogic: AnyObject {
    func presentLoadHistory(_ response: SessionHistoryModels.LoadHistory.Response)
    func presentApplyFilter(_ response: SessionHistoryModels.ApplyFilter.Response)
    func presentClearFilter(_ response: SessionHistoryModels.ClearFilter.Response)
    func presentApplySort(_ response: SessionHistoryModels.ApplySort.Response)
    func presentLoadNextPage(_ response: SessionHistoryModels.LoadNextPage.Response)
    func presentOpenSession(_ response: SessionHistoryModels.OpenSession.Response)
    func presentAddNote(_ response: SessionHistoryModels.AddNote.Response)
    func presentDeleteNote(_ response: SessionHistoryModels.DeleteNote.Response)
    func presentExportPDF(_ response: SessionHistoryModels.ExportPDF.Response)
    func presentExportCSV(_ response: SessionHistoryModels.ExportCSV.Response)
    func presentExportJSON(_ response: SessionHistoryModels.ExportJSON.Response)
    func presentAudioState(_ response: SessionHistoryModels.AudioState.Response)
    func presentStatsSummary(_ response: SessionHistoryModels.LoadStatsSummary.Response)
    func presentLyalyaComment(_ response: SessionHistoryModels.LoadLyalyaComment.Response)
    func presentSearch(_ response: SessionHistoryModels.Search.Response)
    func presentFailure(_ response: SessionHistoryModels.Failure.Response)
}

// MARK: - SessionHistoryPresenter

/// Преобразует `Response` от Interactor'а в `ViewModel`, готовую к показу.
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

    // MARK: - PresentationLogic: List cases

    func presentLoadHistory(_ response: SessionHistoryModels.LoadHistory.Response) {
        let vm = makeListViewModel(.init(
            sessions: response.sessions,
            allSessions: response.allSessions,
            filter: response.activeFilter,
            sort: response.activeSort,
            currentPage: response.currentPage,
            isLastPage: response.isLastPage
        ))
        display?.displayLoadHistory(vm)
    }

    func presentApplyFilter(_ response: SessionHistoryModels.ApplyFilter.Response) {
        let base = makeListViewModel(.init(
            sessions: response.sessions,
            allSessions: response.allSessions,
            filter: response.activeFilter,
            sort: response.activeSort,
            currentPage: response.currentPage,
            isLastPage: response.isLastPage
        ))
        display?.displayApplyFilter(.init(
            groups: base.groups,
            totalCount: base.totalCount,
            filteredCount: base.filteredCount,
            activeFilter: base.activeFilter,
            activeSort: base.activeSort,
            activeSoundChips: base.activeSoundChips,
            isEmpty: base.isEmpty,
            emptyKind: base.emptyKind,
            emptyTitle: base.emptyTitle,
            emptyMessage: base.emptyMessage,
            currentPage: base.currentPage,
            isLastPage: base.isLastPage
        ))
    }

    func presentClearFilter(_ response: SessionHistoryModels.ClearFilter.Response) {
        let base = makeListViewModel(.init(
            sessions: response.sessions,
            allSessions: response.allSessions,
            filter: response.activeFilter,
            sort: response.activeSort,
            currentPage: response.currentPage,
            isLastPage: response.isLastPage
        ))
        display?.displayClearFilter(.init(
            groups: base.groups,
            totalCount: base.totalCount,
            filteredCount: base.filteredCount,
            activeFilter: base.activeFilter,
            activeSort: base.activeSort,
            activeSoundChips: base.activeSoundChips,
            isEmpty: base.isEmpty,
            emptyKind: base.emptyKind,
            emptyTitle: base.emptyTitle,
            emptyMessage: base.emptyMessage,
            currentPage: base.currentPage,
            isLastPage: base.isLastPage
        ))
    }

    func presentApplySort(_ response: SessionHistoryModels.ApplySort.Response) {
        let base = makeListViewModel(.init(
            sessions: response.sessions,
            allSessions: response.allSessions,
            filter: response.activeFilter,
            sort: response.activeSort,
            currentPage: response.currentPage,
            isLastPage: response.isLastPage
        ))
        display?.displayApplySort(.init(
            groups: base.groups,
            totalCount: base.totalCount,
            filteredCount: base.filteredCount,
            activeFilter: base.activeFilter,
            activeSort: base.activeSort,
            activeSoundChips: base.activeSoundChips,
            isEmpty: base.isEmpty,
            emptyKind: base.emptyKind,
            emptyTitle: base.emptyTitle,
            emptyMessage: base.emptyMessage,
            currentPage: base.currentPage,
            isLastPage: base.isLastPage
        ))
    }

    func presentLoadNextPage(_ response: SessionHistoryModels.LoadNextPage.Response) {
        let groups = groupByMonth(response.sessions)
        let vm = SessionHistoryModels.LoadNextPage.ViewModel(
            newGroups: groups,
            currentPage: response.currentPage,
            isLastPage: response.isLastPage
        )
        display?.displayLoadNextPage(vm)
    }

    // MARK: - PresentationLogic: Session Detail

    func presentOpenSession(_ response: SessionHistoryModels.OpenSession.Response) {
        let detail = makeDetailViewModel(
            session: response.session,
            attempts: response.attempts,
            parentNote: response.parentNote,
            hasAudioRecording: response.hasAudioRecording
        )
        display?.displayOpenSession(.init(detail: detail))
    }

    // MARK: - PresentationLogic: Notes

    func presentAddNote(_ response: SessionHistoryModels.AddNote.Response) {
        let vm = SessionHistoryModels.AddNote.ViewModel(
            sessionId: response.sessionId,
            noteText: response.noteText,
            toastMessage: String(localized: "sessionHistory.note.saved")
        )
        display?.displayAddNote(vm)
    }

    func presentDeleteNote(_ response: SessionHistoryModels.DeleteNote.Response) {
        let vm = SessionHistoryModels.DeleteNote.ViewModel(
            sessionId: response.sessionId
        )
        display?.displayDeleteNote(vm)
    }

    // MARK: - PresentationLogic: Export

    func presentExportPDF(_ response: SessionHistoryModels.ExportPDF.Response) {
        let vm = SessionHistoryModels.ExportPDF.ViewModel(
            shareURL: response.fileURL,
            toastMessage: String(localized: "sessionHistory.export.pdf.ready")
        )
        display?.displayExportPDF(vm)
    }

    func presentExportCSV(_ response: SessionHistoryModels.ExportCSV.Response) {
        let vm = SessionHistoryModels.ExportCSV.ViewModel(
            shareURL: response.fileURL,
            toastMessage: String(localized: "sessionHistory.export.csv.ready")
        )
        display?.displayExportCSV(vm)
    }

    func presentExportJSON(_ response: SessionHistoryModels.ExportJSON.Response) {
        let vm = SessionHistoryModels.ExportJSON.ViewModel(
            shareURL: response.fileURL,
            toastMessage: String(localized: "sessionHistory.export.json.ready")
        )
        display?.displayExportJSON(vm)
    }

    // MARK: - PresentationLogic: Audio

    func presentAudioState(_ response: SessionHistoryModels.AudioState.Response) {
        let progressText: String
        if response.durationSeconds > 0 {
            let elapsed = response.progress * response.durationSeconds
            progressText = "\(Int(elapsed))s / \(Int(response.durationSeconds))s"
        } else {
            progressText = ""
        }
        let label: String
        if response.isPlaying {
            label = String(localized: "sessionHistory.audio.playing")
        } else {
            label = String(localized: "sessionHistory.audio.stopped")
        }

        let vm = SessionHistoryModels.AudioState.ViewModel(
            sessionId: response.sessionId,
            isPlaying: response.isPlaying,
            progressText: progressText,
            accessibilityLabel: label
        )
        display?.displayAudioState(vm)
    }

    // MARK: - PresentationLogic: Stats Summary

    func presentStatsSummary(_ response: SessionHistoryModels.LoadStatsSummary.Response) {
        let totalText = "\(response.totalSessions)"
        let timeText = formatTotalMinutes(response.totalMinutes)
        let scoreText = "\(response.averageScorePercent)%"
        let bestText = response.bestSound == "—" ? String(localized: "sessionHistory.stats.noData") : response.bestSound
        let hardestText = response.hardestSound == "—" ? String(localized: "sessionHistory.stats.noData") : response.hardestSound

        let weekComparison: String
        if response.prevWeekSessions == 0 {
            weekComparison = String(
                format: String(localized: "sessionHistory.stats.weekFirst"),
                response.weekSessions
            )
        } else if response.weekSessions >= response.prevWeekSessions {
            weekComparison = String(
                format: String(localized: "sessionHistory.stats.weekUp"),
                response.weekSessions,
                response.prevWeekSessions
            )
        } else {
            weekComparison = String(
                format: String(localized: "sessionHistory.stats.weekDown"),
                response.weekSessions,
                response.prevWeekSessions
            )
        }

        let a11y = String(
            format: String(localized: "sessionHistory.a11y.statsSummaryPattern"),
            response.totalSessions,
            response.averageScorePercent,
            response.totalMinutes
        )

        let vm = SessionHistoryModels.LoadStatsSummary.ViewModel(
            totalSessionsText: totalText,
            totalTimeText: timeText,
            averageScoreText: scoreText,
            bestSoundText: bestText,
            hardestSoundText: hardestText,
            weekComparisonText: weekComparison,
            soundBreakdown: response.soundBreakdown,
            accessibilityLabel: a11y
        )
        display?.displayStatsSummary(vm)
    }

    // MARK: - PresentationLogic: Lyalya

    func presentLyalyaComment(_ response: SessionHistoryModels.LoadLyalyaComment.Response) {
        let vm = SessionHistoryModels.LoadLyalyaComment.ViewModel(
            commentText: response.commentText
        )
        display?.displayLyalyaComment(vm)
    }

    // MARK: - PresentationLogic: Search

    func presentSearch(_ response: SessionHistoryModels.Search.Response) {
        let groups = groupByMonth(response.sessions)
        let isEmpty = groups.isEmpty

        let emptyKind: EmptyKind
        if response.allSessions.isEmpty {
            emptyKind = .noSessions
        } else if isEmpty && !response.query.isEmpty {
            emptyKind = .noResultsForSearch
        } else if isEmpty {
            emptyKind = .noResultsForFilter
        } else {
            emptyKind = .none
        }

        let vm = SessionHistoryModels.Search.ViewModel(
            groups: groups,
            totalCount: response.allSessions.count,
            filteredCount: response.sessions.count,
            query: response.query,
            isEmpty: isEmpty,
            emptyKind: emptyKind,
            emptyTitle: emptyTitle(for: emptyKind),
            emptyMessage: emptyMessage(for: emptyKind),
            currentPage: response.currentPage,
            isLastPage: response.isLastPage
        )
        display?.displaySearch(vm)
    }

    // MARK: - Failure

    func presentFailure(_ response: SessionHistoryModels.Failure.Response) {
        logger.error("failure: \(response.message, privacy: .public)")
        display?.displayFailure(.init(toastMessage: response.message))
    }

    // MARK: - List ViewModel builder

    private struct ListContext {
        let sessions: [SessionRecord]
        let allSessions: [SessionRecord]
        let filter: SessionHistoryFilter
        let sort: SessionHistorySort
        let currentPage: Int
        let isLastPage: Bool
    }

    private func makeListViewModel(_ ctx: ListContext) -> SessionHistoryModels.LoadHistory.ViewModel {
        let groups = groupByMonth(ctx.sessions)
        let chips = ctx.filter.sounds.sorted().map { $0.uppercased() }

        let isEmpty = groups.isEmpty
        let emptyKind: EmptyKind
        if ctx.allSessions.isEmpty {
            emptyKind = .noSessions
        } else if isEmpty {
            emptyKind = .noResultsForFilter
        } else {
            emptyKind = .none
        }

        return SessionHistoryModels.LoadHistory.ViewModel(
            groups: groups,
            totalCount: ctx.allSessions.count,
            filteredCount: ctx.sessions.count,
            activeFilter: ctx.filter,
            activeSort: ctx.sort,
            activeSoundChips: chips,
            isEmpty: isEmpty,
            emptyKind: emptyKind,
            emptyTitle: emptyTitle(for: emptyKind),
            emptyMessage: emptyMessage(for: emptyKind),
            currentPage: ctx.currentPage,
            isLastPage: ctx.isLastPage
        )
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
        attempts: [SessionAttemptRecord],
        parentNote: String?,
        hasAudioRecording: Bool
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
            parentNote: parentNote,
            hasAudioRecording: hasAudioRecording,
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
        case .objectHunt:             return "GameAR"
        case .letterTracing:          return "GameListenAndChoose"
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return String(
            format: String(localized: "sessionHistory.row.minutesPattern"),
            minutes
        )
    }

    private func formatTotalMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return String(
                    format: String(localized: "sessionHistory.stats.hoursOnly"),
                    hours
                )
            }
            return String(
                format: String(localized: "sessionHistory.stats.hoursMinutes"),
                hours,
                mins
            )
        }
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
        case .noResultsForSearch:
            return String(localized: "sessionHistory.empty.noSearch.title")
        }
    }

    private func emptyMessage(for kind: EmptyKind) -> String {
        switch kind {
        case .none, .noSessions:
            return String(localized: "sessionHistory.empty.noSessions.message")
        case .noResultsForFilter:
            return String(localized: "sessionHistory.empty.noResults.message")
        case .noResultsForSearch:
            return String(localized: "sessionHistory.empty.noSearch.message")
        }
    }
}
