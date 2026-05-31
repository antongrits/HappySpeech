import Foundation
import OSLog

// MARK: - FourthExtraCorpus
//
// F2-005 «Четвёртый лишний» (Wave 2).
//
// Корпус наборов классификации/обобщения. Загружается из
// `pack_fourth_extra.json` (своя схема, как `pack_sound_detective.json`).
// Каждый набор — ровно 4 карточки с ровно одной `isExtra:true`. Все
// `imageAsset` проверены по `word_manifest.json`. Полностью offline /
// on-device.

enum FourthExtraCorpus {

    /// Сколько раундов в одной сессии (9–12, антифатиговое правило).
    static var roundsPerSession: Int { FourthExtraPackLoader.shared.roundsPerSession }

    /// Все наборы корпуса.
    static var allRounds: [FourthExtraRound] { FourthExtraPackLoader.shared.rounds }

    /// Наборы заданного варианта.
    static func rounds(for variant: ExtraVariant) -> [FourthExtraRound] {
        allRounds.filter { $0.variant == variant }
    }

    /// Наборы варианта, не превышающие возрастной гейт (minAge ≤ age).
    static func rounds(for variant: ExtraVariant, maxAge age: Int) -> [FourthExtraRound] {
        rounds(for: variant).filter { $0.minAge <= age }
    }

    /// «Лёгкие» наборы (difficulty == 1) для ретро-старта.
    static func easyRounds(for variant: ExtraVariant, maxAge age: Int) -> [FourthExtraRound] {
        let pool = rounds(for: variant, maxAge: age)
        let easy = pool.filter { $0.difficulty <= 1 }
        return easy.isEmpty ? pool : easy
    }

    /// Фонетические наборы варианта с приоритетом целевых звуков ребёнка.
    /// Если целевых наборов мало — добивает остальными.
    static func phoneticRounds(
        maxAge age: Int,
        targetSounds: [String]
    ) -> [FourthExtraRound] {
        let pool = rounds(for: .phonetic, maxAge: age)
        guard !targetSounds.isEmpty else { return pool }
        let normalized = Set(targetSounds.map { $0.uppercased() })
        let preferred = pool.filter { round in
            guard let sound = round.targetSound?.uppercased() else { return false }
            return normalized.contains(sound)
        }
        let rest = pool.filter { round in
            guard let sound = round.targetSound?.uppercased() else { return true }
            return !normalized.contains(sound)
        }
        return preferred + rest
    }
}

// MARK: - FourthExtraPackLoader
//
// Разбирает `pack_fourth_extra.json` один раз. Отбрасывает наборы без ровно
// одной `isExtra:true` (валидация корпуса). При отказе бандла возвращает
// безопасный минимальный набор, чтобы модуль оставался рабочим.

struct FourthExtraPackLoader {

    static let shared = FourthExtraPackLoader()

    let roundsPerSession: Int
    let rounds: [FourthExtraRound]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "FourthExtra.PackLoader"
    )

    private struct Pack: Decodable {
        let roundsPerSession: Int
        let items: [ItemDTO]
    }

    private struct ItemDTO: Decodable {
        let id: String
        let variant: String
        let rule: String
        let categoryLabel: String?
        let targetSound: String?
        let difficulty: Int
        let minAge: Int
        let members: [MemberDTO]
    }

    private struct MemberDTO: Decodable {
        let word: String
        let imageAsset: String
        let isExtra: Bool
        let extraReason: String?
    }

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_fourth_extra", withExtension: "json"
        ) else {
            Self.logger.error("pack_fourth_extra.json not found in bundle — using fallback")
            roundsPerSession = 10
            rounds = FourthExtraPackLoader.fallbackRounds
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            roundsPerSession = max(6, pack.roundsPerSession)
            let decoded = pack.items.compactMap(Self.makeRound)
            rounds = decoded.isEmpty ? FourthExtraPackLoader.fallbackRounds : decoded
        } catch {
            Self.logger.error(
                "pack_fourth_extra.json decode error: \(error.localizedDescription, privacy: .public)"
            )
            roundsPerSession = 10
            rounds = FourthExtraPackLoader.fallbackRounds
        }
    }

    private static func makeRound(_ dto: ItemDTO) -> FourthExtraRound? {
        guard let variant = ExtraVariant(rawValue: dto.variant) else {
            logger.error("Unknown variant: \(dto.variant, privacy: .public)")
            return nil
        }
        guard let rule = ExtraRule(rawValue: dto.rule) else {
            logger.error("Unknown rule: \(dto.rule, privacy: .public)")
            return nil
        }
        let cards = dto.members.enumerated().map { index, member in
            ExtraCard(
                id: "\(dto.id)-\(index)",
                word: member.word,
                imageAsset: member.imageAsset,
                isExtra: member.isExtra,
                extraReason: member.extraReason
            )
        }
        // Валидация: ровно 4 карточки и ровно одна «лишняя».
        guard cards.count == 4, cards.filter(\.isExtra).count == 1 else {
            logger.error("Invalid set (cards/extra count): \(dto.id, privacy: .public)")
            return nil
        }
        return FourthExtraRound(
            id: dto.id,
            variant: variant,
            rule: rule,
            categoryLabel: dto.categoryLabel,
            targetSound: dto.targetSound,
            cards: cards,
            difficulty: dto.difficulty,
            minAge: dto.minAge
        )
    }

    // MARK: Fallback (минимальный рабочий набор)

    private static let fallbackRounds: [FourthExtraRound] = [
        FourthExtraRound(
            id: "fe-fb-fruits", variant: .semantic, rule: .category,
            categoryLabel: "фрукты", targetSound: nil,
            cards: [
                .init(id: "fe-fb-fruits-0", word: "яблоко", imageAsset: "word_apple", isExtra: false, extraReason: nil),
                .init(id: "fe-fb-fruits-1", word: "груша", imageAsset: "word_grusha", isExtra: false, extraReason: nil),
                .init(id: "fe-fb-fruits-2", word: "банан", imageAsset: "word_banan", isExtra: false, extraReason: nil),
                .init(id: "fe-fb-fruits-3", word: "стул", imageAsset: "word_stul", isExtra: true, extraReason: "это мебель, а не фрукт")
            ],
            difficulty: 1, minAge: 5
        ),
        FourthExtraRound(
            id: "fe-fb-dishes", variant: .semantic, rule: .category,
            categoryLabel: "посуда", targetSound: nil,
            cards: [
                .init(id: "fe-fb-dishes-0", word: "чашка", imageAsset: "word_chashka", isExtra: false, extraReason: nil),
                .init(id: "fe-fb-dishes-1", word: "тарелка", imageAsset: "word_tarelka", isExtra: false, extraReason: nil),
                .init(id: "fe-fb-dishes-2", word: "ложка", imageAsset: "word_spoon", isExtra: false, extraReason: nil),
                .init(id: "fe-fb-dishes-3", word: "медведь", imageAsset: "word_bear", isExtra: true, extraReason: "это животное, а не посуда")
            ],
            difficulty: 1, minAge: 5
        ),
        FourthExtraRound(
            id: "fe-fb-phon-sh", variant: .phonetic, rule: .sound,
            categoryLabel: nil, targetSound: "Ш",
            cards: [
                .init(id: "fe-fb-phon-sh-0", word: "шапка", imageAsset: "word_hat", isExtra: false, extraReason: nil),
                .init(id: "fe-fb-phon-sh-1", word: "шуба", imageAsset: "word_shuba", isExtra: false, extraReason: nil),
                .init(id: "fe-fb-phon-sh-2", word: "машина", imageAsset: "word_car", isExtra: false, extraReason: nil),
                .init(id: "fe-fb-phon-sh-3", word: "рак", imageAsset: "word_rak", isExtra: true, extraReason: "в слове нет звука Ш")
            ],
            difficulty: 2, minAge: 6
        )
    ]
}
