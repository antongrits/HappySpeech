import Foundation

// MARK: - Domain Types

/// Unique identifier wrapper — prevents mixing different entity IDs.
public struct EntityID<T>: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String = UUID().uuidString) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

// MARK: - Type Aliases

public typealias ChildID      = EntityID<ChildProfileTag>
public typealias SessionID    = EntityID<SessionTag>
public typealias AttemptID    = EntityID<AttemptTag>
public typealias ContentPackID = EntityID<ContentPackTag>
public typealias SpecialistID = EntityID<SpecialistTag>

// Phantom types for type-safe IDs
public enum ChildProfileTag {}
public enum SessionTag {}
public enum AttemptTag {}
public enum ContentPackTag {}
public enum SpecialistTag {}

// MARK: - Sound Groups

/// The four main Russian sound families used in therapy.
public enum SoundFamily: String, CaseIterable, Codable, Sendable {
    case whistling  = "whistling"   // Свистящие: С З Ц
    case hissing    = "hissing"     // Шипящие:   Ш Ж Ч Щ
    case sonorant   = "sonorant"    // Сонорные:  Р Рь Л Ль
    case velar      = "velar"       // Заднеязычные: К Г Х

    public var displayName: String {
        switch self {
        case .whistling: return "Свистящие"
        case .hissing:   return "Шипящие"
        case .sonorant:  return "Сонорные"
        case .velar:     return "Заднеязычные"
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
}

// MARK: - Correction Stage

/// The 10-stage correction ladder from Russian speech therapy methodology.
public enum CorrectionStage: String, CaseIterable, Codable, Sendable, Comparable {
    case prep       = "prep"        // 0. Подготовка артикуляции
    case isolated   = "isolated"    // 1. Изолированный звук
    case syllable   = "syllable"    // 2. Слоги
    case wordInit   = "wordInit"    // 3. Слово (начальная позиция)
    case wordMed    = "wordMed"     // 4. Слово (средняя позиция)
    case wordFinal  = "wordFinal"   // 5. Слово (конечная позиция)
    case phrase     = "phrase"      // 6. Словосочетание/фраза
    case sentence   = "sentence"    // 7. Предложение
    case story      = "story"       // 8. Рассказ
    case diff       = "diff"        // 9. Дифференциация

    public var displayName: String {
        switch self {
        case .prep:      return "Артикуляция"
        case .isolated:  return "Звук"
        case .syllable:  return "Слоги"
        case .wordInit:  return "Слова"
        case .wordMed:   return "Слова"
        case .wordFinal: return "Слова"
        case .phrase:    return "Фразы"
        case .sentence:  return "Предложения"
        case .story:     return "Рассказ"
        case .diff:      return "Различение"
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
}

// MARK: - Template Types

/// The 16 game templates available in the lesson player.
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

    public var displayName: String {
        switch self {
        case .listenAndChoose:       return "Слушай и выбирай"
        case .repeatAfterModel:      return "Повторяй за мной"
        case .dragAndMatch:          return "Перетащи и совмести"
        case .storyCompletion:       return "Закончи историю"
        case .puzzleReveal:          return "Собери пазл"
        case .sorting:               return "Разложи по группам"
        case .memory:                return "Запомни пары"
        case .bingo:                 return "Лото"
        case .soundHunter:           return "Охотник за звуком"
        case .articulationImitation: return "Повтори движение"
        case .arActivity:            return "AR-зеркало"
        case .visualAcoustic:        return "Вижу звук"
        case .breathing:             return "Дышим правильно"
        case .rhythm:                return "Ритм речи"
        case .narrativeQuest:        return "Сказка"
        case .minimalPairs:          return "Похожие звуки"
        }
    }
}

// MARK: - User Roles

public enum UserRole: String, Codable, Sendable {
    case parent     = "parent"
    case specialist = "specialist"
    case child      = "child"
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
