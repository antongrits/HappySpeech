import FirebaseFunctions
import Foundation

// MARK: - Models

/// Снапшот прогресса по конкретному звуку за неделю.
public struct SoundProgressSnapshot: Sendable, Equatable {
    public let sessions: Int
    public let attempts: Int
    public let correct: Int
    public let successRate: Double

    public init(sessions: Int, attempts: Int, correct: Int, successRate: Double) {
        self.sessions = sessions
        self.attempts = attempts
        self.correct = correct
        self.successRate = successRate
    }
}

/// Еженедельная сводка от нейро-логопеда (rule-based, не LLM).
public struct WeekSummary: Sendable, Equatable {
    public let weekStart: Date
    public let weekEnd: Date
    public let totalSessions: Int
    public let totalMinutes: Int
    public let avgSuccessRate: Double
    public let soundProgress: [String: SoundProgressSnapshot]
    public let recommendations: [String]

    public init(
        weekStart: Date,
        weekEnd: Date,
        totalSessions: Int,
        totalMinutes: Int,
        avgSuccessRate: Double,
        soundProgress: [String: SoundProgressSnapshot],
        recommendations: [String]
    ) {
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.totalSessions = totalSessions
        self.totalMinutes = totalMinutes
        self.avgSuccessRate = avgSuccessRate
        self.soundProgress = soundProgress
        self.recommendations = recommendations
    }
}

// MARK: - Protocol

/// Клиент Cloud Function `generateNeurolinguistSummary`.
public protocol NeurolinguistSummaryClientProtocol: CloudFunctionsClient {
    /// Запрашивает еженедельную rule-based сводку для ребёнка.
    ///
    /// - Parameters:
    ///   - childId: Идентификатор ребёнка.
    ///   - weekOffset: Сдвиг от текущей недели (0 = эта неделя, 1 = прошлая).
    /// - Returns: ``WeekSummary``.
    /// - Throws: ``CloudFunctionsClientError``.
    func summary(
        childId: String,
        weekOffset: Int
    ) async throws -> WeekSummary
}

// MARK: - Live

public final class LiveNeurolinguistSummaryClient: LiveCloudFunctionsClientBase,
                                                   NeurolinguistSummaryClientProtocol,
                                                   @unchecked Sendable {

    public init(region: String = CloudFunctionsRegion.default) {
        super.init(region: region, category: "NeurolinguistSummary")
    }

    public func summary(
        childId: String,
        weekOffset: Int
    ) async throws -> WeekSummary {
        guard !childId.isEmpty else {
            throw CloudFunctionsClientError.invalidArgument("childId")
        }
        let safeOffset = max(0, min(weekOffset, 26))

        let callable = functions.httpsCallable("generateNeurolinguistSummary")
        let payload: [String: Any] = [
            "childId": childId,
            "weekOffset": safeOffset
        ]

        do {
            let result = try await callable.call(payload)
            return try parse(result.data)
        } catch {
            logger.error("generateNeurolinguistSummary error: \(error.localizedDescription)")
            throw mapError(error)
        }
    }

    private func parse(_ data: Any) throws -> WeekSummary {
        let root = try extractDictionary(from: data)
        guard let summary = root["weekSummary"] as? [String: Any] else {
            throw CloudFunctionsClientError.invalidResponse("missing weekSummary")
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let weekStart = (summary["weekStart"] as? String).flatMap { formatter.date(from: $0) }
            ?? Date()
        let weekEnd = (summary["weekEnd"] as? String).flatMap { formatter.date(from: $0) }
            ?? Date()
        let totalSessions = (summary["totalSessions"] as? Int)
            ?? (summary["totalSessions"] as? NSNumber)?.intValue ?? 0
        let totalMinutes = (summary["totalMinutes"] as? Int)
            ?? (summary["totalMinutes"] as? NSNumber)?.intValue ?? 0
        let avgSuccessRate = (summary["avgSuccessRate"] as? Double)
            ?? (summary["avgSuccessRate"] as? NSNumber)?.doubleValue ?? 0

        var soundProgress: [String: SoundProgressSnapshot] = [:]
        if let raw = summary["soundProgress"] as? [String: [String: Any]] {
            for (sound, snap) in raw {
                soundProgress[sound] = SoundProgressSnapshot(
                    sessions: (snap["sessions"] as? Int)
                        ?? (snap["sessions"] as? NSNumber)?.intValue ?? 0,
                    attempts: (snap["attempts"] as? Int)
                        ?? (snap["attempts"] as? NSNumber)?.intValue ?? 0,
                    correct: (snap["correct"] as? Int)
                        ?? (snap["correct"] as? NSNumber)?.intValue ?? 0,
                    successRate: (snap["successRate"] as? Double)
                        ?? (snap["successRate"] as? NSNumber)?.doubleValue ?? 0
                )
            }
        }

        let recommendations = (summary["recommendations"] as? [String]) ?? []

        return WeekSummary(
            weekStart: weekStart,
            weekEnd: weekEnd,
            totalSessions: totalSessions,
            totalMinutes: totalMinutes,
            avgSuccessRate: avgSuccessRate,
            soundProgress: soundProgress,
            recommendations: recommendations
        )
    }
}

// MARK: - Mock

public final class MockNeurolinguistSummaryClient: NeurolinguistSummaryClientProtocol,
                                                   @unchecked Sendable {

    public let region: String = CloudFunctionsRegion.default
    public var stubbedSummary: WeekSummary = WeekSummary(
        weekStart: Date().addingTimeInterval(-7 * 86_400),
        weekEnd: Date(),
        totalSessions: 5,
        totalMinutes: 42,
        avgSuccessRate: 0.78,
        soundProgress: [
            "Р": SoundProgressSnapshot(
                sessions: 3, attempts: 30, correct: 22, successRate: 0.733
            ),
            "Л": SoundProgressSnapshot(
                sessions: 2, attempts: 20, correct: 18, successRate: 0.9
            )
        ],
        recommendations: [
            "Звук «Р» даётся сложнее — вернитесь к этапу слогов.",
            "Отлично закреплён звук «Л» — можно переходить к фразам."
        ]
    )
    public var shouldThrowError: Bool = false

    public init() {}

    public func summary(
        childId: String,
        weekOffset: Int
    ) async throws -> WeekSummary {
        if shouldThrowError {
            throw CloudFunctionsClientError.serverError("Mock error")
        }
        return stubbedSummary
    }
}
