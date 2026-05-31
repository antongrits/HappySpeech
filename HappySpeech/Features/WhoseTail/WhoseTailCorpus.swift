import Foundation
import OSLog

// MARK: - WhoseTailCorpus
//
// F2-006 «Чей хвост / чей домик» (Wave 2).
//
// Корпус заданий словообразования прилагательных. Загружается из
// `pack_whose_tail.json` (своя схема, как `pack_fourth_extra.json`). Каждый раунд
// — «улика» (хвост / домик / предмет) + ряд карточек-вариантов (звери /
// материалы) с ровно одним правильным сопоставлением. Дефектные формы
// («лисячий», «волковый») в опции НЕ кладутся (стоп-лист). Полностью offline /
// on-device.

enum WhoseTailCorpus {

    /// Сколько раундов в одной сессии (8–12, антифатиговое правило).
    static var roundsPerSession: Int { WhoseTailPackLoader.shared.roundsPerSession }

    /// Все раунды корпуса.
    static var allRounds: [WhoseRound] { WhoseTailPackLoader.shared.rounds }

    /// Раунды заданного под-типа.
    static func rounds(for subtask: WhoseSubtask) -> [WhoseRound] {
        allRounds.filter { $0.subtask == subtask }
    }

    /// Раунды под-типа, не превышающие возрастной гейт (minAge ≤ age).
    static func rounds(for subtask: WhoseSubtask, maxAge age: Int) -> [WhoseRound] {
        rounds(for: subtask).filter { $0.minAge <= age }
    }

    /// Все раунды, доступные ребёнку по возрасту (любой под-тип, minAge ≤ age).
    static func rounds(maxAge age: Int) -> [WhoseRound] {
        allRounds.filter { $0.minAge <= age }
    }

    /// «Лёгкие» раунды (difficulty == 1) для ретро-старта.
    static func easyRounds(maxAge age: Int) -> [WhoseRound] {
        let pool = rounds(maxAge: age)
        let easy = pool.filter { $0.difficulty <= 1 }
        return easy.isEmpty ? pool : easy
    }
}

// MARK: - WhoseTailPackLoader
//
// Разбирает `pack_whose_tail.json` один раз. Отбрасывает раунды без ровно одной
// правильной карточки и без 2–4 вариантов (валидация корпуса). При отказе
// бандла возвращает безопасный минимальный набор, чтобы модуль оставался рабочим.

struct WhoseTailPackLoader {

    static let shared = WhoseTailPackLoader()

    let roundsPerSession: Int
    let rounds: [WhoseRound]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WhoseTail.PackLoader"
    )

    private struct Pack: Decodable {
        let roundsPerSession: Int
        let items: [ItemDTO]
    }

    private struct ItemDTO: Decodable {
        let id: String
        let subtask: String
        let cueImage: String
        let question: String
        let difficulty: Int
        let minAge: Int
        let options: [OptionDTO]
        let spokenForm: String
    }

    private struct OptionDTO: Decodable {
        let id: String
        let word: String
        let imageAsset: String
        let isCorrect: Bool
        let form: String
    }

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_whose_tail", withExtension: "json"
        ) else {
            Self.logger.error("pack_whose_tail.json not found in bundle — using fallback")
            roundsPerSession = 10
            rounds = WhoseTailPackLoader.fallbackRounds
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            roundsPerSession = max(6, pack.roundsPerSession)
            let decoded = pack.items.compactMap(Self.makeRound)
            rounds = decoded.isEmpty ? WhoseTailPackLoader.fallbackRounds : decoded
        } catch {
            Self.logger.error(
                "pack_whose_tail.json decode error: \(error.localizedDescription, privacy: .public)"
            )
            roundsPerSession = 10
            rounds = WhoseTailPackLoader.fallbackRounds
        }
    }

    private static func makeRound(_ dto: ItemDTO) -> WhoseRound? {
        guard let subtask = WhoseSubtask(rawValue: dto.subtask) else {
            logger.error("Unknown subtask: \(dto.subtask, privacy: .public)")
            return nil
        }
        let options = dto.options.map { opt in
            WhoseOption(
                id: opt.id,
                word: opt.word,
                imageAsset: opt.imageAsset,
                isCorrect: opt.isCorrect,
                form: opt.form
            )
        }
        // Валидация: 2–4 варианта и ровно одна правильная карточка.
        guard (2...4).contains(options.count),
              options.filter(\.isCorrect).count == 1 else {
            logger.error("Invalid round (option/correct count): \(dto.id, privacy: .public)")
            return nil
        }
        return WhoseRound(
            id: dto.id,
            subtask: subtask,
            cueImage: dto.cueImage,
            question: dto.question,
            options: options,
            spokenForm: dto.spokenForm,
            difficulty: dto.difficulty,
            minAge: dto.minAge
        )
    }

    // MARK: Fallback (минимальный рабочий набор)

    private static let fallbackRounds: [WhoseRound] = [
        WhoseRound(
            id: "wt-fb-poss-fox", subtask: .possessiveTail,
            cueImage: "tail_fox", question: "Чей это хвост?",
            options: [
                .init(id: "wt-fb-poss-fox-c", word: "лиса", imageAsset: "word_fox",
                      isCorrect: true, form: "лисий хвост"),
                .init(id: "wt-fb-poss-fox-d1", word: "заяц", imageAsset: "word_hare",
                      isCorrect: false, form: "заячий хвост")
            ],
            spokenForm: "Это лисий хвост.", difficulty: 1, minAge: 5
        ),
        WhoseRound(
            id: "wt-fb-poss-hare", subtask: .possessiveTail,
            cueImage: "tail_hare", question: "Чей это хвост?",
            options: [
                .init(id: "wt-fb-poss-hare-c", word: "заяц", imageAsset: "word_hare",
                      isCorrect: true, form: "заячий хвост"),
                .init(id: "wt-fb-poss-hare-d1", word: "кот", imageAsset: "word_cat",
                      isCorrect: false, form: "кошачий хвост")
            ],
            spokenForm: "Это заячий хвост.", difficulty: 1, minAge: 5
        ),
        WhoseRound(
            id: "wt-fb-poss-wolf", subtask: .possessiveTail,
            cueImage: "tail_volk", question: "Чей это хвост?",
            options: [
                .init(id: "wt-fb-poss-wolf-c", word: "волк", imageAsset: "word_volk",
                      isCorrect: true, form: "волчий хвост"),
                .init(id: "wt-fb-poss-wolf-d1", word: "лиса", imageAsset: "word_fox",
                      isCorrect: false, form: "лисий хвост"),
                .init(id: "wt-fb-poss-wolf-d2", word: "собака", imageAsset: "word_sobaka",
                      isCorrect: false, form: "собачий хвост")
            ],
            spokenForm: "Это волчий хвост.", difficulty: 2, minAge: 6
        ),
        WhoseRound(
            id: "wt-fb-home-fox", subtask: .animalHome,
            cueImage: "home_nora_fox", question: "Чей это домик? Чья это нора?",
            options: [
                .init(id: "wt-fb-home-fox-c", word: "лиса", imageAsset: "word_fox",
                      isCorrect: true, form: "лисья нора"),
                .init(id: "wt-fb-home-fox-d1", word: "белка", imageAsset: "word_belka",
                      isCorrect: false, form: "беличье дупло")
            ],
            spokenForm: "Это лисья нора.", difficulty: 2, minAge: 6
        ),
        WhoseRound(
            id: "wt-fb-home-bear", subtask: .animalHome,
            cueImage: "home_berloga", question: "Чей это домик? Чья это берлога?",
            options: [
                .init(id: "wt-fb-home-bear-c", word: "медведь", imageAsset: "word_bear",
                      isCorrect: true, form: "медвежья берлога"),
                .init(id: "wt-fb-home-bear-d1", word: "волк", imageAsset: "word_volk",
                      isCorrect: false, form: "волчье логово")
            ],
            spokenForm: "Это медвежья берлога.", difficulty: 2, minAge: 6
        ),
        WhoseRound(
            id: "wt-fb-rel-stol", subtask: .relativeMaterial,
            cueImage: "word_stol", question: "Из чего сделан стол?",
            options: [
                .init(id: "wt-fb-rel-stol-c", word: "дерево", imageAsset: "word_derevo",
                      isCorrect: true, form: "деревянный стол"),
                .init(id: "wt-fb-rel-stol-d1", word: "бумага", imageAsset: "word_bumaga",
                      isCorrect: false, form: "бумажный стол")
            ],
            spokenForm: "Стол деревянный.", difficulty: 2, minAge: 6
        )
    ]
}
