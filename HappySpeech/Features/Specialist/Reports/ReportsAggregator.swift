import Foundation

// MARK: - ReportsAggregator
//
// Pure functions over `SessionDTO` — produce the building blocks that the
// ReportsInteractor shows on screen and the ReportsDocumentFormatter writes
// to disk. No I/O, no actors — trivially unit-testable.

enum ReportsAggregator {

    static func summarize(sessions: [SessionDTO]) -> ReportSummary {
        guard !sessions.isEmpty else {
            return ReportSummary(totalSessions: 0, totalMinutes: 0,
                                 overallSuccessRate: 0,
                                 improvedSounds: [], strugglingSounds: [])
        }
        let totalMinutes = sessions
            .map { max(0, Int($0.durationSeconds) / 60) }
            .reduce(0, +)
        let overall = sessions
            .map(\.successRate)
            .reduce(0, +) / Double(sessions.count)

        // Сгруппировать по звуку: если последняя сессия лучше первой >10% —
        // "улучшение", если хуже >10% — "борется".
        let grouped = Dictionary(grouping: sessions, by: { $0.targetSound })
        var improved: [String] = []
        var struggling: [String] = []
        for (sound, group) in grouped where group.count >= 2 {
            let ordered = group.sorted { $0.date < $1.date }
            guard let first = ordered.first?.successRate,
                  let last  = ordered.last?.successRate else { continue }
            let delta = last - first
            if delta >= 0.10 { improved.append(sound) }
            else if delta <= -0.10 { struggling.append(sound) }
        }

        return ReportSummary(
            totalSessions: sessions.count,
            totalMinutes: totalMinutes,
            overallSuccessRate: overall,
            improvedSounds: improved.sorted(),
            strugglingSounds: struggling.sorted()
        )
    }

    static func soundBreakdown(sessions: [SessionDTO]) -> [SoundBreakdownRow] {
        let grouped = Dictionary(grouping: sessions, by: { $0.targetSound })
        return grouped
            .map { (sound, group) -> SoundBreakdownRow in
                let attempts  = group.map(\.totalAttempts).reduce(0, +)
                let successes = group.map(\.correctAttempts).reduce(0, +)
                let confidence = group.map(\.successRate).reduce(0, +) / Double(group.count)
                // WoW delta: split by midpoint
                let ordered = group.sorted { $0.date < $1.date }
                let half = ordered.count / 2
                let earlierAvg = half == 0 ? 0 :
                    ordered.prefix(half).map(\.successRate).reduce(0, +) / Double(half)
                let laterAvg = ordered.count - half == 0 ? 0 :
                    ordered.suffix(ordered.count - half).map(\.successRate).reduce(0, +)
                        / Double(max(1, ordered.count - half))
                return SoundBreakdownRow(
                    sound: sound,
                    attempts: attempts,
                    successes: successes,
                    averageConfidence: confidence,
                    currentStageTitle: String(localized: "reports.stage.\(group.last?.stage ?? "unknown")"),
                    weekOverWeekDelta: laterAvg - earlierAvg
                )
            }
            .sorted { $0.sound < $1.sound }
    }

    static func timeline(sessions: [SessionDTO]) -> [SessionTimelineEntry] {
        sessions
            .sorted { $0.date < $1.date }
            .map { session in
                SessionTimelineEntry(
                    date: session.date,
                    durationMinutes: max(0, Int(session.durationSeconds) / 60),
                    activityCount: session.totalAttempts,
                    averageScore: session.successRate
                )
            }
    }
}
