import Foundation

// MARK: - IPADictionary

/// Статический IPA-справочник для 49 фонем русского языка.
///
/// В отличие от ``RussianPhonemeInventory`` (плоский массив для индексации
/// в выходе `RussianPhonemeClassifier`), `IPADictionary` группирует фонемы по
/// артикуляционным признакам и предоставляет богатые метаданные:
/// - категория (гласный/согласный/аффрикат/сонорный)
/// - звонкость / глухость
/// - твёрдость / мягкость
/// - место и способ образования
/// - соответствующая русская графема (для UI-подсказок и G2P отладки)
///
/// ### Назначение
///
/// 1. **UI**: подписи к спектрограмме, фонемная карта в SpecialistReports.
/// 2. **G2P отладка**: вывод человеко-читаемых описаний при анализе.
/// 3. **Логопедическая методика**: фильтрация фонем по группам (свистящие /
///    шипящие / соноры / заднеязычные) для построения uроков.
/// 4. **Phonetic accuracy scoring**: контекстная оценка ошибок (замена `s` → `ʂ`
///    в той же группе шипящих менее серьёзная, чем `s` → `r`).
///
/// ### Совместимость с RussianPhonemeInventory
///
/// `IPADictionary.allIPA` ⊆ `RussianPhonemeInventory.all`. Любая фонема из
/// inventory может быть найдена через ``IPADictionary/info(for:)``.
///
/// ## See Also
/// - ``RussianPhonemeInventory`` (плоский inventory для CoreML output)
/// - ``RussianG2P`` (графема → фонема)
/// - ``Phoneme`` (модель фонемы для VIP)
public enum IPADictionary {

    // MARK: - PhonemeCategory

    /// Артикуляционная категория фонемы (для группировки в логопедических уроках).
    public enum PhonemeCategory: String, Sendable, CaseIterable {
        /// Гласные (ударные и безударные).
        case vowel
        /// Согласные смычные взрывные (б, п, д, т, г, к).
        case stop
        /// Согласные щелевые (в, ф, з, с, ж, ш, х).
        case fricative
        /// Аффрикаты (ц, ч, щ).
        case affricate
        /// Сонорные согласные (м, н, л, р, й).
        case sonorant
        /// Знаки твёрдости/мягкости (без своей фонемы).
        case sign
    }

    // MARK: - Voicing

    /// Звонкость фонемы.
    public enum Voicing: String, Sendable {
        /// Звонкая (с участием голосовых связок).
        case voiced
        /// Глухая (без участия голосовых связок).
        case voiceless
        /// Не применимо (гласные, сонорные с дефолтной звонкостью, знаки).
        case notApplicable
    }

    // MARK: - Hardness

    /// Твёрдость / мягкость согласного.
    public enum Hardness: String, Sendable {
        /// Твёрдый согласный.
        case hard
        /// Мягкий (палатализованный) согласный.
        case soft
        /// Всегда мягкий (ч, щ, й).
        case alwaysSoft
        /// Всегда твёрдый (ж, ш, ц).
        case alwaysHard
        /// Не применимо (гласные).
        case notApplicable
    }

    // MARK: - PhonemeInfo

    /// Метаданные одной фонемы.
    public struct PhonemeInfo: Sendable, Equatable, Hashable {
        /// IPA-символ фонемы (ключ).
        public let ipa: String
        /// Соответствующая русская графема (или комбинация для йотированных).
        public let cyrillic: String
        /// Артикуляционная категория.
        public let category: PhonemeCategory
        /// Звонкость.
        public let voicing: Voicing
        /// Твёрдость / мягкость.
        public let hardness: Hardness
        /// Логопедическая группа: "свистящие" / "шипящие" / "соноры" /
        /// "заднеязычные" / "губные" / "зубные" / "гласные ударные" /
        /// "гласные безударные" / "знаки".
        public let logopedicGroup: String
        /// Человеко-читаемое описание (для UI-подсказок).
        public let humanDescription: String

        public init(
            ipa: String,
            cyrillic: String,
            category: PhonemeCategory,
            voicing: Voicing,
            hardness: Hardness,
            logopedicGroup: String,
            humanDescription: String
        ) {
            self.ipa = ipa
            self.cyrillic = cyrillic
            self.category = category
            self.voicing = voicing
            self.hardness = hardness
            self.logopedicGroup = logopedicGroup
            self.humanDescription = humanDescription
        }
    }

    // MARK: - Inventory (49 phonemes)

    /// Полный inventory IPA-фонем русского с метаданными.
    ///
    /// Порядок и состав совпадают с ``RussianPhonemeInventory/all``
    /// (гарантия: каждый IPA из inventory имеет запись здесь).
    public static let inventory: [PhonemeInfo] = [
        // MARK: - Парные согласные звонкие/глухие (твёрдые)
        PhonemeInfo(
            ipa: "b", cyrillic: "б", category: .stop, voicing: .voiced,
            hardness: .hard, logopedicGroup: "губные",
            humanDescription: "Звонкий губно-губной взрывной, твёрдый"
        ),
        PhonemeInfo(
            ipa: "p", cyrillic: "п", category: .stop, voicing: .voiceless,
            hardness: .hard, logopedicGroup: "губные",
            humanDescription: "Глухой губно-губной взрывной, твёрдый"
        ),
        PhonemeInfo(
            ipa: "d", cyrillic: "д", category: .stop, voicing: .voiced,
            hardness: .hard, logopedicGroup: "зубные",
            humanDescription: "Звонкий зубной взрывной, твёрдый"
        ),
        PhonemeInfo(
            ipa: "t", cyrillic: "т", category: .stop, voicing: .voiceless,
            hardness: .hard, logopedicGroup: "зубные",
            humanDescription: "Глухой зубной взрывной, твёрдый"
        ),
        PhonemeInfo(
            ipa: "g", cyrillic: "г", category: .stop, voicing: .voiced,
            hardness: .hard, logopedicGroup: "заднеязычные",
            humanDescription: "Звонкий заднеязычный взрывной, твёрдый"
        ),
        PhonemeInfo(
            ipa: "k", cyrillic: "к", category: .stop, voicing: .voiceless,
            hardness: .hard, logopedicGroup: "заднеязычные",
            humanDescription: "Глухой заднеязычный взрывной, твёрдый"
        ),
        PhonemeInfo(
            ipa: "v", cyrillic: "в", category: .fricative, voicing: .voiced,
            hardness: .hard, logopedicGroup: "губные",
            humanDescription: "Звонкий губно-зубной щелевой, твёрдый"
        ),
        PhonemeInfo(
            ipa: "f", cyrillic: "ф", category: .fricative, voicing: .voiceless,
            hardness: .hard, logopedicGroup: "губные",
            humanDescription: "Глухой губно-зубной щелевой, твёрдый"
        ),
        PhonemeInfo(
            ipa: "z", cyrillic: "з", category: .fricative, voicing: .voiced,
            hardness: .hard, logopedicGroup: "свистящие",
            humanDescription: "Звонкий зубной свистящий, твёрдый"
        ),
        PhonemeInfo(
            ipa: "s", cyrillic: "с", category: .fricative, voicing: .voiceless,
            hardness: .hard, logopedicGroup: "свистящие",
            humanDescription: "Глухой зубной свистящий, твёрдый"
        ),

        // MARK: - Шипящие (всегда твёрдые/мягкие фиксированные)
        PhonemeInfo(
            ipa: "ʐ", cyrillic: "ж", category: .fricative, voicing: .voiced,
            hardness: .alwaysHard, logopedicGroup: "шипящие",
            humanDescription: "Звонкий нёбный шипящий, всегда твёрдый"
        ),
        PhonemeInfo(
            ipa: "ʂ", cyrillic: "ш", category: .fricative, voicing: .voiceless,
            hardness: .alwaysHard, logopedicGroup: "шипящие",
            humanDescription: "Глухой нёбный шипящий, всегда твёрдый"
        ),

        // MARK: - Аффрикаты и фрикативные
        PhonemeInfo(
            ipa: "ts", cyrillic: "ц", category: .affricate, voicing: .voiceless,
            hardness: .alwaysHard, logopedicGroup: "свистящие",
            humanDescription: "Глухая зубная аффриката, всегда твёрдая"
        ),
        PhonemeInfo(
            ipa: "tɕ", cyrillic: "ч", category: .affricate, voicing: .voiceless,
            hardness: .alwaysSoft, logopedicGroup: "шипящие",
            humanDescription: "Глухая нёбно-зубная аффриката, всегда мягкая"
        ),
        PhonemeInfo(
            ipa: "ɕː", cyrillic: "щ", category: .fricative, voicing: .voiceless,
            hardness: .alwaysSoft, logopedicGroup: "шипящие",
            humanDescription: "Глухой долгий нёбный шипящий, всегда мягкий"
        ),
        PhonemeInfo(
            ipa: "x", cyrillic: "х", category: .fricative, voicing: .voiceless,
            hardness: .hard, logopedicGroup: "заднеязычные",
            humanDescription: "Глухой заднеязычный щелевой, твёрдый"
        ),

        // MARK: - Сонорные (твёрдые)
        PhonemeInfo(
            ipa: "m", cyrillic: "м", category: .sonorant, voicing: .voiced,
            hardness: .hard, logopedicGroup: "соноры",
            humanDescription: "Губно-губной носовой сонорный, твёрдый"
        ),
        PhonemeInfo(
            ipa: "n", cyrillic: "н", category: .sonorant, voicing: .voiced,
            hardness: .hard, logopedicGroup: "соноры",
            humanDescription: "Зубной носовой сонорный, твёрдый"
        ),
        PhonemeInfo(
            ipa: "l", cyrillic: "л", category: .sonorant, voicing: .voiced,
            hardness: .hard, logopedicGroup: "соноры",
            humanDescription: "Боковой сонорный, твёрдый"
        ),
        PhonemeInfo(
            ipa: "r", cyrillic: "р", category: .sonorant, voicing: .voiced,
            hardness: .hard, logopedicGroup: "соноры",
            humanDescription: "Дрожащий сонорный, твёрдый"
        ),
        PhonemeInfo(
            ipa: "j", cyrillic: "й", category: .sonorant, voicing: .voiced,
            hardness: .alwaysSoft, logopedicGroup: "соноры",
            humanDescription: "Среднеязычный сонорный, всегда мягкий"
        ),

        // MARK: - Палатализованные согласные (мягкие пары)
        PhonemeInfo(
            ipa: "bʲ", cyrillic: "бь", category: .stop, voicing: .voiced,
            hardness: .soft, logopedicGroup: "губные",
            humanDescription: "Звонкий губно-губной взрывной, мягкий"
        ),
        PhonemeInfo(
            ipa: "pʲ", cyrillic: "пь", category: .stop, voicing: .voiceless,
            hardness: .soft, logopedicGroup: "губные",
            humanDescription: "Глухой губно-губной взрывной, мягкий"
        ),
        PhonemeInfo(
            ipa: "dʲ", cyrillic: "дь", category: .stop, voicing: .voiced,
            hardness: .soft, logopedicGroup: "зубные",
            humanDescription: "Звонкий зубной взрывной, мягкий"
        ),
        PhonemeInfo(
            ipa: "tʲ", cyrillic: "ть", category: .stop, voicing: .voiceless,
            hardness: .soft, logopedicGroup: "зубные",
            humanDescription: "Глухой зубной взрывной, мягкий"
        ),
        PhonemeInfo(
            ipa: "gʲ", cyrillic: "гь", category: .stop, voicing: .voiced,
            hardness: .soft, logopedicGroup: "заднеязычные",
            humanDescription: "Звонкий заднеязычный взрывной, мягкий"
        ),
        PhonemeInfo(
            ipa: "kʲ", cyrillic: "кь", category: .stop, voicing: .voiceless,
            hardness: .soft, logopedicGroup: "заднеязычные",
            humanDescription: "Глухой заднеязычный взрывной, мягкий"
        ),
        PhonemeInfo(
            ipa: "vʲ", cyrillic: "вь", category: .fricative, voicing: .voiced,
            hardness: .soft, logopedicGroup: "губные",
            humanDescription: "Звонкий губно-зубной щелевой, мягкий"
        ),
        PhonemeInfo(
            ipa: "fʲ", cyrillic: "фь", category: .fricative, voicing: .voiceless,
            hardness: .soft, logopedicGroup: "губные",
            humanDescription: "Глухой губно-зубной щелевой, мягкий"
        ),
        PhonemeInfo(
            ipa: "zʲ", cyrillic: "зь", category: .fricative, voicing: .voiced,
            hardness: .soft, logopedicGroup: "свистящие",
            humanDescription: "Звонкий зубной свистящий, мягкий"
        ),
        PhonemeInfo(
            ipa: "sʲ", cyrillic: "сь", category: .fricative, voicing: .voiceless,
            hardness: .soft, logopedicGroup: "свистящие",
            humanDescription: "Глухой зубной свистящий, мягкий"
        ),
        PhonemeInfo(
            ipa: "mʲ", cyrillic: "мь", category: .sonorant, voicing: .voiced,
            hardness: .soft, logopedicGroup: "соноры",
            humanDescription: "Губно-губной носовой сонорный, мягкий"
        ),
        PhonemeInfo(
            ipa: "nʲ", cyrillic: "нь", category: .sonorant, voicing: .voiced,
            hardness: .soft, logopedicGroup: "соноры",
            humanDescription: "Зубной носовой сонорный, мягкий"
        ),
        PhonemeInfo(
            ipa: "lʲ", cyrillic: "ль", category: .sonorant, voicing: .voiced,
            hardness: .soft, logopedicGroup: "соноры",
            humanDescription: "Боковой сонорный, мягкий"
        ),
        PhonemeInfo(
            ipa: "rʲ", cyrillic: "рь", category: .sonorant, voicing: .voiced,
            hardness: .soft, logopedicGroup: "соноры",
            humanDescription: "Дрожащий сонорный, мягкий"
        ),
        PhonemeInfo(
            ipa: "xʲ", cyrillic: "хь", category: .fricative, voicing: .voiceless,
            hardness: .soft, logopedicGroup: "заднеязычные",
            humanDescription: "Глухой заднеязычный щелевой, мягкий"
        ),

        // MARK: - Гласные ударные
        PhonemeInfo(
            ipa: "a", cyrillic: "а", category: .vowel, voicing: .notApplicable,
            hardness: .notApplicable, logopedicGroup: "гласные ударные",
            humanDescription: "Гласный нижнего подъёма, ударный"
        ),
        PhonemeInfo(
            ipa: "e", cyrillic: "е", category: .vowel, voicing: .notApplicable,
            hardness: .notApplicable, logopedicGroup: "гласные ударные",
            humanDescription: "Гласный среднего подъёма переднего ряда, ударный"
        ),
        PhonemeInfo(
            ipa: "i", cyrillic: "и", category: .vowel, voicing: .notApplicable,
            hardness: .notApplicable, logopedicGroup: "гласные ударные",
            humanDescription: "Гласный верхнего подъёма переднего ряда, ударный"
        ),
        PhonemeInfo(
            ipa: "o", cyrillic: "о", category: .vowel, voicing: .notApplicable,
            hardness: .notApplicable, logopedicGroup: "гласные ударные",
            humanDescription: "Гласный среднего подъёма заднего ряда, ударный"
        ),
        PhonemeInfo(
            ipa: "u", cyrillic: "у", category: .vowel, voicing: .notApplicable,
            hardness: .notApplicable, logopedicGroup: "гласные ударные",
            humanDescription: "Гласный верхнего подъёма заднего ряда, ударный"
        ),
        PhonemeInfo(
            ipa: "ɨ", cyrillic: "ы", category: .vowel, voicing: .notApplicable,
            hardness: .notApplicable, logopedicGroup: "гласные ударные",
            humanDescription: "Гласный верхнего подъёма среднего ряда, ударный"
        ),
        PhonemeInfo(
            ipa: "æ", cyrillic: "я (после мягкого)", category: .vowel,
            voicing: .notApplicable, hardness: .notApplicable,
            logopedicGroup: "гласные ударные",
            humanDescription: "Гласный нижнего подъёма переднего ряда, ударный"
        ),
        PhonemeInfo(
            ipa: "ɔ", cyrillic: "о (открытый)", category: .vowel,
            voicing: .notApplicable, hardness: .notApplicable,
            logopedicGroup: "гласные ударные",
            humanDescription: "Гласный среднего подъёма заднего ряда, открытый"
        ),
        PhonemeInfo(
            ipa: "ɛ", cyrillic: "э (открытый)", category: .vowel,
            voicing: .notApplicable, hardness: .notApplicable,
            logopedicGroup: "гласные ударные",
            humanDescription: "Гласный среднего подъёма переднего ряда, открытый"
        ),
        PhonemeInfo(
            ipa: "ɵ", cyrillic: "ё (огублённый)", category: .vowel,
            voicing: .notApplicable, hardness: .notApplicable,
            logopedicGroup: "гласные ударные",
            humanDescription: "Гласный среднего подъёма центрального ряда, огублённый"
        ),

        // MARK: - Гласные безударные (редуцированные)
        PhonemeInfo(
            ipa: "ə", cyrillic: "о/а (заударный)", category: .vowel,
            voicing: .notApplicable, hardness: .notApplicable,
            logopedicGroup: "гласные безударные",
            humanDescription: "Шва — заударная редукция о/а"
        ),
        PhonemeInfo(
            ipa: "ɪ", cyrillic: "и/е/я (безударный)", category: .vowel,
            voicing: .notApplicable, hardness: .notApplicable,
            logopedicGroup: "гласные безударные",
            humanDescription: "Безударная редукция и/е/я (ikan'e)"
        ),
        PhonemeInfo(
            ipa: "ʌ", cyrillic: "о/а (предударный)", category: .vowel,
            voicing: .notApplicable, hardness: .notApplicable,
            logopedicGroup: "гласные безударные",
            humanDescription: "Предударная редукция о/а (akan'e в первом слоге)"
        )
    ]

    // MARK: - Lookups

    /// Все IPA-символы в порядке inventory.
    public static let allIPA: [String] = inventory.map(\.ipa)

    /// Возвращает метаданные фонемы по IPA-символу.
    ///
    /// - Parameter ipa: IPA-символ (например, `"ʂ"`, `"sʲ"`, `"a"`).
    /// - Returns: ``PhonemeInfo`` или `nil`, если символ не найден.
    public static func info(for ipa: String) -> PhonemeInfo? {
        inventory.first { $0.ipa == ipa }
    }

    /// Все фонемы в указанной логопедической группе.
    ///
    /// - Parameter group: название группы (например, `"шипящие"`, `"свистящие"`).
    /// - Returns: список фонем, принадлежащих группе.
    public static func phonemes(in group: String) -> [PhonemeInfo] {
        inventory.filter { $0.logopedicGroup == group }
    }

    /// Все фонемы заданной артикуляционной категории.
    public static func phonemes(in category: PhonemeCategory) -> [PhonemeInfo] {
        inventory.filter { $0.category == category }
    }

    /// Все логопедические группы (для UI выбора).
    public static let allGroups: [String] = [
        "свистящие", "шипящие", "соноры", "заднеязычные",
        "губные", "зубные", "гласные ударные", "гласные безударные"
    ]

    // MARK: - Articulation Distance (для phonetic accuracy)

    /// Артикуляционное расстояние между двумя фонемами в `[0, 1]`.
    ///
    /// 0.0 — идентичны, 1.0 — максимально различны.
    /// Используется для contextually-aware scoring: замена в той же группе
    /// (`s` → `ʂ`) штрафуется меньше, чем замена через категории (`s` → `r`).
    ///
    /// ### Алгоритм
    ///
    /// - 0.0 — фонемы совпадают.
    /// - 0.25 — одна и та же фонема разной мягкости (`s` ↔ `sʲ`).
    /// - 0.4 — разные фонемы той же логопедической группы.
    /// - 0.7 — разные фонемы той же категории (vowel/stop/fricative...).
    /// - 1.0 — разные категории.
    public static func articulationDistance(_ a: String, _ b: String) -> Double {
        guard a != b else { return 0.0 }
        guard let ai = info(for: a), let bi = info(for: b) else { return 1.0 }

        // Одна и та же базовая фонема разной мягкости
        let aBase = a.replacingOccurrences(of: "ʲ", with: "")
        let bBase = b.replacingOccurrences(of: "ʲ", with: "")
        if aBase == bBase {
            return 0.25
        }

        if ai.logopedicGroup == bi.logopedicGroup {
            return 0.4
        }
        if ai.category == bi.category {
            return 0.7
        }
        return 1.0
    }
}
