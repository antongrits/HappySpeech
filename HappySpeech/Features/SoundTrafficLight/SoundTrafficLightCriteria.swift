import Foundation

// MARK: - SoundTrafficLightCriteria
//
// v29 Фаза 8, Функция 5 «Звуковой светофор».
//
// Методические критерии перехода между уровнями дифференциации и завершения
// пары (этап 14, спека `sound-traffic-light-phrase-text-content`). Чистая,
// детерминированная логика — без random, легко тестируется.

enum SoundTrafficLightCriteria {

    /// Сколько успешных сессий подряд нужно для перехода на следующий уровень.
    /// (Слог/слово/фраза — × 2 сессии; текст — × 3 сессии для завершения пары.)
    static func requiredSessions(toAdvanceFrom level: DifferentiationLevel) -> Int {
        level == .text ? 3 : 2
    }

    /// Порог точности сессии, после которого она считается «успешной» для уровня.
    /// Слог/слово — 90%; фраза — 85% (спека).
    static func passThreshold(for level: DifferentiationLevel) -> Double {
        level == .phrase ? 0.85 : 0.90
    }

    /// Допуск при подсчёте слов на уровне ТЕКСТ (±1 слово, спека критерия ТЕКСТ).
    static let textCountTolerance = 1

    /// Считается ли сессия успешной (квалифицирующей) для перехода.
    /// Для слога/слова/фразы — по доле верных ответов; для текста — по доле
    /// засчитанных текстов (каждый в допуске ±1).
    static func isQualifying(
        accuracy: Double,
        level: DifferentiationLevel
    ) -> Bool {
        accuracy >= passThreshold(for: level)
    }

    /// Применяет результат сессии к прогрессу и возвращает обновлённый снимок.
    ///
    /// - Если сессия квалифицирующая — увеличивает счётчик подряд успешных
    ///   сессий; при достижении порога переводит на следующий доступный уровень
    ///   (счётчик сбрасывается). На уровне ТЕКСТ при достижении порога пара
    ///   помечается завершённой.
    /// - Если сессия не квалифицирующая — счётчик подряд успешных сбрасывается
    ///   (без штрафного отката уровня: регресс — нормальная часть работы).
    ///
    /// - Parameters:
    ///   - current: текущий прогресс ребёнка по паре.
    ///   - accuracy: доля верных в завершённой сессии [0...1].
    ///   - availableLevels: уровни, для которых у пары есть материал.
    /// - Returns: обновлённый прогресс.
    static func advance(
        _ current: DifferentiationProgress,
        accuracy: Double,
        availableLevels: [DifferentiationLevel]
    ) -> DifferentiationProgress {
        var result = current
        let level = current.level

        guard isQualifying(accuracy: accuracy, level: level) else {
            result.consecutiveQualifyingSessions = 0
            return result
        }

        result.consecutiveQualifyingSessions += 1
        let needed = requiredSessions(toAdvanceFrom: level)
        guard result.consecutiveQualifyingSessions >= needed else {
            return result
        }

        // Порог достигнут — переходим на следующий доступный уровень.
        result.consecutiveQualifyingSessions = 0
        if let nextLevel = nextAvailableLevel(after: level, in: availableLevels) {
            result.level = nextLevel
        } else {
            // Уровень — последний доступный (как правило ТЕКСТ): пара завершена.
            result.isPairCompleted = true
        }
        return result
    }

    /// Следующий доступный уровень после заданного (по материалу пары).
    static func nextAvailableLevel(
        after level: DifferentiationLevel,
        in availableLevels: [DifferentiationLevel]
    ) -> DifferentiationLevel? {
        guard let index = availableLevels.firstIndex(of: level),
              index + 1 < availableLevels.count else {
            return nil
        }
        return availableLevels[index + 1]
    }

    /// Нормализует уровень к первому доступному, если у пары нет материала
    /// для него (обратная совместимость с legacy-паками без слогов/фраз).
    static func resolveStartLevel(
        stored: DifferentiationLevel,
        availableLevels: [DifferentiationLevel]
    ) -> DifferentiationLevel {
        if availableLevels.contains(stored) { return stored }
        return availableLevels.first ?? .word
    }
}
