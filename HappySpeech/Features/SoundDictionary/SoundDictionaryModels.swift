import Foundation

// MARK: - SoundDictionaryModels (Clean Swift: Models)
//
// Block AE v21 — интерактивная энциклопедия 42 фонем русского языка.
//
// Сущности фичи:
//   • PhonemeGroup — группировка фонем по логопедической классификации
//   • PhonemeEntry — одна фонема: IPA + Cyrillic + пример слова + audio
//   • Request/Response/ViewModel — VIP контракты
//
// Persistence: read-only (статический корпус 42 фонем).
// COPPA: всё on-device, no networking.

// MARK: - PhonemeGroup

/// Логопедическая группа звуков. Цвет/иконка совпадают с group-coding
/// из основного контента приложения.
public enum PhonemeGroup: String, CaseIterable, Sendable, Equatable {
    case vowels         // гласные а, о, у, э, и, ы
    case whistling      // свистящие с, з, ц + мягкие
    case hissing        // шипящие ш, ж, ч, щ
    case sonants        // соноры р, рь, л, ль
    case velar          // заднеязычные к, г, х + мягкие
    case nasal          // носовые м, мь, н, нь
    case labial         // губные б, п, в, ф + мягкие
    case dental         // переднеязычные т, д
    case glide          // йот й

    public var titleKey: String {
        switch self {
        case .vowels:    return "soundDictionary.group.vowels"
        case .whistling: return "soundDictionary.group.whistling"
        case .hissing:   return "soundDictionary.group.hissing"
        case .sonants:   return "soundDictionary.group.sonants"
        case .velar:     return "soundDictionary.group.velar"
        case .nasal:     return "soundDictionary.group.nasal"
        case .labial:    return "soundDictionary.group.labial"
        case .dental:    return "soundDictionary.group.dental"
        case .glide:     return "soundDictionary.group.glide"
        }
    }

    public var symbolName: String {
        switch self {
        case .vowels:    return "mouth.fill"
        case .whistling: return "wind"
        case .hissing:   return "flame"
        case .sonants:   return "waveform.path"
        case .velar:     return "circle.dashed"
        case .nasal:     return "nose"
        case .labial:    return "lips"
        case .dental:    return "rectangle.dashed"
        case .glide:     return "arrow.up.and.down"
        }
    }
}

// MARK: - PhonemeEntry

/// Одна фонема — то, что показывается в карточке и в детальном sheet.
public struct PhonemeEntry: Identifiable, Sendable, Equatable, Hashable {
    public let id: String
    public let cyrillic: String           // «С», «Ш», «Р»
    public let ipa: String                // «s», «ʂ», «r»
    public let group: PhonemeGroup
    public let exampleWord: String        // «солнце»
    public let exampleSyllable: String    // «са»
    public let articulationNoteKey: String // localization key для описания артикуляции
    public let audioResourceName: String? // имя .m4a в Resources/Audio/Content/Phonemic, без расширения

    public init(
        id: String,
        cyrillic: String,
        ipa: String,
        group: PhonemeGroup,
        exampleWord: String,
        exampleSyllable: String,
        articulationNoteKey: String,
        audioResourceName: String? = nil
    ) {
        self.id = id
        self.cyrillic = cyrillic
        self.ipa = ipa
        self.group = group
        self.exampleWord = exampleWord
        self.exampleSyllable = exampleSyllable
        self.articulationNoteKey = articulationNoteKey
        self.audioResourceName = audioResourceName
    }
}

// MARK: - SoundDictionaryModels namespace

enum SoundDictionaryModels {

    // MARK: Load

    enum Load {
        struct Request: Sendable {}

        struct Response: Sendable {
            let entries: [PhonemeEntry]
        }

        struct ViewModel: Sendable {
            let sections: [SectionViewModel]
            let totalCount: Int
            let totalCountLabel: String   // «42 звука русского языка»
        }

        struct SectionViewModel: Identifiable, Sendable {
            let id: String                  // PhonemeGroup.rawValue
            let groupTitle: String
            let groupSymbol: String
            let groupAccessibilityLabel: String
            let cells: [CellViewModel]
        }

        struct CellViewModel: Identifiable, Sendable, Equatable {
            let id: String                  // phoneme id
            let cyrillic: String
            let ipa: String                 // «[s]»
            let exampleSyllable: String
            let accessibilityLabel: String
        }
    }

    // MARK: SelectPhoneme

    enum SelectPhoneme {
        struct Request: Sendable {
            let phonemeId: String
        }

        struct Response: Sendable {
            let entry: PhonemeEntry
            let hasAudio: Bool
        }

        struct ViewModel: Sendable {
            let title: String               // «С» (cyrillic)
            let ipaLabel: String            // «[s]»
            let groupTitle: String
            let exampleWord: String
            let articulationNote: String
            let hasAudio: Bool
            let practiceCtaLabel: String    // «Поупражняться»
            let playAudioLabel: String      // «Прослушать»
        }
    }

    // MARK: PlayAudio

    enum PlayAudio {
        struct Request: Sendable {
            let phonemeId: String
        }

        struct Response: Sendable {
            let success: Bool
            let usedFallbackTTS: Bool
        }

        struct ViewModel: Sendable {
            let toastMessage: String?
        }
    }

    // MARK: PracticePhoneme

    enum PracticePhoneme {
        struct Request: Sendable {
            let phonemeId: String
        }

        struct Response: Sendable {
            let phonemeId: String
        }

        struct ViewModel: Sendable {
            let phonemeId: String
        }
    }
}

// MARK: - PhonemeCorpus

/// Статический корпус 42 фонем русского языка.
///
/// Источник: ``RussianPhonemeInventory`` + фильтр на «детский» набор
/// (только базовые позиции, без сложных аллофонов).
public enum PhonemeCorpus {

    /// Полный корпус — 42 фонемы, упорядочены по группам.
    public static let all: [PhonemeEntry] = [
        // MARK: Гласные (6)
        .init(id: "vow-a", cyrillic: "А", ipa: "a", group: .vowels,
              exampleWord: "автобус", exampleSyllable: "ам",
              articulationNoteKey: "soundDictionary.phoneme.vow-a.articulation"),
        .init(id: "vow-o", cyrillic: "О", ipa: "o", group: .vowels,
              exampleWord: "облако", exampleSyllable: "ом",
              articulationNoteKey: "soundDictionary.phoneme.vow-o.articulation"),
        .init(id: "vow-u", cyrillic: "У", ipa: "u", group: .vowels,
              exampleWord: "утка", exampleSyllable: "ум",
              articulationNoteKey: "soundDictionary.phoneme.vow-u.articulation"),
        .init(id: "vow-e", cyrillic: "Э", ipa: "ɛ", group: .vowels,
              exampleWord: "это", exampleSyllable: "эх",
              articulationNoteKey: "soundDictionary.phoneme.vow-e.articulation"),
        .init(id: "vow-i", cyrillic: "И", ipa: "i", group: .vowels,
              exampleWord: "игра", exampleSyllable: "ил",
              articulationNoteKey: "soundDictionary.phoneme.vow-i.articulation"),
        .init(id: "vow-y", cyrillic: "Ы", ipa: "ɨ", group: .vowels,
              exampleWord: "мышь", exampleSyllable: "ыс",
              articulationNoteKey: "soundDictionary.phoneme.vow-y.articulation"),

        // MARK: Свистящие (5)
        .init(id: "wh-s", cyrillic: "С", ipa: "s", group: .whistling,
              exampleWord: "солнце", exampleSyllable: "са",
              articulationNoteKey: "soundDictionary.phoneme.wh-s.articulation",
              audioResourceName: "phon-fs-0"),
        .init(id: "wh-s-soft", cyrillic: "Сь", ipa: "sʲ", group: .whistling,
              exampleWord: "сирень", exampleSyllable: "си",
              articulationNoteKey: "soundDictionary.phoneme.wh-s-soft.articulation",
              audioResourceName: "phon-fs-1"),
        .init(id: "wh-z", cyrillic: "З", ipa: "z", group: .whistling,
              exampleWord: "звезда", exampleSyllable: "за",
              articulationNoteKey: "soundDictionary.phoneme.wh-z.articulation",
              audioResourceName: "phon-fs-2"),
        .init(id: "wh-z-soft", cyrillic: "Зь", ipa: "zʲ", group: .whistling,
              exampleWord: "земля", exampleSyllable: "зи",
              articulationNoteKey: "soundDictionary.phoneme.wh-z-soft.articulation",
              audioResourceName: "phon-fs-3"),
        .init(id: "wh-ts", cyrillic: "Ц", ipa: "ts", group: .whistling,
              exampleWord: "цапля", exampleSyllable: "ца",
              articulationNoteKey: "soundDictionary.phoneme.wh-ts.articulation",
              audioResourceName: "phon-fs-4"),

        // MARK: Шипящие (4)
        .init(id: "hs-sh", cyrillic: "Ш", ipa: "ʂ", group: .hissing,
              exampleWord: "шапка", exampleSyllable: "ша",
              articulationNoteKey: "soundDictionary.phoneme.hs-sh.articulation",
              audioResourceName: "phon-hs-0"),
        .init(id: "hs-zh", cyrillic: "Ж", ipa: "ʐ", group: .hissing,
              exampleWord: "жираф", exampleSyllable: "жа",
              articulationNoteKey: "soundDictionary.phoneme.hs-zh.articulation",
              audioResourceName: "phon-hs-1"),
        .init(id: "hs-ch", cyrillic: "Ч", ipa: "tɕ", group: .hissing,
              exampleWord: "чашка", exampleSyllable: "ча",
              articulationNoteKey: "soundDictionary.phoneme.hs-ch.articulation",
              audioResourceName: "phon-hs-2"),
        .init(id: "hs-shch", cyrillic: "Щ", ipa: "ɕː", group: .hissing,
              exampleWord: "щётка", exampleSyllable: "ща",
              articulationNoteKey: "soundDictionary.phoneme.hs-shch.articulation",
              audioResourceName: "phon-hs-3"),

        // MARK: Соноры (4)
        .init(id: "son-r", cyrillic: "Р", ipa: "r", group: .sonants,
              exampleWord: "рыба", exampleSyllable: "ра",
              articulationNoteKey: "soundDictionary.phoneme.son-r.articulation"),
        .init(id: "son-r-soft", cyrillic: "Рь", ipa: "rʲ", group: .sonants,
              exampleWord: "река", exampleSyllable: "ри",
              articulationNoteKey: "soundDictionary.phoneme.son-r-soft.articulation"),
        .init(id: "son-l", cyrillic: "Л", ipa: "l", group: .sonants,
              exampleWord: "лампа", exampleSyllable: "ла",
              articulationNoteKey: "soundDictionary.phoneme.son-l.articulation"),
        .init(id: "son-l-soft", cyrillic: "Ль", ipa: "lʲ", group: .sonants,
              exampleWord: "лимон", exampleSyllable: "ли",
              articulationNoteKey: "soundDictionary.phoneme.son-l-soft.articulation"),

        // MARK: Заднеязычные (6)
        .init(id: "vel-k", cyrillic: "К", ipa: "k", group: .velar,
              exampleWord: "кошка", exampleSyllable: "ка",
              articulationNoteKey: "soundDictionary.phoneme.vel-k.articulation"),
        .init(id: "vel-k-soft", cyrillic: "Кь", ipa: "kʲ", group: .velar,
              exampleWord: "кисель", exampleSyllable: "ки",
              articulationNoteKey: "soundDictionary.phoneme.vel-k-soft.articulation"),
        .init(id: "vel-g", cyrillic: "Г", ipa: "ɡ", group: .velar,
              exampleWord: "гора", exampleSyllable: "га",
              articulationNoteKey: "soundDictionary.phoneme.vel-g.articulation"),
        .init(id: "vel-g-soft", cyrillic: "Гь", ipa: "ɡʲ", group: .velar,
              exampleWord: "гитара", exampleSyllable: "ги",
              articulationNoteKey: "soundDictionary.phoneme.vel-g-soft.articulation"),
        .init(id: "vel-h", cyrillic: "Х", ipa: "x", group: .velar,
              exampleWord: "хлеб", exampleSyllable: "ха",
              articulationNoteKey: "soundDictionary.phoneme.vel-h.articulation"),
        .init(id: "vel-h-soft", cyrillic: "Хь", ipa: "xʲ", group: .velar,
              exampleWord: "хитрый", exampleSyllable: "хи",
              articulationNoteKey: "soundDictionary.phoneme.vel-h-soft.articulation"),

        // MARK: Носовые (4)
        .init(id: "nas-m", cyrillic: "М", ipa: "m", group: .nasal,
              exampleWord: "мама", exampleSyllable: "ма",
              articulationNoteKey: "soundDictionary.phoneme.nas-m.articulation"),
        .init(id: "nas-m-soft", cyrillic: "Мь", ipa: "mʲ", group: .nasal,
              exampleWord: "мишка", exampleSyllable: "ми",
              articulationNoteKey: "soundDictionary.phoneme.nas-m-soft.articulation"),
        .init(id: "nas-n", cyrillic: "Н", ipa: "n", group: .nasal,
              exampleWord: "ночь", exampleSyllable: "на",
              articulationNoteKey: "soundDictionary.phoneme.nas-n.articulation"),
        .init(id: "nas-n-soft", cyrillic: "Нь", ipa: "nʲ", group: .nasal,
              exampleWord: "няня", exampleSyllable: "ня",
              articulationNoteKey: "soundDictionary.phoneme.nas-n-soft.articulation"),

        // MARK: Губные (8)
        .init(id: "lab-b", cyrillic: "Б", ipa: "b", group: .labial,
              exampleWord: "банан", exampleSyllable: "ба",
              articulationNoteKey: "soundDictionary.phoneme.lab-b.articulation"),
        .init(id: "lab-b-soft", cyrillic: "Бь", ipa: "bʲ", group: .labial,
              exampleWord: "белка", exampleSyllable: "би",
              articulationNoteKey: "soundDictionary.phoneme.lab-b-soft.articulation"),
        .init(id: "lab-p", cyrillic: "П", ipa: "p", group: .labial,
              exampleWord: "папа", exampleSyllable: "па",
              articulationNoteKey: "soundDictionary.phoneme.lab-p.articulation"),
        .init(id: "lab-p-soft", cyrillic: "Пь", ipa: "pʲ", group: .labial,
              exampleWord: "пирог", exampleSyllable: "пи",
              articulationNoteKey: "soundDictionary.phoneme.lab-p-soft.articulation"),
        .init(id: "lab-v", cyrillic: "В", ipa: "v", group: .labial,
              exampleWord: "ваза", exampleSyllable: "ва",
              articulationNoteKey: "soundDictionary.phoneme.lab-v.articulation"),
        .init(id: "lab-v-soft", cyrillic: "Вь", ipa: "vʲ", group: .labial,
              exampleWord: "ветер", exampleSyllable: "ви",
              articulationNoteKey: "soundDictionary.phoneme.lab-v-soft.articulation"),
        .init(id: "lab-f", cyrillic: "Ф", ipa: "f", group: .labial,
              exampleWord: "фонарь", exampleSyllable: "фа",
              articulationNoteKey: "soundDictionary.phoneme.lab-f.articulation"),
        .init(id: "lab-f-soft", cyrillic: "Фь", ipa: "fʲ", group: .labial,
              exampleWord: "филин", exampleSyllable: "фи",
              articulationNoteKey: "soundDictionary.phoneme.lab-f-soft.articulation"),

        // MARK: Переднеязычные (4)
        .init(id: "den-t", cyrillic: "Т", ipa: "t", group: .dental,
              exampleWord: "тыква", exampleSyllable: "та",
              articulationNoteKey: "soundDictionary.phoneme.den-t.articulation"),
        .init(id: "den-t-soft", cyrillic: "Ть", ipa: "tʲ", group: .dental,
              exampleWord: "тигр", exampleSyllable: "ти",
              articulationNoteKey: "soundDictionary.phoneme.den-t-soft.articulation"),
        .init(id: "den-d", cyrillic: "Д", ipa: "d", group: .dental,
              exampleWord: "дом", exampleSyllable: "да",
              articulationNoteKey: "soundDictionary.phoneme.den-d.articulation"),
        .init(id: "den-d-soft", cyrillic: "Дь", ipa: "dʲ", group: .dental,
              exampleWord: "дятел", exampleSyllable: "дя",
              articulationNoteKey: "soundDictionary.phoneme.den-d-soft.articulation"),

        // MARK: Йот (1)
        .init(id: "gli-j", cyrillic: "Й", ipa: "j", group: .glide,
              exampleWord: "йогурт", exampleSyllable: "йа",
              articulationNoteKey: "soundDictionary.phoneme.gli-j.articulation")
    ]

    public static func entry(forId id: String) -> PhonemeEntry? {
        all.first { $0.id == id }
    }

    public static func entries(in group: PhonemeGroup) -> [PhonemeEntry] {
        all.filter { $0.group == group }
    }
}
