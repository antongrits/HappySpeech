import Foundation

// MARK: - TongueTwisterArenaModels

/// Модели игры «Арена скороговорок».
///
/// Скороговорки — курируемый методический контент (`TongueTwisterContent`).
/// Запись произношения реальная (через AudioService + ASRService в интеракторе),
/// лучший результат по каждой скороговорке персистится в `UserDefaults`.
enum TongueTwisterArenaModels {

    struct Twister: Identifiable, Hashable {
        let id: String
        let text: String
        let targetSound: String
    }

    /// Фаза записи/оценки выбранной скороговорки.
    enum AttemptPhase: Equatable {
        case idle
        case recording
        case scoring
        case result(stars: Int, similarity: Double)
    }

    struct ViewState: Equatable {
        var twisters: [Twister]
        var selected: Twister?
        var phase: AttemptPhase
        /// Лучший результат (звёзды 0…3) по id скороговорки.
        var bestStars: [String: Int]

        var isRecording: Bool {
            phase == .recording
        }

        var isScoring: Bool {
            phase == .scoring
        }

        func bestStars(for twisterId: String) -> Int {
            bestStars[twisterId] ?? 0
        }

        static let initial = ViewState(
            twisters: [],
            selected: nil,
            phase: .idle,
            bestStars: [:]
        )
    }
}
