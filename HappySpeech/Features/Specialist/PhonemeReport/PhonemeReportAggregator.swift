import Foundation

// MARK: - PhonemeReportAggregator
//
// Чистые функции над `SessionDTO` — превращают РЕАЛЬНУЮ историю сессий в
// карту точности по целевым звукам. Без I/O и без random — тривиально
// тестируется.
//
// Источник каждого числа:
//   • attempts/successes  — `Session.totalAttempts` / `Session.correctAttempts`
//   • accuracy            — среднее `Session.successRate` по сессиям звука
//   • trendDelta          — поздняя половина − ранняя половина (по дате)
//   • history             — `(date, successRate)` каждой сессии звука
//   • lastStage           — `Session.stage` самой свежей сессии звука
// Звук без сессий → строка с `accuracy == nil` (явный «нет данных»).

enum PhonemeReportAggregator {

    /// Строит строки точности по звукам. Объединяет целевые звуки из профиля
    /// (план коррекции) с фактически отработанными в сессиях — так звук из
    /// плана без практики получает честный «нет данных», а звук, который
    /// ребёнок практиковал вне плана, тоже попадает в отчёт.
    static func buildRows(
        targetSounds: [String],
        sessions: [SessionDTO]
    ) -> [PhonemeReportRow] {
        let grouped = Dictionary(grouping: sessions, by: { normalize($0.targetSound) })

        // Полный набор звуков: план ∪ фактически встреченные в сессиях.
        let plannedNormalized = targetSounds.map(normalize)
        let allSounds = orderedUnique(plannedNormalized + Array(grouped.keys))
            .filter { !$0.isEmpty }

        return allSounds.map { sound -> PhonemeReportRow in
            let group = grouped[sound] ?? []
            return makeRow(sound: sound, sessions: group)
        }
        .sorted(by: rowOrder)
    }

    /// Группирует строки по `SoundFamily`, сохраняя только непустые группы.
    static func groupByFamily(
        _ rows: [PhonemeReportRow]
    ) -> [(family: SoundFamily, rows: [PhonemeReportRow])] {
        let grouped = Dictionary(grouping: rows, by: { $0.family })
        return SoundFamily.allCases.compactMap { family in
            guard let familyRows = grouped[family], !familyRows.isEmpty else { return nil }
            return (family, familyRows.sorted(by: rowOrder))
        }
    }

    // MARK: - Per-sound row

    private static func makeRow(sound: String, sessions: [SessionDTO]) -> PhonemeReportRow {
        let family = ChildHomePresenter.family(for: sound)
        guard !sessions.isEmpty else {
            return PhonemeReportRow(
                sound: sound, family: family,
                attempts: 0, successes: 0, accuracy: nil,
                sessionCount: 0, trendDelta: nil, lastStageRaw: nil, history: []
            )
        }
        let ordered = sessions.sorted { $0.date < $1.date }
        let attempts = ordered.map(\.totalAttempts).reduce(0, +)
        let successes = ordered.map(\.correctAttempts).reduce(0, +)
        let accuracy = ordered.map(\.successRate).reduce(0, +) / Double(ordered.count)

        let history = ordered.map { HistoryPoint(date: $0.date, accuracy: $0.successRate) }
        let trend = trendDelta(ordered: ordered)
        let lastStage = ordered.last?.stage

        return PhonemeReportRow(
            sound: sound, family: family,
            attempts: attempts, successes: successes,
            accuracy: accuracy,
            sessionCount: ordered.count,
            trendDelta: trend,
            lastStageRaw: lastStage,
            history: history
        )
    }

    /// Дельта тренда: средняя точность поздней половины минус ранней.
    /// `nil`, если сессий < 2.
    private static func trendDelta(ordered: [SessionDTO]) -> Double? {
        guard ordered.count >= 2 else { return nil }
        let half = ordered.count / 2
        let earlier = ordered.prefix(half)
        let later = ordered.suffix(ordered.count - half)
        guard !earlier.isEmpty, !later.isEmpty else { return nil }
        let earlierAvg = earlier.map(\.successRate).reduce(0, +) / Double(earlier.count)
        let laterAvg = later.map(\.successRate).reduce(0, +) / Double(later.count)
        return laterAvg - earlierAvg
    }

    // MARK: - Coverage

    /// Сколько звуков из набора имеют реальные данные.
    static func coverage(_ rows: [PhonemeReportRow]) -> (withData: Int, total: Int) {
        (rows.filter(\.hasData).count, rows.count)
    }

    // MARK: - Helpers

    /// Нормализует целевой звук к одной форме (верхний регистр, обрезка
    /// пробелов). Мягкие пары вроде «Рь»/«Ль» считаются отдельными звуками
    /// (соответствует методологии), регистр приводится к верхнему.
    private static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func orderedUnique(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in items where !seen.contains(item) {
            seen.insert(item)
            result.append(item)
        }
        return result
    }

    /// Порядок строк: сначала по группе (в порядке `SoundFamily.allCases`),
    /// затем по убыванию числа сессий (отработанные выше), затем по алфавиту.
    private static func rowOrder(_ lhs: PhonemeReportRow, _ rhs: PhonemeReportRow) -> Bool {
        let li = SoundFamily.allCases.firstIndex(of: lhs.family) ?? 0
        let ri = SoundFamily.allCases.firstIndex(of: rhs.family) ?? 0
        if li != ri { return li < ri }
        if lhs.sessionCount != rhs.sessionCount { return lhs.sessionCount > rhs.sessionCount }
        return lhs.sound < rhs.sound
    }
}
