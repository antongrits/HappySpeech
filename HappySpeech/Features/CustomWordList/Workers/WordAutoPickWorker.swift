import Foundation
import OSLog

// MARK: - WordPosition

/// Позиция целевого звука в слове (логопедическая классификация).
public enum WordPosition: String, Sendable, CaseIterable, Codable, Identifiable {
    case initial  = "initial"   // звук в начале слова (первая фонема)
    case medial   = "medial"    // звук в середине слова
    case ending   = "final"     // звук в конце слова (последняя фонема)
    case any      = "any"       // любая позиция

    public var id: String { rawValue }

    /// Название позиции на русском.
    var localizedKey: String {
        switch self {
        case .initial: return "customWordList.autoPick.position.initial"
        case .medial:  return "customWordList.autoPick.position.medial"
        case .ending:  return "customWordList.autoPick.position.final"
        case .any:     return "customWordList.autoPick.position.any"
        }
    }
}

// MARK: - SyllableRange

/// Диапазон сложности по числу слогов.
public enum SyllableRange: String, Sendable, CaseIterable, Codable, Identifiable {
    case oneTwo   = "1-2"   // 1–2 слога (для 5–6 лет)
    case twoThree = "2-3"   // 2–3 слога (6–7 лет)
    case threePlus = "3+"   // 3 и более (7–8 лет)
    case all      = "all"   // любое число слогов

    public var id: String { rawValue }

    var localizedKey: String {
        switch self {
        case .oneTwo:    return "customWordList.autoPick.syllables.oneTwo"
        case .twoThree:  return "customWordList.autoPick.syllables.twoThree"
        case .threePlus: return "customWordList.autoPick.syllables.threePlus"
        case .all:       return "customWordList.autoPick.syllables.all"
        }
    }

    func matches(_ count: Int) -> Bool {
        switch self {
        case .oneTwo:    return count >= 1 && count <= 2
        case .twoThree:  return count >= 2 && count <= 3
        case .threePlus: return count >= 3
        case .all:       return true
        }
    }
}

// MARK: - AutoPickParams

/// Параметры автоматического подбора слов специалистом.
public struct AutoPickParams: Sendable, Equatable {
    public var targetSound: String
    public var position: WordPosition
    public var syllableRange: SyllableRange
    public var requestedCount: Int

    public init(
        targetSound: String = "Р",
        position: WordPosition = .any,
        syllableRange: SyllableRange = .all,
        requestedCount: Int = 10
    ) {
        self.targetSound = targetSound
        self.position = position
        self.syllableRange = syllableRange
        self.requestedCount = requestedCount
    }
}

// MARK: - AutoPickResult

/// Результат автоподбора: список найденных слов и кол-во кандидатов в базе.
public struct AutoPickResult: Sendable, Equatable {
    /// Итоговый список слов (≤ requestedCount).
    public let words: [String]
    /// Всего слов-кандидатов до применения лимита.
    public let totalCandidates: Int
}

// MARK: - WordAutoPickWorkerProtocol

@MainActor
protocol WordAutoPickWorkerProtocol {
    func pick(params: AutoPickParams) -> AutoPickResult
}

// MARK: - WordAutoPickWorker

/// Фильтрует реальные слова из `LessonContentMap` (word_manifest.json)
/// по целевому звуку, позиции в слове и диапазону слогов.
///
/// **Источник данных:** только `LessonContentMap.entries` — слова,
/// которые уже есть в бандле с картинками. Новых слов не придумывает.
///
/// **Определение позиции:**
/// - Начало (initial): первый символ слова (строчная нормализация) совпадает
///   с одной из графем целевого звука.
/// - Конец (final): последний символ слова (без мягкого/твёрдого знаков)
///   совпадает с одной из графем.
/// - Середина (medial): хотя бы одно вхождение не в начале и не в конце.
/// - Мягкость (Рь, Ль, Сь): проверяется двухсимвольная последовательность
///   «согласная + ь».
///
/// **Подсчёт слогов:** число гласных букв (а е ё и й о у ы э ю я).
@MainActor
final class WordAutoPickWorker: WordAutoPickWorkerProtocol {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "CustomWordList.AutoPickWorker"
    )

    // MARK: - Гласные русского языка

    private static let vowels: Set<Character> = [
        "а", "е", "ё", "и", "й", "о", "у", "ы", "э", "ю", "я"
    ]

    // MARK: - Маппинг звук → графемы

    /// Для каждого звука — упорядоченный список буквосочетаний, которые
    /// представляют этот звук в орфографии. Длинные (2-символьные) идут
    /// первыми, чтобы двухсимвольный матч проверялся раньше односимвольного.
    private static let graphemes: [String: [String]] = [
        "С":  ["с"],
        "Сь": ["сь"],
        "З":  ["з"],
        "Зь": ["зь"],
        "Ц":  ["ц"],
        "Ш":  ["ш"],
        "Ж":  ["ж"],
        "Ч":  ["ч"],
        "Щ":  ["щ"],
        "Р":  ["р"],
        "Рь": ["рь"],
        "Л":  ["л"],
        "Ль": ["ль"],
        "К":  ["к"],
        "Г":  ["г"],
        "Х":  ["х"],
        "Й":  ["й"]
    ]

    // MARK: - pick

    func pick(params: AutoPickParams) -> AutoPickResult {
        let sound = params.targetSound
        guard let targetGraphemes = Self.graphemes[sound], !targetGraphemes.isEmpty else {
            Self.logger.warning("AutoPick: неизвестный звук '\(sound)' — пустой результат")
            return AutoPickResult(words: [], totalCandidates: 0)
        }

        // Берём слова с совпадающим soundFamily ИЛИ слова, где звук
        // встречается орфографически (для расширения охвата при soundFamily == nil).
        let allEntries = LessonContentMap.allEntries

        let candidates = allEntries.filter { entry in
            // 1. Слово содержит целевой звук (орфографически)
            guard containsSound(entry.word, graphemes: targetGraphemes) else { return false }
            // 2. Позиция
            guard matchesPosition(entry.word, graphemes: targetGraphemes, position: params.position) else { return false }
            // 3. Слоги
            let syllables = countSyllables(entry.word)
            guard params.syllableRange.matches(syllables) else { return false }
            return true
        }

        let totalCandidates = candidates.count

        // Перемешиваем для разнообразия, затем берём лимит
        let shuffled = candidates.shuffled()
        let selected = Array(shuffled.prefix(params.requestedCount)).map { $0.word }

        Self.logger.info("AutoPick [\(sound)/\(params.position.rawValue)/\(params.syllableRange.rawValue)]: \(totalCandidates) кандидатов → \(selected.count) выбрано")

        return AutoPickResult(words: selected, totalCandidates: totalCandidates)
    }

    // MARK: - Helpers

    /// Слово содержит хотя бы одну из графем (без учёта позиции).
    private func containsSound(_ word: String, graphemes: [String]) -> Bool {
        let lower = word.lowercased()
        return graphemes.contains { lower.contains($0) }
    }

    /// Проверяет позицию звука в слове.
    private func matchesPosition(
        _ word: String,
        graphemes: [String],
        position: WordPosition
    ) -> Bool {
        if position == .any { return true }
        let lower = word.lowercased()
        // Убираем ё→е для нормализации не нужно — оставляем как есть
        let chars = Array(lower)
        let len = chars.count

        for grapheme in graphemes {
            let gChars = Array(grapheme)
            let gLen = gChars.count

            // Перебираем все вхождения графемы в слове
            var index = 0
            while index <= len - gLen {
                let slice = Array(chars[index ..< index + gLen])
                if slice == gChars {
                    switch position {
                    case .initial:
                        // Начало: индекс 0
                        if index == 0 { return true }
                    case .ending:
                        // Конец: последний символ(ы) слова перед мягким/твёрдым знаком
                        // Ищем «рабочий» конец — без ь/ъ на хвосте
                        let effectiveEnd = effectiveWordEnd(chars: chars)
                        if index + gLen - 1 == effectiveEnd { return true }
                    case .medial:
                        // Середина: не начало и не конец
                        let effectiveEnd = effectiveWordEnd(chars: chars)
                        if index != 0 && index + gLen - 1 != effectiveEnd { return true }
                    case .any:
                        return true
                    }
                }
                index += 1
            }
        }
        return false
    }

    /// Индекс последнего «значимого» символа слова (без суффиксного ь/ъ).
    private func effectiveWordEnd(chars: [Character]) -> Int {
        var end = chars.count - 1
        while end > 0, chars[end] == "ь" || chars[end] == "ъ" {
            end -= 1
        }
        return end
    }

    /// Число слогов = число гласных букв в слове.
    private func countSyllables(_ word: String) -> Int {
        word.lowercased().filter { Self.vowels.contains($0) }.count
    }
}

// MARK: - LessonContentMap extension (доступ к полному массиву)

extension LessonContentMap {
    /// Все записи манифеста — для использования в AutoPickWorker.
    /// Вспомогательный путь доступа к внутреннему `entries`, не раскрытому публично.
    static var allEntries: [LessonContentMap.Entry] {
        // Используем публичный words(soundFamily:) с «*» — не существует,
        // поэтому фильтруем через words(stage:) с общим стейджем
        // и дополняем прямым доступом к записям через entry(for:).
        // Поскольку LessonContentMap не экспортирует entries напрямую,
        // используем workaround: перебираем все слова через words(stage:)
        // для всех известных стейджей и дедублируем.
        var seen = Set<String>()
        var result: [LessonContentMap.Entry] = []
        let stages = ["word", "wordInit", "wordMid", "wordEnd", "wordFinal", "wordMed", "wordFin", "cluster"]
        for stage in stages {
            for entry in LessonContentMap.words(stage: stage)
            where seen.insert(entry.word.lowercased()).inserted {
                result.append(entry)
            }
        }
        return result
    }
}
