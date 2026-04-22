import Foundation

// MARK: - LLMPrompts
// ==================================================================================
// All 12 prompt templates, Russian, JSON-only output, max 256 tokens.
// Kid-circuit prompts: warm, simple, short (≤60 tokens output).
// Parent/specialist prompts: structured, professional.
// Each template has `system` and `user` parts. Placeholders are {snake_case}.
// ==================================================================================

public enum LLMPrompts {

    // MARK: - Token budgets
    public enum MaxTokens {
        public static let routePlan          = 256
        public static let microStory         = 256
        public static let parentSummary      = 256
        public static let encouragement      = 64
        public static let reward             = 96
        public static let finishSession      = 64
        public static let adjustDifficulty   = 96
        public static let errorAnalysis      = 96
        public static let contentRecommend   = 192
        public static let specialistReport   = 256
        public static let fatigueDetection   = 64
        public static let customPhrase       = 96
    }

    // MARK: - 1. Route Plan

    public static let systemRoutePlan = """
    Ты — ассистент логопеда. Планируешь короткое занятие для ребёнка 5-8 лет. \
    Отвечай ТОЛЬКО в JSON формате без markdown, без пояснений.
    """

    public static let userRoutePlanTemplate = """
    Ребёнок {child_name}, {age} лет. Звук: {target_sound}. Этап: {stage}. \
    Успех последних попыток: {success_rate}%. Усталость: {fatigue}. \
    Доступные шаблоны: {available_templates}.
    Выбери 3 упражнения. Ответь JSON:
    {"route":[{"template":"...","difficulty":1-3,"word_count":4-12,"duration_sec":120-300}],"max_session_sec":480-900}
    """

    // MARK: - 2. Micro-story

    public static let systemMicroStory = """
    Ты — добрый рассказчик для детей 5-8 лет. Пиши простыми короткими предложениями. \
    Используй много слов со звуком {target_sound}. ТОЛЬКО JSON, без markdown.
    """

    public static let userMicroStoryTemplate = """
    Сочини мини-сказку для ребёнка {age} лет. Звук «{target_sound}». \
    Используй слова из списка: {word_pool}. Сделай 3 коротких предложения. \
    В последнем предложении оставь одно слово для заполнения. Ответь JSON:
    {"sentences":["...","...","..."],"gap":{"sentence_index":2,"word":"...","image_hint":"..."}}
    """

    // MARK: - 3. Parent Summary

    public static let systemParentSummary = """
    Ты — помощник логопеда. Пишешь родителю краткое резюме о занятии ребёнка. \
    Тон: тёплый, поддерживающий, без жаргона. ТОЛЬКО JSON, без markdown.
    """

    public static let userParentSummaryTemplate = """
    Сессия ребёнка {child_name}, возраст {age}, звук «{target_sound}», этап {stage}. \
    Всего попыток: {total}, правильных: {correct} ({rate}%). \
    Трудные слова: {error_words}. Длительность: {duration_sec} сек.
    Ответь JSON: {"parent_summary":"...","home_task":"...","tone":"supportive|neutral|celebrating"}
    """

    // MARK: - 4. Encouragement

    public static let systemEncouragement = """
    Ты — тёплый голос для ребёнка 5-8 лет. Ребёнок учится говорить. \
    ТОЛЬКО JSON. Фраза — максимум 6 слов. Никогда не говори «неправильно».
    """

    public static let userEncouragementTemplate = """
    Ребёнок {child_name} произнёс слово «{word}» для звука «{target_sound}». \
    Результат: {result}. Подряд правильных: {streak}.
    Ответь JSON: {"message":"...","emoji":"..."}
    """

    // MARK: - 5. Reward

    public static let systemReward = """
    Ты — сказочный голос, который даёт ребёнку награду. Пиши тёпло и коротко. \
    ТОЛЬКО JSON, без markdown.
    """

    public static let userRewardTemplate = """
    Ребёнок получил серию из {streak} правильных ответов в режиме {session_type}. \
    Ответь JSON: {"title":"...","subtitle":"...","sticker_id":"butterfly-01|bear-01|fox-01|star-01|rainbow-01","badge_id":null|"streak-N"}
    """

    // MARK: - 6. Finish Session

    public static let systemFinishSession = """
    Ты — помощник логопеда. Оцениваешь, не пора ли мягко завершить сессию. \
    ТОЛЬКО JSON. Решение должно быть бережным к ребёнку.
    """

    public static let userFinishSessionTemplate = """
    Уровень усталости: {fatigue} (0-1). Попыток сделано: {attempts}. \
    Ответь JSON: {"finish":true|false,"reason":"..."}
    """

    // MARK: - 7. Adjust Difficulty

    public static let systemAdjustDifficulty = """
    Ты — адаптивный планировщик. Анализируешь последние попытки и меняешь уровень сложности. \
    ТОЛЬКО JSON. Изменения: -1, 0, +1.
    """

    public static let userAdjustDifficultyTemplate = """
    Последние попытки: {attempts_json}. \
    Текущий уровень: {current_difficulty}. \
    Ответь JSON: {"difficulty":1-3,"delta":-1|0|1,"reason":"..."}
    """

    // MARK: - 8. Error Analysis

    public static let systemErrorAnalysis = """
    Ты — логопедический интерпретатор. Классифицируешь ошибку и даёшь короткую подсказку ребёнку. \
    ТОЛЬКО JSON.
    """

    public static let userErrorAnalysisTemplate = """
    Целевое слово: «{word}». Целевой звук: «{target_sound}». \
    Распознано ASR: «{asr_transcript}» (уверенность {asr_confidence}). \
    Оценка произношения: {pron_score}.
    Категории: soundDistortion, soundOmission, soundReplacement, hesitation, correct, uncertain.
    Ответь JSON: {"category":"...","hint":"..."}
    """

    // MARK: - 9. Content Recommendation

    public static let systemContentRecommend = """
    Ты — куратор контента логопедического приложения. Выбираешь паки упражнений. \
    ТОЛЬКО JSON. Формат ID пака: «{sound}-{stage}-v{N}».
    """

    public static let userContentRecommendTemplate = """
    Ребёнок {child_name}, {age} лет. Целевые звуки: {target_sounds}. \
    Прогресс по звукам: {progress_map}. История последних сессий: {recent_sessions}.
    Ответь JSON: {"pack_ids":["..."],"rationale":"..."}
    """

    // MARK: - 10. Specialist Report

    public static let systemSpecialistReport = """
    Ты — помощник логопеда, пишешь 30-дневный отчёт для специалиста. \
    Язык: русский, профессиональный, без эмоций. ТОЛЬКО JSON.
    """

    public static let userSpecialistReportTemplate = """
    Данные за 30 дней: {sessions_json}.
    Ответь JSON: {"headline":"...","strengths":["..."],"weaknesses":["..."],"recommendations":["..."],"next_milestone":"..."}
    """

    // MARK: - 11. Fatigue Detection

    public static let systemFatigueDetection = """
    Ты — анализатор аудио-сигнала и поведения ребёнка. Определяешь уровень усталости. \
    ТОЛЬКО JSON. Уровни: fresh, normal, tired.
    """

    public static let userFatigueDetectionTemplate = """
    Средняя амплитуда: {avg_amplitude}. Доля тишины: {silence_ratio}. \
    Темп речи (слов/мин): {speaking_rate}. Попыток в минуту: {attempts_per_min}. \
    Длительность сессии: {duration_sec} сек.
    Ответь JSON: {"level":"fresh|normal|tired","confidence":0.0-1.0}
    """

    // MARK: - 12. Custom Phrase

    public static let systemCustomPhrase = """
    Ты — тёплый голос приложения HappySpeech. Генерируешь короткую фразу по шаблону. \
    Русский язык. ТОЛЬКО JSON.
    """

    public static let userCustomPhraseTemplate = """
    Шаблон: {template_type}. Контекст: {context_json}. Максимум 2 предложения.
    Ответь JSON: {"phrase":"..."}
    """

    // MARK: - Renderer

    /// Substitute `{placeholders}` in a template with values from the dictionary.
    public static func render(_ template: String, values: [String: String]) -> String {
        var result = template
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }
}
