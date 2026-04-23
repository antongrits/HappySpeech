import Foundation

// MARK: - RuleBasedDecisionService
// ==================================================================================
// Deterministic, dependency-free fallback for all 12 decision points.
// No ML, no network. Produces valid outputs even when the LLM is absent.
// Used:
//   1. As the ultimate fallback inside LiveLLMDecisionService.
//   2. Standalone for tests, previews, and first-run (before LLM download).
// ==================================================================================

public struct RuleBasedDecisionService: Sendable {

    public init() {}

    // MARK: - 1. Route planning

    public func planDailyRoute(context: RoutePlanContext) -> (route: [RouteStepItem], maxDurationSec: Int) {
        // Fatigue rotation: Active → Passive → Motor → Active
        // successRate > 0.85 → promote templates, < 0.60 → review/prep templates
        let templates = templatesForStage(
            stage: context.currentStage,
            successRate: context.recentSuccessRate,
            fatigue: context.fatigueLevel,
            available: context.availableTemplates
        )

        let maxDuration: Int
        switch context.fatigueLevel {
        case .tired:  maxDuration = 480   // 8 min
        case .normal: maxDuration = 600   // 10 min
        case .fresh:  maxDuration = 900   // 15 min
        }

        let baseDifficulty: Int
        switch context.recentSuccessRate {
        case 0.85...:      baseDifficulty = 3
        case 0.60..<0.85:  baseDifficulty = 2
        default:           baseDifficulty = 1
        }

        let steps = templates.prefix(3).map { template in
            RouteStepItem(
                templateType: template,
                targetSound: context.targetSound,
                stage: context.currentStage,
                difficulty: baseDifficulty,
                wordCount: templateWordCount(template),
                durationTargetSec: templateDuration(template, fatigue: context.fatigueLevel)
            )
        }

        return (Array(steps), maxDuration)
    }

    // MARK: - 2. Micro-story

    public func generateMicroStory(context: StoryContext) -> MicroStory {
        // Pool of 20 micro-stories keyed by sound family — selected deterministically.
        let family = soundFamily(for: context.targetSound)
        let pool = microStoryPool(for: family)
        let idx = stableIndex(seed: context.targetSound + context.wordPool.joined(), upperBound: pool.count)
        let template = pool[idx]

        let words = !context.wordPool.isEmpty ? context.wordPool : fallbackWords(for: family)
        let sentences = template.fillIn(words: words)
        let lastWord = words.last ?? context.targetSound
        let gaps = [MicroStory.Gap(sentenceIndex: sentences.count - 1, word: lastWord, imageHint: lastWord)]
        return MicroStory(sentences: sentences, gaps: gaps)
    }

    // MARK: - 3. Parent summary

    public func generateParentSummary(session: SessionSummaryInput) -> ParentSummary {
        let ratePct = Int((session.successRate * 100).rounded())
        let mins = max(1, session.durationSec / 60)
        let errors = session.errorWords.prefix(3).joined(separator: ", ")

        let summaryText: String
        switch ratePct {
        case 85...:
            summaryText = "\(session.childName) отлично поработал со звуком «\(session.targetSound)» — \(ratePct)% правильно за \(mins) мин. Продолжайте в том же духе!"
        case 60..<85:
            summaryText = "\(session.childName) хорошо занимался со звуком «\(session.targetSound)» — \(ratePct)% из \(session.totalAttempts) попыток. Ещё немного практики и будет замечательно."
        default:
            summaryText = "\(session.childName) работал со звуком «\(session.targetSound)» — \(ratePct)% из \(session.totalAttempts) попыток. Мягкая поддержка важнее скорости — попробуйте повторить короткими подходами."
        }

        let homeTask: String
        if errors.isEmpty {
            homeTask = "Повторите любые простые слова со звуком «\(session.targetSound)» — 3–5 раз перед сном."
        } else {
            homeTask = "Дома повторите: \(errors). По 3 раза медленно, с чётким звуком «\(session.targetSound)»."
        }

        return ParentSummary(summaryText: summaryText, homeTask: homeTask, tone: "supportive")
    }

    // MARK: - 4. Encouragement (50 Russian phrases)

    public func pickEncouragementPhrase(context: AttemptContext) -> (message: String, emoji: String) {
        if context.isCorrect {
            let pool = Self.encouragementCorrect
            let idx = stableIndex(seed: context.word + "\(context.streak)", upperBound: pool.count)
            let emoji = Self.emojiPositive[stableIndex(seed: context.word, upperBound: Self.emojiPositive.count)]
            return (pool[idx], emoji)
        } else {
            let pool = Self.encouragementTryAgain
            let idx = stableIndex(seed: context.word + "\(context.streak)", upperBound: pool.count)
            let emoji = Self.emojiGentle[stableIndex(seed: context.word, upperBound: Self.emojiGentle.count)]
            return (pool[idx], emoji)
        }
    }

    // MARK: - 5. Reward

    public func pickReward(streak: Int, sessionType: LLMSessionType) -> Reward {
        let stickerId = Self.stickerPool[streak % Self.stickerPool.count]
        let title: String
        let subtitle: String
        switch streak {
        case 0...2:
            title = "Отличное начало!"
            subtitle = "Новый стикер для твоей коллекции"
        case 3...5:
            title = "Молодец, так держать!"
            subtitle = "Ты получил особый стикер"
        case 6...9:
            title = "Супер-серия!"
            subtitle = "Редкий стикер разблокирован"
        default:
            title = "Легендарная серия!"
            subtitle = "Эпический стикер — только для лучших"
        }
        let badge: String? = (streak >= 7) ? "streak-\(streak)" : nil
        return Reward(title: title, subtitle: subtitle, stickerId: stickerId, badgeId: badge)
    }

    // MARK: - 6. Finish session

    public func decideFinishSession(fatigueLevel: Double, attempts: Int) -> (finish: Bool, reason: String) {
        // Fatigue [0..1]. Finish when very tired AND enough practice, or too many attempts.
        if fatigueLevel >= 0.8 && attempts >= 6 {
            return (true, "ребёнок устал — лучше закончить на положительной ноте")
        }
        if fatigueLevel >= 0.9 {
            return (true, "сильная усталость — завершаем сессию мягко")
        }
        if attempts >= 30 {
            return (true, "достаточно попыток за одну сессию — делаем перерыв")
        }
        return (false, "можно продолжать")
    }

    // MARK: - 7. Difficulty adjustment

    public func adjustDifficulty(recentAttempts: [AttemptOutcome]) -> (difficulty: Difficulty, delta: Int, reason: String) {
        guard !recentAttempts.isEmpty else {
            return (.medium, 0, "нет данных — оставляем средний уровень")
        }
        let successes = recentAttempts.filter { $0.isCorrect }.count
        let rate = Double(successes) / Double(recentAttempts.count)

        if rate > 0.85 && recentAttempts.count >= 3 {
            return (.hard, +1, "три правильных подряд — можно усложнить")
        }
        if rate < 0.40 && recentAttempts.count >= 3 {
            return (.easy, -1, "мало верных ответов — упрощаем")
        }
        if rate < 0.60 {
            return (.easy, -1, "успех ниже 60% — упрощаем")
        }
        return (.medium, 0, "темп стабильный — удерживаем уровень")
    }

    // MARK: - 8. Error analysis

    public func analyzeError(attempt: AttemptOutcome, target: String) -> ErrorAnalysis {
        if attempt.isCorrect || attempt.pronunciationScore >= 0.65 {
            return ErrorAnalysis(category: .correct, hint: "Отлично — звук чёткий, продолжай.")
        }
        if attempt.asrTranscript.isEmpty {
            return ErrorAnalysis(category: .hesitation, hint: "Попробуй произнести слово чуть громче.")
        }
        if !attempt.asrTranscript.lowercased().contains(target.lowercased()) {
            return ErrorAnalysis(category: .soundOmission, hint: "Слово сказано, но звука «\(target)» не слышно — попробуй ещё раз, медленно.")
        }
        if attempt.asrConfidence < 0.5 {
            return ErrorAnalysis(category: .uncertain, hint: "Звук тихий. Скажи громче и чётче.")
        }
        if attempt.pronunciationScore < 0.4 {
            return ErrorAnalysis(category: .soundDistortion, hint: "Звук получился немного искажённым — попробуй ещё раз, как будто поёшь.")
        }
        return ErrorAnalysis(category: .soundReplacement, hint: "Похоже, другой звук прозвучал вместо «\(target)» — прислушайся к образцу.")
    }

    // MARK: - 9. Content recommendation

    public func recommendContent(profile: ChildProfileInput, history: [SessionSummaryInput]) -> ContentRecommendation {
        // Pick packs for the weakest sound first.
        let weakest = profile.progressSummary.min(by: { $0.value < $1.value })?.key ?? profile.targetSounds.first ?? "С"
        let stages: [CorrectionStage] = [.wordInit, .wordMed, .wordFinal]
        let packIds = stages.map { "\(weakest)-\($0.rawValue)-v1" }
        let rationale = "Рекомендуем паки для звука «\(weakest)» — по прогрессу это самое слабое место."
        return ContentRecommendation(packIds: packIds, rationale: rationale)
    }

    // MARK: - 10. Specialist report

    public func generateSpecialistReport(sessions30d: [SessionSummaryInput]) -> SpecialistReport {
        guard !sessions30d.isEmpty else {
            return SpecialistReport(
                headline: "Нет данных за последние 30 дней",
                strengths: [],
                weaknesses: [],
                recommendations: ["Необходимо минимум 3 сессии для анализа."],
                nextMilestone: "Первая сессия"
            )
        }
        let totalAttempts = sessions30d.reduce(0) { $0 + $1.totalAttempts }
        let totalCorrect = sessions30d.reduce(0) { $0 + $1.correctAttempts }
        let overallRate = totalAttempts > 0 ? Double(totalCorrect) / Double(totalAttempts) : 0
        let ratePct = Int((overallRate * 100).rounded())

        // Group by sound
        var bySound: [String: (total: Int, correct: Int)] = [:]
        for s in sessions30d {
            var entry = bySound[s.targetSound] ?? (0, 0)
            entry.total += s.totalAttempts
            entry.correct += s.correctAttempts
            bySound[s.targetSound] = entry
        }

        var strengths: [String] = []
        var weaknesses: [String] = []
        for (sound, entry) in bySound.sorted(by: { $0.key < $1.key }) {
            let r = entry.total > 0 ? Double(entry.correct) / Double(entry.total) : 0
            if r >= 0.75 {
                strengths.append("Звук «\(sound)»: \(Int((r * 100).rounded()))% — уверенный уровень.")
            } else if r < 0.55 {
                weaknesses.append("Звук «\(sound)»: \(Int((r * 100).rounded()))% — требует дополнительной работы.")
            }
        }

        let headline = "За 30 дней: \(sessions30d.count) сессий, общий успех \(ratePct)%."
        let recommendations = [
            "Увеличить частоту коротких домашних упражнений (5–7 мин ежедневно).",
            "Для слабых звуков — начинать сессию с разминки и изолированного звука.",
            "Использовать AR-зеркало для самонаблюдения артикуляции 2–3 раза в неделю."
        ]
        let next = weaknesses.isEmpty
            ? "Переходить на этап предложений и рассказа."
            : "Закрепить слова средней позиции по слабым звукам."
        return SpecialistReport(
            headline: headline,
            strengths: strengths,
            weaknesses: weaknesses,
            recommendations: recommendations,
            nextMilestone: next
        )
    }

    // MARK: - 11. Fatigue detection

    public func detectFatigue(audioMetrics: AudioMetricsInput, sessionDuration: TimeInterval) -> (level: FatigueLevel, confidence: Double) {
        // Heuristics:
        //  - silenceRatio > 0.6 or attemptsPerMinute < 2 → tired
        //  - duration > 600 and silenceRatio > 0.4 → tired
        //  - duration > 300 and amplitude trend down → normal
        //  - otherwise fresh
        let durationMin = sessionDuration / 60.0
        var score: Double = 0

        if audioMetrics.silenceRatio > 0.6 { score += 0.5 }
        else if audioMetrics.silenceRatio > 0.4 { score += 0.3 }

        if audioMetrics.attemptsPerMinute < 2 { score += 0.3 }
        else if audioMetrics.attemptsPerMinute < 3.5 { score += 0.15 }

        if durationMin > 10 { score += 0.2 }
        else if durationMin > 6 { score += 0.1 }

        if audioMetrics.averageAmplitude < 0.05 { score += 0.15 }

        let level: FatigueLevel
        switch score {
        case 0.55...: level = .tired
        case 0.3..<0.55: level = .normal
        default: level = .fresh
        }
        return (level, min(1.0, max(0.3, score + 0.3)))
    }

    // MARK: - 12. Custom phrase (warmup / parent tip / homework / transition / sessionComplete)

    public func generateCustomPhrase(template: PhraseTemplate, context: [String: String]) -> String {
        let name = context["child_name"] ?? "Друг"
        let sound = context["target_sound"] ?? "звук"
        switch template {
        case .warmup:
            return "Привет, \(name)! Давай позанимаемся со звуком «\(sound)». Глубокий вдох — и начнём!"
        case .parentTip:
            return Self.parentTips[stableIndex(seed: sound, upperBound: Self.parentTips.count)]
                .replacingOccurrences(of: "{sound}", with: sound)
        case .homework:
            let words = context["weak_words"] ?? "любые слова"
            return "Домашнее задание: повторите \(words) по 3 раза в день перед зеркалом. Спокойно, без спешки."
        case .transition:
            return "Отлично! Переходим к следующему заданию — будет интересно!"
        case .sessionComplete:
            return "Сессия завершена — ты молодец, \(name)! До скорой встречи."
        }
    }

    // MARK: - Helpers

    private func templatesForStage(
        stage: CorrectionStage,
        successRate: Double,
        fatigue: FatigueLevel,
        available: [TemplateType]
    ) -> [TemplateType] {
        let all = available.isEmpty ? TemplateType.allCases : available

        // Fatigue rotation: active → passive → motor → active
        let activeOrder: [TemplateType] = [
            .repeatAfterModel, .minimalPairs, .storyCompletion, .narrativeQuest
        ]
        let passiveOrder: [TemplateType] = [
            .listenAndChoose, .memory, .bingo, .sorting, .dragAndMatch, .puzzleReveal
        ]
        let motorOrder: [TemplateType] = [
            .articulationImitation, .breathing, .rhythm, .arActivity, .visualAcoustic
        ]

        var base: [TemplateType]
        switch stage {
        case .prep, .isolated, .syllable:
            base = motorOrder + passiveOrder + activeOrder
        case .wordInit, .wordMed, .wordFinal:
            base = passiveOrder + activeOrder + motorOrder
        case .phrase, .sentence, .story, .diff:
            base = activeOrder + passiveOrder + motorOrder
        }

        // If very tired — prefer passive
        if fatigue == .tired {
            base = passiveOrder + motorOrder + activeOrder
        }

        // Low success rate → bring motor/prep earlier
        if successRate < 0.6 {
            base = motorOrder + passiveOrder + activeOrder
        }

        return base.filter { all.contains($0) }
    }

    private func templateWordCount(_ template: TemplateType) -> Int {
        switch template {
        case .breathing, .rhythm, .articulationImitation, .arActivity: return 4
        case .listenAndChoose, .memory, .bingo, .sorting: return 8
        case .repeatAfterModel, .minimalPairs: return 10
        case .storyCompletion, .narrativeQuest: return 6
        default: return 8
        }
    }

    private func templateDuration(_ template: TemplateType, fatigue: FatigueLevel) -> Int {
        let base: Int
        switch template {
        case .breathing, .rhythm: base = 120
        case .narrativeQuest, .storyCompletion: base = 240
        default: base = 180
        }
        return fatigue == .tired ? Int(Double(base) * 0.75) : base
    }

    private func soundFamily(for sound: String) -> SoundFamily {
        let upper = sound.uppercased()
        for family in SoundFamily.allCases where family.sounds.contains(where: { $0.uppercased() == upper }) {
            return family
        }
        return .whistling
    }

    private func fallbackWords(for family: SoundFamily) -> [String] {
        switch family {
        case .whistling: return ["сова", "сом", "санки", "сад"]
        case .hissing:   return ["шар", "шапка", "шуба", "шишка"]
        case .sonorant:  return ["рыба", "рак", "радуга", "ракета"]
        case .velar:     return ["кот", "кит", "куст", "камень"]
        }
    }

    private func stableIndex(seed: String, upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        var hash: UInt64 = 1469598103934665603
        for byte in seed.utf8 {
            hash = hash ^ UInt64(byte)
            hash = hash &* 1099511628211
        }
        return Int(hash % UInt64(upperBound))
    }

    private func microStoryPool(for family: SoundFamily) -> [MicroStoryTemplate] {
        switch family {
        case .whistling: return Self.storiesWhistling
        case .hissing:   return Self.storiesHissing
        case .sonorant:  return Self.storiesSonorant
        case .velar:     return Self.storiesVelar
        }
    }

    // MARK: - Static pools (private)

    struct MicroStoryTemplate: Sendable {
        let templates: [String]
        func fillIn(words: [String]) -> [String] {
            var idx = 0
            return templates.map { tmpl in
                let word = words[idx % words.count]
                idx += 1
                return tmpl.replacingOccurrences(of: "{w}", with: word)
            }
        }
    }

    static let storiesWhistling: [MicroStoryTemplate] = [
        .init(templates: ["Жил-был {w} в саду.", "Он любил слушать {w}.", "Однажды {w} нашёл друга."]),
        .init(templates: ["У Сони был {w}.", "Соня играла в {w}.", "Вечером {w} спал."]),
        .init(templates: ["В лесу рос {w}.", "Рядом жил {w}.", "Они стали дружить."]),
        .init(templates: ["Саша купил {w}.", "Дома {w} стоял на столе.", "Все любили этот {w}."]),
        .init(templates: ["Зимой пришёл {w}.", "Он принёс {w}.", "Семья радовалась."])
    ]

    static let storiesHissing: [MicroStoryTemplate] = [
        .init(templates: ["Жил-был маленький {w}.", "Он шумел и {w}.", "Друзья его любили."]),
        .init(templates: ["На поле гулял {w}.", "Рядом шуршал {w}.", "Солнце светило ярко."]),
        .init(templates: ["В домике жил {w}.", "Он пёк {w} для гостей.", "Все были счастливы."]),
        .init(templates: ["Маша нашла {w}.", "Дома у неё ждал {w}.", "Вечером был праздник."]),
        .init(templates: ["В лесу шуршал {w}.", "Потом прилетел {w}.", "Они играли вместе."])
    ]

    static let storiesSonorant: [MicroStoryTemplate] = [
        .init(templates: ["В речке жил {w}.", "Он дружил с {w}.", "Каждое утро пели песни."]),
        .init(templates: ["Рома нашёл {w}.", "Потом увидел {w}.", "Рома улыбнулся."]),
        .init(templates: ["На лугу рос {w}.", "Рядом сидел {w}.", "Они встречали рассвет."]),
        .init(templates: ["Рита любила {w}.", "Она рисовала {w}.", "Картина получилась красивой."]),
        .init(templates: ["Радуга привела {w}.", "За ней стоял {w}.", "Все радовались."])
    ]

    static let storiesVelar: [MicroStoryTemplate] = [
        .init(templates: ["Жил-был {w}.", "Он хотел {w}.", "Сказка закончилась хорошо."]),
        .init(templates: ["Кот поймал {w}.", "Рядом сидел {w}.", "Все были рады."]),
        .init(templates: ["В сказке был {w}.", "Герой искал {w}.", "И нашёл!"]),
        .init(templates: ["Коля купил {w}.", "Дома он увидел {w}.", "Мама похвалила."]),
        .init(templates: ["Гуси нашли {w}.", "Потом прилетел {w}.", "Лес ожил."])
    ]

    // 50 Russian encouragement phrases (25 correct + 25 try-again)

    static let encouragementCorrect: [String] = [
        "Отлично!", "Молодец, получилось!", "Вот это да!", "Супер!", "Прекрасно!",
        "Здорово сказал!", "Точно в цель!", "Чисто и ясно!", "Красиво звучит!", "Просто класс!",
        "Вот так и надо!", "Легко и чётко!", "Получилось!", "Именно так!", "Радую Лялю!",
        "Ух ты, как здорово!", "Ты растёшь!", "Это мой чемпион!", "Звук как по нотам!", "Светлый молодец!",
        "Звёздочка заслужена!", "Ты слышишь, как круто?", "Плюс балл!", "Настоящий мастер!", "Ты волшебник звука!"
    ]

    static let encouragementTryAgain: [String] = [
        "Почти-почти!", "Давай ещё разок!", "Ещё попробуй!", "Уже лучше, попробуем снова!",
        "Чуть-чуть не хватило!", "Повтори потихоньку.", "Сделай глубокий вдох и ещё раз.",
        "Медленно и чётко!", "Улыбнись и попробуй снова!", "Ты справишься, ещё разок!",
        "Ничего страшного — пробуем!", "Слушай меня и повторяй.", "Губки округли и скажи снова.",
        "Подними язычок и ещё раз.", "Вместе с Лялей — ещё!", "Спокойно, давай вместе!",
        "Это точно получится — ещё попытка!", "Помни: медленно и чётко.", "Сейчас выйдет!",
        "Я в тебя верю — пробуй ещё!", "Ещё одно дыхание и снова!", "Послушай образец и повтори.",
        "Немножко другой звук, попробуй ещё.", "Успокойся, расслабь плечи — и давай!",
        "Ты уже близко — ещё разок!"
    ]

    static let emojiPositive: [String] = ["✨", "⭐", "🌟", "🎉", "👏", "🏆", "🥇", "💫"]
    static let emojiGentle:   [String] = ["💪", "🌱", "🤗", "💖", "🙂", "🌈"]

    static let stickerPool: [String] = [
        "butterfly-01", "bear-01", "fox-01", "bunny-01", "hedgehog-01",
        "star-01", "heart-01", "crown-01", "rainbow-01", "moon-01"
    ]

    static let parentTips: [String] = [
        "Занимайтесь коротко — 5–7 минут, но ежедневно.",
        "Хвалите усилие, а не только результат.",
        "Произносите звук «{sound}» медленно и преувеличенно перед зеркалом.",
        "Играйте в «эхо» — повторяйте слова по очереди.",
        "Используйте песенки и считалочки со звуком «{sound}».",
        "Не исправляйте ребёнка резко — дайте второй пример.",
        "Перед сном делайте артикуляционную гимнастику 2 минуты.",
        "Если ребёнок устал — лучше закончить и вернуться завтра.",
        "Сделайте «день звука {sound}» — ищите слова вокруг дома.",
        "Читайте вслух книги с частым звуком «{sound}».",
        "Записывайте ребёнка на видео — он услышит сам себя.",
        "Делайте паузы — ребёнок нуждается в тишине для концентрации.",
        "Начинайте занятие с любимой игры — настройтесь позитивно.",
        "Подбадривайте: «Я слышу, как ты стараешься!».",
        "Не сравнивайте с другими детьми — только с его вчерашним «я»."
    ]
}
