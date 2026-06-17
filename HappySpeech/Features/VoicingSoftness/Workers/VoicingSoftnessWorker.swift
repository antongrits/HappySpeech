import Foundation
import OSLog

// MARK: - VoicingSoftnessWorkerProtocol

@MainActor
protocol VoicingSoftnessWorkerProtocol: AnyObject {
    /// Собирает сессию тренажёра для ребёнка. Режим — предпочтительный
    /// (из истории) либо подобранный по возрасту.
    func buildSession(
        childId: String,
        preferredMode: VoicingSoftnessMode?
    ) async -> VoicingSoftnessModels.Start.Response
}

// MARK: - VoicingSoftnessWorker (Clean Swift: Worker)
//
// «Карта звонкости и мягкости».
//
// Формирует сессию дифференциации признаков:
//   • режим подбирается по возрасту ребёнка (возрастной гейт) либо задаётся;
//   • целевой звук — из targetSounds ребёнка (актуальный рабочий звук);
//   • антифатиговое чередование (никогда 2 токена одной зоны подряд);
//   • уважает roundsPerSession (9–12, без таймеров).
// Offline / on-device — корпус локальный.

@MainActor
final class VoicingSoftnessWorker: VoicingSoftnessWorkerProtocol {

    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "VoicingSoftness.Worker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func buildSession(
        childId: String,
        preferredMode: VoicingSoftnessMode?
    ) async -> VoicingSoftnessModels.Start.Response {
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

        let mode = Self.resolveMode(preferredMode: preferredMode, age: age)
        return Self.makeSession(mode: mode, targetSounds: targetSounds)
    }

    // MARK: - Mode resolution (возрастной гейт)

    /// Подбирает режим: предпочтительный, но не выше возрастного гейта.
    static func resolveMode(preferredMode: VoicingSoftnessMode?, age: Int) -> VoicingSoftnessMode {
        let ageCap = ageAllowedMode(age: age)
        guard let preferred = preferredMode else { return ageCap }
        return min(preferred, ageCap)
    }

    /// Максимально допустимый режим для возраста (5 → voicing, 6 → softness, 7+ → trapWords).
    static func ageAllowedMode(age: Int) -> VoicingSoftnessMode {
        if age >= VoicingSoftnessMode.trapWords.minAge { return .trapWords }
        if age >= VoicingSoftnessMode.softness.minAge { return .softness }
        return .voicing
    }

    // MARK: - Session building

    static func makeSession(
        mode: VoicingSoftnessMode,
        targetSounds: [String]
    ) -> VoicingSoftnessModels.Start.Response {
        let total = VoicingSoftnessCorpus.roundsPerSession

        switch mode {
        case .voicing, .softness:
            let pool = VoicingSoftnessCorpus.sortItems(for: mode, targetSounds: targetSounds)
            let rounds = makeSortRounds(pool: pool, count: total)
            let target = rounds.first?.baseSound ?? targetSounds.first ?? defaultSound(for: mode)
            Self.logger.debug(
                "Built voicing/softness session: \(rounds.count) sort rounds, mode \(mode.rawValue, privacy: .public)"
            )
            return .init(mode: mode, sortRounds: rounds, trapRounds: [], targetSound: target)

        case .trapWords:
            let pool = VoicingSoftnessCorpus.trapRounds(targetSounds: targetSounds)
            let rounds = makeTrapRounds(pool: pool, count: total)
            let target = rounds.first?.baseSound ?? targetSounds.first ?? "З"
            Self.logger.debug("Built trap-words session: \(rounds.count) trap rounds")
            return .init(mode: mode, sortRounds: [], trapRounds: rounds, targetSound: target)
        }
    }

    /// Дефолтный звук режима (когда у ребёнка нет targetSounds).
    private static func defaultSound(for mode: VoicingSoftnessMode) -> String {
        switch mode {
        case .voicing:   return "Б"
        case .softness:  return "Л"
        case .trapWords: return "З"
        }
    }

    /// Раунды сортировки: антифатиговое чередование зон (не 2 одной зоны подряд).
    /// Когда пул короче нужного числа раундов — переиспользуем его, продолжая
    /// избегать повторов зоны (для устойчиво полной сессии).
    static func makeSortRounds(
        pool: [VoicingSoftnessItem],
        count: Int
    ) -> [VoicingSoftnessItem] {
        guard !pool.isEmpty, count > 0 else { return [] }
        var available = pool.shuffled()
        var result: [VoicingSoftnessItem] = []
        while result.count < count {
            if available.isEmpty { available = pool.shuffled() }
            let lastZone = result.last?.correctZone
            // Предпочитаем токен с зоной, отличной от предыдущего; если такого
            // нет (пул одной зоны) — берём первый, чтобы не зациклиться.
            let pickIndex = available.firstIndex { $0.correctZone != lastZone } ?? 0
            result.append(available.remove(at: pickIndex))
        }
        return Array(result.prefix(count))
    }

    /// Раунды слов-ловушек: чередуем признак (voicing/softness) где возможно.
    /// Слов-ловушек обычно меньше, чем count → переиспользуем пул циклически,
    /// продолжая чередовать признак различения.
    static func makeTrapRounds(
        pool: [VoicingSoftnessTrapRound],
        count: Int
    ) -> [VoicingSoftnessTrapRound] {
        guard !pool.isEmpty, count > 0 else { return [] }
        var available = pool.shuffled()
        var result: [VoicingSoftnessTrapRound] = []
        while result.count < count {
            if available.isEmpty { available = pool.shuffled() }
            let lastContrast = result.last?.contrast
            let pickIndex = available.firstIndex { $0.contrast != lastContrast } ?? 0
            result.append(available.remove(at: pickIndex))
        }
        return Array(result.prefix(count))
    }
}

// MARK: - VoicingSoftnessMode Comparable (для возрастного capping)

extension VoicingSoftnessMode: Comparable {
    private var order: Int {
        switch self {
        case .voicing:   return 0
        case .softness:  return 1
        case .trapWords: return 2
        }
    }
    public static func < (lhs: VoicingSoftnessMode, rhs: VoicingSoftnessMode) -> Bool {
        lhs.order < rhs.order
    }
}
