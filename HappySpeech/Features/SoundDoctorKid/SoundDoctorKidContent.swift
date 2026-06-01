import Foundation

// MARK: - SoundDoctorKidContent

/// Курируемый набор «случаев» для игры «Звуковой доктор»: для каждого звука —
/// верное артикуляционное описание и неверные варианты.
///
/// Это методический контент (артикуляционные уклады по русской логопедии),
/// единый источник правды. Игра выбирает случаи под рабочие звуки ребёнка.
enum SoundDoctorKidContent {

    /// Все случаи, ключ — буква-звук.
    static let all: [SoundDoctorKidModels.Case] = [
        .init(
            sound: "Р",
            hint: String(localized: "soundDoctor.case.r.hint"),
            options: [
                .init(id: "r-a", articulation: String(localized: "soundDoctor.case.r.opt1"), isCorrect: false),
                .init(id: "r-b", articulation: String(localized: "soundDoctor.case.r.opt2"), isCorrect: true),
                .init(id: "r-c", articulation: String(localized: "soundDoctor.case.r.opt3"), isCorrect: false)
            ]
        ),
        .init(
            sound: "С",
            hint: String(localized: "soundDoctor.case.s.hint"),
            options: [
                .init(id: "s-a", articulation: String(localized: "soundDoctor.case.s.opt1"), isCorrect: true),
                .init(id: "s-b", articulation: String(localized: "soundDoctor.case.s.opt2"), isCorrect: false),
                .init(id: "s-c", articulation: String(localized: "soundDoctor.case.s.opt3"), isCorrect: false)
            ]
        ),
        .init(
            sound: "Ш",
            hint: String(localized: "soundDoctor.case.sh.hint"),
            options: [
                .init(id: "sh-a", articulation: String(localized: "soundDoctor.case.sh.opt1"), isCorrect: false),
                .init(id: "sh-b", articulation: String(localized: "soundDoctor.case.sh.opt2"), isCorrect: false),
                .init(id: "sh-c", articulation: String(localized: "soundDoctor.case.sh.opt3"), isCorrect: true)
            ]
        ),
        .init(
            sound: "Л",
            hint: String(localized: "soundDoctor.case.l.hint"),
            options: [
                .init(id: "l-a", articulation: String(localized: "soundDoctor.case.l.opt1"), isCorrect: true),
                .init(id: "l-b", articulation: String(localized: "soundDoctor.case.l.opt2"), isCorrect: false),
                .init(id: "l-c", articulation: String(localized: "soundDoctor.case.l.opt3"), isCorrect: false)
            ]
        )
    ]

    /// Случаи под рабочие звуки ребёнка (с добором остальных, если совпадений
    /// мало), не более `limit`.
    static func cases(forTargetSounds targets: [String], limit: Int = 4) -> [SoundDoctorKidModels.Case] {
        let upper = Set(targets.map { $0.uppercased() })
        let matched = all.filter { upper.contains($0.sound.uppercased()) }
        let rest = all.filter { !matched.contains($0) }
        return Array((matched + rest).prefix(limit))
    }
}
