import Foundation
import OSLog

// MARK: - AdvancedGrammarContentWorker
//
// Загружает pack_advanced_grammar.json и строит раунды для трёх режимов с
// КОРРЕКТНОЙ русской грамматикой (род/число/падеж выверены в паке и при
// генерации дистракторов). Дистракторы — типичные детские грамматические
// ошибки (гиперобобщение окончаний, неверный предлог/род), а не случайный шум.

@MainActor
final class AdvancedGrammarContentWorker {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "AdvancedGrammarContent")

    /// Тестовый seam: переопределяет загрузку из бандла детерминированными
    /// сырыми элементами. В проде всегда nil.
    private let seededItems: [AdvancedGrammarRawItem]?

    init(seededItems: [AdvancedGrammarRawItem]? = nil) {
        self.seededItems = seededItems
    }

    // MARK: - Public API

    func loadRounds(
        mode: AdvancedGrammarMode,
        difficulty: AdvancedGrammarDifficulty
    ) async -> [AdvancedGrammarRound] {
        let items: [AdvancedGrammarRawItem]
        if let seededItems {
            items = seededItems
        } else {
            items = await fetchItems(for: mode)
        }
        guard !items.isEmpty else {
            logger.warning("No items for mode=\(mode.rawValue, privacy: .public) — using fallback")
            return Self.fallbackRounds(mode: mode, difficulty: difficulty)
        }
        let count = min(items.count, difficulty.totalRounds)
        let selected = Array(items.shuffled().prefix(max(count, 1)))
        return selected.map { build(item: $0, mode: mode) }
    }

    // MARK: - Round construction

    private func build(item: AdvancedGrammarRawItem, mode: AdvancedGrammarMode) -> AdvancedGrammarRound {
        switch mode {
        case .complexPreposition: return buildPreposition(item)
        case .possessive:         return buildPossessive(item)
        case .agreement:          return buildAgreement(item)
        }
    }

    // MARK: Сложные предлоги

    private func buildPreposition(_ item: AdvancedGrammarRawItem) -> AdvancedGrammarRound {
        let subject = item.subject ?? "котёнок"
        let verb = item.subjectVerb ?? "выглянул"
        let objectGenitive = item.objectGenitive ?? (item.object ?? "")
        let preposition = item.preposition ?? "из-за"
        let scene = PrepositionScene(rawValue: item.scene ?? "behind") ?? .behind

        // Полная фраза: «Котёнок выглянул из-под стола».
        let fullPhrase = "\(subject.capitalizedFirst) \(verb) \(preposition) \(objectGenitive)"
        // Шаблон с пропуском для qbadge: «Котёнок выглянул … стола».
        let prompt = "\(subject.capitalizedFirst) \(verb) … \(objectGenitive)"

        // Все 4 предлога — варианты; правильный отмечается по совпадению.
        let prepChoices: [(prep: String, scene: PrepositionScene)] = [
            ("из-за", .behind),
            ("из-под", .under),
            ("из", .inside),
            ("возле", .beside)
        ]
        var choices = prepChoices.map { entry in
            AdvancedGrammarChoice(
                id: entry.prep,
                primary: entry.prep,
                secondary: entry.scene.localizedMeaning()
            )
        }
        choices.shuffle()
        let correctId = preposition

        let imageName = item.object.flatMap { resolveAsset(item.objectAsset, word: $0) } ?? "questionmark.circle"

        return AdvancedGrammarRound(
            id: item.id,
            mode: .complexPreposition,
            title: String(
                format: String(localized: "advancedGrammar.preposition.question %@",
                               defaultValue: "Откуда %@ %@?"),
                subject, verb
            ),
            subtitle: AdvancedGrammarMode.complexPreposition.localizedSubtitle,
            promptTemplate: prompt,
            imageName: imageName,
            scene: scene,
            gender: nil,
            choices: choices,
            correctChoiceId: correctId,
            fullPhrase: fullPhrase,
            hint: item.hint ?? ""
        )
    }

    // MARK: Притяжательные

    private func buildPossessive(_ item: AdvancedGrammarRawItem) -> AdvancedGrammarRound {
        let part = item.part ?? "хвост"
        let possessive = item.possessive ?? "лисий"
        let gender = GrammaticalGender(rawValue: item.partGender ?? "masculine") ?? .masculine
        let questionWord = item.questionWord ?? "чей"

        // Полная фраза: «лисий хвост» (притяж. прил. + часть).
        let fullPhrase = "\(possessive) \(part)"

        // Варианты — формы вопроса чей/чья/чьё/чьи, цвет по роду.
        let formChoices: [(word: String, gender: GrammaticalGender, example: String)] = [
            ("чей", .masculine, String(localized: "advancedGrammar.possessive.ex.he",  defaultValue: "он · хвост")),
            ("чья", .feminine,  String(localized: "advancedGrammar.possessive.ex.she", defaultValue: "она · лапа")),
            ("чьё", .neuter,    String(localized: "advancedGrammar.possessive.ex.it",  defaultValue: "оно · ухо")),
            ("чьи", .plural,    String(localized: "advancedGrammar.possessive.ex.they",defaultValue: "они · уши"))
        ]
        var choices = formChoices.map { entry in
            AdvancedGrammarChoice(
                id: entry.word,
                primary: entry.word,
                secondary: entry.example,
                gender: entry.gender
            )
        }
        choices.shuffle()

        let imageName = resolveAsset(item.partAsset, word: part) ?? "questionmark.circle"

        return AdvancedGrammarRound(
            id: item.id,
            mode: .possessive,
            title: String(
                format: String(localized: "advancedGrammar.possessive.question %@",
                               defaultValue: "%@ это?"),
                questionWord.capitalizedFirst
            ),
            subtitle: AdvancedGrammarMode.possessive.localizedSubtitle,
            // Карточка части: «Пушистый хвост» с подсветкой части.
            promptTemplate: "\((item.partAdjective ?? "").capitalizedFirst) \(part)".trimmingCharacters(in: .whitespaces),
            imageName: imageName,
            scene: nil,
            gender: gender,
            choices: choices,
            correctChoiceId: questionWord,
            // Произносим всю конструкцию: «лисий хвост».
            fullPhrase: fullPhrase,
            hint: item.hint ?? ""
        )
    }

    // MARK: Согласование

    private func buildAgreement(_ item: AdvancedGrammarRawItem) -> AdvancedGrammarRound {
        let noun = item.noun ?? "машина"
        let stem = item.adjectiveStem ?? "красн"
        let ending = item.ending ?? "ая"
        let gender = GrammaticalGender(rawValue: item.gender ?? "feminine") ?? .feminine

        // Правильная полная фраза: «красная машина».
        let fullAdjective = stem + ending
        let fullPhrase = "\(fullAdjective) \(noun)"

        // Варианты — окончания по роду/числу, каждое со своим примером.
        // Окончание правильного варианта берём из данных (учитывает -ой/-ий
        // ударные/мягкие основы); остальные — типичные альтернативы того же
        // прилагательного с другими родовыми окончаниями.
        let endingByGender = Self.agreementEndings(stem: stem, correctEnding: ending, correctGender: gender)
        var choices = endingByGender.map { entry in
            AdvancedGrammarChoice(
                id: entry.gender.rawValue,
                primary: stem + entry.ending,
                secondary: entry.example,
                gender: entry.gender
            )
        }
        choices.shuffle()

        let imageName = resolveAsset(item.nounAsset, word: noun) ?? "questionmark.circle"

        return AdvancedGrammarRound(
            id: item.id,
            mode: .agreement,
            title: String(localized: "advancedGrammar.agreement.question",
                          defaultValue: "Договори словечко"),
            subtitle: AdvancedGrammarMode.agreement.localizedSubtitle,
            // build-фраза с пропуском окончания: «красн[?] машина».
            promptTemplate: "\(stem)… \(noun)",
            imageName: imageName,
            scene: nil,
            gender: gender,
            choices: choices,
            correctChoiceId: gender.rawValue,
            fullPhrase: fullPhrase,
            hint: item.hint ?? ""
        )
    }

    // MARK: - Agreement ending table
    //
    // Окончания прилагательного по роду/числу. Для правильного варианта берём
    // окончание из данных (учитывает мягкие/ударные основы: синий, большой).
    // Дистракторы — стандартные родовые окончания того же ряда, чтобы ребёнок
    // выбирал по согласованию, а не по бессмыслице.

    private struct AgreementEnding {
        let gender: GrammaticalGender
        let ending: String
        let example: String
    }

    private static func agreementEndings(
        stem: String,
        correctEnding: String,
        correctGender: GrammaticalGender
    ) -> [AgreementEnding] {
        // Базовые твёрдые окончания.
        var masculine = "ый"
        var feminine = "ая"
        var neuter = "ое"
        var plural = "ые"

        // Подстройка под мягкую/ударную основу по правильному окончанию.
        switch correctEnding {
        case "ий":   // мягкая основа (синий)
            masculine = "ий"; feminine = "яя"; neuter = "ее"; plural = "ие"
        case "ой":   // ударное окончание (большой)
            masculine = "ой"; feminine = "ая"; neuter = "ое"; plural = "ые"
        default:
            break
        }
        // Гарантируем, что окончание правильного рода = данные.
        switch correctGender {
        case .masculine: masculine = correctEnding
        case .feminine:  feminine = correctEnding
        case .neuter:    neuter = correctEnding
        case .plural:    plural = correctEnding
        }

        return [
            AgreementEnding(gender: .masculine, ending: masculine,
                            example: String(localized: "advancedGrammar.agreement.ex.he",  defaultValue: "он · мяч")),
            AgreementEnding(gender: .feminine, ending: feminine,
                            example: String(localized: "advancedGrammar.agreement.ex.she", defaultValue: "она · машина")),
            AgreementEnding(gender: .neuter, ending: neuter,
                            example: String(localized: "advancedGrammar.agreement.ex.it",  defaultValue: "оно · яблоко")),
            AgreementEnding(gender: .plural, ending: plural,
                            example: String(localized: "advancedGrammar.agreement.ex.they",defaultValue: "они · сапоги"))
        ]
    }

    // MARK: - Asset resolution

    /// Резолвит явный ассет из пака, иначе ищет russian-word в word_manifest.
    /// Nil → вызывающий ставит SF-плейсхолдер.
    private func resolveAsset(_ explicit: String?, word: String) -> String? {
        if let explicit, !explicit.isEmpty { return explicit }
        return LessonContentMap.asset(for: word)
    }

    // MARK: - Fetch from bundle

    private func fetchItems(for mode: AdvancedGrammarMode) async -> [AdvancedGrammarRawItem] {
        guard let url = Bundle.main.url(forResource: "pack_advanced_grammar", withExtension: "json") else {
            logger.error("pack_advanced_grammar.json not found in bundle")
            return []
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let pack = try JSONDecoder().decode(AdvancedGrammarPack.self, from: data)
            guard let stage = pack.stages[mode.rawValue] else { return [] }
            return stage.items
        } catch {
            logger.error("pack_advanced_grammar.json parse error: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - Fallback (если пак недоступен)

    static func fallbackRounds(
        mode: AdvancedGrammarMode,
        difficulty: AdvancedGrammarDifficulty
    ) -> [AdvancedGrammarRound] {
        let raw: [AdvancedGrammarRawItem]
        switch mode {
        case .complexPreposition:
            raw = [
                AdvancedGrammarRawItem(
                    id: "fb-prep-0", subject: "котёнок", subjectVerb: "выглянул",
                    object: "стол", objectGenitive: "стола", preposition: "из-под",
                    scene: "under", hint: "Котёнок был под столом и выглянул снизу — «из-под».")
            ]
        case .possessive:
            raw = [
                AdvancedGrammarRawItem(
                    id: "fb-poss-0", part: "хвост", partAdjective: "пушистый",
                    partGender: "masculine", questionWord: "чей",
                    owner: "лиса", possessive: "лисий",
                    hint: "Хвост — он. Спрашиваем «чей?». Хвост лисы — лисий хвост.")
            ]
        case .agreement:
            raw = [
                AdvancedGrammarRawItem(
                    id: "fb-agr-0", noun: "машина", gender: "feminine",
                    adjectiveStem: "красн", ending: "ая",
                    hint: "Машина — она, моя. Значит «красная машина».")
            ]
        }
        let worker = AdvancedGrammarContentWorker(seededItems: raw)
        return raw.map { worker.build(item: $0, mode: mode) }
    }
}

// MARK: - Raw decode types

struct AdvancedGrammarPack: Decodable {
    let stages: [String: Stage]
    struct Stage: Decodable {
        let items: [AdvancedGrammarRawItem]
    }
}

/// Сырой элемент пака — поля union по трём режимам (опциональны).
struct AdvancedGrammarRawItem: Decodable, Sendable {
    let id: String
    // preposition
    let subject: String?
    let subjectVerb: String?
    let object: String?
    let objectAsset: String?
    let objectGenitive: String?
    let preposition: String?
    let scene: String?
    // possessive
    let part: String?
    let partAsset: String?
    let partAdjective: String?
    let partGender: String?
    let questionWord: String?
    let owner: String?
    let possessive: String?
    // agreement
    let noun: String?
    let nounAsset: String?
    let gender: String?
    let adjectiveStem: String?
    let ending: String?
    let endingStressed: Bool?
    // common
    let hint: String?

    init(
        id: String,
        subject: String? = nil, subjectVerb: String? = nil, object: String? = nil,
        objectAsset: String? = nil, objectGenitive: String? = nil, preposition: String? = nil,
        scene: String? = nil,
        part: String? = nil, partAsset: String? = nil, partAdjective: String? = nil,
        partGender: String? = nil, questionWord: String? = nil, owner: String? = nil,
        possessive: String? = nil,
        noun: String? = nil, nounAsset: String? = nil, gender: String? = nil,
        adjectiveStem: String? = nil, ending: String? = nil, endingStressed: Bool? = nil,
        hint: String? = nil
    ) {
        self.id = id
        self.subject = subject; self.subjectVerb = subjectVerb; self.object = object
        self.objectAsset = objectAsset; self.objectGenitive = objectGenitive
        self.preposition = preposition; self.scene = scene
        self.part = part; self.partAsset = partAsset; self.partAdjective = partAdjective
        self.partGender = partGender; self.questionWord = questionWord; self.owner = owner
        self.possessive = possessive
        self.noun = noun; self.nounAsset = nounAsset; self.gender = gender
        self.adjectiveStem = adjectiveStem; self.ending = ending; self.endingStressed = endingStressed
        self.hint = hint
    }
}

// MARK: - String helper

private extension String {
    /// Капитализирует только первую букву, остальное не трогает.
    var capitalizedFirst: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}
