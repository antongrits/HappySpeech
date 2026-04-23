import Foundation

// MARK: - ReportsDocumentFormatter
//
// Pure text formatters for CSV and a plaintext placeholder that stands in for
// real PDF rendering. The placeholder gets wrapped by `SpecialistExportService`
// (UIKit PDFKit layer) in production; keeping it in pure Foundation means the
// aggregator + formatter can be unit-tested without any graphics stack.

enum ReportsDocumentFormatter {

    // MARK: - CSV

    /// Flat per-attempt CSV, one row per attempt, header first.
    /// Schema:  session_id, date_iso, target_sound, stage, word, asr_score, pron_score, manual_score, is_correct
    static func makeCSV(sessions: [SessionDTO]) -> String {
        var lines: [String] = [
            "session_id,date_iso,target_sound,stage,word,asr_score,pron_score,manual_score,is_correct"
        ]
        let formatter = ISO8601DateFormatter()
        for session in sessions {
            for attempt in session.attempts {
                let row = [
                    escape(session.id),
                    escape(formatter.string(from: session.date)),
                    escape(session.targetSound),
                    escape(session.stage),
                    escape(attempt.word),
                    String(format: "%.3f", attempt.asrScore),
                    String(format: "%.3f", attempt.pronunciationScore),
                    String(format: "%.3f", attempt.manualScore),
                    attempt.isCorrect ? "1" : "0",
                ]
                lines.append(row.joined(separator: ","))
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Plaintext PDF stand-in

    /// Readable plaintext summary rendered by SpecialistExportService into a
    /// real PDF. Keeping this separate means we can unit-test the content
    /// without spinning up PDFKit / UIGraphicsRenderer in CI.
    static func makePlainTextReport(childId: String, sessions: [SessionDTO]) -> String {
        let summary = ReportsAggregator.summarize(sessions: sessions)
        let perSound = ReportsAggregator.soundBreakdown(sessions: sessions)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        var out: [String] = [
            "HappySpeech — отчёт о прогрессе",
            "ID ребёнка: \(childId)",
            "Сгенерировано: \(formatter.string(from: Date()))",
            "",
            "Сводка:",
            "  Всего сессий: \(summary.totalSessions)",
            "  Всего минут:  \(summary.totalMinutes)",
            "  Средний успех: \(Int(summary.overallSuccessRate * 100))%",
        ]
        let commaSep = ", "
        if !summary.improvedSounds.isEmpty {
            out.append("  Улучшение: " + summary.improvedSounds.joined(separator: commaSep))
        }
        if !summary.strugglingSounds.isEmpty {
            out.append("  Сложно: " + summary.strugglingSounds.joined(separator: commaSep))
        }
        out.append("")
        out.append("По звукам:")
        for row in perSound {
            let wowString = String(format: "%+.1f", row.weekOverWeekDelta * 100)
            let confidencePercent = Int(row.averageConfidence * 100)
            out.append(
                "  \(row.sound): попыток \(row.attempts), успешных \(row.successes), "
                + "уверенность \(confidencePercent)%, WoW \(wowString)pp"
            )
        }
        return out.joined(separator: "\n") + "\n"
    }

    // MARK: - Private

    private static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}
