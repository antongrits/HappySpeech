import Foundation

// MARK: - AlignmentVocabMap

/// Соответствие IPA-фонем из ``RussianG2P``/``IPADictionary`` и 37-классного
/// словаря модели ``Wav2Vec2RuChild`` (``Wav2Vec2Vocabulary``).
///
/// ## Структура словаря (37 классов)
/// ```
/// idx  symbol   примечание
///  0   <pad>    CTC blank token
///  1   <s>      BOS (не используется в alignment)
///  2   </s>     EOS (не используется в alignment)
///  3   <unk>    unknown
///  4   |        word boundary
///  5   а        гласная А
///  6   б        согласная Б
///  7   в        согласная В
///  8   г        согласная Г
///  9   д        согласная Д
/// 10   е        гласная Е (включая Ё)
/// 11   ж        согласная Ж
/// 12   з        согласная З
/// 13   и        гласная И
/// 14   й        согласная Й
/// 15   к        согласная К
/// 16   л        согласная Л
/// 17   м        согласная М
/// 18   н        согласная Н
/// 19   о        гласная О
/// 20   п        согласная П
/// 21   р        согласная Р
/// 22   с        согласная С
/// 23   т        согласная Т
/// 24   у        гласная У
/// 25   ф        согласная Ф
/// 26   х        согласная Х
/// 27   ц        согласная Ц
/// 28   ч        согласная Ч
/// 29   ш        согласная Ш
/// 30   щ        согласная Щ
/// 31   ъ        твёрдый знак
/// 32   ы        гласная Ы
/// 33   ь        мягкий знак
/// 34   э        гласная Э
/// 35   ю        гласная Ю
/// 36   я        гласная Я
/// ```
///
/// ## Принципы маппинга IPA → vocab-id
/// Модель работает на УРОВНЕ БУКВ КИРИЛЛИЦЫ, а не на уровне фонем IPA.
/// Поэтому маппинг — это однозначное соответствие IPA-фонемы → наиболее близкой
/// кириллической буквы в словаре:
///
/// - Палатализованные согласные (rʲ, lʲ, sʲ, ...) → базовая буква (р, л, с...).
///   Мягкость в Wav2Vec2 РУССКОМ словаре не разграничивается явно — мягкий знак
///   идёт отдельным токеном. Для alignment'а достаточно базовой буквы.
/// - Редуцированные гласные (ʌ, ə, ɪ, ɵ, æ, ɔ, ɛ) → ближайший звук по позиции
///   (о/а → о; ɪ/æ → и; ɵ/ɛ/ɔ → е; ʌ → а).
/// - Сложные IPA (tɕ → ч; ɕː → щ; ʂ → ш; ʐ → ж; ts → ц) → однозначная буква.
/// - Фонемы, не поддерживаемые словарём (j — йотирующий перед гласной, семивокал):
///   j маппируется в й (index 14). Это приближение: /j/ в начале слова перед
///   гласной, строго говоря, — не та же позиция, что буква «й». Для forced
///   alignment'а уроков, где слова содержат й как отдельный звук (яма, ёж, юг),
///   это допустимое приближение.
///
/// ## Unsupported
/// Фонемы ``unsupportedIPAs`` не имеют однозначного кириллического аналога в
/// словаре и маппируются в `nil`. При получении `nil` вызывающий код должен
/// либо пропустить фонему, либо заменить её «ближайшей» по `articulationDistance`.
///
/// ## Честные границы
/// Маппинг покрывает все фонемы из ``RussianPhonemeInventory`` (49 IPA-символов).
/// Мягкие пары маппируются в твёрдый аналог — это потеря информации о мягкости,
/// которая в 37-классном словаре частично восстанавливается по позиции мягкого знака.
/// Для слов детского логопедического контента (короткие, без экзотических кластеров)
/// точность вычисленных спанов достаточна для GOP-диагностики.
public enum AlignmentVocabMap {

    // MARK: - IPA → Vocab-ID

    /// Возвращает vocab-id (индекс в ``Wav2Vec2Vocabulary``) для IPA-символа.
    ///
    /// - Returns: vocab-id [0, 36] или nil если фонема явно не поддерживается.
    public static func vocabId(for ipa: String) -> Int? {
        guard let cyrillic = ipaToCyrillic[ipa] else { return nil }
        return Wav2Vec2Vocabulary.index(of: cyrillic)
    }

    /// Конвертирует массив IPA-фонем в vocab-id, пропуская неподдерживаемые.
    ///
    /// - Parameter phonemes: массив IPA-символов (из ``RussianG2P/transcribe(_:)``)
    /// - Returns: массив vocab-id только для поддерживаемых фонем.
    public static func vocabIds(for phonemes: [String]) -> [Int] {
        phonemes.compactMap { vocabId(for: $0) }
    }

    /// Возвращает IPA-символ по vocab-id.
    ///
    /// Используется при обратном маппинге: competitor vocab-id → IPA для передачи
    /// в ``ChildSpeechScoringPolicy/isDevelopmentalSubstitution(target:produced:)``.
    ///
    /// Поскольку маппинг не биективен (несколько IPA → одна буква), возвращается
    /// «каноническая» твёрдая форма: например, vocab-id "р" → "r" (не "rʲ").
    public static func canonicalIPA(forVocabId id: Int) -> String? {
        guard let cyrillic = Wav2Vec2Vocabulary.symbol(at: id) else { return nil }
        return cyrillicToCanonicalIPA[cyrillic]
    }

    // MARK: - IPA-символы без прямого vocab-аналога

    /// Набор IPA-символов, не имеющих однозначного кириллического аналога
    /// в 37-классном словаре Wav2Vec2RuChild.
    ///
    /// При встрече этих символов в эталонной последовательности alignment
    /// их следует пропускать или заменять ближайшей фонемой.
    public static let unsupportedIPAs: Set<String> = [
        // Редуцированная шва — нет отдельного символа в словаре,
        // при alignment'е заменяем на «о» (index 19).
        // (Оставлена в таблице как приближение, не в unsupported.)
    ]

    // MARK: - Маппинг IPA → кириллица (37 классов)
    //
    // Каждый IPA-символ из RussianPhonemeInventory (49 фонем) + G2P-output
    // однозначно маппируется в одну кириллическую букву словаря.
    //
    // Порядок: согласные твёрдые → мягкие пары → аффрикаты → гласные → редуцированные.
    private static let ipaToCyrillic: [String: String] = [

        // MARK: Согласные твёрдые
        "b":  "б",     // voiced bilabial stop
        "p":  "п",     // voiceless bilabial stop
        "d":  "д",     // voiced dental stop
        "t":  "т",     // voiceless dental stop
        "g":  "г",     // voiced velar stop
        "k":  "к",     // voiceless velar stop
        "v":  "в",     // voiced labiodental fricative
        "f":  "ф",     // voiceless labiodental fricative
        "z":  "з",     // voiced dental fricative (whistling)
        "s":  "с",     // voiceless dental fricative (whistling)
        "ʐ":  "ж",     // voiced palatal fricative (hissing) — Ж
        "ʂ":  "ш",     // voiceless palatal fricative (hissing) — Ш
        "x":  "х",     // voiceless velar fricative
        "m":  "м",     // bilabial nasal sonorant
        "n":  "н",     // dental nasal sonorant
        "l":  "л",     // lateral sonorant
        "r":  "р",     // trill sonorant
        "j":  "й",     // palatal approximant / semivowel

        // MARK: Аффрикаты и долгие шипящие
        "ts": "ц",     // voiceless dental affricate — Ц
        "tɕ": "ч",     // voiceless palatal affricate — Ч
        "ɕː": "щ",     // voiceless long palatal fricative — Щ

        // MARK: Мягкие пары (палатализованные) → базовая буква
        // Wav2Vec2 37-классный словарь не имеет отдельных символов для мягких пар.
        // Мягкость кодируется позицией мягкого знака (ь) в тексте.
        // Для forced alignment достаточно базовой буквы.
        "bʲ": "б",
        "pʲ": "п",
        "dʲ": "д",
        "tʲ": "т",
        "gʲ": "г",
        "kʲ": "к",
        "vʲ": "в",
        "fʲ": "ф",
        "zʲ": "з",
        "sʲ": "с",
        "xʲ": "х",
        "mʲ": "м",
        "nʲ": "н",
        "lʲ": "л",
        "rʲ": "р",

        // MARK: Гласные ударные
        "a":  "а",     // open low vowel
        "e":  "е",     // mid front vowel (включает Ё по словарю)
        "i":  "и",     // high front vowel
        "o":  "о",     // mid back vowel
        "u":  "у",     // high back vowel
        "ɨ":  "ы",     // high central vowel

        // MARK: Редуцированные гласные → ближайший символ
        // ʌ (предударная редукция о/а, akan'e) → а (семантически ближе к «а»)
        "ʌ":  "а",
        // ə (шва, заударная редукция) → о (нейтральный средний гласный)
        "ə":  "о",
        // ɪ (безударная редукция е/и/я) → и
        "ɪ":  "и",
        // æ (гласная нижнего подъёма переднего ряда, «я» после мягкого) → я
        "æ":  "я",
        // ɔ (открытый о) → о
        "ɔ":  "о",
        // ɛ (открытый э) → е
        "ɛ":  "е",
        // ɵ (огублённый ё) → е (словарь Ё кодирует через «е», index 10)
        "ɵ":  "е"
    ]

    // MARK: Обратный маппинг: кириллическая буква → канонический IPA (твёрдая форма)
    //
    // Используется для декодирования competitor vocab-id обратно в IPA,
    // чтобы сравнить с ChildSpeechScoringPolicy.developmentalSubstitutions.
    private static let cyrillicToCanonicalIPA: [String: String] = [
        "а": "a",
        "б": "b",
        "в": "v",
        "г": "g",
        "д": "d",
        "е": "e",
        "ж": "ʐ",
        "з": "z",
        "и": "i",
        "й": "j",
        "к": "k",
        "л": "l",
        "м": "m",
        "н": "n",
        "о": "o",
        "п": "p",
        "р": "r",
        "с": "s",
        "т": "t",
        "у": "u",
        "ф": "f",
        "х": "x",
        "ц": "ts",
        "ч": "tɕ",
        "ш": "ʂ",
        "щ": "ɕː",
        "ы": "ɨ",
        "э": "e",
        "ю": "u",
        "я": "a"
        // ъ, ь, <pad>, <s>, </s>, <unk>, | — не IPA-фонемы, не включены.
    ]
}

// MARK: - AlignmentVocabMap + Coverage

extension AlignmentVocabMap {

    /// Проверяет, что каждый IPA-символ из ``RussianPhonemeInventory`` либо
    /// маппируется в vocab-id, либо явно перечислен в ``unsupportedIPAs``.
    ///
    /// Используется в юнит-тестах для гарантии полноты покрытия.
    /// Возвращает список IPA без покрытия (должен быть пустым).
    public static func uncoveredIPAs() -> [String] {
        let allIPA = RussianPhonemeInventory.all
        return allIPA.filter { ipa in
            !unsupportedIPAs.contains(ipa) && vocabId(for: ipa) == nil
        }
    }
}
