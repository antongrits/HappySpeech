import Foundation

// MARK: - StageAdvancementPlanner (P0-4)
//
// Чистая детерминированная логика ПРОДВИЖЕНИЯ ВПЕРЁД по 10-этапной лестнице
// коррекции звука (Фомичёва). Дополняет `StageProgressionPlanner`, который умеет
// только откат (rollback): откат отвечает за регресс, этот планировщик — за
// освоение.
//
// ### Методический критерий перехода (wiki/concepts/correction-stages.md)
//   • Стандартный критерий — 80% верных попыток в 2 подряд сессиях стадии.
//   • Изолированный звук — 8/10 попыток (= 0.8) × 2 сессии.
//   • Рассказ — 70% + связность × 2 сессии (связность не измеряется on-device,
//     поэтому используем порог точности 0.7).
//   • Дифференциация — 90% × 3 сессии. Дифференциация (`.diff`) НЕ является
//     линейным шагом лестницы: она надстраивается над автоматизацией ОБОИХ
//     звуков пары и управляется отдельно (`SoundTrafficLight` /
//     `DifferentiationProgressStore`). Поэтому линейное продвижение упирается в
//     `.story` (потолок) и не перепрыгивает в `.diff` автоматически (gate).
//
// ### Почему чистая static-логика
// Та же мотивация, что у `StageProgressionPlanner` / `ReviewLadder`: без I/O и
// глобального состояния — тестируется напрямую, переиспользуется в
// `SessionShellInteractor` (персист по факту сессии) и потенциально в отчётах.

public enum StageAdvancementPlanner {

    // MARK: - Пороги точности перехода

    /// Стандартный порог «квалифицирующей» сессии (80%).
    public static let standardQualifyingRate: Double = 0.80

    /// Порог для стадии «рассказ» (70% + связность; связность вне измерения).
    public static let storyQualifyingRate: Double = 0.70

    /// Порог для дифференциации (90%). Используется при оценке `.diff`, хотя
    /// линейное продвижение в `.diff` не заходит (см. gate выше).
    public static let differentiationQualifyingRate: Double = 0.90

    /// Сколько подряд квалифицирующих сессий нужно для большинства стадий.
    public static let standardConsecutiveSessions: Int = 2

    /// Сколько подряд квалифицирующих сессий нужно для дифференциации.
    public static let differentiationConsecutiveSessions: Int = 3

    /// Потолок линейного продвижения. Дифференциация (`.diff`) не достигается
    /// автоматическим линейным шагом — она требует автоматизации обоих звуков
    /// пары и управляется `SoundTrafficLight`. `.prep` (подготовка артикуляции)
    /// — нижний этап, в нём приложение начинает с `.isolated` по умолчанию.
    public static let linearCeiling: CorrectionStage = .story

    // MARK: - Критерий квалификации сессии

    /// Порог точности, при котором сессия считается «квалифицирующей» для стадии.
    public static func qualifyingRate(for stage: CorrectionStage) -> Double {
        switch stage {
        case .story:
            return storyQualifyingRate
        case .diff:
            return differentiationQualifyingRate
        default:
            return standardQualifyingRate
        }
    }

    /// Сколько подряд квалифицирующих сессий нужно стадии для перехода.
    public static func requiredConsecutiveSessions(for stage: CorrectionStage) -> Int {
        stage == .diff ? differentiationConsecutiveSessions : standardConsecutiveSessions
    }

    /// Сессия удовлетворила критерий точности текущей стадии.
    public static func sessionQualifies(stage: CorrectionStage, successRate: Double) -> Bool {
        successRate >= qualifyingRate(for: stage)
    }

    // MARK: - Решение о продвижении

    /// Результат оценки одной завершённой сессии для лестницы.
    public struct AdvancementDecision: Sendable, Equatable {
        /// Прогресс после применения результата сессии (стадия + счётчик).
        public let progress: StageProgress
        /// true, если стадия повысилась относительно входной.
        public let didAdvance: Bool

        public init(progress: StageProgress, didAdvance: Bool) {
            self.progress = progress
            self.didAdvance = didAdvance
        }
    }

    /// Следующая стадия линейной лестницы (без захода в `.diff`).
    ///
    /// Возвращает `nil`, если продвигаться некуда (стадия уже на `linearCeiling`
    /// или выше — например, ребёнок уже в дифференциации, которой управляет
    /// отдельный модуль).
    static func nextLinearStage(after stage: CorrectionStage) -> CorrectionStage? {
        guard stage < linearCeiling else { return nil }
        guard let idx = CorrectionStage.ladder.firstIndex(of: stage) else { return nil }
        let nextIdx = idx + 1
        guard nextIdx < CorrectionStage.ladder.count else { return nil }
        let candidate = CorrectionStage.ladder[nextIdx]
        // `ladder` исключает `.diff`, но страхуемся: не заходим выше потолка.
        return candidate <= linearCeiling ? candidate : nil
    }

    /// Применяет результат одной завершённой сессии к прогрессу лестницы.
    ///
    /// Логика (errorless, методически обоснованная):
    ///   1. Сессия квалифицирующая (точность ≥ порог стадии) → инкремент счётчика
    ///      подряд квалифицирующих сессий.
    ///   2. Счётчик достиг требуемого (2, для `.diff` — 3) И есть куда расти →
    ///      стадия повышается на следующую линейную, счётчик сбрасывается в 0.
    ///   3. Сессия НЕ квалифицирующая → счётчик подряд сбрасывается в 0 (нужны
    ///      именно ПОДРЯД идущие успешные сессии). Стадия не меняется — откат
    ///      (rollback) при настоящем регрессе делает `StageProgressionPlanner`
    ///      на уровне планировщика маршрута, здесь — только «вверх или держим».
    ///   4. Достигнут потолок линейной лестницы (`.story`) — счётчик не растёт
    ///      бесконечно, стадия стабильна; дифференциация заходит отдельно.
    ///
    /// - Parameters:
    ///   - progress: текущий прогресс (стадия + счётчик) до этой сессии.
    ///   - successRate: доля верных попыток сессии (0…1).
    public static func apply(
        progress: StageProgress,
        sessionSuccessRate successRate: Double
    ) -> AdvancementDecision {
        let stage = progress.stage

        guard sessionQualifies(stage: stage, successRate: successRate) else {
            // Неуспешная по критерию сессия обнуляет серию (нужны подряд).
            let reset = StageProgress(stage: stage, consecutiveQualifyingSessions: 0)
            return AdvancementDecision(progress: reset, didAdvance: false)
        }

        let newStreak = progress.consecutiveQualifyingSessions + 1
        let required = requiredConsecutiveSessions(for: stage)

        guard newStreak >= required, let next = nextLinearStage(after: stage) else {
            // Критерий ещё не набран ИЛИ расти некуда — копим серию, держим стадию.
            let held = StageProgress(stage: stage, consecutiveQualifyingSessions: newStreak)
            return AdvancementDecision(progress: held, didAdvance: false)
        }

        // Освоение подтверждено — повышаем стадию, серию обнуляем.
        let advanced = StageProgress(stage: next, consecutiveQualifyingSessions: 0)
        return AdvancementDecision(progress: advanced, didAdvance: true)
    }
}
