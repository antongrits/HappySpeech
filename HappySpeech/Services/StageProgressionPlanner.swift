import Foundation

// MARK: - StageProgressionPlanner (F1-014 / F1-015)
//
// Чистая детерминированная логика поэтапного движения по correction-stages:
//   • F1-015 — ретроспективный старт: первые 2–3 задания каждой сессии берутся
//     с ПРЕДЫДУЩЕГО освоенного этапа («вспомним, что уже умеем»).
//   • F1-014 — откат-логика (rollback): при регрессе (<50% за 2 сессии подряд)
//     или долгом перерыве (>14 дней) рекомендуемая стадия откатывается на ОДИН
//     шаг назад (не к изолированному звуку — методически: на слова → к слогам).
//
// Всё `nonisolated`/static и без I/O — тестируется напрямую, не ломает
// `DisorderRouteStrategy` (надстройка над её результатом).

public enum StageProgressionPlanner {

    // MARK: - F1-014 Rollback

    /// Порог «низкого результата» сессии (методический критерий регресса).
    public static let rollbackSuccessThreshold: Double = 0.5

    /// Число подряд низких сессий, после которых откатываем стадию.
    public static let rollbackLowSessionsCount: Int = 2

    /// Перерыв в днях, после которого откатываем стадию + ретест.
    public static let rollbackBreakDays: Int = 14

    /// Причина отката (для логов/UI и тестов).
    public enum RollbackTrigger: String, Sendable, Equatable {
        /// Нет отката.
        case none
        /// <50% за 2 сессии подряд по текущему звуку.
        case lowAccuracy
        /// Перерыв >14 дней с последней сессии.
        case longBreak
    }

    /// Решение о рекомендуемой стадии с учётом регресса/перерыва.
    public struct StageDecision: Sendable, Equatable {
        /// Стадия, которую планировщик рекомендует для основной работы.
        public let stage: CorrectionStage
        /// Сработавший триггер отката (или `.none`).
        public let trigger: RollbackTrigger
        /// true, если стадия была откачена назад относительно `current`.
        public var didRollback: Bool { trigger != .none }

        public init(stage: CorrectionStage, trigger: RollbackTrigger) {
            self.stage = stage
            self.trigger = trigger
        }
    }

    /// Определяет триггер отката по истории сессий конкретного звука.
    ///
    /// Чистая функция: сессии могут быть в любом порядке (упорядочиваются по дате).
    /// Приоритет: долгий перерыв проверяется первым (он перекрывает всё — нужен
    /// ретест), затем низкая точность за 2 последние сессии.
    ///
    /// - Parameters:
    ///   - soundSessions: сессии ТОЛЬКО по целевому звуку (фильтрация — на вызывающей стороне).
    ///   - now: текущий момент (для расчёта перерыва).
    public static func rollbackTrigger(
        soundSessions: [SessionDTO],
        now: Date = Date()
    ) -> RollbackTrigger {
        let chronological = soundSessions.sorted { $0.date < $1.date }
        guard let last = chronological.last else { return .none }

        // 1. Долгий перерыв > 14 дней → откат + ретест.
        let calendar = Calendar.current
        let daysSince = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: last.date),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        if daysSince > rollbackBreakDays { return .longBreak }

        // 2. <50% за 2 последние сессии подряд.
        let lastTwo = Array(chronological.suffix(rollbackLowSessionsCount))
        if lastTwo.count >= rollbackLowSessionsCount,
           lastTwo.allSatisfy({ $0.successRate < rollbackSuccessThreshold }) {
            return .lowAccuracy
        }

        return .none
    }

    /// Рекомендуемая стадия с учётом возможного отката на один шаг.
    ///
    /// Откат не опускается ниже `.isolated` (изолированный звук) — методически
    /// нельзя «сбрасывать» ребёнка на голую артикуляцию из-за пары неудач.
    public static func recommendedStage(
        current: CorrectionStage,
        soundSessions: [SessionDTO],
        now: Date = Date()
    ) -> StageDecision {
        let trigger = rollbackTrigger(soundSessions: soundSessions, now: now)
        guard trigger != .none else {
            return StageDecision(stage: current, trigger: .none)
        }
        // Откат на один шаг, но не ниже изолированного звука.
        let stepBack = current.previous ?? current
        let floored = max(stepBack, .isolated)
        // Если откатываться некуда (уже на дне) — триггер фиксируем, стадия не меняется.
        let resolved = floored < current ? floored : current
        return StageDecision(stage: resolved, trigger: trigger)
    }

    // MARK: - F1-015 Retrospective start

    /// Сколько ретроспективных заданий ставить в начало сессии (2–3).
    public static let retrospectiveStepCount: Int = 2

    /// Шаблон ретроспективного шага по стадии — лёгкая, узнаваемая активность
    /// (повторение/называние/сортировка), без новой когнитивной нагрузки.
    static func retrospectiveTemplate(for stage: CorrectionStage) -> TemplateType {
        switch stage {
        case .prep:                       return .articulationImitation
        case .isolated, .syllable:        return .repeatAfterModel
        case .wordInit, .wordMed, .wordFinal: return .listenAndChoose
        case .phrase, .sentence:          return .storyCompletion
        case .story:                      return .narrativeQuest
        case .diff:                       return .minimalPairs
        }
    }

    /// Собирает 2–3 ретроспективных шага предыдущей стадии для старта сессии.
    ///
    /// Если предыдущей стадии нет (ребёнок на самом первом этапе) — возвращает
    /// пустой массив (нечего «вспоминать»). Шаги помечены `isRetrospective`.
    ///
    /// - Parameters:
    ///   - currentStage: текущая рабочая стадия.
    ///   - soundTarget: целевой звук.
    ///   - fatigue: при усталости — 2 шага вместо 3 (короче, мягче).
    public static func retrospectiveSteps(
        currentStage: CorrectionStage,
        soundTarget: String,
        fatigue: FatigueLevel
    ) -> [RouteStepItem] {
        guard let prev = currentStage.previous else { return [] }
        let count = fatigue == .tired ? 2 : retrospectiveStepCount
        let template = retrospectiveTemplate(for: prev)
        return (0..<count).map { _ in
            RouteStepItem(
                templateType: template,
                targetSound: soundTarget,
                stage: prev,
                difficulty: 1,
                wordCount: 4,
                durationTargetSec: 60,
                track: .sound,
                isRetrospective: true
            )
        }
    }

    // MARK: - Review steps (F1-016 bridge)

    /// Преобразует due-повтор интервального планировщика в шаг маршрута.
    /// Стадия повтора неизвестна точно — используем `.wordInit` как нейтральную
    /// (повторяем на уровне слова), помечаем ретроспективным (это тоже «повторим»).
    static func reviewStep(for review: ReviewItemState) -> RouteStepItem {
        RouteStepItem(
            templateType: .listenAndChoose,
            targetSound: review.sound,
            stage: .wordInit,
            difficulty: 1,
            wordCount: 4,
            durationTargetSec: 60,
            track: .sound,
            isRetrospective: true
        )
    }
}
