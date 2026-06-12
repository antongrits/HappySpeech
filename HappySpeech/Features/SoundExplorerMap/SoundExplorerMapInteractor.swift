import Foundation
import OSLog

// MARK: - SoundExplorerMapInteractor

/// Бизнес-логика «карты звуков».
///
/// При наличии репозиториев вычисляет уровень освоения каждого звука из
/// реальных данных: `progressSummary` профиля (per-sound rate) и истории
/// сессий (был ли звук в работе). Без репозиториев (Preview/тесты) — остаётся
/// на нейтральном `seedSounds`.
@MainActor
@Observable
final class SoundExplorerMapInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundExplorerMap"
    )

    let childId: String
    var filter: SoundExplorerMapModels.MasteryFilter = .all
    var sounds: [SoundExplorerMapModels.SoundCell] = SoundExplorerMapModels.seedSounds

    private let childRepository: (any ChildRepository)?
    private let sessionRepository: (any SessionRepository)?
    /// Генератор вариаций контента — источник числа реально-наполняемых
    /// активностей на звук (делает сгенерированный контент достижимым из каталога).
    private let variationGenerator: ContentVariationGenerator?

    init(
        childId: String,
        childRepository: (any ChildRepository)? = nil,
        sessionRepository: (any SessionRepository)? = nil,
        variationGenerator: ContentVariationGenerator? = nil
    ) {
        self.childId = childId
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
        self.variationGenerator = variationGenerator
    }

    var visible: [SoundExplorerMapModels.SoundCell] {
        sounds.filter { $0.matches(filter) }
    }

    func setFilter(_ value: SoundExplorerMapModels.MasteryFilter) {
        filter = value
        Self.logger.info("Filter = \(value.rawValue, privacy: .public)")
    }

    /// Пересобирает карту из реальных данных. Безопасно без репозиториев/childId.
    func refresh() {
        guard !childId.isEmpty, childRepository != nil || sessionRepository != nil else {
            Self.logger.info("sound map refresh skipped (no repository/childId)")
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let progress = await self.loadProgress()
            let practiced = await self.loadPracticedSounds()
            let counts = await self.loadActivityCounts()
            self.sounds = self.makeCells(progress: progress, practicedSounds: practiced, activityCounts: counts)
            let variations = counts.values.reduce(0, +)
            Self.logger.info(
                "sound map refreshed (progress=\(progress.count, privacy: .public), variations=\(variations, privacy: .public))"
            )
        }
    }

    /// Число реально-наполняемых вариаций активностей на звук из генератора.
    /// Без генератора — пусто (preview/тесты). Ключи — кириллические звуки.
    private func loadActivityCounts() async -> [String: Int] {
        guard let variationGenerator else { return [:] }
        var counts: [String: Int] = [:]
        for sound in ContentVariationGenerator.soundRoster {
            let activities = await variationGenerator.generateActivities(for: sound)
            counts[sound] = activities.count
        }
        return counts
    }

    // MARK: - Data Loading

    private func loadProgress() async -> [String: Double] {
        guard let childRepository else { return [:] }
        do {
            let profile = try await childRepository.fetch(id: childId)
            return profile.progressSummary
        } catch {
            Self.logger.error("sound map: load profile failed: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }

    /// Множество звуков, которые встречались в сессиях (использовались как target).
    private func loadPracticedSounds() async -> Set<String> {
        guard let sessionRepository else { return [] }
        do {
            let sessions = try await sessionRepository.fetchRecent(childId: childId, limit: 200)
            return Set(sessions.map(\.targetSound).filter { !$0.isEmpty })
        } catch {
            Self.logger.error("sound map: load sessions failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - Aggregation

    /// Строит ячейки с реальным mastery.
    /// Приоритет: explicit rate из `progressSummary` → освоен/учу;
    /// иначе если звук был в сессиях — «учу»; иначе дефолт группы (untried/known).
    func makeCells(
        progress: [String: Double],
        practicedSounds: Set<String>,
        activityCounts: [String: Int] = [:]
    ) -> [SoundExplorerMapModels.SoundCell] {
        SoundExplorerMapModels.inventory.flatMap { group, sounds, defaultMastery in
            sounds.map { sound in
                let mastery = resolveMastery(
                    sound: sound,
                    defaultMastery: defaultMastery,
                    progress: progress,
                    practicedSounds: practicedSounds
                )
                return SoundExplorerMapModels.SoundCell(
                    id: sound,
                    group: group,
                    mastery: mastery,
                    activityCount: activityCounts[sound] ?? 0
                )
            }
        }
    }

    private func resolveMastery(
        sound: String,
        defaultMastery: SoundExplorerMapModels.Mastery,
        progress: [String: Double],
        practicedSounds: Set<String>
    ) -> SoundExplorerMapModels.Mastery {
        // progressSummary хранит ключи как заглавные базовые звуки (например "Р", "Ш").
        let key = matchingKey(for: sound, in: progress.keys)
        if let key, let rate = progress[key] {
            return rate >= SoundExplorerMapModels.knownThreshold ? .known : .learning
        }
        if practicedSounds.contains(where: { sameSound($0, sound) }) {
            return .learning
        }
        return defaultMastery
    }

    /// Ищет ключ progressSummary, соответствующий звуку (без учёта мягкости/регистра).
    private func matchingKey(for sound: String, in keys: Dictionary<String, Double>.Keys) -> String? {
        keys.first { sameSound($0, sound) }
    }

    /// Сравнивает звуки без учёта регистра и мягкого знака (Р == Рь для целей карты).
    private func sameSound(_ lhs: String, _ rhs: String) -> Bool {
        normalized(lhs) == normalized(rhs)
    }

    private func normalized(_ sound: String) -> String {
        sound.uppercased().replacingOccurrences(of: "Ь", with: "")
    }
}
