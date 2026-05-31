import Foundation
import OSLog

// MARK: - SentenceBuilderWorkerProtocol

@MainActor
protocol SentenceBuilderWorkerProtocol: AnyObject {
    /// Собирает сессию синтаксиса для ребёнка. Под-тип — предпочтительный
    /// (из трека) либо подобранный по возрасту.
    func buildSession(
        childId: String,
        preferredSubtask: SentenceSubtask?
    ) async -> SentenceBuilderModels.Start.Response
}

// MARK: - SentenceBuilderWorker (Clean Swift: Worker)
//
// F2-004 «Конструктор предложения» (Wave 2).
//
// Формирует сессию синтаксиса:
//   • под-тип подбирается по возрасту/треку либо задаётся (с гейтом);
//   • возрастной гейт: wordOrder/agreement/preposition ≥ 6 (по minAge корпуса);
//     hard (множ. согласование, multi-distractor) — фактически ≥ 7–8;
//   • ретро-старт: первые 2 раунда — лёгкие (wordOrder, difficulty 1), F1-015;
//   • антифатиговое чередование: никогда 2 одинаковых под-типа подряд;
//   • карточки банка внутри каждого раунда перемешиваются (ответ не «прибит» к
//     позиции в банке);
//   • один и тот же набор не повторяется в сессии.
// Offline / on-device — корпус локальный.

@MainActor
final class SentenceBuilderWorker: SentenceBuilderWorkerProtocol {

    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SentenceBuilder.Worker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func buildSession(
        childId: String,
        preferredSubtask: SentenceSubtask?
    ) async -> SentenceBuilderModels.Start.Response {
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
            "Built sentence-builder session: \(rounds.count) rounds, age \(age, privacy: .public)"
        )
        return .init(rounds: rounds, soundTarget: "грамматика.синтаксис", childAge: age)
    }

    // MARK: - Subtask resolution (возрастной гейт)

    /// Допустим ли под-тип для возраста (возрастной гейт).
    static func isAllowed(_ subtask: SentenceSubtask, age: Int) -> Bool {
        age >= subtask.minAge
    }

    /// Подбирает предпочтительный под-тип: если задан и доступен по возрасту —
    /// он; иначе самый ранний доступный (wordOrder).
    static func resolveSubtask(preferredSubtask: SentenceSubtask?, age: Int) -> SentenceSubtask {
        if let preferred = preferredSubtask, isAllowed(preferred, age: age) {
            return preferred
        }
        return .wordOrder
    }

    // MARK: - Round building

    /// Раунды: ретро-старт (2 лёгких wordOrder-раунда) + основная часть с
    /// ротацией под-типов. Антифатиговое правило: соседние раунды не повторяют
    /// под-тип.
    static func makeRounds(
        preferredSubtask: SentenceSubtask?,
        age: Int
    ) -> [SentenceRound] {
        let total = SentenceBuilderCorpus.roundsPerSession
        var rounds: [SentenceRound] = []

        // Ретро-старт: первые 2 раунда — лёгкие (wordOrder, difficulty 1), F1-015.
        // Порядок среди равно-лёгких раундов стабилен (по id): на трудность это
        // не влияет, зато первый кадр сессии детерминирован (стабильные
        // снапшоты). Вариативность сессии обеспечивает перемешанная основная
        // часть + перемешивание карточек банка внутри раунда.
        let easy = SentenceBuilderCorpus
            .rounds(for: .wordOrder, maxAge: age)
            .filter { $0.difficulty <= 1 }
            .sorted { $0.id < $1.id }
        appendAlternating(from: easy, count: 2, into: &rounds)

        // Основная часть: все доступные по возрасту под-типы.
        let resolved = resolveSubtask(preferredSubtask: preferredSubtask, age: age)
        var main = SentenceBuilderCorpus.rounds(maxAge: age).shuffled()
        if preferredSubtask != nil {
            let preferred = main.filter { $0.subtask == resolved }
            let rest = main.filter { $0.subtask != resolved }
            main = preferred + rest
        }
        let remaining = max(0, total - rounds.count)
        appendAlternating(from: main, count: remaining, into: &rounds)

        // Гарантия непустой сессии при отказе корпуса — но НЕ в обход возрастного
        // гейта: подмешиваем только доступные по возрасту раунды. Если по возрасту
        // нет ни одного раунда (синтаксис недоступен младше 6), сессия пустая —
        // механика не должна выдавать недоступный возрасту контент.
        if rounds.isEmpty {
            let fallback = SentenceBuilderCorpus.rounds(maxAge: age)
            appendAlternating(from: fallback, count: max(1, total), into: &rounds)
        }

        // Перемешиваем карточки банка внутри каждого раунда (ответ не привязан к
        // позиции карточки в банке).
        return rounds.map(Self.shufflingBank)
    }

    /// Добавляет до `count` раундов, избегая двух одинаковых под-типов подряд и
    /// повторов одного набора (по базовому id без сессионного суффикса).
    private static func appendAlternating(
        from pool: [SentenceRound],
        count: Int,
        into rounds: inout [SentenceRound]
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

    /// Уникализирует id раунда в рамках сессии (id остаётся стабильным для
    /// VM/анимаций), сохраняя все остальные поля (включая acceptedOrders).
    private static func reindexed(_ round: SentenceRound, sessionIndex: Int) -> SentenceRound {
        SentenceRound(
            id: "\(round.id)#\(sessionIndex)",
            subtask: round.subtask,
            sceneImage: round.sceneImage,
            bankTokens: round.bankTokens,
            slotCount: round.slotCount,
            acceptedOrders: round.acceptedOrders,
            spokenSentence: round.spokenSentence,
            difficulty: round.difficulty,
            minAge: round.minAge
        )
    }

    /// Перемешивает порядок карточек банка раунда (acceptedOrders по id — не по
    /// позиции — поэтому оценка остаётся детерминированной).
    static func shufflingBank(_ round: SentenceRound) -> SentenceRound {
        SentenceRound(
            id: round.id,
            subtask: round.subtask,
            sceneImage: round.sceneImage,
            bankTokens: round.bankTokens.shuffled(),
            slotCount: round.slotCount,
            acceptedOrders: round.acceptedOrders,
            spokenSentence: round.spokenSentence,
            difficulty: round.difficulty,
            minAge: round.minAge
        )
    }
}
