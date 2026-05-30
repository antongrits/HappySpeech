import Foundation
import OSLog

// MARK: - SoundDetectiveWorkerProtocol

@MainActor
protocol SoundDetectiveWorkerProtocol: AnyObject {
    /// Собирает сессию «детектива» для ребёнка. Уровень — предпочтительный
    /// (из истории) либо подобранный по возрасту.
    func buildSession(
        childId: String,
        preferredLevel: SoundDetectiveLevel?
    ) async -> SoundDetectiveModels.Start.Response
}

// MARK: - SoundDetectiveWorker (Clean Swift: Worker)
//
// F2-009 «Звуковой детектив» (Wave 2).
//
// Формирует сессию позиционного анализа:
//   • уровень подбирается по возрасту ребёнка (возрастной гейт) либо задаётся;
//   • целевой звук — из targetSounds ребёнка (актуальный рабочий звук);
//   • ретро-старт: первые 2 раунда — на лёгком уровне (binary);
//   • антифатиговое чередование позиций (никогда 2 одинаковых подряд).
// Offline / on-device — корпус локальный.

@MainActor
final class SoundDetectiveWorker: SoundDetectiveWorkerProtocol {

    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundDetective.Worker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func buildSession(
        childId: String,
        preferredLevel: SoundDetectiveLevel?
    ) async -> SoundDetectiveModels.Start.Response {
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

        let level = Self.resolveLevel(preferredLevel: preferredLevel, age: age)
        let rounds = Self.makeRounds(level: level, targetSounds: targetSounds)
        let targetSound = rounds.first?.item.targetSound
            ?? targetSounds.first
            ?? "С"

        Self.logger.debug(
            "Built sound-detective session: \(rounds.count) rounds, level \(level.rawValue, privacy: .public)"
        )
        return .init(rounds: rounds, targetSound: targetSound, level: level)
    }

    // MARK: - Level resolution (возрастной гейт)

    /// Подбирает уровень: предпочтительный, но не выше возрастного гейта.
    static func resolveLevel(preferredLevel: SoundDetectiveLevel?, age: Int) -> SoundDetectiveLevel {
        let ageCap = ageAllowedLevel(age: age)
        guard let preferred = preferredLevel else { return ageCap }
        // Не позволяем подняться выше возрастного гейта.
        return min(preferred, ageCap)
    }

    /// Максимально допустимый уровень для возраста (5 → binary, 6 → ternary, 7+ → withAbsent).
    static func ageAllowedLevel(age: Int) -> SoundDetectiveLevel {
        if age >= SoundDetectiveLevel.withAbsent.minAge { return .withAbsent }
        if age >= SoundDetectiveLevel.ternary.minAge { return .ternary }
        return .binary
    }

    // MARK: - Round building

    /// Раунды: ретро-старт (2 лёгких binary-раунда) + основной уровень.
    /// Антифатиговое правило: соседние раунды не повторяют позицию.
    static func makeRounds(
        level: SoundDetectiveLevel,
        targetSounds: [String]
    ) -> [SoundDetectiveRound] {
        let total = SoundDetectiveCorpus.roundsPerSession
        var rounds: [SoundDetectiveRound] = []

        // Ретро-старт: первые 2 раунда на лёгком уровне (binary), если
        // основной уровень сложнее (F1-015).
        if level != .binary {
            let retro = SoundDetectiveCorpus
                .items(for: .binary, targetSounds: targetSounds)
                .shuffled()
            appendAlternating(from: retro, level: .binary, count: 2, into: &rounds)
        }

        // Основная часть на целевом уровне.
        let main = SoundDetectiveCorpus
            .items(for: level, targetSounds: targetSounds)
            .shuffled()
        let remaining = max(0, total - rounds.count)
        appendAlternating(from: main, level: level, count: remaining, into: &rounds)

        // Гарантия непустой сессии (на отказ корпуса).
        if rounds.isEmpty {
            let fallback = SoundDetectiveCorpus.items(for: level, targetSounds: [])
            appendAlternating(from: fallback, level: level, count: max(1, total), into: &rounds)
        }
        return rounds
    }

    /// Добавляет до `count` раундов, избегая двух одинаковых позиций подряд.
    private static func appendAlternating(
        from pool: [SoundDetectiveItem],
        level: SoundDetectiveLevel,
        count: Int,
        into rounds: inout [SoundDetectiveRound]
    ) {
        guard count > 0, !pool.isEmpty else { return }
        var available = pool
        var added = 0
        while added < count, !available.isEmpty {
            let lastPosition = rounds.last?.item.position
            // Предпочитаем элемент с позицией, отличной от предыдущей.
            let pickIndex = available.firstIndex { $0.position != lastPosition }
                ?? 0
            let item = available.remove(at: pickIndex)
            rounds.append(
                SoundDetectiveRound(id: "\(level.rawValue)-\(item.id)-\(rounds.count)", item: item, level: level)
            )
            added += 1
        }
    }
}

// MARK: - SoundDetectiveLevel Comparable (для возрастного capping)

extension SoundDetectiveLevel: Comparable {
    private var order: Int {
        switch self {
        case .binary:     return 0
        case .ternary:    return 1
        case .withAbsent: return 2
        }
    }
    public static func < (lhs: SoundDetectiveLevel, rhs: SoundDetectiveLevel) -> Bool {
        lhs.order < rhs.order
    }
}
