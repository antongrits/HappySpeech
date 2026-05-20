import Foundation

// MARK: - DailyTimeCapModels
//
// v31 Wave F F-05 — «Дневной лимит времени в HappySpeech».
//
// Parent-side фича: родитель устанавливает дневной лимит игры на устройстве
// (per-device, общий для всей семьи), включает / отключает cap, видит
// сегодняшнее использование. NO Family Controls — только in-app accounting.

enum DailyTimeCapModels {

    // MARK: - Status

    enum Status {

        struct Request {}

        struct Response {
            let isEnabled: Bool
            let capMinutes: Int
            let usedSeconds: TimeInterval
        }

        struct ViewModel: Equatable {
            /// Включён ли cap.
            let isEnabled: Bool
            /// Текущий cap в минутах.
            let capMinutes: Int
            /// Допустимые значения (UI-slider).
            let availableMinuteOptions: [Int]
            /// Использовано минут (округлено вверх).
            let usedMinutes: Int
            /// «12 из 30 минут».
            let usageLabel: String
            /// Прогресс 0…1+ (>1 если over-cap).
            let progress: Double
            /// Цвет статус-бара: green / yellow / red.
            let progressTint: TintLevel
            /// True если usedMinutes ≥ capMinutes и cap включён.
            let isCapped: Bool
            /// Локализованный hint под слайдером.
            let footnote: String
        }

        enum TintLevel: Equatable {
            case green
            case yellow
            case red
        }
    }
}
