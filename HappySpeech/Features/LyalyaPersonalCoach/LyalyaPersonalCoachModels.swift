import Foundation

// MARK: - LyalyaPersonalCoachModels

/// Модели «Личный коуч Ляли». Раунды персонализируются под рабочие звуки
/// ребёнка (`LyalyaPersonalCoachWorker` → `LessonContentMap`).
enum LyalyaPersonalCoachModels {

    struct Round: Identifiable, Hashable {
        let id: Int
        let question: String
        let options: [String]
        let correctIndex: Int
    }

    enum Reaction: Equatable {
        case none
        case correct
        case tryAgain
    }
}
