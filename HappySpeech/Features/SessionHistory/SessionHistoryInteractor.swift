import Foundation
import OSLog

// MARK: - SessionHistoryBusinessLogic

@MainActor
protocol SessionHistoryBusinessLogic: AnyObject {
    func loadHistory(_ request: SessionHistoryModels.LoadHistory.Request)
    func applyFilter(_ request: SessionHistoryModels.ApplyFilter.Request)
    func clearFilter(_ request: SessionHistoryModels.ClearFilter.Request)
    func applySort(_ request: SessionHistoryModels.ApplySort.Request)
    func loadNextPage(_ request: SessionHistoryModels.LoadNextPage.Request)
    func openSession(_ request: SessionHistoryModels.OpenSession.Request)
    func addNote(_ request: SessionHistoryModels.AddNote.Request)
    func deleteNote(_ request: SessionHistoryModels.DeleteNote.Request)
    func exportPDF(_ request: SessionHistoryModels.ExportPDF.Request)
    func exportCSV(_ request: SessionHistoryModels.ExportCSV.Request)
    func exportJSON(_ request: SessionHistoryModels.ExportJSON.Request)
    func playAudio(_ request: SessionHistoryModels.PlayAudio.Request)
    func stopAudio(_ request: SessionHistoryModels.StopAudio.Request)
    func loadStatsSummary(_ request: SessionHistoryModels.LoadStatsSummary.Request)
    func loadLyalyaComment(_ request: SessionHistoryModels.LoadLyalyaComment.Request)
    func performSearch(_ request: SessionHistoryModels.Search.Request)
}

// MARK: - SessionHistoryInteractor

/// Бизнес-логика экрана «История сессий».
///
/// Источник данных — in-memory seed (17 сессий, 2 месяца).
/// Реализует 12 фич: список + пагинация, фильтры (дата, звук, шаблон, score),
/// сортировка, поиск, детальный просмотр, заметки родителя, аудио-воспроизведение,
/// статистика-сводка, комментарий «Ляли», экспорт PDF/CSV/JSON.
@MainActor
final class SessionHistoryInteractor: SessionHistoryBusinessLogic {

    // MARK: - Constants

    private enum Constants {
        static let pageSize = 20
        static let chartLimit = 14
        static let audioFadeInterval: TimeInterval = 0.25
        static let lyalyaSessionThreshold = 5
    }

    // MARK: - Collaborators

    var presenter: (any SessionHistoryPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionHistory")
    private let exportService: SpecialistExportServiceLive
    private let audioPlayer: any AudioFilePlaying

    // MARK: - State

    private var allSessions: [SessionRecord] = []
    private var attemptsBySession: [String: [SessionAttemptRecord]] = [:]
    private var audioFilesBySession: [String: String] = [:]
    private var notesBySession: [String: String] = [:]
    private var activeFilter: SessionHistoryFilter = .empty
    private var activeSort: SessionHistorySort = .byDate
    private var searchQuery: String = ""
    private var currentPage: Int = 0
    private var isLastPage: Bool = false
    private var isPlayingAudio: Bool = false
    private var currentPlayingSessionId: String?

    // MARK: - Init

    init(audioPlayer: any AudioFilePlaying = LiveAudioFilePlayer()) {
        self.exportService = SpecialistExportServiceLive()
        self.audioPlayer = audioPlayer
        let seed = Self.makeSeedSessions()
        self.allSessions = seed.sessions
        self.attemptsBySession = seed.attempts
        self.audioFilesBySession = seed.audioFiles
    }

    // MARK: - Load History (с пагинацией)

    func loadHistory(_ request: SessionHistoryModels.LoadHistory.Request) {
        logger.info("loadHistory forceReload=\(request.forceReload, privacy: .public)")

        if request.forceReload {
            let seed = Self.makeSeedSessions()
            allSessions = seed.sessions
            attemptsBySession = seed.attempts
            audioFilesBySession = seed.audioFiles
            currentPage = 0
            isLastPage = false
        }

        let filtered = applyFilterAndSearch(allSessions)
        let sorted = applySortOrder(filtered)
        let pageSlice = pageOf(sessions: sorted, page: currentPage)
        isLastPage = pageSlice.count < Constants.pageSize

        let response = SessionHistoryModels.LoadHistory.Response(
            sessions: pageSlice,
            allSessions: allSessions,
            activeFilter: activeFilter,
            activeSort: activeSort,
            currentPage: currentPage,
            isLastPage: isLastPage,
            isFromCache: !request.forceReload
        )
        presenter?.presentLoadHistory(response)
    }

    // MARK: - Apply Filter

    func applyFilter(_ request: SessionHistoryModels.ApplyFilter.Request) {
        activeFilter = request.filter
        currentPage = 0
        isLastPage = false
        logger.info("applyFilter sounds=\(self.activeFilter.sounds.count, privacy: .public) gameTypes=\(self.activeFilter.gameTypes.count, privacy: .public)")

        let filtered = applyFilterAndSearch(allSessions)
        let sorted = applySortOrder(filtered)
        let pageSlice = pageOf(sessions: sorted, page: currentPage)
        isLastPage = pageSlice.count < Constants.pageSize

        let response = SessionHistoryModels.ApplyFilter.Response(
            sessions: pageSlice,
            allSessions: allSessions,
            activeFilter: activeFilter,
            activeSort: activeSort,
            currentPage: currentPage,
            isLastPage: isLastPage
        )
        presenter?.presentApplyFilter(response)
    }

    // MARK: - Clear Filter

    func clearFilter(_ request: SessionHistoryModels.ClearFilter.Request) {
        activeFilter = .empty
        searchQuery = ""
        currentPage = 0
        isLastPage = false
        logger.info("clearFilter")

        let sorted = applySortOrder(allSessions)
        let pageSlice = pageOf(sessions: sorted, page: currentPage)
        isLastPage = pageSlice.count < Constants.pageSize

        let response = SessionHistoryModels.ClearFilter.Response(
            sessions: pageSlice,
            allSessions: allSessions,
            activeFilter: activeFilter,
            activeSort: activeSort,
            currentPage: currentPage,
            isLastPage: isLastPage
        )
        presenter?.presentClearFilter(response)
    }

    // MARK: - Apply Sort

    func applySort(_ request: SessionHistoryModels.ApplySort.Request) {
        activeSort = request.sort
        currentPage = 0
        isLastPage = false
        logger.info("applySort sort=\(request.sort.rawValue, privacy: .public)")

        let filtered = applyFilterAndSearch(allSessions)
        let sorted = applySortOrder(filtered)
        let pageSlice = pageOf(sessions: sorted, page: currentPage)
        isLastPage = pageSlice.count < Constants.pageSize

        let response = SessionHistoryModels.ApplySort.Response(
            sessions: pageSlice,
            allSessions: allSessions,
            activeFilter: activeFilter,
            activeSort: activeSort,
            currentPage: currentPage,
            isLastPage: isLastPage
        )
        presenter?.presentApplySort(response)
    }

    // MARK: - Load Next Page (Pagination)

    func loadNextPage(_ request: SessionHistoryModels.LoadNextPage.Request) {
        guard !isLastPage else {
            logger.debug("loadNextPage: already at last page")
            return
        }
        currentPage += 1
        logger.info("loadNextPage page=\(self.currentPage, privacy: .public)")

        let filtered = applyFilterAndSearch(allSessions)
        let sorted = applySortOrder(filtered)
        let pageSlice = pageOf(sessions: sorted, page: currentPage)
        isLastPage = pageSlice.count < Constants.pageSize

        let response = SessionHistoryModels.LoadNextPage.Response(
            sessions: pageSlice,
            currentPage: currentPage,
            isLastPage: isLastPage,
            activeFilter: activeFilter,
            activeSort: activeSort
        )
        presenter?.presentLoadNextPage(response)
    }

    // MARK: - Open Session Detail

    func openSession(_ request: SessionHistoryModels.OpenSession.Request) {
        guard let session = allSessions.first(where: { $0.id == request.id }) else {
            logger.warning("openSession: not found id=\(request.id, privacy: .public)")
            presenter?.presentFailure(.init(
                message: String(localized: "sessionHistory.error.sessionNotFound")
            ))
            return
        }
        let attempts = attemptsBySession[request.id] ?? []
        let note = notesBySession[request.id]
        let hasAudio = audioFilesBySession[request.id] != nil
        logger.info("openSession id=\(session.id, privacy: .public) attempts=\(attempts.count, privacy: .public)")

        let response = SessionHistoryModels.OpenSession.Response(
            session: session,
            attempts: attempts,
            parentNote: note,
            hasAudioRecording: hasAudio
        )
        presenter?.presentOpenSession(response)
    }

    // MARK: - Add / Delete Parent Note

    func addNote(_ request: SessionHistoryModels.AddNote.Request) {
        guard !request.sessionId.isEmpty else { return }
        let trimmed = request.noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            logger.warning("addNote: empty text for session=\(request.sessionId, privacy: .public)")
            return
        }
        notesBySession[request.sessionId] = trimmed
        logger.info("addNote sessionId=\(request.sessionId, privacy: .public) length=\(trimmed.count, privacy: .public)")

        let response = SessionHistoryModels.AddNote.Response(
            sessionId: request.sessionId,
            noteText: trimmed
        )
        presenter?.presentAddNote(response)
    }

    func deleteNote(_ request: SessionHistoryModels.DeleteNote.Request) {
        notesBySession.removeValue(forKey: request.sessionId)
        logger.info("deleteNote sessionId=\(request.sessionId, privacy: .public)")

        let response = SessionHistoryModels.DeleteNote.Response(
            sessionId: request.sessionId
        )
        presenter?.presentDeleteNote(response)
    }

    // MARK: - Export PDF

    func exportPDF(_ request: SessionHistoryModels.ExportPDF.Request) {
        let childId = request.childId.isEmpty ? "child" : request.childId
        let sessionDTOs = allSessions.map { buildSessionDTO(from: $0) }
        logger.info("exportPDF childId=\(childId, privacy: .public) count=\(sessionDTOs.count, privacy: .public)")

        Task { [weak self] in
            guard let self else { return }
            do {
                let url = try await exportService.generatePDF(
                    childId: childId,
                    sessions: sessionDTOs
                )
                await MainActor.run {
                    self.presenter?.presentExportPDF(
                        .init(fileURL: url, exportFormat: .pdf, childId: childId)
                    )
                }
            } catch {
                await MainActor.run {
                    self.logger.error("exportPDF failed: \(error.localizedDescription, privacy: .public)")
                    self.presenter?.presentFailure(
                        .init(message: String(localized: "sessionHistory.export.error.pdf"))
                    )
                }
            }
        }
    }

    // MARK: - Export CSV

    func exportCSV(_ request: SessionHistoryModels.ExportCSV.Request) {
        let childId = request.childId.isEmpty ? "child" : request.childId
        let sessionDTOs = allSessions.map { buildSessionDTO(from: $0) }
        logger.info("exportCSV childId=\(childId, privacy: .public) count=\(sessionDTOs.count, privacy: .public)")

        Task { [weak self] in
            guard let self else { return }
            do {
                let url = try await exportService.generateCSV(
                    childId: childId,
                    sessions: sessionDTOs
                )
                await MainActor.run {
                    self.presenter?.presentExportCSV(
                        .init(fileURL: url, exportFormat: .csv, childId: childId)
                    )
                }
            } catch {
                await MainActor.run {
                    self.logger.error("exportCSV failed: \(error.localizedDescription, privacy: .public)")
                    self.presenter?.presentFailure(
                        .init(message: String(localized: "sessionHistory.export.error.csv"))
                    )
                }
            }
        }
    }

    // MARK: - Export JSON

    func exportJSON(_ request: SessionHistoryModels.ExportJSON.Request) {
        let childId = request.childId.isEmpty ? "child" : request.childId
        let sessionCount = allSessions.count
        logger.info("exportJSON childId=\(childId, privacy: .public) count=\(sessionCount, privacy: .public)")

        Task { [weak self] in
            guard let self else { return }
            do {
                let url = try buildJSONExport(childId: childId)
                await MainActor.run {
                    self.presenter?.presentExportJSON(
                        .init(fileURL: url, exportFormat: .json, childId: childId)
                    )
                }
            } catch {
                await MainActor.run {
                    self.logger.error("exportJSON failed: \(error.localizedDescription, privacy: .public)")
                    self.presenter?.presentFailure(
                        .init(message: String(localized: "sessionHistory.export.error.json"))
                    )
                }
            }
        }
    }

    // MARK: - Audio Playback

    func playAudio(_ request: SessionHistoryModels.PlayAudio.Request) {
        guard let filePath = audioFilesBySession[request.sessionId] else {
            logger.warning("playAudio: no file for sessionId=\(request.sessionId, privacy: .public)")
            presenter?.presentFailure(
                .init(message: String(localized: "sessionHistory.audio.error.notFound"))
            )
            return
        }

        stopCurrentAudioIfNeeded()
        logger.info("playAudio sessionId=\(request.sessionId, privacy: .public)")

        do {
            let fileURL = URL(fileURLWithPath: filePath)
            try audioPlayer.play(contentsOf: fileURL)
            isPlayingAudio = true
            currentPlayingSessionId = request.sessionId

            presenter?.presentAudioState(.init(
                sessionId: request.sessionId,
                isPlaying: true,
                progress: 0,
                durationSeconds: audioPlayer.duration
            ))
        } catch {
            logger.error("playAudio failed: \(error.localizedDescription, privacy: .public)")
            presenter?.presentFailure(
                .init(message: String(localized: "sessionHistory.audio.error.playback"))
            )
        }
    }

    func stopAudio(_ request: SessionHistoryModels.StopAudio.Request) {
        guard let playingId = currentPlayingSessionId else { return }
        logger.info("stopAudio sessionId=\(playingId, privacy: .public)")
        stopCurrentAudioIfNeeded()

        presenter?.presentAudioState(.init(
            sessionId: playingId,
            isPlaying: false,
            progress: 0,
            durationSeconds: 0
        ))
    }

    // MARK: - Statistics Summary

    func loadStatsSummary(_ request: SessionHistoryModels.LoadStatsSummary.Request) {
        logger.info("loadStatsSummary childId=\(request.childId, privacy: .public)")
        let stats = buildStatsSummary(sessions: allSessions)

        let response = SessionHistoryModels.LoadStatsSummary.Response(
            totalSessions: stats.totalSessions,
            totalMinutes: stats.totalMinutes,
            averageScorePercent: stats.averageScorePercent,
            bestSound: stats.bestSound,
            hardestSound: stats.hardestSound,
            weekSessions: stats.weekSessions,
            prevWeekSessions: stats.prevWeekSessions,
            soundBreakdown: stats.soundBreakdown
        )
        presenter?.presentStatsSummary(response)
    }

    // MARK: - Lyalya Comment

    func loadLyalyaComment(_ request: SessionHistoryModels.LoadLyalyaComment.Request) {
        let weekCount = countSessionsThisWeek(allSessions)
        let avgScore = averageScore(allSessions)
        let childName = request.childName.isEmpty ? String(localized: "sessionHistory.lyalya.defaultName") : request.childName

        let comment = buildLyalyaComment(
            childName: childName,
            weekCount: weekCount,
            avgScore: avgScore,
            totalSessions: allSessions.count
        )
        logger.info("loadLyalyaComment weekCount=\(weekCount, privacy: .public)")

        let response = SessionHistoryModels.LoadLyalyaComment.Response(
            commentText: comment
        )
        presenter?.presentLyalyaComment(response)
    }

    // MARK: - Search

    func performSearch(_ request: SessionHistoryModels.Search.Request) {
        searchQuery = request.query.trimmingCharacters(in: .whitespacesAndNewlines)
        currentPage = 0
        isLastPage = false
        logger.info("performSearch query=\(self.searchQuery.count, privacy: .public) chars")

        let filtered = applyFilterAndSearch(allSessions)
        let sorted = applySortOrder(filtered)
        let pageSlice = pageOf(sessions: sorted, page: currentPage)
        isLastPage = pageSlice.count < Constants.pageSize

        let response = SessionHistoryModels.Search.Response(
            sessions: pageSlice,
            allSessions: allSessions,
            query: searchQuery,
            activeFilter: activeFilter,
            activeSort: activeSort,
            currentPage: currentPage,
            isLastPage: isLastPage
        )
        presenter?.presentSearch(response)
    }
}

// MARK: - Filter + Sort + Search

private extension SessionHistoryInteractor {

    func applyFilterAndSearch(_ sessions: [SessionRecord]) -> [SessionRecord] {
        var result = sessions

        // Date range
        if let fromDate = activeFilter.fromDate {
            let calendar = Calendar.current
            let fromStart = calendar.startOfDay(for: fromDate)
            result = result.filter { calendar.startOfDay(for: $0.date) >= fromStart }
        }
        if let toDate = activeFilter.toDate {
            let calendar = Calendar.current
            let toStart = calendar.startOfDay(for: toDate)
            result = result.filter { calendar.startOfDay(for: $0.date) <= toStart }
        }

        // Sound filter
        if !activeFilter.sounds.isEmpty {
            result = result.filter { activeFilter.sounds.contains($0.soundTarget) }
        }

        // Game type filter
        if !activeFilter.gameTypes.isEmpty {
            result = result.filter { activeFilter.gameTypes.contains($0.gameType) }
        }

        // Score range filter
        switch activeFilter.scoreRange {
        case .high:
            result = result.filter { $0.score >= 0.80 }
        case .medium:
            result = result.filter { $0.score >= 0.50 && $0.score < 0.80 }
        case .low:
            result = result.filter { $0.score < 0.50 }
        case .all:
            break
        }

        // Full-text search: по звуку, типу игры, дате
        if !searchQuery.isEmpty {
            let lowercasedQuery = searchQuery.lowercased()
            result = result.filter { session in
                session.soundTarget.lowercased().contains(lowercasedQuery)
                || session.gameType.displayName.lowercased().contains(lowercasedQuery)
                || Self.dateSearchString(for: session.date).contains(lowercasedQuery)
            }
        }

        return result
    }

    func applySortOrder(_ sessions: [SessionRecord]) -> [SessionRecord] {
        switch activeSort {
        case .byDate:
            return sessions.sorted { $0.date > $1.date }
        case .byScore:
            return sessions.sorted { $0.score > $1.score }
        case .bySound:
            return sessions.sorted { $0.soundTarget < $1.soundTarget }
        case .byDuration:
            return sessions.sorted { $0.durationSec > $1.durationSec }
        }
    }

    func pageOf(sessions: [SessionRecord], page: Int) -> [SessionRecord] {
        let start = page * Constants.pageSize
        guard start < sessions.count else { return [] }
        let end = min(sessions.count, start + Constants.pageSize)
        return Array(sessions[start..<end])
    }

    static func dateSearchString(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "d MMMM yyyy"
        return df.string(from: date).lowercased()
    }
}

// MARK: - Statistics

private extension SessionHistoryInteractor {

    struct StatsSummary {
        let totalSessions: Int
        let totalMinutes: Int
        let averageScorePercent: Int
        let bestSound: String
        let hardestSound: String
        let weekSessions: Int
        let prevWeekSessions: Int
        let soundBreakdown: [SoundScoreBreakdownItem]
    }

    func buildStatsSummary(sessions: [SessionRecord]) -> StatsSummary {
        let total = sessions.count
        let totalMinutes = sessions.reduce(0) { $0 + $1.durationSec } / 60

        let avgScore: Int
        if sessions.isEmpty {
            avgScore = 0
        } else {
            let sum = sessions.reduce(0.0) { $0 + Double($1.score) }
            avgScore = Int((sum / Double(sessions.count) * 100).rounded())
        }

        // Per-sound breakdown
        var soundScores: [String: [Float]] = [:]
        for session in sessions where session.soundTarget != "—" {
            soundScores[session.soundTarget, default: []].append(session.score)
        }
        let breakdown = soundScores.map { sound, scores -> SoundScoreBreakdownItem in
            let avg = scores.reduce(0, +) / Float(scores.count)
            return SoundScoreBreakdownItem(sound: sound, averageScore: avg, sessionCount: scores.count)
        }.sorted { $0.averageScore > $1.averageScore }

        let bestSound = breakdown.first?.sound ?? "—"
        let hardestSound = breakdown.last?.sound ?? "—"

        // This week vs prev week
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let weekSessions = sessions.filter { $0.date >= weekAgo }.count
        let prevWeekSessions = sessions.filter { $0.date >= twoWeeksAgo && $0.date < weekAgo }.count

        return StatsSummary(
            totalSessions: total,
            totalMinutes: totalMinutes,
            averageScorePercent: avgScore,
            bestSound: bestSound,
            hardestSound: hardestSound,
            weekSessions: weekSessions,
            prevWeekSessions: prevWeekSessions,
            soundBreakdown: breakdown
        )
    }

    func countSessionsThisWeek(_ sessions: [SessionRecord]) -> Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessions.filter { $0.date >= weekAgo }.count
    }

    func averageScore(_ sessions: [SessionRecord]) -> Double {
        guard !sessions.isEmpty else { return 0 }
        let sum = sessions.reduce(0.0) { $0 + Double($1.score) }
        return sum / Double(sessions.count)
    }
}

// MARK: - Lyalya Comment Builder

private extension SessionHistoryInteractor {

    func buildLyalyaComment(
        childName: String,
        weekCount: Int,
        avgScore: Double,
        totalSessions: Int
    ) -> String {
        let scorePercent = Int(avgScore * 100)

        if weekCount == 0 {
            return String(
                format: String(localized: "sessionHistory.lyalya.noSessions"),
                childName
            )
        }

        if weekCount >= Constants.lyalyaSessionThreshold {
            if scorePercent >= 75 {
                return String(
                    format: String(localized: "sessionHistory.lyalya.excellentWeek"),
                    childName,
                    weekCount
                )
            } else {
                return String(
                    format: String(localized: "sessionHistory.lyalya.goodWeek"),
                    childName,
                    weekCount
                )
            }
        }

        if scorePercent >= 80 {
            return String(
                format: String(localized: "sessionHistory.lyalya.highScore"),
                childName,
                scorePercent
            )
        }

        return String(
            format: String(localized: "sessionHistory.lyalya.keepGoing"),
            childName,
            weekCount
        )
    }
}

// MARK: - Export Helpers

private extension SessionHistoryInteractor {

    /// Конвертирует `SessionRecord` (in-memory VIP тип) в `SessionDTO` (Data layer тип).
    /// Необходимо для передачи в `SpecialistExportService`.
    func buildSessionDTO(from record: SessionRecord) -> SessionDTO {
        let attempts = (attemptsBySession[record.id] ?? []).map { att in
            AttemptDTO(
                id: att.id,
                word: att.word,
                audioLocalPath: audioFilesBySession[record.id] ?? "",
                audioStoragePath: "",
                asrTranscript: att.word,
                asrScore: Double(att.score),
                pronunciationScore: Double(att.score),
                manualScore: 0,
                isCorrect: att.isCorrect,
                timestamp: record.date
            )
        }
        return SessionDTO(
            id: record.id,
            childId: "history-child",
            date: record.date,
            templateType: record.gameType.rawValue,
            targetSound: record.soundTarget,
            stage: "wordInit",
            durationSeconds: record.durationSec,
            totalAttempts: record.attempts,
            correctAttempts: Int(Float(record.attempts) * record.score),
            fatigueDetected: false,
            isSynced: false,
            attempts: attempts
        )
    }

    /// Формирует JSON-файл из всех сессий для backup-экспорта.
    func buildJSONExport(childId: String) throws -> URL {
        struct JSONSession: Encodable {
            let id: String
            let date: String
            let gameType: String
            let sound: String
            let score: Float
            let durationSec: Int
            let attempts: Int
            let isPassed: Bool
        }

        let dateFormatter = ISO8601DateFormatter()
        let sessions = allSessions.map { s in
            JSONSession(
                id: s.id,
                date: dateFormatter.string(from: s.date),
                gameType: s.gameType.rawValue,
                sound: s.soundTarget,
                score: s.score,
                durationSec: s.durationSec,
                attempts: s.attempts,
                isPassed: s.isPassed
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sessions)

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hs-reports", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let timestamp = Int(Date().timeIntervalSince1970)
        let url = dir.appendingPathComponent("sessions-\(childId)-\(timestamp).json")
        try data.write(to: url, options: .atomic)
        return url
    }
}

// MARK: - Audio Helpers

private extension SessionHistoryInteractor {

    func stopCurrentAudioIfNeeded() {
        audioPlayer.stop()
        isPlayingAudio = false
        currentPlayingSessionId = nil
    }
}

// MARK: - Seed data

private extension SessionHistoryInteractor {

    static func makeSeedSessions() -> (
        sessions: [SessionRecord],
        attempts: [String: [SessionAttemptRecord]],
        audioFiles: [String: String]
    ) {
        let calendar = Calendar.current
        let now = Date()

        func dateAt(daysAgo: Int, hour: Int = 17, minute: Int = 30) -> Date {
            let baseDay = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            return calendar.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: baseDay
            ) ?? baseDay
        }

        struct SeedRow {
            let daysAgo: Int
            let hour: Int
            let minute: Int
            let template: TemplateType
            let sound: String
            let score: Float
            let durationSec: Int
            let attempts: Int
            let words: [String]
        }

        let rows: [SeedRow] = [
            SeedRow(daysAgo: 0, hour: 17, minute: 30, template: .listenAndChoose,
                    sound: "Р", score: 0.86, durationSec: 540, attempts: 12,
                    words: ["рыба", "ракета", "рука", "роза", "ручей"]),
            SeedRow(daysAgo: 1, hour: 18, minute: 5, template: .repeatAfterModel,
                    sound: "Р", score: 0.72, durationSec: 480, attempts: 10,
                    words: ["трава", "пирог", "ворона", "корова", "сорока"]),
            SeedRow(daysAgo: 2, hour: 17, minute: 0, template: .memory,
                    sound: "Ш", score: 0.91, durationSec: 510, attempts: 14,
                    words: ["шар", "мышь", "шуба", "машина", "шапка"]),
            SeedRow(daysAgo: 3, hour: 18, minute: 30, template: .breathing,
                    sound: "—", score: 0.95, durationSec: 240, attempts: 6,
                    words: ["вдох-выдох", "пёрышко", "одуванчик"]),
            SeedRow(daysAgo: 4, hour: 17, minute: 45, template: .sorting,
                    sound: "Л", score: 0.62, durationSec: 600, attempts: 11,
                    words: ["лук", "лужа", "стол", "белка", "лента"]),
            SeedRow(daysAgo: 6, hour: 18, minute: 0, template: .puzzleReveal,
                    sound: "С", score: 0.78, durationSec: 420, attempts: 9,
                    words: ["сок", "лиса", "автобус", "снег", "сумка"]),
            SeedRow(daysAgo: 7, hour: 17, minute: 20, template: .minimalPairs,
                    sound: "С", score: 0.55, durationSec: 660, attempts: 13,
                    words: ["сук-шук", "кас-каш", "плюс-плющ"]),
            SeedRow(daysAgo: 9, hour: 18, minute: 15, template: .articulationImitation,
                    sound: "Р", score: 0.82, durationSec: 360, attempts: 7,
                    words: ["рр-р-р", "тдр-тдр", "брр-брр"]),
            SeedRow(daysAgo: 12, hour: 17, minute: 30, template: .narrativeQuest,
                    sound: "Ш", score: 0.74, durationSec: 720, attempts: 15,
                    words: ["шарик", "мишка", "шишка", "лошадка"]),
            SeedRow(daysAgo: 14, hour: 18, minute: 5, template: .bingo,
                    sound: "Л", score: 0.88, durationSec: 540, attempts: 12,
                    words: ["лимон", "ёлка", "лак", "лошадь", "пила"]),
            SeedRow(daysAgo: 18, hour: 17, minute: 50, template: .soundHunter,
                    sound: "З", score: 0.69, durationSec: 480, attempts: 10,
                    words: ["заяц", "зонт", "коза", "звезда", "зебра"]),
            SeedRow(daysAgo: 22, hour: 18, minute: 0, template: .visualAcoustic,
                    sound: "Ц", score: 0.45, durationSec: 540, attempts: 11,
                    words: ["цветок", "огурец", "цапля", "пицца"]),
            SeedRow(daysAgo: 28, hour: 17, minute: 30, template: .rhythm,
                    sound: "—", score: 0.93, durationSec: 300, attempts: 8,
                    words: ["та-та-та", "ти-ти", "па-па-пам"]),
            SeedRow(daysAgo: 34, hour: 18, minute: 0, template: .dragAndMatch,
                    sound: "Ж", score: 0.66, durationSec: 600, attempts: 12,
                    words: ["жук", "ёж", "лужа", "одежда"]),
            SeedRow(daysAgo: 40, hour: 17, minute: 30, template: .storyCompletion,
                    sound: "К", score: 0.81, durationSec: 660, attempts: 13,
                    words: ["кот", "молоко", "окно", "паук"]),
            SeedRow(daysAgo: 46, hour: 18, minute: 10, template: .arActivity,
                    sound: "Х", score: 0.58, durationSec: 480, attempts: 9,
                    words: ["хвост", "муха", "пух", "хлеб"]),
            SeedRow(daysAgo: 52, hour: 17, minute: 30, template: .listenAndChoose,
                    sound: "Г", score: 0.77, durationSec: 540, attempts: 11,
                    words: ["гусь", "гора", "снег", "пирог"])
        ]

        var sessions: [SessionRecord] = []
        var attempts: [String: [SessionAttemptRecord]] = [:]
        var audioFiles: [String: String] = [:]

        for (index, row) in rows.enumerated() {
            let sessionId = "sess-\(index + 1)"
            let date = dateAt(daysAgo: row.daysAgo, hour: row.hour, minute: row.minute)
            let isPassed = row.score >= 0.7

            let session = SessionRecord(
                id: sessionId,
                date: date,
                gameType: row.template,
                soundTarget: row.sound,
                score: row.score,
                durationSec: row.durationSec,
                attempts: row.attempts,
                isPassed: isPassed
            )
            sessions.append(session)

            var attemptList: [SessionAttemptRecord] = []
            for (wordIndex, word) in row.words.enumerated() {
                let baseScore = max(0.30, min(0.97, row.score + Float.random(in: -0.18...0.18)))
                let isCorrect = baseScore >= 0.65
                attemptList.append(
                    SessionAttemptRecord(
                        id: "\(sessionId)-att-\(wordIndex + 1)",
                        word: word,
                        score: baseScore,
                        isCorrect: isCorrect,
                        durationMs: 1100 + (wordIndex * 80) % 700
                    )
                )
            }
            attempts[sessionId] = attemptList

            // Только первые 5 сессий «имеют» аудио (симуляция).
            if index < 5 {
                audioFiles[sessionId] = "/dev/null"
            }
        }

        return (sessions.sorted { $0.date > $1.date }, attempts, audioFiles)
    }
}
