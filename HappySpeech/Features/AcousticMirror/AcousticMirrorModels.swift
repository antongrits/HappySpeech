import Foundation

// MARK: - AcousticMirrorModels
//
// «Акустическое зеркало» (kid) — биообратная связь по акустике свистящих/шипящих.
//
// Ребёнок «тянет» звук (С-С-С или Ш-Ш-Ш) ~2 секунды, приложение on-device
// (vDSP, без ML-моделей и сети) измеряет спектральный центр тяжести шума и
// показывает шарик на «горке» между полюсами Ш и С: видно, КУДА смещается звук
// и насколько он близок к цели. 5 раундов → итог со звёздами.
//
// Методически: этап изолированного звука (CorrectionStage.isolated) и
// дифференциация С↔Ш — акустическая визуализация вместо субъективного
// «похоже/не похоже». Не диагноз (project guide §11).

enum AcousticMirrorModels {

    // MARK: - Session constants

    /// Раундов в одной сессии зеркала.
    static let roundsPerSession = 5

    /// Длительность записи одной попытки, секунды (ребёнок тянет звук).
    static let attemptDuration: TimeInterval = 2.4

    /// Звуки, поддержанные зеркалом (сибилянты обоих полюсов).
    static let supportedSounds: [String] = ["С", "З", "Ц", "Ш", "Ж", "Щ", "Ч"]

    // MARK: - Phase

    /// Фаза одного раунда.
    enum Phase: Equatable {
        /// Готов к записи (показ инструкции).
        case ready
        /// Идёт запись (ребёнок тянет звук).
        case recording
        /// Анализ записи.
        case analyzing
        /// Показ результата попытки.
        case result
        /// Сессия завершена (после 5 раундов).
        case completed
    }

    // MARK: - Start

    enum Start {
        struct Request {
            let childId: String
            /// Целевой звук; пустая строка → интерактор resolve'ит из профиля.
            let preferredSound: String
        }

        struct Response {
            let targetSound: String
            let totalRounds: Int
        }

        struct ViewModel: Equatable {
            let targetSound: String
            /// Подпись полюса цели («Свистящий, как насос» / «Шипящий, как змейка»).
            let targetHint: String
            let totalRounds: Int
            /// Инструкция раунда («Потяни звук С-С-С, пока шарик слушает!»).
            let instruction: String
        }
    }

    // MARK: - Attempt

    enum Attempt {
        struct Request {}

        struct Response {
            let evaluation: SibilantEvaluation
            let roundNumber: Int
            let totalRounds: Int
            let isSessionComplete: Bool
        }

        struct ViewModel: Equatable {
            /// Позиция шарика на горке 0 (Ш) … 1 (С).
            let continuumPosition: Double
            /// true → шарик показывать (есть фрикативный звук).
            let hasMeasurement: Bool
            /// Заголовок результата («В яблочко!» / «Звук убежал к Ш…»).
            let title: String
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
            let bestPosition: Double?
            let targetSound: String
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
