import Foundation

// MARK: - SyllableRaceModels
//
// «Скороговорка-ракета» (kid) — игра на диадохокинез (оромоторный темп).
//
// Ребёнок как можно быстрее и ровнее повторяет слоговой ряд (моно «па-па-па»
// или переключательный «па-та-ка»); приложение on-device (vDSP, без ML-моделей
// и сети) детектирует слоговые ядра по огибающей энергии и измеряет темп
// (слог/с), ровность ритма и число слогов. Ракета Ляли летит тем выше, чем
// быстрее и ровнее ряд. 4 раунда → итог со звёздами.
//
// Методически: проба диадохокинеза — стандартная оценка оромоторной координации
// (Fletcher 1972; Williams & Stackhouse 2000). Полезна как разминка перед
// постановкой звука и как объективный показатель прогресса артикуляционной
// ловкости. Не диагноз (project guide §11).

enum SyllableRaceModels {

    // MARK: - Session constants

    /// Раундов в одной сессии (по разным рядам каталога).
    static let roundsPerSession = 4

    /// Длительность записи одной попытки, секунды (ребёнок повторяет ряд).
    static let attemptDuration: TimeInterval = 4.0

    /// Возраст по умолчанию, если профиль недоступен.
    static let defaultChildAge = 6

    // MARK: - Phase

    /// Фаза одного раунда.
    enum Phase: Equatable {
        /// Готов к записи (показ ряда и инструкции).
        case ready
        /// Идёт запись (ребёнок повторяет ряд).
        case recording
        /// Анализ записи.
        case analyzing
        /// Показ результата попытки.
        case result
        /// Сессия завершена.
        case completed
    }

    // MARK: - Start

    enum Start {
        struct Request {
            let childId: String
        }

        struct Response {
            let sequence: DDKSequence
            let roundNumber: Int
            let totalRounds: Int
            let childAge: Int
        }

        struct ViewModel: Equatable {
            /// Отображаемый ряд («па-та-ка»).
            let sequenceDisplay: String
            /// Слоги по отдельности (для подсветки/озвучки).
            let syllables: [String]
            /// Инструкция раунда («Повтори па-та-ка как можно быстрее и ровнее!»).
            let instruction: String
            let roundNumber: Int
            let totalRounds: Int
        }
    }

    // MARK: - Attempt

    enum Attempt {
        struct Request {}

        struct Response {
            let evaluation: DDKEvaluation
            let roundNumber: Int
            let totalRounds: Int
            let isSessionComplete: Bool
        }

        struct ViewModel: Equatable {
            /// Высота ракеты 0…1 (комбинация темпа и ровности).
            let rocketHeight: Double
            /// true → есть распознанный ряд (показывать метрики).
            let hasMeasurement: Bool
            /// Заголовок результата («Вжух! Ракета взлетела!»).
            let title: String
            /// Темп, человекочитаемо («4.6 слога в секунду»).
            let rateLabel: String
            /// Ровность ритма, человекочитаемо («ритм ровный»).
            let steadinessLabel: String?
            /// Подсказка-действие (по флагам качества).
            let hint: String?
            /// Звёзды попытки 0…3.
            let stars: Int
            let roundNumber: Int
            let totalRounds: Int
            /// Настроение Ляли для результата.
            let mascotCelebrates: Bool
        }
    }

    // MARK: - Complete

    enum Complete {
        struct Response {
            let totalStars: Int
            let maxStars: Int
            /// Лучший темп сессии, слог/с.
            let bestRate: Double
        }

        struct ViewModel: Equatable {
            let title: String
            let subtitle: String
            /// Итоговые звёзды сессии 0…3 (нормированные).
            let sessionStars: Int
        }
    }

    // MARK: - Errors

    enum Failure {
        struct ViewModel: Equatable {
            let message: String
            /// true → проблема с разрешением микрофона (показать CTA настроек).
            let isPermissionIssue: Bool
        }
    }
}
