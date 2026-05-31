import Foundation
import OSLog

// MARK: - WordFormationWorkerProtocol

@MainActor
protocol WordFormationWorkerProtocol: AnyObject {
    /// Собирает сессию словообразования для ребёнка. Под-тип —
    /// предпочтительный (из трека) либо подобранный по возрасту.
    func buildSession(
        childId: String,
        preferredSubtask: FormationSubtask?
    ) async -> WordFormationModels.Start.Response
}

// MARK: - WordFormationWorker (Clean Swift: Worker)
//
// F2-007 «Назови ласково / Один-много-нет» (Wave 2).
//
// Формирует сессию словообразования/словоизменения:
//   • под-тип подбирается по возрасту/треку либо задаётся (с гейтом);
//   • возрастной гейт: diminutive/oneMany ≥ 5, manyOf ≥ 6;
//   • ретро-старт: первые 2 раунда — лёгкие (diminutive, difficulty 1), F1-015;
//   • антифатиговое чередование: никогда 2 одинаковых под-типа подряд;
//   • варианты внутри каждого раунда перемешиваются (ответ не «прибит» к позиции).
// Offline / on-device — корпус локальный.

@MainActor
final class WordFormationWorker: WordFormationWorkerProtocol {

    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WordFormation.Worker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func buildSession(
        childId: String,
        preferredSubtask: FormationSubtask?
    ) async -> WordFormationModels.Start.Response {
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
            "Built word-formation session: \(rounds.count) rounds, age \(age, privacy: .public)"
        )
        return .init(rounds: rounds, soundTarget: "грамматика.словообр", childAge: age)
    }

    // MARK: - Subtask resolution (возрастной гейт)

    /// Допустим ли под-тип для возраста (возрастной гейт).
    static func isAllowed(_ subtask: FormationSubtask, age: Int) -> Bool {
        age >= subtask.minAge
    }

    /// Подбирает предпочтительный под-тип: если задан и доступен по возрасту —
    /// он; иначе самый лёгкий доступный (diminutive). manyOf не выдаём до 6.
    static func resolveSubtask(preferredSubtask: FormationSubtask?, age: Int) -> FormationSubtask {
        if let preferred = preferredSubtask, isAllowed(preferred, age: age) {
            return preferred
        }
        return .diminutive
    }

    // MARK: - Round building

    /// Раунды: ретро-старт (2 лёгких diminutive-раунда) + основная часть с
    /// ротацией под-типов. Антифатиговое правило: соседние раунды не повторяют
    /// под-тип.
    static func makeRounds(
        preferredSubtask: FormationSubtask?,
        age: Int
    ) -> [FormationRound] {
        let total = WordFormationCorpus.roundsPerSession
        var rounds: [FormationRound] = []

        // Ретро-старт: первые 2 раунда — лёгкие (diminutive, difficulty 1), F1-015.
        let easy = WordFormationCorpus
            .rounds(for: .diminutive, maxAge: age)
            .filter { $0.difficulty <= 1 }
            .shuffled()
        appendAlternating(from: easy, count: 2, into: &rounds)

        // Основная часть: все доступные по возрасту под-типы.
        // Если задан предпочтительный — его раунды первыми.
        let resolved = resolveSubtask(preferredSubtask: preferredSubtask, age: age)
        var main = WordFormationCorpus.rounds(maxAge: age).shuffled()
        if preferredSubtask != nil {
            let preferred = main.filter { $0.subtask == resolved }
            let rest = main.filter { $0.subtask != resolved }
            main = preferred + rest
        }
        let remaining = max(0, total - rounds.count)
        appendAlternating(from: main, count: remaining, into: &rounds)

        // Гарантия непустой сессии (на отказ корпуса).
        if rounds.isEmpty {
            let fallback = WordFormationCorpus.allRounds
            appendAlternating(from: fallback, count: max(1, total), into: &rounds)
        }

        // Перемешиваем варианты внутри каждого раунда (ответ не привязан к позиции).
        return rounds.map(Self.shufflingOptions)
    }

    /// Добавляет до `count` раундов, избегая двух одинаковых под-типов подряд и
    /// повторов одной основы в сессии (по базовому id без сессионного суффикса).
    private static func appendAlternating(
        from pool: [FormationRound],
        count: Int,
        into rounds: inout [FormationRound]
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

    /// Уникализирует id раунда в рамках сессии (повтор основы недопустим, id
    /// остаётся стабильным для VM/анимаций).
    private static func reindexed(_ round: FormationRound, sessionIndex: Int) -> FormationRound {
        FormationRound(
            id: "\(round.id)#\(sessionIndex)",
            subtask: round.subtask,
            baseWord: round.baseWord,
            baseImage: round.baseImage,
            prompt: round.prompt,
            options: round.options,
            spokenForm: round.spokenForm,
            difficulty: round.difficulty,
            minAge: round.minAge
        )
    }

    /// Перемешивает порядок вариантов раунда (детерминизм ответа — по id, не позиции).
    static func shufflingOptions(_ round: FormationRound) -> FormationRound {
        FormationRound(
            id: round.id,
            subtask: round.subtask,
            baseWord: round.baseWord,
            baseImage: round.baseImage,
            prompt: round.prompt,
            options: round.options.shuffled(),
            spokenForm: round.spokenForm,
            difficulty: round.difficulty,
            minAge: round.minAge
        )
    }
}
