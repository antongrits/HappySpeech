import Foundation
import OSLog

// MARK: - VoiceStrongmanCorpus
//
// Worker «Силача-голоса». Загружает упражнения двух фонопедических режимов из
// `pack_voice_power.json`, фильтрует по возрасту и строит сессию. При
// отсутствии/повреждении пака отдаёт встроенный fallback (реальные гласные
// ряды) — игра никогда не пустая.
//
// Методика: Алмазова, Архипова, Орлова — сила и высота голоса через гласные
// ряды с нарастанием громкости и глиссандо высоты. Ребёнку важна управляемая
// модуляция, а не абсолютные значения, поэтому уровни/направления заданы
// семантически (тихо/средне/громко; вверх/вниз).

struct VoiceStrongmanCorpus {

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "VoiceStrongmanCorpus")

    // MARK: - Session

    /// Собирает сессию: упражнения громкости и высоты, отфильтрованные по
    /// возрасту. Порядок режимов задаёт Interactor (громкость → высота —
    /// методическая градация от силы к модуляции).
    static func buildSession(age: Int) -> VoiceStrongmanSession {
        let pack = loadPack() ?? fallbackPack()

        let loudnessRaw = pack.loudness.filter { $0.minAgeOrZero <= age }
        let pitchRaw = pack.pitch.filter { $0.minAgeOrZero <= age }

        return VoiceStrongmanSession(
            loudness: mapLoudness(loudnessRaw.isEmpty ? pack.loudness : loudnessRaw),
            pitch: mapPitch(pitchRaw.isEmpty ? pack.pitch : pitchRaw)
        )
    }

    // MARK: - Mapping pack → domain

    private static func mapLoudness(_ raw: [RawLoudness]) -> [LoudnessExercise] {
        raw.compactMap { rl in
            guard !rl.vowel.isEmpty, let level = LoudnessLevel(rawValue: rl.level) else { return nil }
            return LoudnessExercise(
                id: rl.id,
                vowel: rl.vowel,
                prompt: rl.prompt,
                level: level,
                animal: rl.animal,
                hint: rl.hint
            )
        }
    }

    private static func mapPitch(_ raw: [RawPitch]) -> [PitchExercise] {
        raw.compactMap { rp in
            guard !rp.vowel.isEmpty, let direction = PitchDirection(rawValue: rp.direction) else { return nil }
            return PitchExercise(
                id: rp.id,
                vowel: rp.vowel,
                prompt: rp.prompt,
                direction: direction,
                steps: max(3, min(rp.steps, 7)),
                hint: rp.hint
            )
        }
    }

    // MARK: - Pack IO

    private static func loadPack() -> RawPack? {
        guard let url = Bundle.main.url(forResource: "pack_voice_power", withExtension: "json")
            ?? Bundle.main.url(
                forResource: "pack_voice_power", withExtension: "json", subdirectory: "Seed"
            ),
            let data = try? Data(contentsOf: url) else {
            logger.warning("pack_voice_power.json missing — using built-in fallback")
            return nil
        }
        return try? JSONDecoder().decode(RawPack.self, from: data)
    }

    // MARK: - Pack DTOs

    private struct RawPack: Decodable {
        let loudness: [RawLoudness]
        let pitch: [RawPitch]
    }

    private struct RawLoudness: Decodable {
        let id: String
        let vowel: String
        let prompt: String
        let minAge: Int?
        let level: String
        let animal: String
        let hint: String
        var minAgeOrZero: Int { minAge ?? 0 }
    }

    private struct RawPitch: Decodable {
        let id: String
        let vowel: String
        let prompt: String
        let minAge: Int?
        let direction: String
        let steps: Int
        let hint: String
        var minAgeOrZero: Int { minAge ?? 0 }
    }

    // MARK: - Fallback (реальные гласные ряды — никаких пустых экранов)

    private static func fallbackPack() -> RawPack {
        RawPack(
            loudness: [
                RawLoudness(
                    id: "fb-loud-a-mouse", vowel: "А", prompt: "Тяни «а-а-а», как мышка — тихо",
                    minAge: 5, level: "quiet", animal: "🐭",
                    hint: "Тихо-тихо спой «а-а-а», как маленькая мышка. Шарик будет совсем крошечный."
                ),
                RawLoudness(
                    id: "fb-loud-o-cat", vowel: "О", prompt: "Спой «о-о-о», как котик — средне",
                    minAge: 5, level: "medium", animal: "🐱",
                    hint: "Спой «о-о-о», как ласковый котик. Голос ровный — попади в золотую полоску."
                ),
                RawLoudness(
                    id: "fb-loud-u-bear", vowel: "У", prompt: "Спой «у-у-у», как мишка — громко",
                    minAge: 6, level: "loud", animal: "🐻",
                    hint: "Спой «у-у-у», как большой добрый мишка. Громко, но не кричи — попади в полоску."
                )
            ],
            pitch: [
                RawPitch(
                    id: "fb-pitch-u-up", vowel: "У", prompt: "Веди «у-у-у» по лесенке вверх",
                    minAge: 5, direction: "up", steps: 5,
                    hint: "Цыплёнок лезет вверх, пока ты тянешь «у-у-у» всё тоньше. Веди его до верха!"
                ),
                RawPitch(
                    id: "fb-pitch-u-down", vowel: "У", prompt: "Спускай «у-у-у» по лесенке вниз",
                    minAge: 5, direction: "down", steps: 5,
                    hint: "А теперь веди голос вниз — «у-у-у» становится толще и ниже. Цыплёнок спускается."
                )
            ]
        )
    }
}
