import Foundation
import OSLog

// MARK: - FourthExtraWorkerProtocol

@MainActor
protocol FourthExtraWorkerProtocol: AnyObject {
    /// Собирает сессию «Четвёртого лишнего» для ребёнка. Вариант —
    /// предпочтительный (из трека) либо подобранный по возрасту.
    func buildSession(
        childId: String,
        preferredVariant: ExtraVariant?
    ) async -> FourthExtraModels.Start.Response
}

// MARK: - FourthExtraWorker (Clean Swift: Worker)
//
// F2-005 «Четвёртый лишний» (Wave 2).
//
// Формирует сессию классификации/обобщения:
//   • вариант подбирается по возрасту/треку либо задаётся;
//   • возрастной гейт: easy≥5, hard/phonetic≥6, тонкие признаки≥7;
//   • фонетический вариант приоритизирует целевые звуки ребёнка;
//   • ретро-старт: первые 2 раунда — «лёгкие» (явный лишний, difficulty 1);
//   • антифатиговое чередование: никогда 2 одинаковых правила подряд;
//   • карточки внутри каждого набора перемешиваются (ответ не «прибит» к позиции).
// Offline / on-device — корпус локальный.

@MainActor
final class FourthExtraWorker: FourthExtraWorkerProtocol {

    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "FourthExtra.Worker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func buildSession(
        childId: String,
        preferredVariant: ExtraVariant?
    ) async -> FourthExtraModels.Start.Response {
        var age = 6
        var targetSounds: [String] = []
        do {
            let child = try await childRepository.fetch(id: childId)
            age = child.age
            targetSounds = child.targetSounds
        } catch {
            Self.logger.error(
                "Failed to read child, using defaults: \(error.localizedDescription, privacy: .public)"
            )
        }

        let variant = Self.resolveVariant(preferredVariant: preferredVariant, age: age)
        let rounds = Self.makeRounds(variant: variant, age: age, targetSounds: targetSounds)
        let soundTarget = Self.soundTarget(for: variant, rounds: rounds, targetSounds: targetSounds)

        Self.logger.debug(
            "Built fourth-extra session: \(rounds.count) rounds, variant \(variant.rawValue, privacy: .public)"
        )
        return .init(rounds: rounds, soundTarget: soundTarget, childAge: age)
    }

    // MARK: - Variant resolution (возрастной гейт)

    /// Подбирает вариант: предпочтительный, но фонетический недоступен до 6.
    static func resolveVariant(preferredVariant: ExtraVariant?, age: Int) -> ExtraVariant {
        guard let preferred = preferredVariant else {
            // По умолчанию семантический (доступен с 5).
            return .semantic
        }
        // Фонетический вариант — возрастной гейт ≥ 6.
        if preferred == .phonetic, age < 6 {
            return .semantic
        }
        return preferred
    }

    /// «Звук» сессии для record: semantic → "лексика", phonetic → целевой звук.
    static func soundTarget(
        for variant: ExtraVariant,
        rounds: [FourthExtraRound],
        targetSounds: [String]
    ) -> String {
        switch variant {
        case .semantic:
            return "лексика"
        case .phonetic:
            return rounds.compactMap(\.targetSound).first
                ?? targetSounds.first
                ?? "лексика"
        }
    }

    // MARK: - Round building

    /// Раунды: ретро-старт (2 лёгких раунда) + основная часть.
    /// Антифатиговое правило: соседние раунды не повторяют правило.
    static func makeRounds(
        variant: ExtraVariant,
        age: Int,
        targetSounds: [String]
    ) -> [FourthExtraRound] {
        let total = FourthExtraCorpus.roundsPerSession
        var rounds: [FourthExtraRound] = []

        // Ретро-старт: первые 2 раунда — «лёгкие» (явный лишний), F1-015.
        let easy = FourthExtraCorpus.easyRounds(for: variant, maxAge: age).shuffled()
        appendAlternating(from: easy, count: 2, into: &rounds)

        // Основная часть.
        let main: [FourthExtraRound]
        switch variant {
        case .phonetic:
            main = FourthExtraCorpus.phoneticRounds(maxAge: age, targetSounds: targetSounds)
        case .semantic:
            main = FourthExtraCorpus.rounds(for: .semantic, maxAge: age).shuffled()
        }
        let remaining = max(0, total - rounds.count)
        appendAlternating(from: main, count: remaining, into: &rounds)

        // Гарантия непустой сессии (на отказ корпуса).
        if rounds.isEmpty {
            let fallback = FourthExtraCorpus.rounds(for: variant)
            appendAlternating(from: fallback, count: max(1, total), into: &rounds)
        }

        // Перемешиваем карточки внутри каждого набора (ответ не привязан к позиции).
        return rounds.map(Self.shufflingCards)
    }

    /// Добавляет до `count` раундов, избегая двух одинаковых правил подряд и
    /// повторов одного и того же набора в сессии. Сравнение по базовому id
    /// (уже добавленные раунды несут суффикс `#index` после `reindexed`).
    private static func appendAlternating(
        from pool: [FourthExtraRound],
        count: Int,
        into rounds: inout [FourthExtraRound]
    ) {
        guard count > 0, !pool.isEmpty else { return }
        let usedBaseIds = Set(rounds.map { baseId($0.id) })
        var available = pool.filter { candidate in
            !usedBaseIds.contains(baseId(candidate.id))
        }
        var added = 0
        while added < count, !available.isEmpty {
            let lastRule = rounds.last?.rule
            let pickIndex = available.firstIndex { $0.rule != lastRule } ?? 0
            let round = available.remove(at: pickIndex)
            rounds.append(reindexed(round, sessionIndex: rounds.count))
            added += 1
        }
    }

    /// Базовый id набора без сессионного суффикса `#index`.
    private static func baseId(_ id: String) -> String {
        id.split(separator: "#").first.map(String.init) ?? id
    }

    /// Уникализирует id раунда в рамках сессии (повтор набора недопустим, но
    /// id остаётся стабильным для VM/анимаций).
    private static func reindexed(_ round: FourthExtraRound, sessionIndex: Int) -> FourthExtraRound {
        FourthExtraRound(
            id: "\(round.id)#\(sessionIndex)",
            variant: round.variant,
            rule: round.rule,
            categoryLabel: round.categoryLabel,
            targetSound: round.targetSound,
            cards: round.cards,
            difficulty: round.difficulty,
            minAge: round.minAge
        )
    }

    /// Перемешивает порядок карточек набора (детерминизм ответов — по id, не позиции).
    static func shufflingCards(_ round: FourthExtraRound) -> FourthExtraRound {
        FourthExtraRound(
            id: round.id,
            variant: round.variant,
            rule: round.rule,
            categoryLabel: round.categoryLabel,
            targetSound: round.targetSound,
            cards: round.cards.shuffled(),
            difficulty: round.difficulty,
            minAge: round.minAge
        )
    }
}
