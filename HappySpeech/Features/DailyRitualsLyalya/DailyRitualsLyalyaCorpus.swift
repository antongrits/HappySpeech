import Foundation

// MARK: - DailyRitualsLyalyaCorpus
//
// v31 Волна A, Функция Ф8 «Утро и вечер с Лялей».
//
// Композиция шагов ритуала. НЕ создаёт новый контент: это компоновка
// существующих типов упражнений (артикуляция, дыхание, чистоговорка,
// короткая история). Каждый шаг — короткий блок 1–2 минуты.
//
// Методическое основание (см. [[parent-guidance-full]], Косинова Е.М.):
// регулярная короткая практика эффективнее редкой длинной.

enum DailyRitualsLyalyaCorpus {

    static let morningSteps: [RitualStep] = [
        RitualStep(
            id: "ritual-morning-greet",
            titleKey: "dailyRituals.morning.step.greet.title",
            descriptionKey: "dailyRituals.morning.step.greet.desc",
            symbolName: "hand.wave.fill",
            durationSeconds: 30
        ),
        RitualStep(
            id: "ritual-morning-articulation",
            titleKey: "dailyRituals.morning.step.articulation.title",
            descriptionKey: "dailyRituals.morning.step.articulation.desc",
            symbolName: "mouth.fill",
            durationSeconds: 90
        ),
        RitualStep(
            id: "ritual-morning-breath",
            titleKey: "dailyRituals.morning.step.breath.title",
            descriptionKey: "dailyRituals.morning.step.breath.desc",
            symbolName: "wind",
            durationSeconds: 60
        ),
        RitualStep(
            id: "ritual-morning-chistogovorka",
            titleKey: "dailyRituals.morning.step.chistogovorka.title",
            descriptionKey: "dailyRituals.morning.step.chistogovorka.desc",
            symbolName: "text.bubble.fill",
            durationSeconds: 60
        )
    ]

    static let eveningSteps: [RitualStep] = [
        RitualStep(
            id: "ritual-evening-recap",
            titleKey: "dailyRituals.evening.step.recap.title",
            descriptionKey: "dailyRituals.evening.step.recap.desc",
            symbolName: "bubble.left.and.bubble.right.fill",
            durationSeconds: 90
        ),
        RitualStep(
            id: "ritual-evening-breath",
            titleKey: "dailyRituals.evening.step.breath.title",
            descriptionKey: "dailyRituals.evening.step.breath.desc",
            symbolName: "wind",
            durationSeconds: 60
        ),
        RitualStep(
            id: "ritual-evening-story",
            titleKey: "dailyRituals.evening.step.story.title",
            descriptionKey: "dailyRituals.evening.step.story.desc",
            symbolName: "book.fill",
            durationSeconds: 120
        )
    ]

    static func steps(for kind: RitualKind) -> [RitualStep] {
        switch kind {
        case .morning: return morningSteps
        case .evening: return eveningSteps
        }
    }
}
