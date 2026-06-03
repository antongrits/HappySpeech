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
        // Полная фраза с родо-согласованным числительным из данных («одно ухо»,
        // «одна книга», «один кот»), чтобы вопрос был грамматически корректным;
        // голое существительное — для генерации дистракторов и картинки.
        let singularPhrase = parts.first?.trimmingCharacters(in: .whitespaces) ?? item.word
        let singular = parts.first.map { Self.extractNoun(from: $0) } ?? item.word
        let plural = parts.last.map { Self.extractNoun(from: $0) } ?? item.word

        let questionText = String(format: String(localized: "grammar.game.plural.question"), singularPhrase)
        let distractors = Self.pluralDistractors(for: singular, correct: plural, count: difficulty.choiceCount - 1)
        var allChoices = [GrammarChoice(id: "correct", text: plural, imageName: nil)]
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
        // Творит. форма — целая фраза «с Машей», поэтому берём части как есть
        // (без extractNoun, который вернул бы предлог «с»).
        let parts = item.word.components(separatedBy: " — ").map { $0.trimmingCharacters(in: .whitespaces) }
        let base = parts.first ?? item.word          // именит.: «Маша»
        let instrumental = parts.count > 1 ? parts[parts.count - 1] : item.word   // творит.: «с Машей»

        let isPartyMode = difficulty == .hard
        let question: String
        if isPartyMode {
            // «Пригласить %@?» — компаньон в винит. падеже (имя = винит. для имён
            // на -а даёт «Машу»; берём базовую форму, шаблон допускает имя).
            question = String(format: String(localized: "grammar.game.party.invite"), base)
        } else {
            // Корректный творительный вопрос «С кем дружить? Это %@.» вместо
            // прежнего ошибочного дательного «Кому нужен %@?».
            question = String(
                format: String(localized: "grammar.game.instrumental.question", bundle: .main),
                base
            )
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

    // MARK: - Fetch items

    private func fetchItems(
        for mode: GrammarGameMode,
        difficulty: GrammarDifficulty
    ) async -> [GrammarPackItem] {
        // Падежные режимы (дательный/родительный/творительный) НЕ берут items из
        // pack_grammar.json: его падежные стадии (`cases`, `grammar_cases`,
        // `prepositions`, `sentences_grammar`) содержат не существительные, а
        // ИНСТРУКЦИИ/предложения («именительный: кто? что?», «иду В школу»). Из них
        // `extractNoun` извлекает мусор → бессмысленный вопрос и абсурдные
        // дистракторы. Для этих режимов используем чистые in-code каталоги
        // существительных/творительных пар. `one_many` берёт чистую стадию `plural`.
        switch mode {
        case .oneMany:
            return await pluralItems(difficulty: difficulty)
        case .dative:
            return Self.caseObjectItems(prefix: "dat", difficulty: difficulty)
        case .genitive:
            return Self.caseObjectItems(prefix: "gen", difficulty: difficulty)
        case .instrumental:
            return Self.instrumentalItems(difficulty: difficulty)
        }
    }

    private func pluralItems(difficulty: GrammarDifficulty) async -> [GrammarPackItem] {
        guard let url = Bundle.main.url(forResource: "pack_grammar", withExtension: "json") else {
            logger.error("pack_grammar.json not found in bundle")
            return []
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let raw  = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            return parseItems(from: raw, mode: .oneMany, difficulty: difficulty)
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

    /// Стадии JSON-пака для чтения. Используется только `one_many` (чистая стадия
    /// `plural`); падежные режимы берут in-code каталоги (см. `fetchItems`).
    private static func stageKeys(for mode: GrammarGameMode) -> [String] {
        switch mode {
        case .oneMany:                          return ["plural"]
        case .dative, .genitive, .instrumental: return []
        }
    }

    /// Извлекает первое значимое существительное из строки вида
    /// «один кот» → «кот», «много котов» → «котов»
    static func extractNoun(from text: String) -> String {
        let stopWords: Set<String> = ["один", "одна", "одно", "много", "несколько"]
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        return words.first(where: { !stopWords.contains($0.lowercased()) }) ?? text
    }

    // MARK: - In-code case-noun catalogs
    //
    // pack_grammar.json не содержит чистых пар «слово — форма» для падежей (его
    // падежные стадии — инструкции/предложения), поэтому существительные для
    // дательного/родительного/творительного режимов берутся из кодовых каталогов.
    // Слова подобраны так, чтобы резолвиться в `word_*` ассеты и грамматически
    // согласоваться с шаблонами вопросов.

    /// Объекты-существительные для дательного/родительного режимов.
    /// `dat` — предмет, который кому-то нужен (именит.=винит. падеж, муж. род,
    /// чтобы согласоваться с «Кому нужен %@?»). `gen` — предмет, который взяли
    /// (винит. падеж, для «Откуда Ляля взяла %@?»).
    static func caseObjectItems(prefix: String, difficulty: GrammarDifficulty) -> [GrammarPackItem] {
        // Существительные мужского рода, неодушевлённые: именит. = винит. падеж,
        // поэтому одна форма годится и для «Кому нужен %@?» (дательный режим), и
        // для «Откуда Ляля взяла %@?» (родительный режим — что взяла, винит.). Все
        // слова резолвятся в word_* ассеты.
        let words = ["мяч", "зонт", "ключ", "бант", "шар", "топор", "молоток", "карандаш"]
        return words.enumerated().map { idx, word in
            GrammarPackItem(
                id: "\(prefix)-\(idx)",
                word: word,
                hint: "",
                difficulty: min(3, 1 + idx / 3),
                audioFile: ""
            )
        }
    }

    /// Пары «компаньон — творительная форма» для творительного режима «С кем дружу?».
    /// Формат `word` = «именит. — творит.» (как у plural), чтобы переиспользовать
    /// разбор по « — ». Творит. форма = «с <имя/животное в твор. падеже>».
    static func instrumentalItems(difficulty: GrammarDifficulty) -> [GrammarPackItem] {
        let pairs: [(base: String, instrumental: String)] = [
            ("Маша", "с Машей"),
            ("Ваня", "с Ваней"),
            ("мама", "с мамой"),
            ("папа", "с папой"),
            ("кот", "с котом"),
            ("собака", "с собакой"),
            ("друг", "с другом"),
            ("кукла", "с куклой")
        ]
        return pairs.enumerated().map { idx, pair in
            GrammarPackItem(
                id: "instr-\(idx)",
                word: "\(pair.base) — \(pair.instrumental)",
                hint: "",
                difficulty: min(3, 1 + idx / 3),
                audioFile: ""
            )
        }
    }

    /// Резолвит существительное в имя имейджсета (`word_*`) через
    /// `LessonContentMap` — единый путь, что используют рабочие экраны уроков.
    /// Прежний `"illus_<кириллица>"` не существовал в каталоге (все ассеты —
    /// `word_*` латиницей), картинка не показывалась. Если ассета реально нет —
    /// graceful SF Symbol-плейсхолдер `questionmark.circle` (HSPictTile/HSContentSymbol
    /// корректно его рендерят).
    private static func imageAsset(for noun: String) -> String {
        LessonContentMap.asset(for: noun) ?? "questionmark.circle"
    }

    // MARK: - Distractor generation

    /// Реалистичные детские ошибки множественного числа.
    ///
    /// Для регулярных слов — гиперобобщение частотных окончаний (-ов/-ей/-а/-и) и
    /// застревание на ед.числе. Для слов-исключений (супплетивы/чередования:
    /// ухо→уши, ребёнок→дети, друг→друзья…) механическая склейка давала
    /// нечитаемый абсурд («ухоов», «ребёноков»), и ребёнок отсеивал бы вариант не
    /// по грамматике, а по бессмыслице. Поэтому для них используется курируемый
    /// набор ПРАВДОПОДОБНЫХ детских ошибок (типичные гиперобобщения, которые дети
    /// реально произносят: «ухи», «другов», «деревов»).
    static func pluralDistractors(for singular: String, correct: String, count: Int) -> [String] {
        let key = singular.lowercased()
        var pool: [String]
        if let curated = Self.irregularPluralErrors[key] {
            pool = curated.filter { $0 != correct }
        } else {
            pool = []
            // Гиперобобщение частотного окончания.
            let hypergen = singular + "ов"
            if hypergen != correct { pool.append(hypergen) }
            // Застревание на ед.ч.
            let sing = "много " + singular
            if sing != correct { pool.append(sing) }
            // Другое частое окончание.
            let altEnding = singular + "ей"
            if altEnding != correct && altEnding != hypergen { pool.append(altEnding) }
            // Добавить «а» (дома, стола).
            let altA = singular + "а"
            if altA != correct { pool.append(altA) }
            // Добавить «и» (типичная детская форма).
            let altI = singular + "и"
            if altI != correct && altI != altA { pool.append(altI) }
        }

        var result: [String] = []
        for d in pool.shuffled() {
            if result.count >= count { break }
            if !result.contains(d) && d != correct { result.append(d) }
        }
        // Если не хватает — добить ед.ч.-вариантом (всегда правдоподобная ошибка).
        let singFallback = "много " + singular
        while result.count < count {
            let candidate = result.isEmpty || !result.contains(singFallback)
                ? singFallback
                : "\(singular)а"
            if candidate == correct || result.contains(candidate) { break }
            result.append(candidate)
        }
        return result
    }

    /// Курируемые правдоподобные детские ошибки мн.ч. для слов-исключений
    /// (супплетивы и чередования основы). Это РЕАЛЬНЫЕ гиперобобщения детской
    /// речи, а не механическая склейка.
    private static let irregularPluralErrors: [String: [String]] = [
        "ухо":      ["ухи", "ухов", "много ухо"],
        "ребёнок":  ["ребёнки", "ребёноки", "много ребёнок"],
        "ребенок":  ["ребенки", "ребеноки", "много ребенок"],
        "друг":     ["другы", "другов", "много друг"],
        "брат":     ["браты", "братов", "много брат"],
        "дерево":   ["деревы", "деревов", "много дерево"],
        "лист":     ["листы", "листов", "много лист"],
        "стул":     ["стулы", "стулов", "много стул"],
        "перо":     ["перы", "перов", "много перо"],
        "цыплёнок": ["цыплёнки", "цыплёноки", "много цыплёнок"],
        "цыпленок": ["цыпленки", "цыпленоки", "много цыпленок"],
        "рот":      ["роты", "ротов", "много рот"],
        "пень":     ["пеньи", "пенёв", "много пень"]
    ]

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
        // Фраза с родо-согласованным числительным (женский род книга/машина → «одна»).
        let fallbackWords: [(phrase: String, singular: String, plural: String)] = [
            ("один кот", "кот", "коты"), ("один дом", "дом", "дома"), ("один мяч", "мяч", "мячи"),
            ("одна книга", "книга", "книги"), ("одна машина", "машина", "машины")
        ]
        let count = min(fallbackWords.count, difficulty.totalRounds)
        return fallbackWords.prefix(count).enumerated().map { idx, pair in
            let item = GrammarPackItem(
                id: "fallback-\(idx)",
                word: "\(pair.phrase) — много \(pair.plural)",
                hint: "\(pair.singular) → \(pair.plural)",
                difficulty: 1,
                audioFile: ""
            )
            let question = String(format: String(localized: "grammar.game.plural.question"), pair.phrase)
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
