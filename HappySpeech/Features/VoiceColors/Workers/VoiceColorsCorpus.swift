import Foundation
import OSLog

// MARK: - VoiceColorsCorpus
//
// Worker «Голосовых красок». Загружает задания трёх просодических режимов из
// `pack_prosody_plus.json`, фильтрует по возрасту и строит сессию. При
// отсутствии/повреждении пака отдаёт встроенный fallback (реальные фразы) —
// игра никогда не пустая.
//
// Целевые pitch-контуры интонации генерируются процедурно из типа интонации
// (вопрос — рост в финале, восклицание — пик в середине, спокойно — плавный
// спуск). Это методически корректный мелодический рисунок (Лопатина, Шевцова):
// ребёнку важно попасть в форму, а не в абсолютную частоту, — `ContourComparator`
// нормализует высоту голоса.

struct VoiceColorsCorpus {

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "VoiceColorsCorpus")

    // MARK: - Session

    /// Собирает сессию заданий: по одному заданию каждого режима, отфильтровав
    /// по возрасту. Порядок режимов: интонация → ударение → эмоция (методическая
    /// градация от простого к сложному; см. expansion 2.4).
    static func buildSession(age: Int) -> VoiceColorsSession {
        let pack = loadPack() ?? fallbackPack()

        let intonation = pack.intonation.filter { $0.minAgeOrZero <= age }
        let stress = pack.stress.filter { $0.minAgeOrZero <= age }
        let emotion = pack.emotion.filter { $0.minAgeOrZero <= age }

        return VoiceColorsSession(
            intonation: mapIntonation(intonation.isEmpty ? pack.intonation : intonation),
            stress: mapStress(stress.isEmpty ? pack.stress : stress),
            emotion: mapEmotion(emotion.isEmpty ? pack.emotion : emotion)
        )
    }

    // MARK: - Target contour (reuse KaraokePitch contour shapes)

    /// Целевой pitch-контур для типа интонации (21 точка, время 0…1).
    static func targetContour(for mode: IntonationMode) -> [PitchPoint] {
        switch mode.contourKey {
        case "question":    return makeQuestionContour()
        case "exclamation": return makeExclamationContour()
        default:            return makeStatementContour()
        }
    }

    private static func makeStatementContour() -> [PitchPoint] {
        // Высокая середина → плавно вниз (спокойное повествование).
        (0...20).map { step in
            let time = Double(step) / 20.0
            return PitchPoint(time: time, frequencyHz: 280 - 40 * time)
        }
    }

    private static func makeQuestionContour() -> [PitchPoint] {
        // Рост в финале (последние 30%).
        (0...20).map { step in
            let time = Double(step) / 20.0
            let freq: Double = time < 0.7
                ? 230 + 5 * time
                : 230 + 5 * 0.7 + 330 * (time - 0.7)
            return PitchPoint(time: time, frequencyHz: freq)
        }
    }

    private static func makeExclamationContour() -> [PitchPoint] {
        // Резкий рост к 0.3, плато 0.3–0.6, спуск.
        (0...20).map { step in
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

    // MARK: - Mapping pack → domain

    private static func mapIntonation(_ raw: [RawIntonation]) -> [IntonationTask] {
        raw.compactMap { rt in
            guard !rt.text.isEmpty, !rt.variants.isEmpty else { return nil }
            let variants: [IntonationTask.Variant] = rt.variants.compactMap { rv in
                guard let mode = IntonationMode(rawValue: rv.mode) else { return nil }
                return IntonationTask.Variant(mode: mode, mark: rv.mark, hint: rv.hint)
            }
            guard !variants.isEmpty else { return nil }
            return IntonationTask(id: rt.id, text: rt.text, variants: variants)
        }
    }

    private static func mapStress(_ raw: [RawStress]) -> [StressTask] {
        raw.compactMap { rs in
            guard rs.words.count >= 2, !rs.targets.isEmpty else { return nil }
            let targets: [StressTask.Target] = rs.targets.compactMap { rt in
                guard rs.words.indices.contains(rt.index) else { return nil }
                return StressTask.Target(index: rt.index, question: rt.question, emoji: rt.emoji)
            }
            guard !targets.isEmpty else { return nil }
            return StressTask(id: rs.id, words: rs.words, targets: targets)
        }
    }

    private static func mapEmotion(_ raw: [RawEmotion]) -> [EmotionTask] {
        raw.compactMap { re in
            guard !re.text.isEmpty, !re.options.isEmpty else { return nil }
            let options: [EmotionTask.Option] = re.options.compactMap { ro in
                guard let emotion = VoiceEmotion(rawValue: ro.emotion) else { return nil }
                return EmotionTask.Option(
                    emotion: emotion, phrase: ro.phrase,
                    emoji: ro.emoji, name: ro.name, hint: ro.hint
                )
            }
            guard !options.isEmpty else { return nil }
            return EmotionTask(id: re.id, text: re.text, options: options)
        }
    }

    // MARK: - Pack IO

    private static func loadPack() -> RawPack? {
        guard let url = Bundle.main.url(forResource: "pack_prosody_plus", withExtension: "json")
            ?? Bundle.main.url(
                forResource: "pack_prosody_plus", withExtension: "json", subdirectory: "Seed"
            ),
            let data = try? Data(contentsOf: url) else {
            logger.warning("pack_prosody_plus.json missing — using built-in fallback")
            return nil
        }
        return try? JSONDecoder().decode(RawPack.self, from: data)
    }

    // MARK: - Pack DTOs

    private struct RawPack: Decodable {
        let intonation: [RawIntonation]
        let stress: [RawStress]
        let emotion: [RawEmotion]
    }

    private struct RawIntonation: Decodable {
        let id: String
        let text: String
        let minAge: Int?
        let variants: [RawIntonationVariant]
        var minAgeOrZero: Int { minAge ?? 0 }
    }
    private struct RawIntonationVariant: Decodable {
        let mode: String
        let mark: String
        let hint: String
    }

    private struct RawStress: Decodable {
        let id: String
        let words: [String]
        let minAge: Int?
        let targets: [RawStressTarget]
        var minAgeOrZero: Int { minAge ?? 0 }
    }
    private struct RawStressTarget: Decodable {
        let index: Int
        let question: String
        let emoji: String
    }

    private struct RawEmotion: Decodable {
        let id: String
        let text: String
        let minAge: Int?
        let options: [RawEmotionOption]
        var minAgeOrZero: Int { minAge ?? 0 }
    }
    private struct RawEmotionOption: Decodable {
        let emotion: String
        let phrase: String
        let emoji: String
        let name: String
        let hint: String
    }

    // MARK: - Fallback (реальные фразы — никаких пустых экранов)

    private static func fallbackPack() -> RawPack {
        RawPack(
            intonation: [
                RawIntonation(
                    id: "fb-into-mama", text: "Мама пришла", minAge: 5,
                    variants: [
                        RawIntonationVariant(mode: "question", mark: "?",
                            hint: "Скажи как вопрос — голосок едет вверх"),
                        RawIntonationVariant(mode: "exclamation", mark: "!",
                            hint: "Скажи с восторгом — голос взлетает"),
                        RawIntonationVariant(mode: "calm", mark: ".",
                            hint: "Скажи спокойно — голосок ровный")
                    ]
                )
            ],
            stress: [
                RawStress(
                    id: "fb-stress-koshka", words: ["кошка", "ест", "рыбу"], minAge: 6,
                    targets: [
                        RawStressTarget(index: 0, question: "Кто ест рыбу?", emoji: "🐱"),
                        RawStressTarget(index: 2, question: "Что ест кошка?", emoji: "🐟")
                    ]
                )
            ],
            emotion: [
                RawEmotion(
                    id: "fb-emo-sneg", text: "Снег пошёл", minAge: 5,
                    options: [
                        RawEmotionOption(emotion: "joy", phrase: "Снег пошёл!", emoji: "😄",
                            name: "Весело", hint: "Голос звенит и улыбается"),
                        RawEmotionOption(emotion: "sad", phrase: "Снег пошёл…", emoji: "😢",
                            name: "Грустно", hint: "Голос тихий и опускается"),
                        RawEmotionOption(emotion: "surprise", phrase: "Снег пошёл?!", emoji: "😮",
                            name: "Удивлённо", hint: "Голос подпрыгивает от неожиданности")
                    ]
                )
            ]
        )
    }
}

// MARK: - VoiceColorsSession

/// Собранная сессия: по списку заданий на каждый режим.
struct VoiceColorsSession: Sendable, Equatable {
    let intonation: [IntonationTask]
    let stress: [StressTask]
    let emotion: [EmotionTask]

    var isEmpty: Bool {
        intonation.isEmpty && stress.isEmpty && emotion.isEmpty
    }
}
