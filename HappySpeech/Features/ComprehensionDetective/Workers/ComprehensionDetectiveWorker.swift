import Foundation
import OSLog

// MARK: - ComprehensionDetectiveWorkerProtocol

@MainActor
protocol ComprehensionDetectiveWorkerProtocol: AnyObject {
    /// Собирает сессию «Понимание-детектив» для ребёнка. Уровень —
    /// предпочтительный (из трека) либо подобранный по возрасту.
    func buildSession(
        childId: String,
        preferredTier: GrammarTier?
    ) async -> ComprehensionDetectiveModels.Start.Response

    /// Озвучивает инструкцию. `slowly == true` — медленнее и по частям
    /// (errorless-подсказка после промахов).
    func voiceInstruction(_ text: String, slowly: Bool) async
}

// MARK: - ComprehensionDetectiveWorker (Clean Swift: Worker)
//
// v31 Волна B, Функция Ф.2 «Понимание-детектив» (F2-014).
//
// Формирует сессию на понимание устной инструкции:
//   • ведущий уровень подбирается по возрасту (возрастной гейт) либо задаётся,
//     но не выше возрастного потолка (capping);
//   • ретро-старт: первые 2 раунда — на лёгком уровне (одно поручение);
//   • антифатиговое чередование: соседние раунды не повторяют уровень;
//   • картинки внутри каждого раунда перемешиваются (ответ не «прибит» к позиции).
// Offline / on-device — корпус локальный.

@MainActor
final class ComprehensionDetectiveWorker: ComprehensionDetectiveWorkerProtocol {

    private let childRepository: any ChildRepository
    private let randomSource: () -> Double

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ComprehensionDetective.Worker"
    )

    init(
        childRepository: any ChildRepository,
        randomSource: @escaping () -> Double = { Double.random(in: 0..<1) }
    ) {
        self.childRepository = childRepository
        self.randomSource = randomSource
    }

    // MARK: - Build session

    func buildSession(
        childId: String,
        preferredTier: GrammarTier?
    ) async -> ComprehensionDetectiveModels.Start.Response {
        var age = 6
        do {
            let child = try await childRepository.fetch(id: childId)
            age = child.age
        } catch {
            Self.logger.error(
                "Failed to read child, using defaults: \(error.localizedDescription, privacy: .public)"
            )
        }

        let leadTier = Self.resolveTier(preferredTier: preferredTier, age: age)
        let rounds = makeRounds(leadTier: leadTier, age: age)

        Self.logger.debug(
            "Built detective session: \(rounds.count) rounds, lead tier \(leadTier.rawValue, privacy: .public), age \(age, privacy: .public)"
        )
        return .init(
            rounds: rounds,
            soundTarget: "понимание речи",
            childAge: age,
            leadTier: leadTier
        )
    }

    // MARK: - Tier resolution (возрастной гейт)

    /// Подбирает ведущий уровень: предпочтительный, но не выше возрастного гейта.
    static func resolveTier(preferredTier: GrammarTier?, age: Int) -> GrammarTier {
        let ageCap = ageAllowedTier(age: age)
        guard let preferred = preferredTier else { return ageCap }
        return min(preferred, ageCap)
    }

    /// Максимально допустимый уровень для возраста (по minAge уровней).
    static func ageAllowedTier(age: Int) -> GrammarTier {
        GrammarTier.allCases.last { $0.minAge <= age } ?? .simple
    }

    // MARK: - Round building

    /// Раунды: ретро-старт (2 лёгких раунда) + основная часть на ведущем уровне.
    /// Антифатиговое правило: соседние раунды не повторяют уровень.
    func makeRounds(leadTier: GrammarTier, age: Int) -> [DetectiveRound] {
        let total = ComprehensionDetectiveCorpus.roundsPerSession
        var rounds: [DetectiveRound] = []
        var usedItemIds: Set<String> = []

        // Ретро-старт: первые 2 раунда на лёгком уровне (simple), если ведущий
        // уровень сложнее (F1-015).
        if leadTier != .simple {
            let retro = ComprehensionDetectiveCorpus.items(for: .simple, maxAge: age).shuffled()
            appendAlternating(from: retro, count: 2, into: &rounds, used: &usedItemIds)
        }

        // Основная часть: ведущий уровень + соседние (не выше возрастного гейта),
        // чтобы было из чего чередовать.
        let cap = Self.ageAllowedTier(age: age)
        let mainTiers: [GrammarTier] = GrammarTier.allCases.filter { tier in
            tier.rawValue >= max(1, leadTier.rawValue - 1) && tier <= cap
        }
        var mainPool: [DetectiveItem] = mainTiers
            .flatMap { ComprehensionDetectiveCorpus.items(for: $0, maxAge: age) }
        mainPool.shuffle()
        let remaining = max(0, total - rounds.count)
        appendAlternating(from: mainPool, count: remaining, into: &rounds, used: &usedItemIds)

        // Гарантия непустой сессии (на отказ корпуса).
        if rounds.isEmpty {
            let fallback = ComprehensionDetectiveCorpus.items(for: .simple)
            appendAlternating(from: fallback, count: max(1, total), into: &rounds, used: &usedItemIds)
        }
        return rounds
    }

    /// Добавляет до `count` раундов, избегая двух одинаковых уровней подряд и
    /// повторов пунктов в одной сессии.
    private func appendAlternating(
        from pool: [DetectiveItem],
        count: Int,
        into rounds: inout [DetectiveRound],
        used: inout Set<String>
    ) {
        guard count > 0, !pool.isEmpty else { return }
        var available = pool.filter { !used.contains($0.id) }
        var added = 0
        while added < count, !available.isEmpty {
            let lastTier = rounds.last?.item.tier
            // Предпочитаем пункт с уровнем, отличным от предыдущего.
            let pickIndex = available.firstIndex { $0.tier != lastTier } ?? 0
            let item = available.remove(at: pickIndex)
            used.insert(item.id)
            rounds.append(
                DetectiveRound(
                    id: "\(item.id)#\(rounds.count)",
                    item: item,
                    shuffledPictures: shuffle(item.pictures)
                )
            )
            added += 1
        }
    }

    // MARK: - Shuffle (детерминируемый для тестов)

    func shuffle(_ pictures: [DetectivePicture]) -> [DetectivePicture] {
        var array = pictures
        guard array.count > 1 else { return array }
        for index in stride(from: array.count - 1, through: 1, by: -1) {
            let randIndex = Int(randomSource() * Double(index + 1))
            let clamped = max(0, min(index, randIndex))
            array.swapAt(index, clamped)
        }
        return array
    }

    // MARK: - Voice

    func voiceInstruction(_ text: String, slowly: Bool) async {
        await LessonVoiceWorker.shared.speak(
            text,
            lessonType: "comprehension-detective",
            rate: slowly ? 0.78 : 0.95
        )
    }
}

// MARK: - GrammarTier Comparable (для возрастного capping)

extension GrammarTier: Comparable {
    public static func < (lhs: GrammarTier, rhs: GrammarTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
