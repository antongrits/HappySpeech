import Foundation
import OSLog

// MARK: - SessionReviewBusinessLogic

@MainActor
protocol SessionReviewBusinessLogic: AnyObject {
    func loadSession(_ request: SessionReviewModels.LoadSession.Request) async
    func setManualScore(_ request: SessionReviewModels.SetManualScore.Request) async
    func finalizeReview(_ request: SessionReviewModels.FinalizeReview.Request) async
    func loadDetails(_ request: SessionReviewModels.LoadDetails.Request) async
    func exportPDF(_ request: SessionReviewModels.ExportPDF.Request) async
    /// M6.15: Загрузить per-attempt scoring breakdown для текущей сессии.
    func loadAttemptBreakdown(_ request: SessionReviewModels.LoadAttemptBreakdown.Request) async
    /// M6.15: Добавить текстовую аннотацию специалиста к попытке или всей сессии.
    func addAnnotation(_ request: SessionReviewModels.AddAnnotation.Request) async
    /// M6.15: Удалить аннотацию.
    func deleteAnnotation(_ request: SessionReviewModels.DeleteAnnotation.Request) async
}

// MARK: - SessionReviewInteractor

/// Per-attempt review flow + (M6.15 B1) расширенный обзор сессии для
/// специалиста. Загружает сессию + профиль ребёнка через репозитории,
/// агрегирует результаты по играм и фонемам, генерирует PDF через
/// `SpecialistExportService`.
@MainActor
final class SessionReviewInteractor: SessionReviewBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any SessionReviewPresentationLogic)?

    private let sessionRepository: any SessionRepository
    private let childRepository: (any ChildRepository)?
    private let exportService: (any SpecialistExportService)?
    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionReview")

    // MARK: - State

    private var currentSession: SessionDTO?
    private var rows: [AttemptReviewRow] = []
    private var specialistNotes: String = ""
    private var currentSummary: SessionSummary?
    /// M6.15: Breakdown по попыткам — статистика по каждой попытке с детализацией.
    private var attemptBreakdown: [AttemptBreakdownRow] = []
    /// M6.15: Аннотации специалиста (in-memory; при наличии Realm-поддержки
    /// перепишутся через `SessionAnnotation`-объект в Data-слое).
    private var annotations: [SessionAnnotation] = []

    // MARK: - Init

    init(
        sessionRepository: any SessionRepository,
        childRepository: (any ChildRepository)? = nil,
        exportService: (any SpecialistExportService)? = nil
    ) {
        self.sessionRepository = sessionRepository
        self.childRepository = childRepository
        self.exportService = exportService
    }

    // MARK: - Per-attempt: Load

    func loadSession(_ request: SessionReviewModels.LoadSession.Request) async {
        do {
            let session = try await sessionRepository.fetch(id: request.sessionId)
            currentSession = session
            rows = session.attempts.map { attempt in
                AttemptReviewRow(
                    id: attempt.id,
                    word: attempt.word,
                    asrTranscript: attempt.asrTranscript,
                    autoScore: max(attempt.asrScore, attempt.pronunciationScore),
                    manualScore: attempt.manualScore > 0 ? attempt.manualScore : nil,
                    audioPath: attempt.audioLocalPath,
                    isMarkedCorrect: attempt.isCorrect
                )
            }
            await presenter?.presentLoadSession(.init(
                session: session,
                attemptRows: rows
            ))
        } catch {
            logger.error("loadSession failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Per-attempt: Manual override

    func setManualScore(_ request: SessionReviewModels.SetManualScore.Request) async {
        guard let index = rows.firstIndex(where: { $0.id == request.attemptId }) else { return }
        let clamped = max(0.0, min(1.0, request.manualScore))
        let current = rows[index]
        rows[index] = AttemptReviewRow(
            id: current.id,
            word: current.word,
            asrTranscript: current.asrTranscript,
            autoScore: current.autoScore,
            manualScore: clamped,
            audioPath: current.audioPath,
            isMarkedCorrect: clamped >= 0.5
        )
        let summary = Self.makeSummary(rows: rows)
        await presenter?.presentSetManualScore(.init(attemptRows: rows, summary: summary))
    }

    // MARK: - Per-attempt: Finalize

    func finalizeReview(_ request: SessionReviewModels.FinalizeReview.Request) async {
        specialistNotes = request.specialistNotes
        let savedAt = Date()
        logger.info("review finalized session=\(request.sessionId, privacy: .public) notes=\(request.specialistNotes.count, privacy: .public)")
        await presenter?.presentFinalizeReview(.init(savedAt: savedAt))
    }

    // MARK: - Full session details (B1)

    func loadDetails(_ request: SessionReviewModels.LoadDetails.Request) async {
        do {
            let session = try await sessionRepository.fetch(id: request.sessionId)
            currentSession = session

            let childName = await resolveChildName(for: session.childId)
            let games = Self.aggregateGames(from: session)
            let phonemeAccuracy = Self.aggregatePhonemeAccuracy(from: session)
            let recommendation = Self.makeRecommendation(
                accuracy: phonemeAccuracy,
                fatigueDetected: session.fatigueDetected,
                successRate: session.successRate,
                targetSound: session.targetSound
            )

            let summary = SessionSummary(
                sessionId: session.id,
                date: session.date,
                duration: TimeInterval(session.durationSeconds),
                childName: childName,
                targetSound: session.targetSound,
                games: games,
                phonemeAccuracy: phonemeAccuracy,
                llmRecommendation: recommendation,
                totalAttempts: session.totalAttempts,
                correctAttempts: session.correctAttempts,
                fatigueDetected: session.fatigueDetected
            )
            currentSummary = summary

            await presenter?.presentLoadDetails(.init(summary: summary))
        } catch {
            logger.error("loadDetails failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Export PDF

    func exportPDF(_ request: SessionReviewModels.ExportPDF.Request) async {
        guard let exportService else {
            logger.error("exportPDF: SpecialistExportService is not wired")
            return
        }
        do {
            let session: SessionDTO
            if let cached = currentSession, cached.id == request.sessionId {
                session = cached
            } else {
                session = try await sessionRepository.fetch(id: request.sessionId)
            }
            let url = try await exportService.generatePDF(
                childId: session.childId,
                sessions: [session]
            )
            logger.info("PDF exported for session=\(request.sessionId, privacy: .public) at=\(url.lastPathComponent, privacy: .public)")
            await presenter?.presentExportPDF(.init(url: url))
        } catch {
            logger.error("exportPDF failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Helpers

    /// Подтягивает имя ребёнка через `ChildRepository`. Если репозиторий
    /// не задан или вернул ошибку — возвращает локализованный fallback.
    private func resolveChildName(for childId: String) async -> String {
        guard let childRepository else {
            return String(localized: "review.child.unknown")
        }
        do {
            let profile = try await childRepository.fetch(id: childId)
            return profile.name
        } catch {
            logger.warning("resolveChildName failed for \(childId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return String(localized: "review.child.unknown")
        }
    }

    // MARK: - Aggregations (pure)

    /// Группирует попытки сессии по `templateType`. Внутри сессии может
    /// быть только один шаблон (текущая модель `Session.templateType`),
    /// но методология предусматривает мини-блоки — поэтому мы сначала
    /// смотрим на префикс слова (используется в bingo / sorting),
    /// иначе — собираем единый блок по шаблону сессии.
    static func aggregateGames(from session: SessionDTO) -> [GameResult] {
        guard !session.attempts.isEmpty else {
            return [
                GameResult(
                    id: session.templateType,
                    gameName: gameName(for: session.templateType),
                    templateType: session.templateType,
                    correct: session.correctAttempts,
                    total: session.totalAttempts
                )
            ]
        }
        // В MVP: одна сессия = одна игра.
        let correct = session.attempts.filter(\.isCorrect).count
        let total = session.attempts.count
        return [
            GameResult(
                id: session.templateType,
                gameName: gameName(for: session.templateType),
                templateType: session.templateType,
                correct: correct,
                total: total
            )
        ]
    }

    /// Собирает {фонема → средняя точность 0...1} из попыток сессии.
    /// Для каждой попытки берём `max(asrScore, pronunciationScore)` —
    /// это эффективная оценка произношения. Группировка по `targetSound`
    /// сессии (т.е. в рамках сессии все попытки относятся к одному
    /// целевому звуку) + дополнительная буква, если в слове встречается
    /// другая фонема из same-group.
    static func aggregatePhonemeAccuracy(from session: SessionDTO) -> [String: Double] {
        guard !session.attempts.isEmpty else { return [:] }
        var bucket: [String: [Double]] = [:]
        let key = session.targetSound
        for attempt in session.attempts {
            let score = attempt.manualScore > 0
                ? attempt.manualScore
                : max(attempt.asrScore, attempt.pronunciationScore)
            bucket[key, default: []].append(score)
        }
        return bucket.mapValues { values in
            guard !values.isEmpty else { return 0 }
            return values.reduce(0, +) / Double(values.count)
        }
    }

    /// Простая эвристическая «рекомендация» — ставится, если LLM не сгенерил
    /// своё предложение. Реальная LLM-рекомендация может приходить позже
    /// через `LLMDecisionService.recommendNextStep` и сохраняться в Realm
    /// (см. backlog M6.16). Пока используем интерпретируемые правила.
    static func makeRecommendation(
        accuracy: [String: Double],
        fatigueDetected: Bool,
        successRate: Double,
        targetSound: String
    ) -> String? {
        if fatigueDetected {
            let format = String(localized: "review.recommendation.fatigue")
            return String(format: format, targetSound)
        }
        if successRate >= 0.85 {
            let format = String(localized: "review.recommendation.advance")
            return String(format: format, targetSound)
        }
        if successRate < 0.5 {
            let format = String(localized: "review.recommendation.regress")
            return String(format: format, targetSound)
        }
        return nil
    }

    /// Человекочитаемое имя шаблона. Источник истины — `TemplateType`,
    /// здесь — словарь UI-меток.
    static func gameName(for templateType: String) -> String {
        gameNameMap[templateType] ?? templateType
    }

    private static let gameNameMap: [String: String] = [
        "listenAndChoose": String(localized: "game.listen_and_choose"),
        "repeatAfterModel": String(localized: "game.repeat_after_model"),
        "dragAndMatch": String(localized: "game.drag_and_match"),
        "storyCompletion": String(localized: "game.story_completion"),
        "puzzleReveal": String(localized: "game.puzzle_reveal"),
        "sorting": String(localized: "game.sorting"),
        "memory": String(localized: "game.memory"),
        "bingo": String(localized: "game.bingo"),
        "soundHunter": String(localized: "game.sound_hunter"),
        "articulationImitation": String(localized: "game.articulation_imitation"),
        "ARActivity": String(localized: "game.ar_activity"),
        "visualAcoustic": String(localized: "game.visual_acoustic"),
        "breathing": String(localized: "game.breathing"),
        "rhythm": String(localized: "game.rhythm"),
        "narrativeQuest": String(localized: "game.narrative_quest"),
        "minimalPairs": String(localized: "game.minimal_pairs")
    ]

    // MARK: - Summary (existing)

    static func makeSummary(rows: [AttemptReviewRow]) -> SessionReviewSummary {
        guard !rows.isEmpty else {
            return SessionReviewSummary(
                totalAttempts: 0, markedCorrect: 0,
                averageEffectiveScore: 0, disagreementCount: 0
            )
        }
        let avg = rows.map(\.effectiveScore).reduce(0, +) / Double(rows.count)
        let correct = rows.filter(\.isMarkedCorrect).count
        let disagreements = rows.filter { row in
            guard let manual = row.manualScore else { return false }
            return abs(manual - row.autoScore) > 0.15
        }.count
        return SessionReviewSummary(
            totalAttempts: rows.count,
            markedCorrect: correct,
            averageEffectiveScore: avg,
            disagreementCount: disagreements
        )
    }

    // MARK: - M6.15: Per-attempt breakdown

    /// Загружает детальную статистику по каждой попытке текущей сессии.
    /// Если сессия уже закэширована — использует её; иначе подгружает из репозитория.
    func loadAttemptBreakdown(_ request: SessionReviewModels.LoadAttemptBreakdown.Request) async {
        do {
            let session: SessionDTO
            if let cached = currentSession, cached.id == request.sessionId {
                session = cached
            } else {
                session = try await sessionRepository.fetch(id: request.sessionId)
                currentSession = session
            }

            attemptBreakdown = Self.buildBreakdown(from: session)
            await presenter?.presentAttemptBreakdown(.init(
                sessionId: request.sessionId,
                rows: attemptBreakdown
            ))
        } catch {
            logger.error("loadAttemptBreakdown failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - M6.15: Annotations

    /// Добавляет текстовую аннотацию специалиста к попытке или сессии.
    /// `targetAttemptId` == nil означает аннотацию ко всей сессии.
    func addAnnotation(_ request: SessionReviewModels.AddAnnotation.Request) async {
        guard !request.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.warning("addAnnotation: empty text — ignored")
            return
        }
        let annotation = SessionAnnotation(
            id: UUID().uuidString,
            sessionId: request.sessionId,
            targetAttemptId: request.targetAttemptId,
            text: request.text,
            createdAt: Date()
        )
        annotations.append(annotation)
        let attemptIdLog = request.targetAttemptId ?? "session"
        let textLen = request.text.count
        logger.info(
            "addAnnotation sid=\(request.sessionId, privacy: .public) aid=\(attemptIdLog, privacy: .public) len=\(textLen, privacy: .public)"
        )
        await presenter?.presentAnnotationUpdated(.init(
            sessionId: request.sessionId,
            annotations: annotations
        ))
    }

    /// Удаляет аннотацию по id.
    func deleteAnnotation(_ request: SessionReviewModels.DeleteAnnotation.Request) async {
        annotations.removeAll { $0.id == request.annotationId }
        logger.info("deleteAnnotation id=\(request.annotationId, privacy: .public)")
        await presenter?.presentAnnotationUpdated(.init(
            sessionId: request.sessionId,
            annotations: annotations
        ))
    }

    // MARK: - Helpers (M6.15)

    /// Строит per-attempt breakdown — детальные строки с ASR/ML/manual score.
    static func buildBreakdown(from session: SessionDTO) -> [AttemptBreakdownRow] {
        session.attempts.enumerated().map { index, attempt in
            let autoScore = max(attempt.asrScore, attempt.pronunciationScore >= 0 ? attempt.pronunciationScore : 0)
            let effectiveScore = attempt.manualScore > 0 ? attempt.manualScore : autoScore
            let confidence = ScoreConfidence.make(
                asr: attempt.asrScore,
                pronunciation: attempt.pronunciationScore,
                manual: attempt.manualScore
            )
            return AttemptBreakdownRow(
                index: index + 1,
                id: attempt.id,
                word: attempt.word,
                asrTranscript: attempt.asrTranscript,
                asrScore: attempt.asrScore,
                pronunciationScore: attempt.pronunciationScore >= 0 ? attempt.pronunciationScore : nil,
                manualScore: attempt.manualScore > 0 ? attempt.manualScore : nil,
                effectiveScore: effectiveScore,
                isCorrect: attempt.isCorrect,
                audioPath: attempt.audioLocalPath,
                confidence: confidence,
                timestamp: attempt.timestamp
            )
        }
    }

    /// Вычисляет среднюю точность по группам attemptBreakdown.
    static func breakdownStats(from rows: [AttemptBreakdownRow]) -> BreakdownStats {
        guard !rows.isEmpty else {
            return BreakdownStats(
                averageASR: 0, averagePronunciation: nil,
                averageEffective: 0, totalCorrect: 0, manualOverrideCount: 0
            )
        }
        let avgASR = rows.map(\.asrScore).reduce(0, +) / Double(rows.count)
        let pronunciationRows = rows.compactMap(\.pronunciationScore)
        let avgPron: Double? = pronunciationRows.isEmpty
            ? nil
            : pronunciationRows.reduce(0, +) / Double(pronunciationRows.count)
        let avgEff = rows.map(\.effectiveScore).reduce(0, +) / Double(rows.count)
        let correct = rows.filter(\.isCorrect).count
        let overrides = rows.filter { $0.manualScore != nil }.count
        return BreakdownStats(
            averageASR: avgASR,
            averagePronunciation: avgPron,
            averageEffective: avgEff,
            totalCorrect: correct,
            manualOverrideCount: overrides
        )
    }

    // MARK: - Test hooks

    // swiftlint:disable identifier_name
    func _rows() -> [AttemptReviewRow] { rows }
    func _summary() -> SessionSummary? { currentSummary }
    func _attemptBreakdown() -> [AttemptBreakdownRow] { attemptBreakdown }
    func _annotations() -> [SessionAnnotation] { annotations }
    // swiftlint:enable identifier_name
}
