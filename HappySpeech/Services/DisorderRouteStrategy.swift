import Foundation

// MARK: - DisorderRouteStrategy (F1-021 / F1-013)

/// Стратегия сборки дневного маршрута под тип речевого нарушения.
///
/// База — звуковой маршрут (`LiveAdaptivePlannerService.composeRoute`), затем
/// в зависимости от `SpeechDisorder` добавляются параллельные методические
/// треки. Новые игровые механики (Звуковой детектив, Слоговая улитка, Чей хвост,
/// Конструктор предложения, Понимание-детектив) — это отдельные coordinator-routes,
/// поэтому в `RouteStepItem` они представлены ближайшими по дидактике `TemplateType`
/// (фонематика → minimalPairs/soundHunter/sorting; грамматика → dragAndMatch/
/// storyCompletion; связная речь → narrativeQuest/storyCompletion).
///
/// Методическое обоснование маршрутов — `wiki/concepts/speech-methodology.md`:
///   • дислалия    → звуковой трек (постановка/автоматизация);
///   • ФФН         → + фонематический трек (дифференциация, минимальные пары);
///   • ОНР III–IV  → 4 трека (произношение + фонематика + грамматика + связная речь);
///   • ЗРР         → «медленный старт»: короткие сессии, звукоподражание, называние;
///   • заикание    → дыхание/темп/плавность, без таймеров/скороговорок/соревнований;
///   • дизартрия   → удлинённая артикуляц. гимнастика + Visual-Acoustic + звук.
enum DisorderRouteStrategy {

    /// Собирает маршрут с учётом нарушения.
    static func composeRoute(
        soundTarget: String,
        stage: CorrectionStage,
        fatigue: FatigueLevel,
        disorder: SpeechDisorder
    ) -> [RouteStepItem] {
        switch disorder {
        case .dyslalia:
            return baseSoundRoute(soundTarget: soundTarget, stage: stage, fatigue: fatigue)
        case .ffn:
            return ffnRoute(soundTarget: soundTarget, stage: stage, fatigue: fatigue)
        case .onr:
            return onrRoute(soundTarget: soundTarget, stage: stage, fatigue: fatigue)
        case .zrr:
            return zrrRoute(soundTarget: soundTarget, fatigue: fatigue)
        case .stuttering:
            return stutteringRoute(soundTarget: soundTarget, stage: stage, fatigue: fatigue)
        case .dysarthria:
            return dysarthriaRoute(soundTarget: soundTarget, stage: stage, fatigue: fatigue)
        }
    }

    /// Лимит длительности сессии с учётом нарушения. ЗРР занижает базовый
    /// возрастной cap до 5 минут («медленный старт»); остальные — по возрасту.
    static func sessionCap(for age: Int, disorder: SpeechDisorder) -> Int {
        let base = LiveAdaptivePlannerService.sessionMaxSec(for: age)
        if disorder.isSlowStart {
            return min(base, 300) // 5 минут
        }
        return base
    }

    // MARK: - Base sound track (reuse existing matrix, tag track = .sound)

    /// Базовый звуковой маршрут — переиспользует существующую матрицу планировщика
    /// и помечает шаги треком `.sound`.
    private static func baseSoundRoute(
        soundTarget: String,
        stage: CorrectionStage,
        fatigue: FatigueLevel
    ) -> [RouteStepItem] {
        LiveAdaptivePlannerService.composeRoute(soundTarget: soundTarget, stage: stage, fatigue: fatigue)
            .map { tag($0, with: .sound) }
    }

    // MARK: - ФФН: звук + фонематика

    private static func ffnRoute(
        soundTarget: String,
        stage: CorrectionStage,
        fatigue: FatigueLevel
    ) -> [RouteStepItem] {
        var steps = baseSoundRoute(soundTarget: soundTarget, stage: stage, fatigue: fatigue)
        // Фонематический трек: дифференциация / минимальные пары (профилактика дисграфии).
        steps.append(phonemicStep(soundTarget: soundTarget, fatigue: fatigue))
        return cappedAntiFatigue(steps, fatigue: fatigue)
    }

    // MARK: - ОНР III–IV: 4 параллельных трека (F1-013)

    private static func onrRoute(
        soundTarget: String,
        stage: CorrectionStage,
        fatigue: FatigueLevel
    ) -> [RouteStepItem] {
        // 1. Произношение (warm-up + core из базовой матрицы — берём первые 2 шага)
        let base = baseSoundRoute(soundTarget: soundTarget, stage: stage, fatigue: fatigue)
        var steps: [RouteStepItem] = Array(base.prefix(2))
        // 2. Фонематика
        steps.append(phonemicStep(soundTarget: soundTarget, fatigue: fatigue))
        // 3. Грамматика
        steps.append(grammarStep(soundTarget: soundTarget, fatigue: fatigue))
        // 4. Связная речь
        steps.append(coherentSpeechStep(soundTarget: soundTarget, fatigue: fatigue))
        return cappedAntiFatigue(steps, fatigue: fatigue)
    }

    // MARK: - ЗРР: «медленный старт»

    private static func zrrRoute(
        soundTarget: String,
        fatigue: FatigueLevel
    ) -> [RouteStepItem] {
        // Короткая сессия: вызов речи и называние, без давления на чистоту звука.
        // Звукоподражание / имитация (repeatAfterModel), называние (listenAndChoose).
        let imitation = RouteStepItem(
            templateType: .repeatAfterModel,
            targetSound: soundTarget,
            stage: .isolated,
            difficulty: 1,
            wordCount: 4,
            durationTargetSec: 90,
            track: .sound
        )
        let naming = RouteStepItem(
            templateType: .listenAndChoose,
            targetSound: soundTarget,
            stage: .wordInit,
            difficulty: 1,
            wordCount: 4,
            durationTargetSec: 90,
            track: .coherentSpeech
        )
        let reward = RouteStepItem(
            templateType: .puzzleReveal,
            targetSound: soundTarget,
            stage: .isolated,
            difficulty: 1,
            wordCount: 3,
            durationTargetSec: 60,
            track: .sound
        )
        // Усталость → ещё короче: имитация + награда.
        return fatigue == .tired ? [imitation, reward] : [imitation, naming, reward]
    }

    // MARK: - Заикание: дыхание / темп / плавность

    private static func stutteringRoute(
        soundTarget: String,
        stage: CorrectionStage,
        fatigue: FatigueLevel
    ) -> [RouteStepItem] {
        // Без таймеров/скороговорок/соревнований (hasFluencyGoal). Акцент на
        // дыхание и ритм; звуковая работа — мягко, без timed-mode.
        let breathing = RouteStepItem(
            templateType: .breathing,
            targetSound: soundTarget,
            stage: .prep,
            difficulty: 1,
            wordCount: 1,
            durationTargetSec: 120,
            track: .breathingFluency
        )
        let rhythm = RouteStepItem(
            templateType: .rhythm,
            targetSound: soundTarget,
            stage: stage,
            difficulty: 1,
            wordCount: 6,
            durationTargetSec: 150,
            track: .breathingFluency
        )
        let gentleSound = RouteStepItem(
            templateType: .repeatAfterModel,
            targetSound: soundTarget,
            stage: stage,
            difficulty: 1,
            wordCount: 6,
            durationTargetSec: 120,
            track: .sound
        )
        return fatigue == .tired ? [breathing, rhythm] : [breathing, rhythm, gentleSound]
    }

    // MARK: - Дизартрия: усиленная артикуляция + Visual-Acoustic

    private static func dysarthriaRoute(
        soundTarget: String,
        stage: CorrectionStage,
        fatigue: FatigueLevel
    ) -> [RouteStepItem] {
        // Удлинённая артикуляционная гимнастика (3–4 мин) + Visual-Acoustic
        // биообратная связь, затем звуковой трек.
        let articulation = RouteStepItem(
            templateType: .articulationImitation,
            targetSound: soundTarget,
            stage: .prep,
            difficulty: 1,
            wordCount: 4,
            durationTargetSec: 210,
            track: .articulation
        )
        let visualAcoustic = RouteStepItem(
            templateType: .visualAcoustic,
            targetSound: soundTarget,
            stage: stage,
            difficulty: 2,
            wordCount: 6,
            durationTargetSec: 150,
            track: .articulation
        )
        let core = RouteStepItem(
            templateType: LiveAdaptivePlannerService.composeRoute(
                soundTarget: soundTarget, stage: stage, fatigue: fatigue
            ).first(where: { $0.stage == stage })?.templateType ?? .repeatAfterModel,
            targetSound: soundTarget,
            stage: stage,
            difficulty: 2,
            wordCount: 6,
            durationTargetSec: fatigue == .tired ? 120 : 180,
            track: .sound
        )
        return fatigue == .tired ? [articulation, visualAcoustic] : [articulation, visualAcoustic, core]
    }

    // MARK: - Track step factories

    private static func phonemicStep(soundTarget: String, fatigue: FatigueLevel) -> RouteStepItem {
        // Дифференциация / минимальные пары (фонемный анализ).
        RouteStepItem(
            templateType: .minimalPairs,
            targetSound: soundTarget,
            stage: .diff,
            difficulty: 2,
            wordCount: 6,
            durationTargetSec: fatigue == .tired ? 120 : 150,
            track: .phonemic
        )
    }

    private static func grammarStep(soundTarget: String, fatigue: FatigueLevel) -> RouteStepItem {
        // Словоизменение/словообразование/синтаксис — Grammar Games на dragAndMatch.
        RouteStepItem(
            templateType: .dragAndMatch,
            targetSound: soundTarget,
            stage: .phrase,
            difficulty: 2,
            wordCount: 6,
            durationTargetSec: fatigue == .tired ? 120 : 150,
            track: .grammar
        )
    }

    private static func coherentSpeechStep(soundTarget: String, fatigue: FatigueLevel) -> RouteStepItem {
        // Связная речь — пересказ/рассказ по серии картинок.
        RouteStepItem(
            templateType: .narrativeQuest,
            targetSound: soundTarget,
            stage: .story,
            difficulty: 2,
            wordCount: 6,
            durationTargetSec: fatigue == .tired ? 120 : 150,
            track: .coherentSpeech
        )
    }

    // MARK: - Helpers

    private static func tag(_ step: RouteStepItem, with track: RouteTrack) -> RouteStepItem {
        RouteStepItem(
            templateType: step.templateType,
            targetSound: step.targetSound,
            stage: step.stage,
            difficulty: step.difficulty,
            wordCount: step.wordCount,
            durationTargetSec: step.durationTargetSec,
            track: track
        )
    }

    /// Антифатиговое правило: при `.tired` ограничивает число шагов 3-мя
    /// (тяжёлый день — не перегружать), сохраняя разнообразие треков.
    private static func cappedAntiFatigue(_ steps: [RouteStepItem], fatigue: FatigueLevel) -> [RouteStepItem] {
        guard fatigue == .tired, steps.count > 3 else { return steps }
        return Array(steps.prefix(3))
    }
}
