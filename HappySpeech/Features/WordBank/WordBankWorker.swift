import Foundation
import OSLog

// MARK: - WordBankWorkerProtocol

/// Контракт воркера копилки слов.
protocol WordBankWorkerProtocol: Sendable {
    /// Агрегирует все освоенные (isCorrect == true) слова ребёнка из его сессий.
    func fetchWordStats(childId: String) async throws -> [BankWordStat]
}

// MARK: - WordBankWorker (Clean Swift: Worker)
//
// F-303 v25 — изолированный доступ к данным.
//
// Ответственность:
//   • Запросить все сессии ребёнка через SessionRepository (offline, Realm).
//   • Агрегировать Attempt по (word, targetSound): avg(asrScore), count, max(timestamp).
//   • Порог включения: хотя бы одна правильная попытка (isCorrect == true).

struct WordBankWorker: WordBankWorkerProtocol {

    private let sessionRepository: any SessionRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WordBank.Worker"
    )

    init(sessionRepository: any SessionRepository) {
        self.sessionRepository = sessionRepository
    }

    func fetchWordStats(childId: String) async throws -> [BankWordStat] {
        let sessions = try await sessionRepository.fetchAll(childId: childId)
        let stats = Self.aggregate(sessions: sessions)
        Self.logger.debug("WordBank childId=\(childId, privacy: .private) words=\(stats.count)")
        return stats
    }

    // MARK: - Aggregation

    /// Группирует попытки по (word, targetSound). В банк попадают только слова
    /// хотя бы с одной правильной попыткой.
    static func aggregate(sessions: [SessionDTO]) -> [BankWordStat] {
        struct Accumulator {
            var word: String = ""
            var targetSound: String = ""
            var scoreSum: Double = 0
            var attemptCount: Int = 0
            var correctCount: Int = 0
            var lastPracticedAt: Date = .distantPast
        }

        var buckets: [String: Accumulator] = [:]

        for session in sessions {
            for attempt in session.attempts where !attempt.word.isEmpty {
                let key = attempt.word + "_" + session.targetSound
                var acc = buckets[key] ?? Accumulator()
                acc.word = attempt.word
                acc.targetSound = session.targetSound
                acc.scoreSum += attempt.asrScore
                acc.attemptCount += 1
                if attempt.isCorrect { acc.correctCount += 1 }
                if attempt.timestamp > acc.lastPracticedAt {
                    acc.lastPracticedAt = attempt.timestamp
                }
                buckets[key] = acc
            }
        }

        return buckets.compactMap { key, acc -> BankWordStat? in
            guard acc.correctCount > 0, acc.attemptCount > 0 else { return nil }
            return BankWordStat(
                id: key,
                word: acc.word,
                targetSound: acc.targetSound,
                avgScore: acc.scoreSum / Double(acc.attemptCount),
                attemptCount: acc.attemptCount,
                lastPracticedAt: acc.lastPracticedAt,
                isCorrectCount: acc.correctCount
            )
        }
    }
}
