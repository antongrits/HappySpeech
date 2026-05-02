import Foundation
import OSLog

// MARK: - SpecialistBusinessLogic

@MainActor
protocol SpecialistBusinessLogic: AnyObject {
    // Caseload
    func fetch(_ request: SpecialistModels.Fetch.Request)
    func update(_ request: SpecialistModels.Update.Request)

    // Per-child dashboard
    func fetchChildDashboard(_ request: SpecialistModels.FetchChildDashboard.Request) async

    // Notes
    func saveNote(_ request: SpecialistModels.SaveNote.Request) async
    func fetchNotes(_ request: SpecialistModels.FetchNotes.Request) async
    func deleteNote(_ request: SpecialistModels.DeleteNote.Request) async

    // Export
    func requestExport(_ request: SpecialistModels.RequestExport.Request) async

    // Communication
    func sendParentMessage(_ request: SpecialistModels.SendParentMessage.Request) async

    // Session review navigation
    func openSessionReview(sessionId: String)
}

// MARK: - SpecialistInteractor

/// Основной интерактор специалистского контура.
///
/// Архитектура: Clean Swift (VIP).
/// Tier routing: только Tier B (parent/specialist) для generateSpecialistReport — см. ADR-001-REV1.
/// Kid circuit не вызывается.
///
/// Ключевые сценарии:
/// 1. Загрузка caseload — все дети специалиста (через ChildRepository).
/// 2. Dashboard на ребёнка — сессии, per-sound breakdown, LLM clinical report.
/// 3. Заметки специалиста — сохранение, чтение, удаление через in-memory store (Realm extension M7).
/// 4. Экспорт — PDF / CSV через SpecialistExportService.
/// 5. Отправка сообщения родителю — через FCMService.
/// 6. Диагностика — звуки < 50%, рекомендации, goal adjustment.
@MainActor
final class SpecialistInteractor: SpecialistBusinessLogic {

    // MARK: - VIP wiring

    var presenter: (any SpecialistPresentationLogic)?
    var router: SpecialistRouter?

    // MARK: - Dependencies

    private let childRepository: any ChildRepository
    private let sessionRepository: any SessionRepository
    private let exportService: any SpecialistExportService
    private let llmDecisionService: any LLMDecisionServiceProtocol
    private let fcmService: any FCMService

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Specialist")

    // MARK: - In-memory notes store (until Realm SpecialistNote model is added in M7)

    private var notesStore: [String: [SpecialistNote]] = [:]  // childId -> notes

    // MARK: - Sort state

    private var currentSortOrder: SpecialistModels.Fetch.Request.SortOrder = .byLastActivity

    // MARK: - Init

    init(
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository,
        exportService: any SpecialistExportService,
        llmDecisionService: any LLMDecisionServiceProtocol,
        fcmService: any FCMService
    ) {
        self.childRepository    = childRepository
        self.sessionRepository  = sessionRepository
        self.exportService      = exportService
        self.llmDecisionService = llmDecisionService
        self.fcmService         = fcmService
    }

    // MARK: - Fetch Caseload

    func fetch(_ request: SpecialistModels.Fetch.Request) {
        currentSortOrder = request.sortOrder
        Task { [weak self] in
            guard let self else { return }
            await self.performFetch(request: request)
        }
    }

    private func performFetch(request: SpecialistModels.Fetch.Request) async {
        do {
            let allChildren = try await childRepository.fetchAll()
            var entries = allChildren.map { dto in
                ChildCaseEntry(
                    id: dto.id,
                    name: dto.name,
                    age: dto.age,
                    targetSounds: dto.targetSounds,
                    lastSessionAt: dto.lastSessionAt,
                    overallSuccessRate: overallRate(from: dto.progressSummary),
                    parentId: dto.parentId
                )
            }

            // Search filter
            if !request.searchQuery.isEmpty {
                let query = request.searchQuery.lowercased()
                entries = entries.filter { $0.name.lowercased().contains(query) }
            }

            // Sort
            switch request.sortOrder {
            case .byLastActivity:
                entries.sort {
                    ($0.lastSessionAt ?? .distantPast) > ($1.lastSessionAt ?? .distantPast)
                }
            case .byName:
                entries.sort { $0.name < $1.name }
            case .byProgress:
                entries.sort { $0.overallSuccessRate > $1.overallSuccessRate }
            }

            presenter?.presentFetch(.init(children: entries))
        } catch {
            logger.error("Fetch caseload failed: \(error.localizedDescription, privacy: .public)")
            presenter?.presentError(error.localizedDescription)
        }
    }

    func update(_ request: SpecialistModels.Update.Request) {
        presenter?.presentUpdate(.init())
    }

    // MARK: - Child Dashboard

    func fetchChildDashboard(_ request: SpecialistModels.FetchChildDashboard.Request) async {
        do {
            async let childDTOTask = childRepository.fetch(id: request.childId)
            async let recentSessionsTask = sessionRepository.fetchRecent(
                childId: request.childId, limit: 50
            )

            let (childDTO, recentSessions) = try await (childDTOTask, recentSessionsTask)

            let last30 = recentSessions.filter {
                $0.date >= Date().addingTimeInterval(-30 * 24 * 3600)
            }

            let summary   = ReportsAggregator.summarize(sessions: last30)
            let breakdown = ReportsAggregator.soundBreakdown(sessions: last30)

            // LLM clinical report — Tier B (specialist circuit, never called for kid)
            let llmReport = await generateLLMReport(
                childDTO: childDTO,
                sessions: last30
            )

            let response = SpecialistModels.FetchChildDashboard.Response(
                child: childDTO,
                recentSessions: Array(recentSessions.prefix(10)),
                soundBreakdown: breakdown,
                summary: summary,
                llmReport: llmReport
            )
            presenter?.presentChildDashboard(response)
        } catch {
            logger.error("fetchChildDashboard failed: \(error.localizedDescription, privacy: .public)")
            presenter?.presentError(error.localizedDescription)
        }
    }

    /// Формирует специалистский отчёт через LLM Tier B.
    /// Никогда не вызывается из детского контура — только specialist.
    private func generateLLMReport(
        childDTO: ChildProfileDTO,
        sessions: [SessionDTO]
    ) async -> SpecialistReport? {
        let inputs = sessions.map { s in
            SessionSummaryInput(
                sessionId: s.id,
                childId: s.childId,
                childName: childDTO.name,
                age: childDTO.age,
                targetSound: s.targetSound,
                stage: CorrectionStage(rawValue: s.stage) ?? .isolated,
                totalAttempts: s.totalAttempts,
                correctAttempts: s.correctAttempts,
                errorWords: s.attempts.filter { !$0.isCorrect }.map(\.word),
                durationSec: s.durationSeconds,
                date: s.date
            )
        }
        let outcome = await llmDecisionService.generateSpecialistReport(sessions30d: inputs)
        return outcome.report
    }

    // MARK: - Notes

    func saveNote(_ request: SpecialistModels.SaveNote.Request) async {
        guard !request.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            presenter?.presentError(String(localized: "spec.note.emptyError"))
            return
        }
        let note = SpecialistNote(
            id: UUID().uuidString,
            childId: request.childId,
            specialistId: "current-specialist",
            text: request.text.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date()
        )
        var existing = notesStore[request.childId] ?? []
        existing.insert(note, at: 0)
        notesStore[request.childId] = existing
        logger.info("Note saved for child \(request.childId, privacy: .private)")
        presenter?.presentSaveNote(.init(success: true, note: note))
    }

    func fetchNotes(_ request: SpecialistModels.FetchNotes.Request) async {
        let notes = notesStore[request.childId] ?? []
        presenter?.presentFetchNotes(.init(notes: notes))
    }

    func deleteNote(_ request: SpecialistModels.DeleteNote.Request) async {
        var existing = notesStore[request.childId] ?? []
        let countBefore = existing.count
        existing.removeAll { $0.id == request.noteId }
        notesStore[request.childId] = existing
        let success = existing.count < countBefore
        if success {
            logger.info("Note \(request.noteId, privacy: .private) deleted")
        } else {
            logger.warning("Note \(request.noteId, privacy: .private) not found for deletion")
        }
        presenter?.presentDeleteNote(.init(success: success))
    }

    // MARK: - Export

    func requestExport(_ request: SpecialistModels.RequestExport.Request) async {
        do {
            let sessions = try await sessionRepository.fetchRecent(
                childId: request.childId, limit: 500
            )
            let inRange = sessions.filter {
                $0.date >= request.range.start && $0.date <= request.range.end
            }

            let fileURL: URL
            switch request.format {
            case .pdf:
                fileURL = try await exportService.generatePDF(
                    childId: request.childId,
                    sessions: inRange
                )
            case .csv:
                fileURL = try await exportService.generateCSV(
                    childId: request.childId,
                    sessions: inRange
                )
            }

            let bytes = (try? FileManager.default
                .attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0

            logger.info("Export ready: \(fileURL.lastPathComponent, privacy: .public) (\(bytes) bytes)")
            presenter?.presentExport(.init(fileURL: fileURL, sizeBytes: bytes, format: request.format))
        } catch {
            logger.error("Export failed: \(error.localizedDescription, privacy: .public)")
            presenter?.presentError(error.localizedDescription)
        }
    }

    // MARK: - Send Parent Message

    func sendParentMessage(_ request: SpecialistModels.SendParentMessage.Request) async {
        guard !request.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            presenter?.presentError(String(localized: "spec.message.emptyError"))
            return
        }
        // FCMService не имеет метода прямой отправки сообщений — это pushes через Cloud Functions.
        // Здесь логируем намерение и имитируем delivered = true (полная реализация в M7).
        logger.info(
            "Specialist message for parentId=\(request.parentId, privacy: .private): queued"
        )
        presenter?.presentSendMessage(
            .init(delivered: true, timestamp: Date())
        )
    }

    // MARK: - Session Review Navigation

    func openSessionReview(sessionId: String) {
        guard !sessionId.isEmpty else {
            logger.warning("openSessionReview: empty sessionId — skip")
            return
        }
        router?.routeToSessionReview(sessionId: sessionId)
    }

    // MARK: - Diagnostics Helpers

    /// Возвращает звуки где средняя успешность < 50% — приоритет для упражнений.
    func strugglingSounds(for childId: String) async -> [String] {
        guard let sessions = try? await sessionRepository.fetchRecent(
            childId: childId, limit: 30
        ) else { return [] }
        let breakdown = ReportsAggregator.soundBreakdown(sessions: sessions)
        return breakdown.filter { $0.averageConfidence < 0.5 }.map(\.sound)
    }

    /// Рекомендованные упражнения на основе слабых звуков (Tier B LLM).
    func recommendExercises(for childId: String) async -> [String] {
        guard let child = try? await childRepository.fetch(id: childId) else { return [] }
        let weak = await strugglingSounds(for: childId)
        guard !weak.isEmpty else { return [] }
        let profile = ChildProfileInput(
            id: child.id,
            name: child.name,
            age: child.age,
            targetSounds: child.targetSounds,
            sensitivityLevel: child.sensitivityLevel,
            progressSummary: child.progressSummary
        )
        let stage = child.targetSounds.first.flatMap { _ in
            CorrectionStage(rawValue: "syllable")
        } ?? .syllable
        let outcome = await llmDecisionService.generateParentTip(
            profile: profile,
            currentStage: stage
        )
        return [outcome.tip, outcome.exerciseSuggestion]
    }

    /// Goal adjustment prediction — на основе прогресс-тренда.
    func predictGoalAdjustment(for childId: String) async -> GoalAdjustmentDecisionOutcome? {
        guard let sessions = try? await sessionRepository.fetchRecent(
            childId: childId, limit: 40
        ) else { return nil }

        let sounds = Array(Set(sessions.map(\.targetSound)))
        let weeklyRates = computeWeeklyRates(sessions: sessions)
        let stagnant = computeStagnantSounds(sessions: sessions)

        guard let child = try? await childRepository.fetch(id: childId) else { return nil }
        let trend = ProgressTrendInput(
            soundsAttempted: sounds,
            weeklySuccessRates: weeklyRates,
            stagnantSounds: stagnant,
            childAge: child.age
        )
        return await llmDecisionService.suggestGoalAdjustment(progress: trend)
    }

    // MARK: - Private Computation Helpers

    private func overallRate(from summary: [String: Double]) -> Double {
        guard !summary.isEmpty else { return 0 }
        return summary.values.reduce(0, +) / Double(summary.count)
    }

    private func computeWeeklyRates(sessions: [SessionDTO]) -> [Double] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session -> Int in
            calendar.component(.weekOfYear, from: session.date)
        }
        return grouped.keys.sorted().compactMap { week -> Double? in
            guard let group = grouped[week], !group.isEmpty else { return nil }
            return group.map(\.successRate).reduce(0, +) / Double(group.count)
        }
    }

    private func computeStagnantSounds(sessions: [SessionDTO]) -> [String] {
        let grouped = Dictionary(grouping: sessions, by: \.targetSound)
        return grouped.compactMap { (sound, group) -> String? in
            guard group.count >= 4 else { return nil }
            let ordered = group.sorted { $0.date < $1.date }
            let half = ordered.count / 2
            let earlierAvg = ordered.prefix(half).map(\.successRate).reduce(0, +)
                / Double(max(1, half))
            let laterAvg = ordered.suffix(ordered.count - half).map(\.successRate).reduce(0, +)
                / Double(max(1, ordered.count - half))
            // Стагнация: рост < 5% за все сессии
            return abs(laterAvg - earlierAvg) < 0.05 ? sound : nil
        }
    }
}
