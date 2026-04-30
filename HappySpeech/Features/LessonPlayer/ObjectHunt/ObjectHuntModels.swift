import Foundation

// MARK: - ObjectHuntModels
//
// VIP-модели для игры «Охота за предметом» (Object Hunt).
//
// Игровой поток:
//   1. LoadRound  → загружает раунд (целевой звук, подсказку)
//   2. FrameAnalyzed → результат детектирования от ObjectDetectionWorker
//   3. CompleteRound → раунд пройден (объект найден)
//   4. CompleteGame  → все раунды завершены
//
// Всего раундов: 3 (одна игра = 3 разных целевых звука из одной группы).

enum ObjectHuntModels {

    // MARK: - LoadRound

    enum LoadRound {
        struct Request {
            let soundGroup: String    // "whistling" | "hissing" | "sonorant" | "velar"
            let targetSound: String   // конкретный звук, пример: "Ш"
            let roundIndex: Int       // 0, 1, 2
        }
        struct Response {
            let targetSound: String
            let promptText: String    // "Найди предмет на звук Ш!"
            let roundIndex: Int
            let totalRounds: Int
        }
        struct ViewModel {
            let targetSoundLabel: String  // "Ш"
            let promptText: String
            let roundBadge: String        // "Раунд 1 из 3"
        }
    }

    // MARK: - FrameAnalyzed

    enum FrameAnalyzed {
        struct Request {
            let detectedObjects: [DetectedObject]
        }
        struct Response {
            /// Первый объект с совпавшим звуком, либо nil
            let matchedObject: DetectedObject?
        }
        struct ViewModel {
            /// Отображается поверх камеры, если объект найден
            let matchedLabel: String?
            /// Фраза Ляли при нахождении
            let celebrationText: String?
            let isMatch: Bool
            /// Полный объект для последующего confirmMatch — nil если нет совпадения.
            let matchedObject: DetectedObject?
        }
    }

    // MARK: - CompleteRound

    enum CompleteRound {
        struct Request {
            let matchedObject: DetectedObject
            let roundIndex: Int
        }
        struct Response {
            let celebrationMessage: String
            let isLastRound: Bool
            let roundIndex: Int
        }
        struct ViewModel {
            let celebrationMessage: String
            let shouldAdvance: Bool
        }
    }

    // MARK: - CompleteGame

    enum CompleteGame {
        struct Response {
            let starsEarned: Int
            let score: Float
            let summaryText: String
        }
        struct ViewModel {
            let starsEarned: Int
            let scoreLabel: String
            let summaryText: String
        }
    }

    // MARK: - GamePhase

    enum GamePhase: Equatable, Sendable {
        case loading
        case scanning     // камера активна, ищем предмет
        case matchFound   // найден! показываем celebration
        case roundComplete
        case gameComplete
    }
}
