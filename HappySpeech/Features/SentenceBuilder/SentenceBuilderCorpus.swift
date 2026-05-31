import Foundation
import OSLog

// MARK: - SentenceBuilderCorpus
//
// F2-004 «Конструктор предложения» (Wave 2).
//
// Корпус заданий синтаксиса. Загружается из `pack_sentence_builder.json` (своя
// схема, как `pack_fourth_extra.json` / `pack_whose_tail.json`). Каждый раунд —
// сцена-подсказка + банк слов-карточек (включая дистракторы) + допустимые
// порядки сборки. Полностью offline / on-device.

enum SentenceBuilderCorpus {

    /// Сколько раундов в одной сессии (8–12, антифатиговое правило).
    static var roundsPerSession: Int { SentenceBuilderPackLoader.shared.roundsPerSession }

    /// Все раунды корпуса.
    static var allRounds: [SentenceRound] { SentenceBuilderPackLoader.shared.rounds }

    /// Раунды заданного под-типа.
    static func rounds(for subtask: SentenceSubtask) -> [SentenceRound] {
        allRounds.filter { $0.subtask == subtask }
    }

    /// Раунды под-типа, не превышающие возрастной гейт (minAge ≤ age).
    static func rounds(for subtask: SentenceSubtask, maxAge age: Int) -> [SentenceRound] {
        rounds(for: subtask).filter { $0.minAge <= age }
    }

    /// Все раунды, доступные ребёнку по возрасту (любой под-тип, minAge ≤ age).
    static func rounds(maxAge age: Int) -> [SentenceRound] {
        allRounds.filter { $0.minAge <= age }
    }

    /// «Лёгкие» раунды (difficulty == 1) для ретро-старта.
    static func easyRounds(maxAge age: Int) -> [SentenceRound] {
        let pool = rounds(maxAge: age)
        let easy = pool.filter { $0.difficulty <= 1 }
        return easy.isEmpty ? pool : easy
    }
}

// MARK: - SentenceBuilderPackLoader
//
// Разбирает `pack_sentence_builder.json` один раз. Отбрасывает раунды без
// валидных acceptedOrders / без покрытия токенами / без согласованного slotCount
// (валидация корпуса). При отказе бандла возвращает безопасный минимальный
// набор, чтобы модуль оставался рабочим (≥ 6 раундов).

struct SentenceBuilderPackLoader {

    static let shared = SentenceBuilderPackLoader()

    let roundsPerSession: Int
    let rounds: [SentenceRound]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SentenceBuilder.PackLoader"
    )

    private struct Pack: Decodable {
        let roundsPerSession: Int
        let items: [ItemDTO]
    }

    private struct ItemDTO: Decodable {
        let id: String
        let subtask: String
        let sceneImage: String
        let difficulty: Int
        let minAge: Int
        let tokens: [TokenDTO]
        let distractors: [TokenDTO]?
        let acceptedOrders: [[String]]
        let spokenSentence: String
    }

    private struct TokenDTO: Decodable {
        let id: String
        let text: String
        let imageAsset: String?
        let role: String
    }

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_sentence_builder", withExtension: "json"
        ) else {
            Self.logger.error("pack_sentence_builder.json not found in bundle — using fallback")
            roundsPerSession = 10
            rounds = SentenceBuilderPackLoader.fallbackRounds
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            roundsPerSession = max(6, pack.roundsPerSession)
            let decoded = pack.items.compactMap(Self.makeRound)
            rounds = decoded.isEmpty ? SentenceBuilderPackLoader.fallbackRounds : decoded
        } catch {
            Self.logger.error(
                "pack_sentence_builder.json decode error: \(error.localizedDescription, privacy: .public)"
            )
            roundsPerSession = 10
            rounds = SentenceBuilderPackLoader.fallbackRounds
        }
    }

    private static func makeRound(_ dto: ItemDTO) -> SentenceRound? {
        guard let subtask = SentenceSubtask(rawValue: dto.subtask) else {
            logger.error("Unknown subtask: \(dto.subtask, privacy: .public)")
            return nil
        }

        let core = dto.tokens.compactMap(Self.makeToken(isDistractor: false))
        let distractors = (dto.distractors ?? []).compactMap(Self.makeToken(isDistractor: true))
        let bankTokens = core + distractors

        // Валидация: непустые порядки; каждый id порядка покрыт core-токеном;
        // длина каждого порядка совпадает; slotCount = длина порядка.
        guard !dto.acceptedOrders.isEmpty,
              dto.acceptedOrders.allSatisfy({ !$0.isEmpty }) else {
            logger.error("Empty acceptedOrders in \(dto.id, privacy: .public)")
            return nil
        }
        let coreIds = Set(core.map(\.id))
        let lengths = Set(dto.acceptedOrders.map(\.count))
        guard lengths.count == 1, let slotCount = lengths.first else {
            logger.error("Inconsistent acceptedOrders length in \(dto.id, privacy: .public)")
            return nil
        }
        let allOrderIdsCovered = dto.acceptedOrders.allSatisfy { order in
            order.allSatisfy { coreIds.contains($0) }
        }
        guard allOrderIdsCovered else {
            logger.error("acceptedOrders reference unknown token in \(dto.id, privacy: .public)")
            return nil
        }

        return SentenceRound(
            id: dto.id,
            subtask: subtask,
            sceneImage: dto.sceneImage,
            bankTokens: bankTokens,
            slotCount: slotCount,
            acceptedOrders: dto.acceptedOrders,
            spokenSentence: dto.spokenSentence,
            difficulty: dto.difficulty,
            minAge: dto.minAge
        )
    }

    private static func makeToken(
        isDistractor: Bool
    ) -> (TokenDTO) -> SentenceToken? {
        { dto in
            guard let role = TokenRole(rawValue: dto.role) else {
                logger.error("Unknown role: \(dto.role, privacy: .public)")
                return nil
            }
            return SentenceToken(
                id: dto.id,
                text: dto.text,
                imageAsset: dto.imageAsset,
                role: role,
                isDistractor: isDistractor
            )
        }
    }

    // MARK: Fallback (минимальный рабочий набор ≥ 6 раундов)

    private static let fallbackRounds: [SentenceRound] = [
        SentenceRound(
            id: "sb-fb-order-cat", subtask: .wordOrder,
            sceneImage: "cat.fill",
            bankTokens: [
                .init(id: "fb-cat-1", text: "кот", role: .subject),
                .init(id: "fb-cat-2", text: "спит", role: .verb),
                .init(id: "fb-cat-3", text: "на", role: .prep),
                .init(id: "fb-cat-4", text: "диване", role: .object)
            ],
            slotCount: 4,
            acceptedOrders: [["fb-cat-1", "fb-cat-2", "fb-cat-3", "fb-cat-4"]],
            spokenSentence: "Кот спит на диване.", difficulty: 1, minAge: 6
        ),
        SentenceRound(
            id: "sb-fb-order-fish", subtask: .wordOrder,
            sceneImage: "fish.fill",
            bankTokens: [
                .init(id: "fb-fish-1", text: "рыба", role: .subject),
                .init(id: "fb-fish-2", text: "плывёт", role: .verb),
                .init(id: "fb-fish-3", text: "в", role: .prep),
                .init(id: "fb-fish-4", text: "воде", role: .object)
            ],
            slotCount: 4,
            acceptedOrders: [["fb-fish-1", "fb-fish-2", "fb-fish-3", "fb-fish-4"]],
            spokenSentence: "Рыба плывёт в воде.", difficulty: 1, minAge: 6
        ),
        SentenceRound(
            id: "sb-fb-order-boy", subtask: .wordOrder,
            sceneImage: "book.fill",
            bankTokens: [
                .init(id: "fb-boy-1", text: "мальчик", role: .subject),
                .init(id: "fb-boy-2", text: "читает", role: .verb),
                .init(id: "fb-boy-3", text: "книгу", role: .object)
            ],
            slotCount: 3,
            acceptedOrders: [["fb-boy-1", "fb-boy-2", "fb-boy-3"]],
            spokenSentence: "Мальчик читает книгу.", difficulty: 1, minAge: 6
        ),
        SentenceRound(
            id: "sb-fb-agree-apple", subtask: .agreement,
            sceneImage: "apple.logo",
            bankTokens: [
                .init(id: "fb-ap-adj-m", text: "красный", role: .adjective),
                .init(id: "fb-ap-adj-f", text: "красная", role: .adjective),
                .init(id: "fb-ap-adj-n", text: "красное", role: .adjective),
                .init(id: "fb-ap-noun", text: "яблоко", role: .noun)
            ],
            slotCount: 2,
            acceptedOrders: [["fb-ap-adj-n", "fb-ap-noun"]],
            spokenSentence: "Красное яблоко.", difficulty: 2, minAge: 6
        ),
        SentenceRound(
            id: "sb-fb-agree-dog", subtask: .agreement,
            sceneImage: "pawprint.fill",
            bankTokens: [
                .init(id: "fb-dog-adj-m", text: "большой", role: .adjective),
                .init(id: "fb-dog-adj-f", text: "большая", role: .adjective),
                .init(id: "fb-dog-adj-n", text: "большое", role: .adjective),
                .init(id: "fb-dog-noun", text: "собака", role: .noun)
            ],
            slotCount: 2,
            acceptedOrders: [["fb-dog-adj-f", "fb-dog-noun"]],
            spokenSentence: "Большая собака.", difficulty: 2, minAge: 6
        ),
        SentenceRound(
            id: "sb-fb-prep-bird", subtask: .preposition,
            sceneImage: "bird.fill",
            bankTokens: [
                .init(id: "fb-bird-1", text: "птица", role: .subject),
                .init(id: "fb-bird-2", text: "сидит", role: .verb),
                .init(id: "fb-bird-p-on", text: "на", role: .prep),
                .init(id: "fb-bird-p-under", text: "под", role: .prep),
                .init(id: "fb-bird-3", text: "дереве", role: .object)
            ],
            slotCount: 4,
            acceptedOrders: [["fb-bird-1", "fb-bird-2", "fb-bird-p-on", "fb-bird-3"]],
            spokenSentence: "Птица сидит на дереве.", difficulty: 2, minAge: 6
        )
    ]
}
