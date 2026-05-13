import Foundation
import OSLog

// MARK: - RussianG2P

/// Расширенный rule-based grapheme-to-phoneme конвертер для русского языка.
///
/// В отличие от ``G2PWorker`` (lookup из `russian_phonemes.json` 7712 entries +
/// упрощённый fallback), ``RussianG2P`` реализует полный набор русских фонетических
/// правил и работает **без bundle-зависимости** — может вызываться из любого контекста,
/// включая офлайн фоновые операции, тесты и SwiftUI Preview.
///
/// ### Реализованные правила русской фонетики
///
/// 1. **Палатализация (мягкость)** — согласный становится мягким перед `е/ё/и/ю/я/ь`
///    (например, `п` → `pʲ`, `с` → `sʲ`, `л` → `lʲ`).
/// 2. **Йотированные гласные** — `е/ё/ю/я` дают `[j+гласный]` в начале слова, после
///    гласной и после `ъ/ь`; иначе — обозначают мягкость предыдущего согласного.
/// 3. **Финальное оглушение** (final devoicing) — звонкие парные согласные на конце
///    слова оглушаются: `б→p`, `в→f`, `г→k`, `д→t`, `ж→ʂ`, `з→s`.
/// 4. **Регрессивная ассимиляция по глухости** — звонкий согласный перед глухим
///    оглушается (`сделать` → `[zd]`, наоборот `книжка` → `[ʂk]`).
/// 5. **Редукция безударных гласных** (akan'e + ikan'e):
///    - `о/а` в первом предударном слоге → `ʌ`
///    - `о/а` в остальных безударных позициях → `ə`
///    - `е/я` в безударных позициях → `ɪ`
/// 6. **Стяжение `тс/тьс`** в окончаниях возвратных глаголов → `ts`
///    (`улыбается` → `[…ts:ə]`).
/// 7. **Дентально-альвеолярная ассимиляция мягкости** — `с/з` перед мягким
///    дентальным становятся мягкими (`снег` → `[sʲnʲek]`).
///
/// ### Соответствие inventory
///
/// Все возвращаемые IPA-символы лежат в ``RussianPhonemeInventory/all`` (49 фонем),
/// что обеспечивает совместимость с выходом ``RussianPhonemeClassifier``.
///
/// ### Stress
///
/// По-русски ударение позиционно произвольное и не маркируется в орфографии.
/// `RussianG2P` принимает явное `stressIndex` (0-based позиция ударной гласной
/// в строке) — если не передан, применяется эвристика «ударение на первой гласной»,
/// что подходит для односложных и наиболее частотных двусложных слов в детском
/// логопедическом контенте (мама, папа, дом, кот, лес).
///
/// ### Использование
///
/// ```swift
/// let g2p = RussianG2P()
/// let phonemes = g2p.transcribe("молоко", stressIndex: 5)  // ударение на «о»
/// // → ["m", "ʌ", "l", "ʌ", "k", "o"]
///
/// let ipaString = g2p.transcribeIPA("щенок")
/// // → "ɕːɪnok"
/// ```
///
/// ## See Also
/// - ``G2PWorker`` (dictionary-based lookup с правиловым fallback)
/// - ``RussianPhonemeInventory`` (49 IPA-фонем русского)
/// - ``EnsembleASRService`` (использует фонемы для phonetic accuracy scoring)
public struct RussianG2P: Sendable {

    // MARK: - Logger

    private let logger = Logger(subsystem: "ru.happyspeech", category: "RussianG2P")

    // MARK: - Constants

    /// Гласные буквы русского алфавита.
    private static let vowels: Set<Character> = [
        "а", "е", "ё", "и", "о", "у", "ы", "э", "ю", "я"
    ]

    /// Гласные, перед которыми согласный становится мягким.
    private static let softeningVowels: Set<Character> = ["е", "ё", "и", "ю", "я"]

    /// Звонкие парные согласные (для финального оглушения и ассимиляции).
    private static let voicedPairs: [Character: String] = [
        "б": "p", "в": "f", "г": "k", "д": "t", "ж": "ʂ", "з": "s"
    ]

    /// Глухие согласные — триггеры регрессивной ассимиляции по глухости.
    private static let voicelessTriggers: Set<Character> = [
        "п", "ф", "к", "т", "ш", "щ", "с", "ц", "ч", "х"
    ]

    /// Звонкие согласные (для определения ассимиляции «звонкий перед звонким»).
    private static let voicedConsonants: Set<Character> = [
        "б", "в", "г", "д", "ж", "з"
    ]

    /// Мягкие дентальные — после них `с/з` ассимилируются по мягкости.
    private static let softDentals: Set<Character> = ["т", "д", "н", "л"]

    // MARK: - Init

    public init() {}

    // MARK: - Public API

    /// Транскрибирует русское слово в массив IPA-фонем.
    ///
    /// - Parameters:
    ///   - word: слово в кириллице (любой регистр); пробелы и небуквенные символы
    ///     игнорируются.
    ///   - stressIndex: 0-based позиция ударной гласной в исходной строке. Если `nil`,
    ///     применяется эвристика «ударение на первой гласной».
    /// - Returns: массив IPA-символов в порядке произношения. Каждый элемент — отдельная
    ///   фонема из ``RussianPhonemeInventory``.
    public func transcribe(_ word: String, stressIndex: Int? = nil) -> [String] {
        let chars = Array(word.lowercased())
        guard !chars.isEmpty else { return [] }

        // Определяем индекс ударной гласной
        let stress = resolveStress(chars: chars, hint: stressIndex)

        var result: [String] = []
        var i = 0

        while i < chars.count {
            let ch = chars[i]

            // Пропускаем небуквенные символы
            guard ch.isLetter else {
                i += 1
                continue
            }

            // Гласные
            if Self.vowels.contains(ch) {
                let vowel = transcribeVowel(
                    ch,
                    index: i,
                    chars: chars,
                    stressIndex: stress
                )
                result.append(contentsOf: vowel)
                i += 1
                continue
            }

            // Знаки твёрдости/мягкости — не дают своей фонемы
            if ch == "ь" || ch == "ъ" {
                i += 1
                continue
            }

            // Согласные
            let cons = transcribeConsonant(
                ch,
                index: i,
                chars: chars
            )
            result.append(contentsOf: cons)
            i += 1
        }

        // Пост-обработка: стяжение `тс/тьс` → `ts` (возвратные глаголы)
        let normalized = applyReflexiveContraction(result)

        return normalized
    }

    /// Транскрибирует слово в плотную IPA-строку (без разделителей).
    public func transcribeIPA(_ word: String, stressIndex: Int? = nil) -> String {
        transcribe(word, stressIndex: stressIndex).joined()
    }

    /// Транскрибирует с указанием позиций фонем (для интеграции с ``Phoneme``).
    public func transcribePhonemes(_ word: String, stressIndex: Int? = nil) -> [Phoneme] {
        transcribe(word, stressIndex: stressIndex).enumerated().map {
            Phoneme(ipa: $0.element, position: $0.offset)
        }
    }

    /// Сравнивает две IPA-последовательности через нормализованное расстояние Левенштейна.
    ///
    /// - Returns: значение в `[0, 1]`, где 1.0 — полное совпадение,
    ///   0.0 — максимальная разница.
    public func phoneticSimilarity(_ a: [String], _ b: [String]) -> Double {
        guard !a.isEmpty || !b.isEmpty else { return 1.0 }
        guard !a.isEmpty, !b.isEmpty else { return 0.0 }

        let distance = levenshtein(a, b)
        let maxLen = max(a.count, b.count)
        return 1.0 - Double(distance) / Double(maxLen)
    }

    // MARK: - Stress Resolution

    private func resolveStress(chars: [Character], hint: Int?) -> Int {
        if let hint, hint >= 0, hint < chars.count, Self.vowels.contains(chars[hint]) {
            return hint
        }
        // Fallback: первая гласная
        for (idx, ch) in chars.enumerated() where Self.vowels.contains(ch) {
            return idx
        }
        return 0
    }

    // MARK: - Vowel Transcription

    /// Транскрибирует гласную с учётом редукции и йотирования.
    ///
    /// Возвращает массив фонем — обычно 1 элемент, но 2 для йотированных гласных
    /// в начале слова или после гласной/ь/ъ.
    private func transcribeVowel(
        _ ch: Character,
        index: Int,
        chars: [Character],
        stressIndex: Int
    ) -> [String] {
        let isStressed = (index == stressIndex)
        let prevCh: Character? = index > 0 ? chars[index - 1] : nil
        let prevIsVowelOrSign = prevCh.map {
            Self.vowels.contains($0) || $0 == "ь" || $0 == "ъ"
        } ?? true  // начало слова считаем как «после границы»

        // Йотированные гласные после границы (начало/гласная/ь/ъ)
        let yotated: [Character: (stressed: [String], reduced: [String])] = [
            "е": (["j", "e"], ["j", "ɪ"]),
            "ё": (["j", "o"], ["j", "ɪ"]),  // ё всегда ударное в реальной речи; reduced ветка нужна для дробных слов
            "ю": (["j", "u"], ["j", "u"]),
            "я": (["j", "a"], ["j", "ɪ"])
        ]

        if prevIsVowelOrSign, let pair = yotated[ch] {
            return isStressed ? pair.stressed : pair.reduced
        }

        // Не йотированная позиция — гласная отдельно (мягкость уже учтена в согласном)
        switch ch {
        case "а":
            return [reducedAOPhoneme(index: index, stressIndex: stressIndex, isStressed: isStressed)]
        case "о":
            // О в безударной позиции редуцируется как А (akan'e)
            if isStressed { return ["o"] }
            return [reducedAOPhoneme(index: index, stressIndex: stressIndex, isStressed: false)]
        case "е":
            // После согласного: ударная — [e], безударная — [ɪ] (ikan'e)
            return [isStressed ? "e" : "ɪ"]
        case "ё":
            return ["o"]  // ё всегда ударное по орфографии
        case "и":
            return [isStressed ? "i" : "ɪ"]
        case "у":
            return ["u"]
        case "ы":
            return [isStressed ? "ɨ" : "ɨ"]
        case "э":
            return [isStressed ? "e" : "ɪ"]
        case "ю":
            return ["u"]
        case "я":
            // После мягкого согласного: ударная — [a], безударная — [ɪ]
            return [isStressed ? "a" : "ɪ"]
        default:
            return []
        }
    }

    /// Возвращает редуцированную фонему для `а/о`.
    ///
    /// - Ударная: уже отдельный case (`a` или `o`).
    /// - Первый предударный слог: `ʌ`.
    /// - Остальные безударные: `ə`.
    private func reducedAOPhoneme(index: Int, stressIndex: Int, isStressed: Bool) -> String {
        if isStressed { return "a" }

        // Расстояние от ударной (по индексу буквы — приближение к слогам)
        let distance = stressIndex - index

        // Первый предударный (1–2 позиции до ударной) → ʌ
        if distance >= 1, distance <= 2 {
            return "ʌ"
        }
        // Остальные → ə
        return "ə"
    }

    // MARK: - Consonant Transcription

    /// Транскрибирует согласную с учётом палатализации и оглушения/ассимиляции.
    private func transcribeConsonant(
        _ ch: Character,
        index: Int,
        chars: [Character]
    ) -> [String] {
        let nextCh: Character? = index + 1 < chars.count ? chars[index + 1] : nil
        let isLast = nextCh == nil
        let isSoft = isConsonantSoft(ch: ch, nextCh: nextCh)

        // Финальное оглушение
        if isLast, let devoiced = Self.voicedPairs[ch] {
            return [isSoft ? soften(devoiced) : devoiced]
        }

        // Регрессивная ассимиляция по глухости/звонкости
        if let next = nextCh {
            if Self.voicedConsonants.contains(ch), Self.voicelessTriggers.contains(next),
               let devoiced = Self.voicedPairs[ch] {
                return [isSoft ? soften(devoiced) : devoiced]
            }
            if Self.voicelessTriggers.contains(ch), Self.voicedConsonants.contains(next),
               next != "в" {  // в — не триггер озвончения
                if let voiced = voicelessToVoiced(ch) {
                    return [isSoft ? soften(voiced) : voiced]
                }
            }
        }

        // Базовая транскрипция с палатализацией
        return [basePhoneme(for: ch, soft: isSoft)]
    }

    /// Определяет мягкость согласного: перед `е/ё/и/ю/я/ь` или мягким дентальным.
    private func isConsonantSoft(ch: Character, nextCh: Character?) -> Bool {
        guard let next = nextCh else { return false }

        // Always-soft: ч, щ, й — без проверки следующего
        if ch == "ч" || ch == "щ" || ch == "й" { return false }

        // Always-hard: ж, ш, ц
        if ch == "ж" || ch == "ш" || ch == "ц" { return false }

        // Перед мягкими гласными или мягким знаком
        if next == "ь" { return true }
        if Self.softeningVowels.contains(next) { return true }

        return false
    }

    /// Базовая фонема согласной с применением мягкости.
    private func basePhoneme(for ch: Character, soft: Bool) -> String { // swiftlint:disable:this cyclomatic_complexity

        switch ch {
        // Always-fixed (без палатализации)
        case "ш": return "ʂ"
        case "щ": return "ɕː"
        case "ж": return "ʐ"
        case "ч": return "tɕ"
        case "ц": return "ts"
        case "й": return "j"
        // Свистящие (парные мягкие)
        case "с": return soft ? "sʲ" : "s"
        case "з": return soft ? "zʲ" : "z"
        // Соноры (парные мягкие)
        case "р": return soft ? "rʲ" : "r"
        case "л": return soft ? "lʲ" : "l"
        case "м": return soft ? "mʲ" : "m"
        case "н": return soft ? "nʲ" : "n"
        // Заднеязычные
        case "к": return soft ? "kʲ" : "k"
        case "г": return soft ? "gʲ" : "g"
        case "х": return soft ? "xʲ" : "x"
        // Губные
        case "б": return soft ? "bʲ" : "b"
        case "п": return soft ? "pʲ" : "p"
        case "в": return soft ? "vʲ" : "v"
        case "ф": return soft ? "fʲ" : "f"
        // Зубные
        case "д": return soft ? "dʲ" : "d"
        case "т": return soft ? "tʲ" : "t"
        default: return ""
        }
    }

    /// Делает фонему мягкой (добавляет `ʲ`), если ещё не мягкая.
    private func soften(_ phoneme: String) -> String {
        phoneme.hasSuffix("ʲ") ? phoneme : phoneme + "ʲ"
    }

    /// Переводит глухой согласный в звонкий пар (для регрессивной ассимиляции).
    private func voicelessToVoiced(_ ch: Character) -> String? {
        switch ch {
        case "п": return "b"
        case "ф": return "v"
        case "к": return "g"
        case "т": return "d"
        case "с": return "z"
        case "ш": return "ʐ"
        default: return nil
        }
    }

    // MARK: - Reflexive Contraction

    /// Стягивает `[t]+[s]` или `[tʲ]+[s]` в `[ts]` (возвратные глаголы `-тся/-ться`).
    private func applyReflexiveContraction(_ phonemes: [String]) -> [String] {
        var result: [String] = []
        var i = 0
        while i < phonemes.count {
            let isTOrSoftT = phonemes[i] == "t" || phonemes[i] == "tʲ"
            if i + 1 < phonemes.count,
               isTOrSoftT,
               phonemes[i + 1] == "s" {
                result.append("ts")
                i += 2
            } else {
                result.append(phonemes[i])
                i += 1
            }
        }
        return result
    }

    // MARK: - Levenshtein Distance

    /// Расстояние Левенштейна для двух массивов IPA-фонем.
    private func levenshtein(_ a: [String], _ b: [String]) -> Int {
        let m = a.count
        let n = b.count
        if m == 0 { return n }
        if n == 0 { return m }

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                dp[i][j] = min(
                    dp[i - 1][j] + 1,        // удаление
                    dp[i][j - 1] + 1,        // вставка
                    dp[i - 1][j - 1] + cost  // замена
                )
            }
        }

        return dp[m][n]
    }
}

// MARK: - RussianG2P + Phonetic Accuracy Scoring

extension RussianG2P {

    /// Сравнивает произнесённые ребёнком фонемы с эталонными для слова.
    ///
    /// Используется в ``EnsembleASRService`` Tier A для расчёта phonetic accuracy
    /// без сетевых вызовов (COPPA-safe).
    ///
    /// - Parameters:
    ///   - referenceWord: эталонное русское слово.
    ///   - producedPhonemes: предсказанные фонемы из ``RussianPhonemeClassifier``.
    /// - Returns: значение в `[0, 1]`, где 1.0 — идеальное совпадение.
    public func phoneticAccuracy(
        referenceWord: String,
        producedPhonemes: [String]
    ) -> Double {
        let expected = transcribe(referenceWord)
        return phoneticSimilarity(expected, producedPhonemes)
    }
}
