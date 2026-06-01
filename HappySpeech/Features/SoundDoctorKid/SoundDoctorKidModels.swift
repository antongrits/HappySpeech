import Foundation

// MARK: - SoundDoctorKidModels

/// Модели игры «Звуковой доктор». Случаи — методический контент
/// (`SoundDoctorKidContent`), подобранный под рабочие звуки ребёнка.
enum SoundDoctorKidModels {

    struct Option: Identifiable, Hashable {
        let id: String
        let articulation: String
        let isCorrect: Bool
    }

    struct Case: Identifiable, Hashable {
        /// Идентификатор случая = буква-звук.
        var id: String { sound }
        let sound: String
        let hint: String
        let options: [Option]

        /// Звук, который «болеет» (для UI).
        var brokenSound: String { sound }
    }

    struct ViewState: Equatable {
        var cases: [Case]
        var currentCaseIndex: Int
        var cured: Int
        var isLoaded: Bool

        var currentCase: Case? {
            cases.indices.contains(currentCaseIndex) ? cases[currentCaseIndex] : nil
        }

        var isEmpty: Bool {
            isLoaded && cases.isEmpty
        }

        var isComplete: Bool {
            isLoaded && !cases.isEmpty && currentCaseIndex >= cases.count
        }

        static let initial = ViewState(
            cases: [],
            currentCaseIndex: 0,
            cured: 0,
            isLoaded: false
        )
    }
}
