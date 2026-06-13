import Foundation

// MARK: - VariationSelectionPolicy
//
// Чистая детерминированная логика подбора РЕАЛЬНОЙ вариации контента
// (`GeneratedActivity`) под шаг дневного маршрута, исходя из текущего состояния
// ребёнка. Это «gate шага маршрута»: вместо статичного пака каждый звуковой/
// позиционный шаг наполняется конкретной сгенерированной вариацией
// (`звук × этап × тема × сложность`), выбранной адаптивно.
//
// ### Зачем чистая static-логика (как `StageAdvancementPlanner` / `ReviewLadder`)
// Подбор вариации не делает I/O и не держит состояние — кандидаты (готовые
// `GeneratedActivity`) и сигналы ребёнка приходят аргументами. Это позволяет
// тестировать выбор напрямую (детерминированно, на синтетических кандидатах) и
// переиспользовать в `LiveAdaptivePlannerService` без гонок акторов.
//
// ### Сигналы → решение (методически обоснованно)
//   • **Усталость** (`fatigue`): tired → самая лёгкая и короткая вариация (низ
//     `difficultyBand`, без новых тем); normal → умеренная; fresh → можно сложнее.
//   • **Недавняя успешность** (`successRate`/`easinessFactor`): высокая → выше
//     сложность и приоритет НОВОЙ темы (челлендж/новизна); низкая → проще, без
//     тематической нагрузки (errorless practice).
//   • **Ротация тем** (`themeRotationSeed` — день/индекс сессии): среди тем-
//     кандидатов выбирается следующая по детерминированной ротации, чтобы не
//     повторять одну тему изо дня в день. Полностью детерминированно (нет
//     `shuffled`/`random`).
//
// ### Анти-пустышка и реальность контента
// Кандидаты — это уже отфильтрованные генератором активности с РЕАЛЬНЫМИ
// `items` (слова с резолвимыми картинками/аудио). Политика лишь ВЫБИРАЕТ из них;
// если подходящего кандидата нет — возвращает `nil`, и планировщик оставляет
// исходный rule-based шаг (контракт маршрута не ломается, пустышка не создаётся).

// MARK: - ChildAdaptiveSignals

/// Снимок адаптивных сигналов ребёнка для подбора вариации шага.
/// Все значения выводятся из РЕАЛЬНОГО состояния (`SoundProgressState`,
/// `StageProgress`, история сессий) на стороне планировщика — здесь только
/// иммутабельный value-снимок для чистой логики.
public struct ChildAdaptiveSignals: Sendable, Equatable {

    /// Рабочая стадия звука (после возможного отката) — целевой этап шагов.
    public let workingStage: CorrectionStage
    /// Уровень усталости текущей сессии.
    public let fatigue: FatigueLevel
    /// Доля верных попыток по звуку за недавнюю историю (0…1).
    public let recentSuccessRate: Double
    /// SM-2 easiness factor звука (≈1.3…3.0) — уверенность освоения.
    public let easinessFactor: Double
    /// Сколько подряд неверных попыток (индикатор трудности «здесь и сейчас»).
    public let consecutiveWrong: Int
    /// Детерминированный seed ротации тем (например, день года + индекс ребёнка),
    /// чтобы темы чередовались между сессиями, оставаясь воспроизводимыми.
    public let themeRotationSeed: Int

    public init(
        workingStage: CorrectionStage,
        fatigue: FatigueLevel,
        recentSuccessRate: Double,
        easinessFactor: Double,
        consecutiveWrong: Int,
        themeRotationSeed: Int
    ) {
        self.workingStage = workingStage
        self.fatigue = fatigue
        self.recentSuccessRate = recentSuccessRate
        self.easinessFactor = easinessFactor
        self.consecutiveWrong = consecutiveWrong
        self.themeRotationSeed = max(0, themeRotationSeed)
    }
}

// MARK: - VariationSelectionPolicy

public enum VariationSelectionPolicy {

    // MARK: - Пороги (методические)

    /// Доля верных, выше которой считаем ребёнка готовым к новизне/усложнению.
    public static let highSuccessThreshold: Double = 0.85

    /// Доля верных, ниже которой держим errorless-режим (проще, без тем).
    public static let lowSuccessThreshold: Double = 0.55

    /// EF, выше которого звук освоен достаточно для тематического челленджа.
    public static let confidentEFThreshold: Double = 2.3

    /// Подряд неверных, начиная с которого принудительно упрощаем (даже на fresh).
    public static let strugglingWrongStreak: Int = 2

    // MARK: - Сложностное намерение

    /// Целевое «направление» сложности, выведенное из сигналов.
    public enum DifficultyIntent: Sendable, Equatable {
        /// Самая лёгкая доступная вариация (усталость / серия ошибок).
        case easiest
        /// Умеренная (нижняя половина доступного диапазона сложности).
        case moderate
        /// Повышенная (верхняя половина) — ребёнок уверен и свеж.
        case challenging
    }

    /// Выводит намерение сложности из сигналов (чистая функция).
    /// Приоритет: усталость/серия ошибок → easiest; высокая успешность + свежесть
    /// + уверенный EF → challenging; иначе → moderate.
    public static func difficultyIntent(for signals: ChildAdaptiveSignals) -> DifficultyIntent {
        if signals.fatigue == .tired || signals.consecutiveWrong >= strugglingWrongStreak {
            return .easiest
        }
        let confident = signals.recentSuccessRate >= highSuccessThreshold
            && signals.easinessFactor >= confidentEFThreshold
        if confident, signals.fatigue == .fresh {
            return .challenging
        }
        if signals.recentSuccessRate <= lowSuccessThreshold {
            return .easiest
        }
        return .moderate
    }

    /// Допускать ли тематическую вариацию (новизна) при данных сигналах.
    /// Темы добавляют лексическую нагрузку → их даём, только если ребёнок не устал,
    /// не «застрял» и достаточно успешен. Иначе — внетематическая звуковая работа.
    public static func allowsThemedVariation(for signals: ChildAdaptiveSignals) -> Bool {
        guard signals.fatigue != .tired else { return false }
        guard signals.consecutiveWrong < strugglingWrongStreak else { return false }
        return signals.recentSuccessRate >= highSuccessThreshold
    }

    // MARK: - Подбор вариации под шаг

    /// Выбирает РЕАЛЬНУЮ вариацию (`GeneratedActivity`) под конкретный шаг
    /// маршрута из переданных кандидатов одного звука.
    ///
    /// Алгоритм (детерминированный):
    ///   1. Фильтр совместимости: `template == шаг.template` И `stage == шаг.stage`
    ///      (для тематических кандидатов этап нормализован генератором к `wordInit`,
    ///      поэтому при позиционном шаге допускаем тематический кандидат `.wordInit`).
    ///   2. Возрастной гейт: `minAge <= childAge`.
    ///   3. Тематический гейт: тематические кандидаты допускаются ТОЛЬКО если
    ///      `allowsThemedVariation`. Если темы разрешены и доступны — среди них
    ///      выбирается следующая по детерминированной ротации (`themeRotationSeed`).
    ///   4. Сложностной выбор: внутри отобранного набора берётся вариация,
    ///      чья `difficultyBand` ближе всего к намерению (`DifficultyIntent`).
    ///   5. Тай-брейк: стабильный лексикографический `id` (детерминизм).
    ///
    /// Возвращает `nil`, если совместимого реального кандидата нет — вызывающий
    /// оставляет исходный rule-based шаг (контракт сохранён, пустышка не плодится).
    ///
    /// - Parameters:
    ///   - template: шаблон шага маршрута.
    ///   - stage: целевая стадия шага маршрута.
    ///   - candidates: все валидные активности звука (из генератора).
    ///   - signals: адаптивные сигналы ребёнка.
    ///   - childAge: возраст ребёнка (возрастные гейты §6.3).
    public static func selectVariation(
        template: TemplateType,
        stage: CorrectionStage,
        candidates: [GeneratedActivity],
        signals: ChildAdaptiveSignals,
        childAge: Int
    ) -> GeneratedActivity? {
        let compatible = candidates.filter { candidate in
            guard candidate.template == template else { return false }
            guard candidate.minAge <= childAge else { return false }
            return stageMatches(candidate: candidate, stepStage: stage)
        }
        guard !compatible.isEmpty else { return nil }

        let themed = compatible.filter { $0.kind == .themed }
        let nonThemed = compatible.filter { $0.kind != .themed }

        // Тематическую вариацию даём только при разрешающих сигналах и наличии тем.
        if allowsThemedVariation(for: signals), !themed.isEmpty {
            return selectThemed(from: themed, signals: signals)
        }
        // Иначе — внетематическая работа; если внетематических нет, мягко
        // откатываемся к тематическим (лучше реальный контент, чем пропуск шага).
        let pool = nonThemed.isEmpty ? themed : nonThemed
        return pickByDifficulty(from: pool, intent: difficultyIntent(for: signals))
    }

    // MARK: - Theme rotation

    /// Темы кандидатов в стабильном порядке (по `id`, без `Set`-недетерминизма).
    static func sortedThemes(in themed: [GeneratedActivity]) -> [String] {
        var seen = Set<String>()
        var themes: [String] = []
        for activity in themed.sorted(by: { $0.id < $1.id }) {
            guard let theme = activity.theme else { continue }
            if seen.insert(theme).inserted { themes.append(theme) }
        }
        return themes
    }

    /// Выбирает тематическую вариацию: тема — по детерминированной ротации seed,
    /// внутри темы — по намерению сложности.
    private static func selectThemed(
        from themed: [GeneratedActivity],
        signals: ChildAdaptiveSignals
    ) -> GeneratedActivity? {
        let themes = sortedThemes(in: themed)
        guard !themes.isEmpty else {
            return pickByDifficulty(from: themed, intent: difficultyIntent(for: signals))
        }
        let chosenTheme = themes[signals.themeRotationSeed % themes.count]
        let pool = themed.filter { $0.theme == chosenTheme }
        return pickByDifficulty(from: pool, intent: difficultyIntent(for: signals))
    }

    // MARK: - Difficulty pick

    /// Совместимость стадии кандидата со стадией шага. Тематические кандидаты
    /// нормализованы генератором к `wordInit` — допускаем их для любого
    /// позиционного шага (`wordInit/wordMed/wordFinal`), т.к. тема описывает
    /// словарь, а не позицию (§4/§7.3 матрицы).
    static func stageMatches(candidate: GeneratedActivity, stepStage: CorrectionStage) -> Bool {
        if candidate.stage == stepStage { return true }
        if candidate.kind == .themed,
           candidate.stage == .wordInit,
           ContentVariationGenerator.positionalStages.contains(stepStage) {
            return true
        }
        return false
    }

    /// Репрезентативная сложность вариации — середина её `difficultyBand`.
    static func representativeDifficulty(of activity: GeneratedActivity) -> Double {
        let band = activity.difficultyBand
        return Double(band.lowerBound + band.upperBound) / 2.0
    }

    /// Выбирает вариацию, чья сложность ближе всего к намерению.
    /// `easiest` → минимальная сложность; `challenging` → максимальная;
    /// `moderate` → ближайшая к медиане доступных сложностей. Тай-брейк — `id`.
    static func pickByDifficulty(
        from pool: [GeneratedActivity],
        intent: DifficultyIntent
    ) -> GeneratedActivity? {
        guard !pool.isEmpty else { return nil }
        let sorted = pool.sorted { lhs, rhs in
            let ld = representativeDifficulty(of: lhs)
            let rd = representativeDifficulty(of: rhs)
            if ld != rd { return ld < rd }
            return lhs.id < rhs.id
        }
        switch intent {
        case .easiest:
            return sorted.first
        case .challenging:
            return sorted.last
        case .moderate:
            let difficulties = sorted.map { representativeDifficulty(of: $0) }
            guard let lo = difficulties.first, let hi = difficulties.last else { return sorted.first }
            let target = (lo + hi) / 2.0
            return sorted.min { lhs, rhs in
                let dl = abs(representativeDifficulty(of: lhs) - target)
                let dr = abs(representativeDifficulty(of: rhs) - target)
                if dl != dr { return dl < dr }
                return lhs.id < rhs.id
            }
        }
    }
}
