import Foundation
import OSLog

// MARK: - WhoseTailWorkerProtocol

@MainActor
protocol WhoseTailWorkerProtocol: AnyObject {
    /// Собирает сессию словообразования прилагательных для ребёнка. Под-тип —
    /// предпочтительный (из трека) либо подобранный по возрасту.
    func buildSession(
        childId: String,
        preferredSubtask: WhoseSubtask?
    ) async -> WhoseTailModels.Start.Response
}

// MARK: - WhoseTailWorker (Clean Swift: Worker)
//
// F2-006 «Чей хвост / чей домик» (Wave 2).
//
// Формирует сессию словообразования прилагательных:
//   • под-тип подбирается по возрасту/треку либо задаётся (с гейтом);
//   • возрастной гейт: possessiveTail ≥ 5, animalHome ≥ 6, relativeMaterial ≥ 6;
//     тонкие (difficulty 3) — фактически ≥ 7 по minAge в корпусе;
//   • ретро-старт: первые 2 раунда — лёгкие (possessiveTail, difficulty 1),
//     F1-015;
//   • прогрессия по онтогенезу: сначала притяжательные (possessiveTail) —
//     раньше, затем подмешиваются animalHome / relativeMaterial по возрасту;
//   • антифатиговое чередование: никогда 2 одинаковых под-типа подряд;
//   • варианты внутри каждого раунда перемешиваются (число опций 2/3/4 уже
//     задано difficulty в корпусе; ответ не «прибит» к позиции).
// Offline / on-device — корпус локальный.

@MainActor
final class WhoseTailWorker: WhoseTailWorkerProtocol {

    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WhoseTail.Worker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func buildSession(
        childId: String,
        preferredSubtask: WhoseSubtask?
    ) async -> WhoseTailModels.Start.Response {
        var age = 6
        do {
            let child = try await childRepository.fetch(id: childId)
            age = child.age
        } catch {
            Self.logger.error(
                "Failed to read child, using defaults: \(error.localizedDescription, privacy: .public)"
            )
        }

        let rounds = Self.makeRounds(preferredSubtask: preferredSubtask, age: age)

        Self.logger.debug(
            "Built whose-tail session: \(rounds.count) rounds, age \(age, privacy: .public)"
        )
        return .init(rounds: rounds, soundTarget: "грамматика.притяжат", childAge: age)
    }

    // MARK: - Subtask resolution (возрастной гейт)

    /// Допустим ли под-тип для возраста (возрастной гейт).
    static func isAllowed(_ subtask: WhoseSubtask, age: Int) -> Bool {
        age >= subtask.minAge
    }

    /// Подбирает предпочтительный под-тип: если задан и доступен по возрасту —
    /// он; иначе самый ранний по онтогенезу доступный (possessiveTail).
    static func resolveSubtask(preferredSubtask: WhoseSubtask?, age: Int) -> WhoseSubtask {
        if let preferred = preferredSubtask, isAllowed(preferred, age: age) {
            return preferred
        }
        return .possessiveTail
    }

    // MARK: - Round building

    /// Раунды: ретро-старт (2 лёгких possessiveTail-раунда) + основная часть с
    /// ротацией под-типов. Антифатиговое правило: соседние раунды не повторяют
    /// под-тип.
    static func makeRounds(
        preferredSubtask: WhoseSubtask?,
        age: Int
    ) -> [WhoseRound] {
        let total = WhoseTailCorpus.roundsPerSession
        var rounds: [WhoseRound] = []

        // Ретро-старт: первые 2 раунда — лёгкие (possessiveTail, difficulty 1),
        // F1-015.
        let easy = WhoseTailCorpus
            .rounds(for: .possessiveTail, maxAge: age)
            .filter { $0.difficulty <= 1 }
            .shuffled()
        appendAlternating(from: easy, count: 2, into: &rounds)

        // Основная часть: все доступные по возрасту под-типы.
        // Если задан предпочтительный — его раунды первыми; иначе по онтогенезу
        // приоритет possessiveTail, затем остальное.
        let resolved = resolveSubtask(preferredSubtask: preferredSubtask, age: age)
        var main = WhoseTailCorpus.rounds(maxAge: age).shuffled()
        if preferredSubtask != nil {
            let preferred = main.filter { $0.subtask == resolved }
            let rest = main.filter { $0.subtask != resolved }
            main = preferred + rest
        }
        let remaining = max(0, total - rounds.count)
        appendAlternating(from: main, count: remaining, into: &rounds)

        // Гарантия непустой сессии (на отказ корпуса).
        if rounds.isEmpty {
            let fallback = WhoseTailCorpus.allRounds
            appendAlternating(from: fallback, count: max(1, total), into: &rounds)
        }

        // Перемешиваем варианты внутри каждого раунда (ответ не привязан к позиции).
        return rounds.map(Self.shufflingOptions)
    }

    /// Добавляет до `count` раундов, избегая двух одинаковых под-типов подряд и
    /// повторов одной улики/набора в сессии (по базовому id без сессионного
    /// суффикса).
    private static func appendAlternating(
        from pool: [WhoseRound],
        count: Int,
        into rounds: inout [WhoseRound]
    ) {
        guard count > 0, !pool.isEmpty else { return }
        let usedBaseIds = Set(rounds.map { baseId($0.id) })
        var available = pool.filter { !usedBaseIds.contains(baseId($0.id)) }
        var added = 0
        while added < count, !available.isEmpty {
            let lastSubtask = rounds.last?.subtask
            let pickIndex = available.firstIndex { $0.subtask != lastSubtask } ?? 0
            let round = available.remove(at: pickIndex)
            rounds.append(reindexed(round, sessionIndex: rounds.count))
            added += 1
        }
    }

    /// Базовый id раунда без сессионного суффикса `#index`.
    private static func baseId(_ id: String) -> String {
        id.split(separator: "#").first.map(String.init) ?? id
    }

    /// Уникализирует id раунда в рамках сессии (повтор набора недопустим, id
    /// остаётся стабильным для VM/анимаций).
    private static func reindexed(_ round: WhoseRound, sessionIndex: Int) -> WhoseRound {
        WhoseRound(
            id: "\(round.id)#\(sessionIndex)",
            subtask: round.subtask,
            cueImage: round.cueImage,
            question: round.question,
            options: round.options,
            spokenForm: round.spokenForm,
            difficulty: round.difficulty,
            minAge: round.minAge
        )
    }

    /// Перемешивает порядок вариантов раунда (детерминизм ответа — по id, не
    /// позиции).
    static func shufflingOptions(_ round: WhoseRound) -> WhoseRound {
        WhoseRound(
            id: round.id,
            subtask: round.subtask,
            cueImage: round.cueImage,
            question: round.question,
            options: round.options.shuffled(),
            spokenForm: round.spokenForm,
            difficulty: round.difficulty,
            minAge: round.minAge
        )
    }
}
