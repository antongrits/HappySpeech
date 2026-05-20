import Foundation

// MARK: - KaraokePitchCorpus
//
// Тонкая обёртка над `ProsodyCorpus` (v29 pack_prosody.json, 150 фраз).
// Берёт первые 20 фраз во всех трёх типах интонации (statement / question /
// exclamation) сбалансированно — для караоке-сессии этого достаточно,
// а контент не дублируется.
//
// Эталонные pitch-контуры генерируются процедурно из типа интонации, потому
// что аудио-эталонов для всех 20 фраз нет в бандле (это потребовало бы запись
// студийных треков). Принцип:
//   • statement   — плавно вниз;
//   • question    — рост в финале;
//   • exclamation — пик в середине, спуск к концу.
//
// Это упрощённый, но методически корректный контур (Лопатина, Шевцова —
// интонационная структура русской фразы): дети должны не точно воспроизвести
// абсолютную частоту, а попасть в правильный мелодический рисунок. Метрика
// `ContourComparator` оперирует нормализованным контуром, поэтому абсолютная
// высота голоса ребёнка не критична.

enum KaraokePitchCorpus {

    /// 20 фраз для караоке.
    static let phrases: [KaraokePhrase] = buildPhrases()

    /// Эталонный контур для конкретной фразы (фиксированно 21 точка,
    /// нормализованное время 0…1).
    static func modelContour(for phrase: KaraokePhrase) -> [PitchPoint] {
        switch phrase.intonation.lowercased() {
        case "question":
            return makeQuestionContour()
        case "exclamation":
            return makeExclamationContour()
        default:
            return makeStatementContour()
        }
    }

    // MARK: - Phrase builder

    private static func buildPhrases() -> [KaraokePhrase] {
        // Берём по 7 фраз statement, 7 question, 6 exclamation → 20 итого.
        let prosody = ProsodyCorpus.phrases
        let by: (String) -> [ProsodyPhrase] = { type in
            prosody.filter { $0.intonation.rawValue.lowercased() == type }
        }
        let statement = Array(by("statement").prefix(7))
        let question = Array(by("question").prefix(7))
        let exclamation = Array(by("exclamation").prefix(6))

        var result: [KaraokePhrase] = []
        result.append(contentsOf: statement.map { $0.toKaraoke(symbol: "minus") })
        result.append(contentsOf: question.map { $0.toKaraoke(symbol: "questionmark.circle") })
        result.append(contentsOf: exclamation.map { $0.toKaraoke(symbol: "exclamationmark.circle") })
        if result.isEmpty {
            // Безопасный fallback на случай, если pack_prosody.json не загружен.
            result = fallbackPhrases()
        }
        return result
    }

    private static func fallbackPhrases() -> [KaraokePhrase] {
        [
            .init(id: "kr-1", text: "Мама пришла домой.",
                  intonation: "statement", intonationSymbol: "minus"),
            .init(id: "kr-2", text: "Где моя книжка?",
                  intonation: "question", intonationSymbol: "questionmark.circle"),
            .init(id: "kr-3", text: "Какой красивый день!",
                  intonation: "exclamation", intonationSymbol: "exclamationmark.circle")
        ]
    }

    // MARK: - Reference contours

    private static func makeStatementContour() -> [PitchPoint] {
        // Высокая середина → плавно вниз. F0 нормализованный 0.4…0.7.
        (0...20).map { step -> PitchPoint in
            let time = Double(step) / 20.0
            // Плавная нисходящая дуга.
            let freq = 280 - 40 * time
            return PitchPoint(time: time, frequencyHz: freq)
        }
    }

    private static func makeQuestionContour() -> [PitchPoint] {
        // Рост в финале (последние 30%). Базис 230, к концу 330.
        (0...20).map { step -> PitchPoint in
            let time = Double(step) / 20.0
            let freq: Double
            if time < 0.7 {
                freq = 230 + 5 * time
            } else {
                freq = 230 + 5 * 0.7 + 330 * (time - 0.7)
            }
            return PitchPoint(time: time, frequencyHz: freq)
        }
    }

    private static func makeExclamationContour() -> [PitchPoint] {
        // Резкий рост к 0.3, плато 0.3–0.6, спуск.
        (0...20).map { step -> PitchPoint in
            let time = Double(step) / 20.0
            let freq: Double
            if time < 0.3 {
                freq = 220 + (340 - 220) * (time / 0.3)
            } else if time < 0.6 {
                freq = 340
            } else {
                freq = 340 - 100 * ((time - 0.6) / 0.4)
            }
            return PitchPoint(time: time, frequencyHz: freq)
        }
    }
}

// MARK: - ProsodyPhrase → KaraokePhrase

private extension ProsodyPhrase {

    func toKaraoke(symbol: String) -> KaraokePhrase {
        KaraokePhrase(
            id: "karaoke-\(id)",
            text: text,
            intonation: intonation.rawValue,
            intonationSymbol: symbol
        )
    }
}
