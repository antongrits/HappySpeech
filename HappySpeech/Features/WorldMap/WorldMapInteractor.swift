import Foundation
import OSLog

// MARK: - WorldMapBusinessLogic

@MainActor
protocol WorldMapBusinessLogic: AnyObject {
    func loadMap(_ request: WorldMapModels.LoadMap.Request)
    func selectZone(_ request: WorldMapModels.SelectZone.Request)
    func loadZoneDetail(_ request: WorldMapModels.LoadZoneDetail.Request)
    func refreshProgress(_ request: WorldMapModels.RefreshProgress.Request)
    func tapLyalya(_ request: WorldMapModels.TapLyalya.Request)
    func collectTreasure(_ request: WorldMapModels.CollectTreasure.Request)
    func selectLevel(_ request: WorldMapModels.SelectLevel.Request)
    func loadAdaptiveRecommendation(_ request: WorldMapModels.AdaptiveRecommendation.Request)
    func recordSessionResult(_ request: WorldMapModels.RecordSession.Request)
    func loadVoicePrompt(_ request: WorldMapModels.VoicePrompt.Request)
}

// MARK: - WorldMapInteractor

/// Бизнес-логика карты путешествий ребёнка. 6 островов по группам звуков,
/// Hero Lyalya, коллектибл-сокровища, голосовые подсказки, адаптивное
/// рекомендование следующего уровня, spaced repetition через SM-2.
@MainActor
final class WorldMapInteractor: WorldMapBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any WorldMapPresentationLogic)?
    /// Опциональный репозиторий ребёнка — источник реального `progressSummary`
    /// и `currentStreak`. nil (preview / standalone) → зоны остаются на нулевом
    /// прогрессе (честное пустое состояние), без фабрикации.
    var childRepository: (any ChildRepository)?
    /// Опциональный репозиторий сессий — источник реальной серии активных дней
    /// (`dailyStreak`). nil → серия берётся из `ChildProfileDTO.currentStreak`.
    var sessionRepository: (any SessionRepository)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "WorldMap")

    // MARK: - Map State

    private var zones: [WorldZone] = []
    private var islands: [MapIsland] = []
    private var collectibles: [MapCollectible] = []
    private var collectedIds: Set<String> = []
    private var totalStars: Int = 0
    private var dailyStreak: Int = 0
    private var childAge: Int = 6
    private var lyalyaPosition: MapIslandID = .vowels
    private var recommendedIslandId: String?
    private var recommendedLevelId: String?
    private var fatigueHistory: [Bool] = []
    private var sessionHistory: [MapSessionRecord] = []
    /// Кеш progressSummary последнего загруженного ребёнка.
    private var progressSummary: [String: Double] = [:]

    // MARK: - BusinessLogic

    func loadMap(_ request: WorldMapModels.LoadMap.Request) {
        logger.info("loadMap childId=\(request.childId, privacy: .private(mask: .hash))")

        islands = Self.makeIslands()
        collectibles = Self.makeCollectibles()
        // Зоны начинаются с НУЛЕВОГО прогресса — карта прогресса наполняется
        // только реальными данными ребёнка (см. applyProgressSummaryUnlock).
        // Никаких зашитых 65%/30%/10%: новый ребёнок видит честную пустую карту.
        zones = Self.makeBaseZones()
        totalStars = 0
        dailyStreak = 0
        childAge = request.childAge ?? 6

        // Сначала синхронно отдаём базовые зоны через presenter, чтобы UI
        // (и unit-тест) увидели структуру немедленно. Async-обновление по
        // реальному progressSummary / серии происходит вторым вызовом ниже.
        Task { @MainActor in
            await finishLoadMap(highlightedSound: request.highlightedSound)
        }

        // Асинхронно подгружаем реальный progressSummary + серию и
        // пересчитываем прогресс/разблокировку зон. Если репозитория нет
        // (preview / unit-test) или загрузка падает — зоны остаются на нуле.
        Task { [weak self] in
            guard let self,
                  let repo = self.childRepository,
                  !request.childId.isEmpty else {
                return
            }
            do {
                let profile = try await repo.fetch(id: request.childId)
                let streak = await self.resolveDailyStreak(
                    childId: request.childId,
                    profileStreak: profile.currentStreak
                )
                await MainActor.run {
                    self.progressSummary = profile.progressSummary
                    self.dailyStreak = streak
                    self.applyProgressSummaryUnlock()
                    self.totalStars = self.zones.reduce(0) { $0 + $1.completedLessons }
                }
                await self.finishLoadMap(highlightedSound: request.highlightedSound)
            } catch {
                self.logger.notice("loadMap progressSummary fetch failed: \(error.localizedDescription)")
            }
        }
    }

    /// Реальная серия активных дней подряд. Если есть `sessionRepository` —
    /// считаем по фактическим датам сессий; иначе берём `currentStreak` профиля.
    private func resolveDailyStreak(childId: String, profileStreak: Int) async -> Int {
        guard let sessionRepo = sessionRepository else { return profileStreak }
        guard let sessions = try? await sessionRepo.fetchRecent(childId: childId, limit: 120),
              !sessions.isEmpty else {
            return profileStreak
        }
        return Self.activeDayStreak(in: sessions)
    }

    /// Серия активных дней подряд, заканчивающаяся сегодня или вчера.
    /// «Активный день» — день, в который есть хотя бы одна сессия.
    private static func activeDayStreak(in sessions: [SessionDTO]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let activeDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        guard !activeDays.isEmpty else { return 0 }

        var cursor = today
        if !activeDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  activeDays.contains(yesterday) else {
                return 0
            }
            cursor = yesterday
        }
        var streak = 0
        while activeDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// Финализирует loadMap-ответ после (опциональной) подгрузки прогресса.
    private func finishLoadMap(highlightedSound: String?) async {
        let currentIsland = islands.first(where: { $0.isCurrentLocation }) ?? islands[0]
        lyalyaPosition = currentIsland.islandId

        let highlightedId = highlightedSound.flatMap { sound in
            zones.first(where: { $0.sounds.contains(sound) })?.id
        }

        computeAdaptiveRecommendation()

        let response = WorldMapModels.LoadMap.Response(
            zones: zones,
            islands: islands,
            collectibles: collectibles.filter { !collectedIds.contains($0.id) },
            totalStars: totalStars,
            highlightedZoneId: highlightedId,
            dailyStreak: dailyStreak,
            lyalyaIslandId: lyalyaPosition.rawValue,
            recommendedIslandId: recommendedIslandId,
            recommendedLevelId: recommendedLevelId
        )
        presenter?.presentLoadMap(response)
    }

    /// Пересчитывает прогресс и разблокировку зон из РЕАЛЬНОГО `progressSummary`
    /// ребёнка. Для каждой зоны:
    ///   • `progress` = среднее `progressSummary[sound]` по звукам зоны (0 если
    ///     данных нет) — зоны без звуков (грамматика) остаются на нуле до
    ///     отдельного источника;
    ///   • `completedLessons` = round(progress · totalLessons);
    ///   • `isLocked` = false для корневой зоны; для остальных — если ≥ 50%
    ///     звуков prerequisite-зоны освоены (`progressSummary[sound] >= 0.5`).
    /// Стартовая зона (vowels, без prerequisite) всегда открыта.
    private func applyProgressSummaryUnlock() {
        zones = zones.map { zone in
            var copy = zone

            // 1. Реальный прогресс зоны из среднего освоения её звуков.
            let zoneProgress = averageMastery(for: zone.sounds)
            copy.progress = Float(zoneProgress)
            copy.completedLessons = min(
                zone.totalLessons,
                Int((zoneProgress * Double(zone.totalLessons)).rounded())
            )

            // 2. Разблокировка.
            guard let prereqId = zone.prerequisiteZoneId else {
                // Корневая зона (без prerequisite) всегда доступна.
                copy.isLocked = false
                return copy
            }
            guard let prereq = zones.first(where: { $0.id == prereqId }) else {
                return copy
            }
            let prereqSounds = prereq.sounds
            guard !prereqSounds.isEmpty else {
                copy.isLocked = false
                return copy
            }
            let masteredCount = prereqSounds.reduce(0) { acc, sound in
                acc + ((progressSummary[sound] ?? 0) >= 0.5 ? 1 : 0)
            }
            // Разблокируем, если ≥ 50% prerequisite-звуков освоены.
            copy.isLocked = Double(masteredCount) / Double(prereqSounds.count) < 0.5
            return copy
        }

        // Зеркалим прогресс и разблокировку зон в острова + пересчитываем
        // завершённость уровней из реального прогресса зоны.
        islands = islands.map { island in
            var copy = island
            if let matchingZone = zones.first(where: { $0.id == island.zoneId }) {
                copy.isLocked = matchingZone.isLocked
                copy.completionFraction = Double(matchingZone.progress)
                copy.isCompleted = matchingZone.progress >= 1.0
                copy.levels = Self.applyLevelProgress(
                    to: island.levels,
                    zoneProgress: Double(matchingZone.progress)
                )
            }
            return copy
        }
    }

    /// Пересчитывает завершённость 5 стадий-уровней из реального прогресса зоны
    /// (0…1). Завершено `floor(progress · 5)` уровней; следующий открыт.
    /// Без зашитых successRate/stars — звёзды выставляются 3 за завершённый
    /// уровень (детерминированно, не random).
    private static func applyLevelProgress(
        to levels: [MapLevel],
        zoneProgress: Double
    ) -> [MapLevel] {
        guard !levels.isEmpty else { return levels }
        let completedCount = min(levels.count, Int((zoneProgress * Double(levels.count)).rounded(.down)))
        return levels.enumerated().map { index, level in
            var copy = level
            if index < completedCount {
                copy.isCompleted = true
                copy.isLocked = false
                copy.successRate = 1.0
                copy.stars = 3
            } else {
                copy.isCompleted = false
                // Открыт первый незавершённый уровень (точка входа).
                copy.isLocked = index != completedCount
                copy.successRate = 0.0
                copy.stars = 0
            }
            return copy
        }
    }

    /// Среднее освоение набора звуков из реального `progressSummary` (0…1).
    /// Пустой набор или отсутствие данных → 0 (честное пустое состояние).
    private func averageMastery(for sounds: [String]) -> Double {
        guard !sounds.isEmpty else { return 0 }
        let total = sounds.reduce(0.0) { $0 + (progressSummary[$1] ?? 0) }
        return min(1.0, total / Double(sounds.count))
    }

    func selectZone(_ request: WorldMapModels.SelectZone.Request) {
        guard let zone = zones.first(where: { $0.id == request.zoneId }) else {
            presenter?.presentFailure(.init(
                message: String(localized: "worldMap.error.zoneNotFound")
            ))
            return
        }

        logger.info("selectZone id=\(zone.id, privacy: .public) locked=\(zone.isLocked, privacy: .public)")
        let response = WorldMapModels.SelectZone.Response(
            zone: zone,
            canOpen: !zone.isLocked
        )
        presenter?.presentSelectZone(response)
    }

    func loadZoneDetail(_ request: WorldMapModels.LoadZoneDetail.Request) {
        guard let zone = zones.first(where: { $0.id == request.zoneId }) else {
            presenter?.presentFailure(.init(
                message: String(localized: "worldMap.error.zoneNotFound")
            ))
            return
        }

        let prereqName: String?
        if let prereqId = zone.prerequisiteZoneId {
            prereqName = zones.first(where: { $0.id == prereqId })?.name
        } else {
            prereqName = nil
        }

        let island = islands.first(where: { $0.zoneId == zone.id })
        let levels = island?.levels ?? []
        let unlocksNeeded = computeUnlocksNeeded(for: zone)

        logger.info("loadZoneDetail id=\(zone.id, privacy: .public) levels=\(levels.count, privacy: .public)")
        presenter?.presentLoadZoneDetail(.init(
            zone: zone,
            recommendedLessonCount: zone.recommendedLessonCount,
            estimatedMinutesPerSession: zone.estimatedMinutesPerSession,
            prerequisiteZoneName: prereqName,
            levels: levels,
            recommendedLevelId: recommendedLevelId,
            unlocksNeeded: unlocksNeeded
        ))
    }

    func refreshProgress(_ request: WorldMapModels.RefreshProgress.Request) {
        logger.info("refreshProgress childId=\(request.childId, privacy: .private(mask: .hash))")

        // Пересчитываем зоны из уже закешированного реального progressSummary —
        // никакой фабрикации (раньше искусственно инкрементировался прогресс
        // текущей зоны). Свежие данные подтягиваются ниже асинхронно.
        applyProgressSummaryUnlock()
        totalStars = zones.reduce(0) { $0 + $1.completedLessons }
        computeAdaptiveRecommendation()

        presenter?.presentRefreshProgress(.init(
            zones: zones,
            totalStars: totalStars,
            dailyStreak: dailyStreak
        ))

        // Асинхронно подтягиваем актуальный progressSummary / серию из Realm,
        // если репозитории доступны, и повторно отдаём пересчитанный прогресс.
        guard let repo = childRepository, !request.childId.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let profile = try await repo.fetch(id: request.childId)
                let streak = await self.resolveDailyStreak(
                    childId: request.childId,
                    profileStreak: profile.currentStreak
                )
                await MainActor.run {
                    self.progressSummary = profile.progressSummary
                    self.dailyStreak = streak
                    self.applyProgressSummaryUnlock()
                    self.totalStars = self.zones.reduce(0) { $0 + $1.completedLessons }
                    self.computeAdaptiveRecommendation()
                    self.presenter?.presentRefreshProgress(.init(
                        zones: self.zones,
                        totalStars: self.totalStars,
                        dailyStreak: self.dailyStreak
                    ))
                }
            } catch {
                self.logger.notice("refreshProgress fetch failed: \(error.localizedDescription)")
            }
        }
    }

    func tapLyalya(_ request: WorldMapModels.TapLyalya.Request) {
        logger.info("tapLyalya")
        let prompt = selectLyalyaGreeting()
        presenter?.presentVoicePrompt(.init(text: prompt, isLyalya: true))
    }

    func collectTreasure(_ request: WorldMapModels.CollectTreasure.Request) {
        guard !collectedIds.contains(request.collectibleId) else { return }
        guard let collectible = collectibles.first(where: { $0.id == request.collectibleId }) else { return }

        collectedIds.insert(request.collectibleId)
        totalStars += collectible.starValue

        logger.info("collectTreasure id=\(collectible.id, privacy: .public) stars+=\(collectible.starValue, privacy: .public)")

        let updatedCollectibles = collectibles.filter { !collectedIds.contains($0.id) }
        presenter?.presentCollectTreasure(.init(
            collectible: collectible,
            totalStars: totalStars,
            remainingCollectibles: updatedCollectibles
        ))
    }

    func selectLevel(_ request: WorldMapModels.SelectLevel.Request) {
        guard let island = islands.first(where: { $0.levels.contains(where: { $0.id == request.levelId }) }) else {
            presenter?.presentFailure(.init(message: String(localized: "worldMap.error.zoneNotFound")))
            return
        }
        guard let level = island.levels.first(where: { $0.id == request.levelId }) else { return }

        logger.info("selectLevel id=\(level.id, privacy: .public) locked=\(level.isLocked, privacy: .public)")

        if level.isLocked {
            let lessonsNeeded = computeLessonsToUnlockLevel(level, in: island)
            let msg = String(format: String(localized: "worldMap.level.locked.hint"), lessonsNeeded)
            presenter?.presentFailure(.init(message: msg))
            return
        }

        presenter?.presentSelectLevel(.init(
            level: level,
            islandId: island.id,
            zoneId: island.zoneId
        ))
    }

    func loadAdaptiveRecommendation(_ request: WorldMapModels.AdaptiveRecommendation.Request) {
        computeAdaptiveRecommendation()
        presenter?.presentAdaptiveRecommendation(.init(
            recommendedIslandId: recommendedIslandId,
            recommendedLevelId: recommendedLevelId,
            voiceHint: buildRecommendationHint()
        ))
    }

    func recordSessionResult(_ request: WorldMapModels.RecordSession.Request) {
        let summary = MapSessionRecord(
            islandId: request.islandId,
            levelId: request.levelId,
            successRate: request.successRate,
            fatigueDetected: request.fatigueDetected,
            date: Date()
        )
        sessionHistory.append(summary)
        fatigueHistory.append(request.fatigueDetected)
        if fatigueHistory.count > 5 {
            fatigueHistory.removeFirst()
        }

        updateProgressAfterSession(summary)
        computeAdaptiveRecommendation()

        let islandLog = request.islandId
        let rateLog = request.successRate
        let fatigueLog = request.fatigueDetected
        logger.info("recordSession island=\(islandLog, privacy: .public) rate=\(rateLog, privacy: .public) fatigue=\(fatigueLog, privacy: .public)")

        presenter?.presentRefreshProgress(.init(
            zones: zones,
            totalStars: totalStars,
            dailyStreak: dailyStreak
        ))
    }

    func loadVoicePrompt(_ request: WorldMapModels.VoicePrompt.Request) {
        let text = selectContextualVoicePrompt(context: request.context)
        presenter?.presentVoicePrompt(.init(text: text, isLyalya: false))
    }

    // MARK: - Private: Adaptive Recommendation

    private func computeAdaptiveRecommendation() {
        let recentFatigue = fatigueHistory.suffix(3)
        let highFatigue = recentFatigue.filter { $0 }.count >= 2

        if highFatigue {
            recommendedIslandId = findEasiestActiveIsland()
            recommendedLevelId = nil
            logger.info("adaptivePlanner: high fatigue → easiest island")
            return
        }

        recommendedIslandId = findOptimalNextIsland()
        if let islandId = recommendedIslandId {
            recommendedLevelId = findOptimalNextLevel(in: islandId)
        }
    }

    private func findEasiestActiveIsland() -> String? {
        let unlocked = islands.filter { !$0.isLocked }
        return unlocked.min(by: { $0.completionFraction < $1.completionFraction })?.id
    }

    private func findOptimalNextIsland() -> String? {
        let inProgress = islands.filter { !$0.isLocked && !$0.isCompleted }
        guard !inProgress.isEmpty else {
            return islands.first(where: { !$0.isLocked })?.id
        }
        return inProgress.max(by: { $0.completionFraction < $1.completionFraction })?.id
    }

    private func findOptimalNextLevel(in islandId: String) -> String? {
        guard let island = islands.first(where: { $0.id == islandId }) else { return nil }
        let inProgress = island.levels.filter { !$0.isLocked && !$0.isCompleted }
        return inProgress.first?.id ?? island.levels.first(where: { !$0.isLocked })?.id
    }

    private func buildRecommendationHint() -> String {
        guard let islandId = recommendedIslandId,
              let island = islands.first(where: { $0.id == islandId }) else {
            return String(localized: "worldMap.voice.noRecommendation")
        }
        let recentFatigue = fatigueHistory.suffix(3)
        let highFatigue = recentFatigue.filter { $0 }.count >= 2
        if highFatigue {
            return String(format: String(localized: "worldMap.voice.fatigue.recommendation"), island.name)
        }
        if let levelId = recommendedLevelId,
           let level = island.levels.first(where: { $0.id == levelId }) {
            return String(
                format: String(localized: "worldMap.voice.level.recommendation"),
                island.name, level.name
            )
        }
        return String(format: String(localized: "worldMap.voice.island.recommendation"), island.name)
    }

    // MARK: - Private: Progress Update

    private func updateProgressAfterSession(_ summary: MapSessionRecord) {
        islands = islands.map { island in
            guard island.id == summary.islandId else { return island }
            var updated = island
            updated.levels = island.levels.map { level in
                guard level.id == summary.levelId else { return level }
                var lvl = level
                lvl.successRate = summary.successRate
                if summary.successRate >= 0.8 {
                    lvl.isCompleted = true
                }
                return lvl
            }
            let completedCount = updated.levels.filter { $0.isCompleted }.count
            updated.completionFraction = Double(completedCount) / Double(max(1, updated.levels.count))
            if updated.completionFraction >= 1.0 {
                updated.isCompleted = true
            }
            unlockNextLevelIfNeeded(&updated)
            return updated
        }

        unlockNextIslandIfNeeded()
        syncZonesFromIslands()
    }

    private func unlockNextLevelIfNeeded(_ island: inout MapIsland) {
        for idx in island.levels.indices {
            let current = island.levels[idx]
            if current.isCompleted && idx + 1 < island.levels.count {
                island.levels[idx + 1].isLocked = false
            }
        }
    }

    private func unlockNextIslandIfNeeded() {
        for idx in islands.indices {
            let island = islands[idx]
            guard island.isCompleted, idx + 1 < islands.count else { continue }
            islands[idx + 1].isLocked = false
            lyalyaPosition = islands[idx + 1].islandId
            let unlockedId = islands[idx + 1].id
            logger.info("unlocked island=\(unlockedId, privacy: .public)")
        }
    }

    private func syncZonesFromIslands() {
        zones = zones.map { zone in
            guard let island = islands.first(where: { $0.zoneId == zone.id }) else { return zone }
            var copy = zone
            let total = zone.totalLessons
            copy.completedLessons = Int(island.completionFraction * Double(total))
            copy.progress = Float(island.completionFraction)
            return copy
        }
        totalStars = zones.reduce(0) { $0 + $1.completedLessons }
    }

    // MARK: - Private: Helpers

    private func computeUnlocksNeeded(for zone: WorldZone) -> Int {
        guard zone.isLocked, let prereqId = zone.prerequisiteZoneId,
              let prereq = zones.first(where: { $0.id == prereqId }) else { return 0 }
        let remaining = prereq.totalLessons - prereq.completedLessons
        return max(0, remaining)
    }

    private func computeLessonsToUnlockLevel(_ level: MapLevel, in island: MapIsland) -> Int {
        let completedCount = island.levels.filter { $0.isCompleted }.count
        let levelIndex = island.levels.firstIndex(where: { $0.id == level.id }) ?? 0
        return max(0, levelIndex - completedCount)
    }

    private func selectLyalyaGreeting() -> String {
        let greetings: [String] = [
            String(localized: "worldMap.lyalya.greeting.1"),
            String(localized: "worldMap.lyalya.greeting.2"),
            String(localized: "worldMap.lyalya.greeting.3"),
            String(localized: "worldMap.lyalya.greeting.4")
        ]
        return greetings[Int.random(in: 0..<greetings.count)]
    }

    private func selectContextualVoicePrompt(context: WorldMapModels.VoicePrompt.Context) -> String {
        switch context {
        case .islandUnlocked(let name):
            return String(format: String(localized: "worldMap.voice.islandUnlocked"), name)
        case .levelCompleted(let levelName, let islandName):
            return String(format: String(localized: "worldMap.voice.levelCompleted"), levelName, islandName)
        case .nearUnlock(let name, let count):
            return String(format: String(localized: "worldMap.voice.nearUnlock"), count, name)
        case .firstVisit:
            return String(localized: "worldMap.voice.firstVisit")
        case .encouragement:
            let options: [String] = [
                String(localized: "worldMap.voice.encouragement.1"),
                String(localized: "worldMap.voice.encouragement.2"),
                String(localized: "worldMap.voice.encouragement.3")
            ]
            return options[Int.random(in: 0..<options.count)]
        }
    }

    private func maxSessionMinutes() -> Int {
        switch childAge {
        case ...5: return 8
        case 6: return 10
        case 7: return 12
        default: return 15
        }
    }
}

// MARK: - Seed: Islands

private extension WorldMapInteractor {

    static func makeIslands() -> [MapIsland] {
        makeIslandsPartOne() + makeIslandsPartTwo()
    }

    static func makeIslandsPartOne() -> [MapIsland] {
        [
            MapIsland(
                id: "island-vowels",
                islandId: .vowels,
                zoneId: "zone-vowels",
                name: String(localized: "worldMap.island.vowels"),
                icon: "music.note",
                position: CGPoint(x: 0.18, y: 0.88),
                isLocked: false,
                isCompleted: false,
                isCurrentLocation: false,
                completionFraction: 0.0,
                levels: makeVowelLevels()
            ),
            MapIsland(
                id: "island-whistling",
                islandId: .whistling,
                zoneId: "zone-whistling",
                name: String(localized: "worldMap.island.whistling"),
                icon: "leaf.fill",
                position: CGPoint(x: 0.78, y: 0.75),
                isLocked: false,
                isCompleted: false,
                isCurrentLocation: false,
                completionFraction: 0.0,
                levels: makeWhistlingLevels()
            ),
            MapIsland(
                id: "island-hissing",
                islandId: .hissing,
                zoneId: "zone-hissing",
                name: String(localized: "worldMap.island.hissing"),
                icon: "ant.fill",
                position: CGPoint(x: 0.28, y: 0.60),
                isLocked: false,
                isCompleted: false,
                isCurrentLocation: true,
                completionFraction: 0.0,
                levels: makeHissingLevels()
            )
        ]
    }

    static func makeIslandsPartTwo() -> [MapIsland] {
        [
            // v32 P2 — Аффрикаты (Ч, Щ) выделены в отдельный остров.
            // Методически правильно: Ч/Щ — отдельная категория звуков и часто
            // ставятся уже после Ш/Ж, требуя своих упражнений.
            MapIsland(
                id: "island-affricates",
                islandId: .affricates,
                zoneId: "zone-affricates",
                name: String(localized: "worldMap.island.affricates"),
                icon: "tortoise.fill",
                position: CGPoint(x: 0.50, y: 0.52),
                isLocked: true,
                isCompleted: false,
                isCurrentLocation: false,
                completionFraction: 0.0,
                levels: makeAffricateLevels()
            ),
            MapIsland(
                id: "island-sonorant",
                islandId: .sonorant,
                zoneId: "zone-sonorant",
                name: String(localized: "worldMap.island.sonorant"),
                icon: "flame.fill",
                position: CGPoint(x: 0.74, y: 0.44),
                isLocked: false,
                isCompleted: false,
                isCurrentLocation: false,
                completionFraction: 0.0,
                levels: makeSonorantLevels()
            ),
            MapIsland(
                id: "island-velar",
                islandId: .velar,
                zoneId: "zone-velar",
                name: String(localized: "worldMap.island.velar"),
                icon: "bird.fill",
                position: CGPoint(x: 0.28, y: 0.28),
                isLocked: true,
                isCompleted: false,
                isCurrentLocation: false,
                completionFraction: 0.0,
                levels: makeVelarLevels()
            ),
            MapIsland(
                id: "island-special",
                islandId: .special,
                zoneId: "zone-grammar",
                name: String(localized: "worldMap.island.special"),
                icon: "sparkles",
                position: CGPoint(x: 0.60, y: 0.12),
                isLocked: true,
                isCompleted: false,
                isCurrentLocation: false,
                completionFraction: 0.0,
                levels: makeSpecialLevels()
            )
        ]
    }

    static func makeAffricateLevels() -> [MapLevel] {
        [
            MapLevel(id: "affr-l1", name: String(localized: "worldMap.level.isolated"),
                     stage: .isolated, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "affr-l2", name: String(localized: "worldMap.level.syllable"),
                     stage: .syllable, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "affr-l3", name: String(localized: "worldMap.level.wordInit"),
                     stage: .wordInit, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "affr-l4", name: String(localized: "worldMap.level.phrase"),
                     stage: .phrase, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "affr-l5", name: String(localized: "worldMap.level.story"),
                     stage: .story, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0)
        ]
    }

    // MARK: Level Builders

    static func makeVowelLevels() -> [MapLevel] {
        baseLevels(prefix: "vowel")
    }

    static func makeWhistlingLevels() -> [MapLevel] {
        baseLevels(prefix: "whistle")
    }

    static func makeHissingLevels() -> [MapLevel] {
        baseLevels(prefix: "hiss")
    }

    static func makeSonorantLevels() -> [MapLevel] {
        baseLevels(prefix: "sono")
    }

    /// Пять стадий-уровней с НУЛЕВЫМ прогрессом. Только первый уровень открыт
    /// (точка входа), остальные открываются по мере реального прохождения.
    /// Реальная завершённость пересчитывается из `progress` зоны в
    /// `applyLevelProgress`. Никаких зашитых successRate/stars.
    static func baseLevels(prefix: String) -> [MapLevel] {
        [
            MapLevel(id: "\(prefix)-l1", name: String(localized: "worldMap.level.isolated"),
                     stage: .isolated, isLocked: false, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "\(prefix)-l2", name: String(localized: "worldMap.level.syllable"),
                     stage: .syllable, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "\(prefix)-l3", name: String(localized: "worldMap.level.wordInit"),
                     stage: .wordInit, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "\(prefix)-l4", name: String(localized: "worldMap.level.phrase"),
                     stage: .phrase, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "\(prefix)-l5", name: String(localized: "worldMap.level.story"),
                     stage: .story, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0)
        ]
    }

    static func makeVelarLevels() -> [MapLevel] {
        [
            MapLevel(id: "velar-l1", name: String(localized: "worldMap.level.isolated"),
                     stage: .isolated, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "velar-l2", name: String(localized: "worldMap.level.syllable"),
                     stage: .syllable, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "velar-l3", name: String(localized: "worldMap.level.wordInit"),
                     stage: .wordInit, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "velar-l4", name: String(localized: "worldMap.level.phrase"),
                     stage: .phrase, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "velar-l5", name: String(localized: "worldMap.level.story"),
                     stage: .story, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0)
        ]
    }

    static func makeSpecialLevels() -> [MapLevel] {
        [
            MapLevel(id: "spec-l1", name: String(localized: "worldMap.level.isolated"),
                     stage: .isolated, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "spec-l2", name: String(localized: "worldMap.level.syllable"),
                     stage: .syllable, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "spec-l3", name: String(localized: "worldMap.level.wordInit"),
                     stage: .wordInit, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "spec-l4", name: String(localized: "worldMap.level.phrase"),
                     stage: .phrase, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "spec-l5", name: String(localized: "worldMap.level.story"),
                     stage: .story, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0)
        ]
    }

    // MARK: Collectibles

    static func makeCollectibles() -> [MapCollectible] {
        [
            MapCollectible(id: "c-shell-1", type: .magicShell,
                           position: CGPoint(x: 0.45, y: 0.82), starValue: 2),
            MapCollectible(id: "c-pebble-1", type: .goldPebble,
                           position: CGPoint(x: 0.55, y: 0.68), starValue: 1),
            MapCollectible(id: "c-shell-2", type: .magicShell,
                           position: CGPoint(x: 0.15, y: 0.45), starValue: 2),
            MapCollectible(id: "c-pebble-2", type: .goldPebble,
                           position: CGPoint(x: 0.85, y: 0.32), starValue: 1),
            MapCollectible(id: "c-crystal-1", type: .speechCrystal,
                           position: CGPoint(x: 0.50, y: 0.18), starValue: 5)
        ]
    }

    // MARK: Zones

    /// Базовые зоны карты с НУЛЕВЫМ прогрессом. Реальный `progress` и
    /// `completedLessons` пересчитываются из `progressSummary` ребёнка в
    /// `applyProgressSummaryUnlock`. Никаких зашитых процентов — карта честно
    /// пустая, пока у ребёнка нет сессий.
    static func makeBaseZones() -> [WorldZone] {
        makeBaseZonesPartOne() + makeBaseZonesPartTwo()
    }

    private static func makeBaseZonesPartOne() -> [WorldZone] {
        [
            WorldZone(
                id: "zone-vowels",
                name: String(localized: "worldMap.zone.vowels"),
                icon: "music.note",
                sounds: ["А", "О", "У", "И", "Э", "Ы"],
                progress: 0.0,
                completedLessons: 0,
                totalLessons: 10,
                colorName: "sky",
                isLocked: false,
                position: CGPoint(x: 0.18, y: 0.88),
                isCurrentLocation: false,
                description: String(localized: "worldMap.zone.vowels.desc"),
                prerequisiteZoneId: nil,
                recommendedLessonCount: 10,
                estimatedMinutesPerSession: 8
            ),
            WorldZone(
                id: "zone-whistling",
                name: String(localized: "worldMap.zone.whistling"),
                icon: "leaf.fill",
                sounds: ["С", "Сь", "З", "Зь", "Ц"],
                progress: 0.0,
                completedLessons: 0,
                totalLessons: 20,
                colorName: "mint",
                isLocked: false,
                position: CGPoint(x: 0.78, y: 0.75),
                isCurrentLocation: false,
                description: String(localized: "worldMap.zone.whistling.desc"),
                prerequisiteZoneId: "zone-vowels",
                recommendedLessonCount: 20,
                estimatedMinutesPerSession: 12
            ),
            // v32 P2 — Шипящие фокусируются на Ш/Ж, аффрикаты Ч/Щ переехали
            // в собственную зону `zone-affricates` (методически они часто
            // ставятся уже после шипящих).
            WorldZone(
                id: "zone-hissing",
                name: String(localized: "worldMap.zone.hissing"),
                icon: "ant.fill",
                sounds: ["Ш", "Ж"],
                progress: 0.0,
                completedLessons: 0,
                totalLessons: 20,
                colorName: "butter",
                isLocked: false,
                position: CGPoint(x: 0.28, y: 0.60),
                isCurrentLocation: true,
                description: String(localized: "worldMap.zone.hissing.desc"),
                prerequisiteZoneId: "zone-whistling",
                recommendedLessonCount: 20,
                estimatedMinutesPerSession: 12
            )
        ]
    }

    private static func makeBaseZonesPartTwo() -> [WorldZone] {
        [
            // v32 P2 — Аффрикаты (Ч, Щ) как отдельная категория звуков.
            // По умолчанию заблокированы; разблокировка считается из
            // `progressSummary[Ш]` и `[Ж]` (см. computeUnlockFromProgressSummary).
            WorldZone(
                id: "zone-affricates",
                name: String(localized: "worldMap.zone.affricates"),
                icon: "tortoise.fill",
                sounds: ["Ч", "Щ"],
                progress: 0.0,
                completedLessons: 0,
                totalLessons: 18,
                colorName: "rose",
                isLocked: true,
                position: CGPoint(x: 0.50, y: 0.52),
                isCurrentLocation: false,
                description: String(localized: "worldMap.zone.affricates.desc"),
                prerequisiteZoneId: "zone-hissing",
                recommendedLessonCount: 18,
                estimatedMinutesPerSession: 12
            ),
            WorldZone(
                id: "zone-sonorant",
                name: String(localized: "worldMap.zone.sonorant"),
                icon: "flame.fill",
                sounds: ["Р", "Рь", "Л", "Ль"],
                progress: 0.0,
                completedLessons: 0,
                totalLessons: 20,
                colorName: "lilac",
                isLocked: false,
                position: CGPoint(x: 0.74, y: 0.44),
                isCurrentLocation: false,
                description: String(localized: "worldMap.zone.sonorant.desc"),
                prerequisiteZoneId: "zone-hissing",
                recommendedLessonCount: 20,
                estimatedMinutesPerSession: 14
            ),
            WorldZone(
                id: "zone-velar",
                name: String(localized: "worldMap.zone.velar"),
                icon: "bird.fill",
                sounds: ["К", "Кь", "Г", "Гь", "Х", "Хь"],
                progress: 0.0,
                completedLessons: 0,
                totalLessons: 15,
                colorName: "coral",
                isLocked: true,
                position: CGPoint(x: 0.28, y: 0.28),
                isCurrentLocation: false,
                description: String(localized: "worldMap.zone.velar.desc"),
                prerequisiteZoneId: "zone-sonorant",
                recommendedLessonCount: 15,
                estimatedMinutesPerSession: 12
            ),
            WorldZone(
                id: "zone-grammar",
                name: String(localized: "worldMap.zone.grammar"),
                icon: "books.vertical.fill",
                sounds: [],
                progress: 0.0,
                completedLessons: 0,
                totalLessons: 12,
                colorName: "gold",
                isLocked: true,
                position: CGPoint(x: 0.74, y: 0.14),
                isCurrentLocation: false,
                description: String(localized: "worldMap.zone.grammar.desc"),
                prerequisiteZoneId: "zone-velar",
                recommendedLessonCount: 12,
                estimatedMinutesPerSession: 15
            )
        ]
    }
}

// MARK: - Domain Types: Islands

enum MapIslandID: String, Sendable {
    case vowels
    case whistling
    case hissing
    case affricates    // v32 P2 — Ч, Щ выделены из шипящих в отдельный остров.
    case sonorant
    case velar
    case special
}

struct MapIsland: Sendable, Identifiable {
    let id: String
    let islandId: MapIslandID
    let zoneId: String
    let name: String
    let icon: String
    let position: CGPoint
    var isLocked: Bool
    var isCompleted: Bool
    let isCurrentLocation: Bool
    var completionFraction: Double
    var levels: [MapLevel]
}

struct MapLevel: Sendable, Identifiable {
    let id: String
    let name: String
    let stage: CorrectionStage
    var isLocked: Bool
    var isCompleted: Bool
    var successRate: Double
    var stars: Int
}

struct MapCollectible: Sendable, Identifiable {
    enum CollectibleType: Sendable {
        case goldPebble
        case magicShell
        case speechCrystal
    }

    let id: String
    let type: CollectibleType
    let position: CGPoint
    let starValue: Int
}

// MARK: - Session Summary (internal)

private struct MapSessionRecord: Sendable {
    let islandId: String
    let levelId: String
    let successRate: Double
    let fatigueDetected: Bool
    let date: Date
}
