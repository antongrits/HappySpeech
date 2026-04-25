import Foundation
import OSLog

// MARK: - SessionHistoryBusinessLogic

@MainActor
protocol SessionHistoryBusinessLogic: AnyObject {
    func loadHistory(_ request: SessionHistoryModels.LoadHistory.Request)
    func applyFilter(_ request: SessionHistoryModels.ApplyFilter.Request)
    func clearFilter(_ request: SessionHistoryModels.ClearFilter.Request)
    func openSession(_ request: SessionHistoryModels.OpenSession.Request)
}

// MARK: - SessionHistoryInteractor

/// Бизнес-логика экрана «История сессий».
///
/// Источник данных в M7.2 — in-memory seed (15+ сессий за два месяца, разные
/// звуки, шаблоны, score). На M8 будет подключён `SessionRepository` поверх
/// Realm + listener Firestore — контракт `presenter` останется без изменений.
@MainActor
final class SessionHistoryInteractor: SessionHistoryBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any SessionHistoryPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionHistory")

    // MARK: - State

    private var allSessions: [SessionRecord] = []
    private var attemptsBySession: [String: [SessionAttemptRecord]] = [:]
    private var activeFilter: SessionFilter = .empty

    // MARK: - Init

    init() {
        let seed = Self.makeSeedSessions()
        self.allSessions = seed.sessions
        self.attemptsBySession = seed.attempts
    }

    // MARK: - Business

    func loadHistory(_ request: SessionHistoryModels.LoadHistory.Request) {
        logger.info("loadHistory forceReload=\(request.forceReload, privacy: .public)")

        if request.forceReload {
            let seed = Self.makeSeedSessions()
            allSessions = seed.sessions
            attemptsBySession = seed.attempts
        }

        let response = SessionHistoryModels.LoadHistory.Response(
            allSessions: allSessions,
            activeFilter: activeFilter,
            isFromCache: !request.forceReload
        )
        presenter?.presentLoadHistory(response)
    }

    func applyFilter(_ request: SessionHistoryModels.ApplyFilter.Request) {
        activeFilter = request.filter
        logger.info("applyFilter sounds=\(self.activeFilter.sounds.count, privacy: .public)")

        let response = SessionHistoryModels.ApplyFilter.Response(
            allSessions: allSessions,
            activeFilter: activeFilter
        )
        presenter?.presentApplyFilter(response)
    }

    func clearFilter(_ request: SessionHistoryModels.ClearFilter.Request) {
        activeFilter = .empty
        logger.info("clearFilter")

        let response = SessionHistoryModels.ClearFilter.Response(
            allSessions: allSessions
        )
        presenter?.presentClearFilter(response)
    }

    func openSession(_ request: SessionHistoryModels.OpenSession.Request) {
        guard let session = allSessions.first(where: { $0.id == request.id }) else {
            logger.warning("openSession: not found id=\(request.id, privacy: .public)")
            presenter?.presentFailure(.init(
                message: String(localized: "sessionHistory.error.sessionNotFound")
            ))
            return
        }
        let attempts = attemptsBySession[request.id] ?? []
        logger.info("openSession id=\(session.id, privacy: .public) attempts=\(attempts.count, privacy: .public)")

        let response = SessionHistoryModels.OpenSession.Response(
            session: session,
            attempts: attempts
        )
        presenter?.presentOpenSession(response)
    }
}

// MARK: - Seed data

private extension SessionHistoryInteractor {

    static func makeSeedSessions() -> (sessions: [SessionRecord], attempts: [String: [SessionAttemptRecord]]) {
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
        for (index, row) in rows.enumerated() {
            let id = "sess-\(index + 1)"
            let date = dateAt(daysAgo: row.daysAgo, hour: row.hour, minute: row.minute)
            let isPassed = row.score >= 0.7

            let session = SessionRecord(
                id: id,
                date: date,
                gameType: row.template,
                soundTarget: row.sound,
                score: row.score,
                durationSec: row.durationSec,
                attempts: row.attempts,
                isPassed: isPassed
            )
            sessions.append(session)

            // Генерация попыток: первые слова — успешные, последние — варьируем.
            var attemptList: [SessionAttemptRecord] = []
            for (wIndex, word) in row.words.enumerated() {
                // Успехи концентрируются у начала.
                let baseScore = max(0.3, min(0.97, row.score + Float.random(in: -0.18...0.18)))
                let isCorrect = baseScore >= 0.65
                attemptList.append(
                    SessionAttemptRecord(
                        id: "\(id)-att-\(wIndex + 1)",
                        word: word,
                        score: baseScore,
                        isCorrect: isCorrect,
                        durationMs: 1100 + (wIndex * 80) % 700
                    )
                )
            }
            attempts[id] = attemptList
        }

        return (sessions.sorted { $0.date > $1.date }, attempts)
    }
}
