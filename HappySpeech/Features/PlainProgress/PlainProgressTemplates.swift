import Foundation

// MARK: - PlainProgressTemplates
//
// v29 Фаза 8, Функция 9 «Понятный прогресс».
//
// Размеченный корпус шаблонов формулировок. LLM/логика только подставляют
// реальные метрики в готовые педагогически-безопасные фразы — без выдумывания
// диагнозов и без гарантий результата (project guide §11).
//
// Каждый шаблон — ключ Localizable.xcstrings; подстановка значений идёт
// в `PlainProgressPresenter` через `String(format:)`.

enum PlainProgressTemplates {

    // MARK: - Заголовки нарратива по тренду

    /// Возвращает ключ заголовка карточки-нарратива для тренда.
    static func narrativeTitleKey(for trend: PlainProgressDirection) -> String {
        switch trend {
        case .improved: return "plainProgress.narrative.title.improved"
        case .steady:   return "plainProgress.narrative.title.steady"
        case .declined: return "plainProgress.narrative.title.support"
        case .noData:   return "plainProgress.narrative.title.noData"
        }
    }

    /// Ключ первого предложения нарратива — про общее движение.
    /// Подстановка: имя ребёнка.
    static func openingKey(for trend: PlainProgressDirection) -> String {
        switch trend {
        case .improved: return "plainProgress.narrative.opening.improved"
        case .steady:   return "plainProgress.narrative.opening.steady"
        case .declined: return "plainProgress.narrative.opening.support"
        case .noData:   return "plainProgress.narrative.opening.noData"
        }
    }

    /// Ключ предложения про конкретный звук недели.
    /// Подстановка: имя звука, процент точности.
    static func focusSoundKey(rate: Double) -> String {
        if rate >= 0.85 {
            return "plainProgress.narrative.focus.strong"
        } else if rate >= 0.6 {
            return "plainProgress.narrative.focus.progress"
        } else {
            return "plainProgress.narrative.focus.early"
        }
    }

    /// Ключ заключительной фразы — нормализация и поддержка.
    static func closingKey(for trend: PlainProgressDirection) -> String {
        switch trend {
        case .improved: return "plainProgress.narrative.closing.improved"
        case .steady:   return "plainProgress.narrative.closing.steady"
        case .declined: return "plainProgress.narrative.closing.support"
        case .noData:   return "plainProgress.narrative.closing.noData"
        }
    }

    // MARK: - Рекомендации

    /// Ключ практической рекомендации «что делать дальше».
    /// Подстановка: имя звука.
    static func recommendationKey(for trend: PlainProgressDirection, focusRate: Double) -> String {
        switch trend {
        case .noData:
            return "plainProgress.reco.noData"
        case .declined:
            return "plainProgress.reco.support"
        case .improved, .steady:
            return focusRate >= 0.85
                ? "plainProgress.reco.advance"
                : "plainProgress.reco.practice"
        }
    }

    // MARK: - Вехи прогресса

    /// Каноничный список вех. `reached` вычисляется воркером по метрикам.
    static let milestoneTitleKeys: [(id: String, key: String, symbol: String)] = [
        ("milestone-first-session", "plainProgress.milestone.firstSession", "flag.fill"),
        ("milestone-week-streak",   "plainProgress.milestone.weekStreak",   "flame.fill"),
        ("milestone-sound-stable",  "plainProgress.milestone.soundStable",  "checkmark.seal.fill"),
        ("milestone-ten-sessions",  "plainProgress.milestone.tenSessions",  "star.fill"),
        ("milestone-high-accuracy", "plainProgress.milestone.highAccuracy", "sparkles")
    ]
}
