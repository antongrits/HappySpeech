import Foundation

// MARK: - Sound Groups

/// The four main Russian sound families used in therapy.
public enum SoundFamily: String, CaseIterable, Codable, Sendable {
    case whistling  // Свистящие: С З Ц
    case hissing    // Шипящие:   Ш Ж Ч Щ
    case sonorant   // Сонорные:  Р Рь Л Ль
    case velar      // Заднеязычные: К Г Х

    public var displayName: String {
        switch self {
        case .whistling: return String(localized: "soundFamily.whistling")
        case .hissing:   return String(localized: "soundFamily.hissing")
        case .sonorant:  return String(localized: "soundFamily.sonorant")
        case .velar:     return String(localized: "soundFamily.velar")
        }
    }

    public var sounds: [String] {
        switch self {
        case .whistling: return ["С", "З", "Ц"]
        case .hissing:   return ["Ш", "Ж", "Ч", "Щ"]
        case .sonorant:  return ["Р", "Рь", "Л", "Ль"]
        case .velar:     return ["К", "Г", "Х"]
        }
    }

    /// Репрезентативный кириллический звук группы (первый в `sounds`):
    /// whistling→«С», hissing→«Ш», sonorant→«Р», velar→«К».
    public var primarySound: String {
        sounds.first ?? rawValue
    }

    /// Кириллический целевой звук для произвольной строки группы. Принимает
    /// rawValue (`"whistling"`…) или уже-кириллический звук. Для нераспознанной
    /// строки возвращает её как есть — единый helper для шаблонов упражнений
    /// (F1-016: запись исхода в `ReviewSchedulerService`).
    public static func cyrillicSound(forGroup group: String) -> String {
        if let family = SoundFamily(rawValue: group) { return family.primarySound }
        return group
    }
}

// MARK: - Correction Stage

/// The 10-stage correction ladder from Russian speech therapy methodology.
public enum CorrectionStage: String, CaseIterable, Codable, Sendable, Comparable {
    case prep       // 0. Подготовка артикуляции
    case isolated   // 1. Изолированный звук
    case syllable   // 2. Слоги
    case wordInit   // 3. Слово (начальная позиция)
    case wordMed    // 4. Слово (средняя позиция)
    case wordFinal  // 5. Слово (конечная позиция)
    case phrase     // 6. Словосочетание/фраза
    case sentence   // 7. Предложение
    case story      // 8. Рассказ
    case diff       // 9. Дифференциация

    public var displayName: String {
        switch self {
        case .prep:      return String(localized: "correctionStage.prep")
        case .isolated:  return String(localized: "correctionStage.isolated")
        case .syllable:  return String(localized: "correctionStage.syllable")
        case .wordInit:  return String(localized: "correctionStage.word")
        case .wordMed:   return String(localized: "correctionStage.word")
        case .wordFinal: return String(localized: "correctionStage.word")
        case .phrase:    return String(localized: "correctionStage.phrase")
        case .sentence:  return String(localized: "correctionStage.sentence")
        case .story:     return String(localized: "correctionStage.story")
        case .diff:      return String(localized: "correctionStage.diff")
        }
    }

    public var stageIndex: Int {
        switch self {
        case .prep:      return 0
        case .isolated:  return 1
        case .syllable:  return 2
        case .wordInit:  return 3
        case .wordMed:   return 4
        case .wordFinal: return 5
        case .phrase:    return 6
        case .sentence:  return 7
        case .story:     return 8
        case .diff:      return 9
        }
    }

    public static func < (lhs: CorrectionStage, rhs: CorrectionStage) -> Bool {
        lhs.stageIndex < rhs.stageIndex
    }

    /// Стадии, упорядоченные по `stageIndex` (детерминированный порядок лестницы).
    /// Исключает `.diff` — дифференциация не является линейным шагом откатной
    /// лестницы, она надстраивается над автоматизацией (см. speech-methodology).
    public static var ladder: [CorrectionStage] {
        [.prep, .isolated, .syllable, .wordInit, .wordMed, .wordFinal, .phrase, .sentence, .story]
    }

    /// Предыдущий этап лестницы (методический откат «на шаг назад»).
    ///
    /// Методическое правило (correction-stages): регресс на словах → откат к
    /// слогам, НЕ к изолированному звуку. Поэтому шаг — ровно один уровень вниз
    /// по `ladder`. `.prep` (нижний) и `.isolated` уже базовые — откат
    /// упирается в `.isolated`/`.prep`, ниже не опускаемся. Для `.diff`
    /// предыдущим считается `.story` (последняя линейная стадия).
    public var previous: CorrectionStage? {
        if self == .diff { return .story }
        guard let idx = Self.ladder.firstIndex(of: self), idx > 0 else { return nil }
        return Self.ladder[idx - 1]
    }
}

// MARK: - Template Types

/// The 17 game templates available in the lesson player.
public enum TemplateType: String, CaseIterable, Codable, Sendable {
    case listenAndChoose        = "listen-and-choose"
    case repeatAfterModel       = "repeat-after-model"
    case dragAndMatch           = "drag-and-match"
    case storyCompletion        = "story-completion"
    case puzzleReveal           = "puzzle-reveal"
    case sorting                = "sorting"
    case memory                 = "memory"
    case bingo                  = "bingo"
    case soundHunter            = "sound-hunter"
    case articulationImitation  = "articulation-imitation"
    case arActivity             = "ar-activity"
    case visualAcoustic         = "visual-acoustic"
    case breathing              = "breathing"
    case rhythm                 = "rhythm"
    case narrativeQuest         = "narrative-quest"
    case minimalPairs           = "minimal-pairs"
    /// Block K (v12): 17-й шаблон — поиск предметов через Vision + VNClassifyImageRequest.
    case objectHunt             = "object-hunt"
    /// Block Q (v12): 18-й шаблон — написание буквы PencilKit + Vision handwriting recognition.
    case letterTracing          = "letter-tracing"

    public var displayName: String {
        switch self {
        case .listenAndChoose:       return String(localized: "template.listenAndChoose")
        case .repeatAfterModel:      return String(localized: "template.repeatAfterModel")
        case .dragAndMatch:          return String(localized: "template.dragAndMatch")
        case .storyCompletion:       return String(localized: "template.storyCompletion")
        case .puzzleReveal:          return String(localized: "template.puzzleReveal")
        case .sorting:               return String(localized: "template.sorting")
        case .memory:                return String(localized: "template.memory")
        case .bingo:                 return String(localized: "template.bingo")
        case .soundHunter:           return String(localized: "template.soundHunter")
        case .articulationImitation: return String(localized: "template.articulationImitation")
        case .arActivity:            return String(localized: "template.arActivity")
        case .visualAcoustic:        return String(localized: "template.visualAcoustic")
        case .breathing:             return String(localized: "template.breathing")
        case .rhythm:                return String(localized: "template.rhythm")
        case .narrativeQuest:        return String(localized: "template.narrativeQuest")
        case .minimalPairs:          return String(localized: "template.minimalPairs")
        case .objectHunt:            return String(localized: "template.objectHunt")
        case .letterTracing:         return String(localized: "template.letterTracing")
        }
    }
}

// MARK: - User Roles

public enum UserRole: String, Codable, Sendable {
    case parent
    case specialist
    case child
}

// MARK: - Speech Disorder (F1-021)

/// Тип речевого нарушения, который родитель/логопед указывает при настройке
/// профиля ребёнка. Определяет акценты дневного маршрута в `AdaptivePlannerService`.
///
/// Методическое обоснование маршрутов — `wiki/concepts/speech-methodology.md`
/// (Филичёва/Чиркина, Левина, Лопатина, Ткаченко). Приложение работает только
/// с педагогически корректируемыми формами; при тяжёлых формах рекомендуется
/// очный логопед (см. ethical-boundaries).
public enum SpeechDisorder: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Дислалия — нарушение звукопроизношения при сохранном слухе. Базовый профиль.
    case dyslalia
    /// ФФН — фонетико-фонематическое недоразвитие (+ фонематический трек).
    case ffn
    /// ОНР III–IV — общее недоразвитие речи (4 параллельных трека).
    case onr
    /// ЗРР — задержка речевого развития (режим «медленного старта»).
    case zrr
    /// Заикание — нарушение плавности (дыхание/темп, без таймеров и соревнований).
    case stuttering
    /// Дизартрия (стёртая) — усиленная артикуляция + биообратная связь.
    case dysarthria

    public var id: String { rawValue }

    /// Профиль по умолчанию при отсутствии явного выбора.
    public static let `default`: SpeechDisorder = .dyslalia

    public var displayName: String {
        switch self {
        case .dyslalia:   return String(localized: "disorder.dyslalia.title")
        case .ffn:        return String(localized: "disorder.ffn.title")
        case .onr:        return String(localized: "disorder.onr.title")
        case .zrr:        return String(localized: "disorder.zrr.title")
        case .stuttering: return String(localized: "disorder.stuttering.title")
        case .dysarthria: return String(localized: "disorder.dysarthria.title")
        }
    }

    public var disorderDescription: String {
        switch self {
        case .dyslalia:   return String(localized: "disorder.dyslalia.desc")
        case .ffn:        return String(localized: "disorder.ffn.desc")
        case .onr:        return String(localized: "disorder.onr.desc")
        case .zrr:        return String(localized: "disorder.zrr.desc")
        case .stuttering: return String(localized: "disorder.stuttering.desc")
        case .dysarthria: return String(localized: "disorder.dysarthria.desc")
        }
    }

    public var systemImageName: String {
        switch self {
        case .dyslalia:   return "waveform"
        case .ffn:        return "ear"
        case .onr:        return "text.bubble"
        case .zrr:        return "tortoise"
        case .stuttering: return "wind"
        case .dysarthria: return "mouth"
        }
    }

    /// Цель плавности речи (заикание): глобально гасит таймеры/скороговорки/
    /// соревнования во всех играх (методический запрет, F1-024).
    public var hasFluencyGoal: Bool { self == .stuttering }

    /// Режим «медленного старта» (ЗРР): короткие сессии, акцент на вызов речи.
    public var isSlowStart: Bool { self == .zrr }
}

// MARK: - Route Track (F1-013 / F1-021)

/// Логопедический трек дневного маршрута. Используется планировщиком, чтобы
/// чередовать разные направления коррекции в одной сессии (особенно для ОНР).
public enum RouteTrack: String, Codable, Sendable, CaseIterable {
    /// Произношение: постановка/автоматизация звука (базовый трек).
    case sound
    /// Фонематика: дифференциация, фонемный анализ, минимальные пары.
    case phonemic
    /// Грамматика: словоизменение/словообразование/синтаксис.
    case grammar
    /// Связная речь: пересказ, рассказ, понимание.
    case coherentSpeech
    /// Дыхание/темп/плавность (заикание).
    case breathingFluency
    /// Артикуляционная гимнастика (дизартрия, подготовка).
    case articulation
}

// MARK: - Fatigue Level

public enum FatigueLevel: Int, Codable, Sendable {
    case fresh  = 0
    case normal = 1
    case tired  = 2
}

// MARK: - Score

/// Pronunciation score 0.0–1.0. -1 means not yet scored.
public struct PronunciationScore: Codable, Sendable, Equatable {
    public let value: Double

    public static let notScored = PronunciationScore(rawValue: -1)

    public init(rawValue: Double) {
        self.value = rawValue
    }

    public var isScored: Bool { value >= 0 }

    public var isCorrect: Bool { value >= 0.65 }

    public var tier: ScoreTier {
        switch value {
        case 0.85...:       return .excellent
        case 0.65..<0.85:  return .good
        case 0.40..<0.65:  return .improving
        default:           return .needsPractice
        }
    }

    public enum ScoreTier {
        case excellent, good, improving, needsPractice
    }
}

// MARK: - StreakCalculator

/// Единый источник правды для расчёта серии активных дней подряд.
///
/// Используется в ChildHomeInteractor, WorldMapInteractor и любых других местах,
/// где нужен стрик. Гарантирует идентичный алгоритм везде:
///   - «Активный день» — день, в который есть хотя бы одна сессия.
///   - Серия считается от сегодня или вчера назад подряд.
///   - Если ни сегодня, ни вчера не было практики — стрик 0.
public enum StreakCalculator {

    /// Считает trailing-run серию активных дней из списка сессий.
    /// - Parameters:
    ///   - sessions: список `SessionDTO` за произвольный период.
    ///   - calendar: календарь (по умолчанию `.current`).
    ///   - referenceDate: дата «сегодня» (параметр для тестируемости; по умолчанию `Date()`).
    /// - Returns: количество дней подряд с активностью, заканчивающихся сегодня или вчера.
    public static func activeDayStreak(
        in sessions: [SessionDTO],
        calendar: Calendar = .current,
        referenceDate: Date = Date()
    ) -> Int {
        let today = calendar.startOfDay(for: referenceDate)
        let activeDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        guard !activeDays.isEmpty else { return 0 }

        // Стартуем с сегодня; если сегодня не было — пробуем вчера.
        var cursor = today
        if !activeDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  activeDays.contains(yesterday) else {
                return 0
            }
            cursor = yesterday
        }
        var streak = 0
        while activeDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
