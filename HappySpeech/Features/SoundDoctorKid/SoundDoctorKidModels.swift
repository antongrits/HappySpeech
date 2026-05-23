import Foundation

// MARK: - SoundDoctorKidModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum SoundDoctorKidModels {

    struct Option: Identifiable, Hashable {
        let id: String
        let articulation: String
        let isCorrect: Bool
    }

    struct Case: Identifiable, Hashable {
        let id: Int
        let brokenSound: String
        let hint: String
        let options: [Option]
    }

    struct ViewState: Equatable {
        var cases: [Case]
        var currentCaseIndex: Int
        var cured: Int

        var currentCase: Case? {
            cases.indices.contains(currentCaseIndex) ? cases[currentCaseIndex] : nil
        }

        static let initial = ViewState(
            cases: [
                Case(id: 0, brokenSound: "Р",
                     hint: "Язык дрожит за верхними зубами",
                     options: [
                        Option(id: "r-a", articulation: "Зубы сомкнуть, шипеть", isCorrect: false),
                        Option(id: "r-b", articulation: "Язык вверх, вибрация", isCorrect: true),
                        Option(id: "r-c", articulation: "Губы трубочкой", isCorrect: false)
                     ]),
                Case(id: 1, brokenSound: "С",
                     hint: "Воздух свистит между зубами",
                     options: [
                        Option(id: "s-a", articulation: "Язык внизу, улыбка", isCorrect: true),
                        Option(id: "s-b", articulation: "Язык под нёбо", isCorrect: false),
                        Option(id: "s-c", articulation: "Зубы разомкнуть", isCorrect: false)
                     ]),
                Case(id: 2, brokenSound: "Ш",
                     hint: "Язык чашечкой за верхними зубами",
                     options: [
                        Option(id: "sh-a", articulation: "Язык внизу", isCorrect: false),
                        Option(id: "sh-b", articulation: "Губы вытянуть", isCorrect: false),
                        Option(id: "sh-c", articulation: "Язык чашечкой, губы трубочкой", isCorrect: true)
                     ]),
                Case(id: 3, brokenSound: "Л",
                     hint: "Кончик языка упирается в верхние зубы",
                     options: [
                        Option(id: "l-a", articulation: "Кончик в верхние зубы", isCorrect: true),
                        Option(id: "l-b", articulation: "Язык дрожит", isCorrect: false),
                        Option(id: "l-c", articulation: "Зубы сжаты", isCorrect: false)
                     ])
            ],
            currentCaseIndex: 0,
            cured: 0
        )
    }
}
