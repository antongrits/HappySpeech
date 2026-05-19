import Foundation

// MARK: - BreatheAndSpeakCorpus
//
// v29 Фаза 8, Функция 10 «Дыши и говори».
//
// Корпус артикуляционно-дыхательных комплексов под группы звуков. Упражнения
// взяты из классической артикуляционной (Фомичёва) и дыхательной гимнастики
// и собраны в методически верном порядке: разогрев → специфические уклады →
// дыхательное завершение.
//
// Названия и инструкции хранятся как ключи локализации и резолвятся при
// доступе через `String(localized:)`. Полностью offline / on-device.

enum BreatheAndSpeakCorpus {

    /// Все комплексы корпуса.
    static var complexes: [ArticulationComplex] {
        [
            ArticulationComplex(
                id: "complex-r",
                soundGroup: "Р",
                title: String(localized: "breatheAndSpeak.complex.r.title"),
                exercises: [
                    exercise("ex-r-malyar", .articulation,
                             "breatheAndSpeak.ex.malyar", "paintbrush.fill", 4),
                    exercise("ex-r-gribok", .articulation,
                             "breatheAndSpeak.ex.gribok", "mountain.2.fill", 4),
                    exercise("ex-r-loshadka", .articulation,
                             "breatheAndSpeak.ex.loshadka", "hare.fill", 4),
                    exercise("ex-r-baraban", .articulation,
                             "breatheAndSpeak.ex.baraban", "music.note", 4),
                    exercise("ex-r-motorchik", .articulation,
                             "breatheAndSpeak.ex.motorchik", "fan.fill", 5),
                    exercise("ex-r-veter", .breathing,
                             "breatheAndSpeak.ex.veter", "wind", 5)
                ]
            ),
            ArticulationComplex(
                id: "complex-s",
                soundGroup: "С",
                title: String(localized: "breatheAndSpeak.complex.s.title"),
                exercises: [
                    exercise("ex-s-zaborchik", .articulation,
                             "breatheAndSpeak.ex.zaborchik", "square.grid.3x1.below.line.grid.1x2", 4),
                    exercise("ex-s-lopatka", .articulation,
                             "breatheAndSpeak.ex.lopatka", "rectangle.fill", 4),
                    exercise("ex-s-gorka", .articulation,
                             "breatheAndSpeak.ex.gorka", "triangle.fill", 4),
                    exercise("ex-s-pochistim", .articulation,
                             "breatheAndSpeak.ex.pochistim", "sparkles", 4),
                    exercise("ex-s-svecha", .breathing,
                             "breatheAndSpeak.ex.svecha", "flame.fill", 5)
                ]
            ),
            ArticulationComplex(
                id: "complex-sh",
                soundGroup: "Ш",
                title: String(localized: "breatheAndSpeak.complex.sh.title"),
                exercises: [
                    exercise("ex-sh-zaborchik", .articulation,
                             "breatheAndSpeak.ex.zaborchik", "square.grid.3x1.below.line.grid.1x2", 4),
                    exercise("ex-sh-chashechka", .articulation,
                             "breatheAndSpeak.ex.chashechka", "cup.and.saucer.fill", 5),
                    exercise("ex-sh-vkusnoe", .articulation,
                             "breatheAndSpeak.ex.vkusnoe", "tongue", 4),
                    exercise("ex-sh-loshadka", .articulation,
                             "breatheAndSpeak.ex.loshadka", "hare.fill", 4),
                    exercise("ex-sh-listik", .breathing,
                             "breatheAndSpeak.ex.listik", "leaf.fill", 5)
                ]
            ),
            ArticulationComplex(
                id: "complex-l",
                soundGroup: "Л",
                title: String(localized: "breatheAndSpeak.complex.l.title"),
                exercises: [
                    exercise("ex-l-lopatka", .articulation,
                             "breatheAndSpeak.ex.lopatka", "rectangle.fill", 4),
                    exercise("ex-l-igolochka", .articulation,
                             "breatheAndSpeak.ex.igolochka", "pencil.tip", 4),
                    exercise("ex-l-parohod", .articulation,
                             "breatheAndSpeak.ex.parohod", "ferry.fill", 5),
                    exercise("ex-l-malyar", .articulation,
                             "breatheAndSpeak.ex.malyar", "paintbrush.fill", 4),
                    exercise("ex-l-korablik", .breathing,
                             "breatheAndSpeak.ex.korablik", "sailboat.fill", 5)
                ]
            )
        ]
    }

    /// Подбирает комплекс под целевые звуки ребёнка; по умолчанию — комплекс «С».
    static func recommendedComplex(for targetSounds: [String]) -> ArticulationComplex {
        let all = complexes
        let normalized = targetSounds.map { $0.uppercased() }
        for sound in normalized {
            if let match = all.first(where: { $0.soundGroup.uppercased() == sound }) {
                return match
            }
        }
        return all.first ?? all[0]
    }

    // MARK: - Private

    private static func exercise(
        _ id: String,
        _ kind: ExerciseKind,
        _ baseKey: String,
        _ symbol: String,
        _ hold: Int
    ) -> ComplexExercise {
        ComplexExercise(
            id: id,
            kind: kind,
            name: Bundle.main.localizedString(forKey: "\(baseKey).name", value: nil, table: nil),
            instruction: Bundle.main.localizedString(forKey: "\(baseKey).hint", value: nil, table: nil),
            symbolName: symbol,
            holdSeconds: hold
        )
    }
}
