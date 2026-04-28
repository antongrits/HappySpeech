import Foundation
import OSLog

// MARK: - GrammarContentLoaderWorker

/// Загружает и парсит pack_grammar.json, выдаёт items по mode+difficulty.
/// Дистракторы генерируются программно (не из JSON) по типичным детским ошибкам.
@MainActor
final class GrammarContentLoaderWorker {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "GrammarContentLoader")

    // MARK: - Public API

    func loadRounds(
        mode: GrammarGameMode,
        difficulty: GrammarDifficulty
    ) async -> [GrammarRound] {
        let items = await fetchItems(for: mode, difficulty: difficulty)
        let count = min(items.count, difficulty.totalRounds)
        guard count > 0 else {
            logger.warning("No items for mode=\(mode.rawValue) difficulty=\(difficulty.rawValue)")
            return Self.fallbackRounds(mode: mode, difficulty: difficulty)
        }
        let selected = Array(items.shuffled().prefix(count))
        return selected.map { item in
            buildRound(item: item, mode: mode, difficulty: difficulty)
        }
    }

    // MARK: - Private: round construction

    private func buildRound(
        item: GrammarPackItem,
        mode: GrammarGameMode,
        difficulty: GrammarDifficulty
    ) -> GrammarRound {
        switch mode {
        case .oneMany:      return buildPluralRound(item: item, difficulty: difficulty)
        case .dative:       return buildDativeRound(item: item, difficulty: difficulty)
        case .genitive:     return buildGenitiveRound(item: item, difficulty: difficulty)
        case .instrumental: return buildInstrumentalRound(item: item, difficulty: difficulty)
        }
    }

    // MARK: - Plural (Именительный падеж, мн.ч.)

    private func buildPluralRound(item: GrammarPackItem, difficulty: GrammarDifficulty) -> GrammarRound {
        let parts = item.word.components(separatedBy: " — ")
        let singular = parts.first.map { Self.extractNoun(from: $0) } ?? item.word
        let plural   = parts.last.map  { Self.extractNoun(from: $0) } ?? item.word

        let questionText = String(format: String(localized: "grammar.game.plural.question"), singular)
        let distractors  = Self.pluralDistractors(for: singular, correct: plural, count: difficulty.choiceCount - 1)
        var allChoices   = [GrammarChoice(id: "correct", text: plural, imageName: nil)]
        allChoices += distractors.enumerated().map { idx, d in
            GrammarChoice(id: "d\(idx)", text: d, imageName: nil)
        }
        allChoices.shuffle()
        let correctIndex = allChoices.firstIndex(where: { $0.id == "correct" }) ?? 0

        return GrammarRound(
            id: UUID(),
            mode: .oneMany,
            sourceItem: item,
            questionText: questionText,
            correctAnswer: plural,
            choices: allChoices,
            correctIndex: correctIndex,
            imageName: Self.imageAsset(for: singular),
            extraData: .none
        )
    }

    // MARK: - Dative (Дательный падеж)

    private func buildDativeRound(item: GrammarPackItem, difficulty: GrammarDifficulty) -> GrammarRound {
        let noun = Self.extractNoun(from: item.word)
        let characters = Self.dativeCharacters()
        let targetIndex = Int.random(in: 0..<characters.count)
        let targetChar = characters[targetIndex]
        let question = String(format: String(localized: "grammar.game.dative.question"), noun)

        return GrammarRound(
            id: UUID(),
            mode: .dative,
            sourceItem: item,
            questionText: question,
            correctAnswer: targetChar.dativeName,
            choices: [],    // drag-and-drop — варианты через extraData
            correctIndex: targetIndex,
            imageName: Self.imageAsset(for: noun),
            extraData: .dative(characters: characters, targetCharacterIndex: targetIndex)
        )
    }

    // MARK: - Genitive (Родительный падеж)

    private func buildGenitiveRound(item: GrammarPackItem, difficulty: GrammarDifficulty) -> GrammarRound {
        let noun = Self.extractNoun(from: item.word)
        let containers = Self.genitiveContainers()
        let correctIndex = Int.random(in: 0..<containers.count)
        let correctContainer = containers[correctIndex]
        let question = String(format: String(localized: "grammar.game.detective.hint"), noun)

        return GrammarRound(
            id: UUID(),
            mode: .genitive,
            sourceItem: item,
            questionText: question,
            correctAnswer: correctContainer.genitiveName,
            choices: [],    // tap-targets через extraData
            correctIndex: correctIndex,
            imageName: Self.imageAsset(for: noun),
            extraData: .genitive(containers: containers, correctContainerIndex: correctIndex)
        )
    }

    // MARK: - Instrumental (Творительный падеж)

    private func buildInstrumentalRound(
        item: GrammarPackItem,
        difficulty: GrammarDifficulty
    ) -> GrammarRound {
        let parts = item.word.components(separatedBy: " — ")
        let base         = parts.first.map { Self.extractNoun(from: $0) } ?? item.word
        let instrumental = parts.last.map  { Self.extractNoun(from: $0) } ?? item.word

        let isPartyMode = difficulty == .hard
        let question: String
        if isPartyMode {
            question = String(format: String(localized: "grammar.game.party.invite"), instrumental)
        } else {
            question = String(format: String(localized: "grammar.game.dative.question"), base)
        }

        let distractors = Self.instrumentalDistractors(
            for: instrumental,
            count: difficulty.choiceCount - 1
        )
        var choices = [GrammarChoice(id: "correct", text: instrumental, imageName: nil)]
        choices += distractors.enumerated().map { idx, d in
            GrammarChoice(id: "d\(idx)", text: d, imageName: nil)
        }
        choices.shuffle()
        let correctIndex = choices.firstIndex(where: { $0.id == "correct" }) ?? 0

        return GrammarRound(
            id: UUID(),
            mode: .instrumental,
            sourceItem: item,
            questionText: question,
            correctAnswer: instrumental,
            choices: choices,
            correctIndex: correctIndex,
            imageName: Self.imageAsset(for: base),
            extraData: .instrumental(partyMode: isPartyMode)
        )
    }

    // MARK: - Fetch items from pack_grammar.json

    private func fetchItems(
        for mode: GrammarGameMode,
        difficulty: GrammarDifficulty
    ) async -> [GrammarPackItem] {
        guard let url = Bundle.main.url(forResource: "pack_grammar", withExtension: "json") else {
            logger.error("pack_grammar.json not found in bundle")
            return []
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let raw  = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            return parseItems(from: raw, mode: mode, difficulty: difficulty)
        } catch {
            logger.error("pack_grammar.json parse error: \(error.localizedDescription)")
            return []
        }
    }

    private func parseItems(
        from raw: [String: Any],
        mode: GrammarGameMode,
        difficulty: GrammarDifficulty
    ) -> [GrammarPackItem] {
        let stageKeys = Self.stageKeys(for: mode)
        var result: [GrammarPackItem] = []
        guard let stages = raw["stages"] as? [String: Any] else { return [] }

        for key in stageKeys {
            guard let stage = stages[key] as? [String: Any],
                  let items = stage["items"] as? [[String: Any]] else { continue }
            for item in items {
                guard let id   = item["id"] as? String,
                      let word = item["word"] as? String else { continue }
                let diff = item["difficulty"] as? Int ?? 1
                // Фильтр по сложности: ±1 от текущего уровня
                guard abs(diff - difficulty.rawValue) <= 1 else { continue }
                result.append(GrammarPackItem(
                    id: id,
                    word: word,
                    hint: item["hint"] as? String ?? "",
                    difficulty: diff,
                    audioFile: item["audio_file"] as? String ?? ""
                ))
            }
        }
        return result
    }

    // MARK: - Static helpers

    private static func stageKeys(for mode: GrammarGameMode) -> [String] {
        switch mode {
        case .oneMany:      return ["plural"]
        case .dative:       return ["cases", "grammar_cases", "sentences_grammar"]
        case .genitive:     return ["grammar_cases", "prepositions"]
        case .instrumental: return ["cases", "grammar_cases", "sentences_grammar"]
        }
    }

    /// Извлекает первое значимое существительное из строки вида
    /// «один кот» → «кот», «много котов» → «котов»
    static func extractNoun(from text: String) -> String {
        let stopWords: Set<String> = ["один", "одна", "одно", "много", "несколько"]
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        return words.first(where: { !stopWords.contains($0.lowercased()) }) ?? text
    }

    private static func imageAsset(for noun: String) -> String {
        "illus_\(noun.lowercased())"
    }

    // MARK: - Distractor generation

    /// Типичные детские ошибки для мн.числа: гиперобобщение -ов и ед.ч.
    static func pluralDistractors(for singular: String, correct: String, count: Int) -> [String] {
        var pool: [String] = []
        // B: гиперобобщение частотного окончания
        let hypergen = singular + "ов"
        if hypergen != correct { pool.append(hypergen) }
        // C: ед.ч. вместо мн.ч.
        let sing = "много " + singular
        if sing != correct { pool.append(sing) }
        // D: другое частое окончание
        let altEnding = singular + "ей"
        if altEnding != correct && altEnding != hypergen { pool.append(altEnding) }
        // E: добавить «а» (дома, стола)
        let altA = singular + "а"
        if altA != correct { pool.append(altA) }

        var result: [String] = []
        for d in pool.shuffled() {
            if result.count >= count { break }
            if !result.contains(d) { result.append(d) }
        }
        // Если не хватает — добавить дополнительные слова
        while result.count < count {
            result.append("\(singular)и")
        }
        return result
    }

    static func instrumentalDistractors(for correct: String, count: Int) -> [String] {
        let pool = ["с Ваней", "с собакой", "с мамой", "карандашом", "ложкой",
                    "с другом", "с кошкой", "мячом", "ручкой", "с Машей"]
        return pool.filter { $0 != correct }.shuffled().prefix(count).map { $0 }
    }

    // MARK: - Character / Container catalogs

    static func dativeCharacters() -> [DativeCharacter] {
        [
            DativeCharacter(id: "masha",   name: "Маша",   dativeName: "Маше",   imageName: "char_masha"),
            DativeCharacter(id: "papa",    name: "Папа",   dativeName: "Папе",   imageName: "char_papa"),
            DativeCharacter(id: "dog",     name: "Собака", dativeName: "Собаке", imageName: "char_dog"),
            DativeCharacter(id: "kitten",  name: "Котёнок",dativeName: "Котёнку",imageName: "char_kitten")
        ]
    }

    static func genitiveContainers() -> [GenitiveContainer] {
        [
            GenitiveContainer(id: "box",   name: "Ящик",   genitiveName: "из ящика",  imageName: "container_box"),
            GenitiveContainer(id: "table", name: "Стол",   genitiveName: "со стола",  imageName: "container_table"),
            GenitiveContainer(id: "shelf", name: "Полка",  genitiveName: "с полки",   imageName: "container_shelf"),
            GenitiveContainer(id: "bag",   name: "Сумка",  genitiveName: "из сумки",  imageName: "container_bag")
        ]
    }

    // MARK: - Fallback rounds (если JSON недоступен)

    static func fallbackRounds(mode: GrammarGameMode, difficulty: GrammarDifficulty) -> [GrammarRound] {
        let fallbackWords: [(singular: String, plural: String)] = [
            ("кот", "коты"), ("дом", "дома"), ("мяч", "мячи"),
            ("книга", "книги"), ("машина", "машины")
        ]
        let count = min(fallbackWords.count, difficulty.totalRounds)
        return fallbackWords.prefix(count).enumerated().map { idx, pair in
            let item = GrammarPackItem(
                id: "fallback-\(idx)",
                word: "один \(pair.singular) — много \(pair.plural)",
                hint: "\(pair.singular) → \(pair.plural)",
                difficulty: 1,
                audioFile: ""
            )
            let question = String(format: String(localized: "grammar.game.plural.question"), pair.singular)
            let distractors = pluralDistractors(
                for: pair.singular,
                correct: pair.plural,
                count: difficulty.choiceCount - 1
            )
            var choices = [GrammarChoice(id: "correct", text: pair.plural, imageName: nil)]
            choices += distractors.enumerated().map { i, d in
                GrammarChoice(id: "d\(i)", text: d, imageName: nil)
            }
            choices.shuffle()
            let correctIndex = choices.firstIndex(where: { $0.id == "correct" }) ?? 0
            return GrammarRound(
                id: UUID(),
                mode: mode,
                sourceItem: item,
                questionText: question,
                correctAnswer: pair.plural,
                choices: choices,
                correctIndex: correctIndex,
                imageName: imageAsset(for: pair.singular),
                extraData: .none
            )
        }
    }
}
