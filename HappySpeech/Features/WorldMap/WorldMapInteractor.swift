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

    // MARK: - BusinessLogic

    func loadMap(_ request: WorldMapModels.LoadMap.Request) {
        logger.info("loadMap childId=\(request.childId, privacy: .private(mask: .hash))")

        islands = Self.makeIslands()
        collectibles = Self.makeCollectibles()
        zones = Self.makeSeedZones()
        totalStars = zones.reduce(0) { $0 + $1.completedLessons }
        dailyStreak = 4
        childAge = request.childAge ?? 6

        let currentIsland = islands.first(where: { $0.isCurrentLocation }) ?? islands[0]
        lyalyaPosition = currentIsland.islandId

        let highlightedId = request.highlightedSound.flatMap { sound in
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

        zones = zones.map { zone in
            var copy = zone
            if zone.isCurrentLocation && copy.completedLessons < copy.totalLessons {
                copy.completedLessons += 1
                copy.progress = Float(copy.completedLessons) / Float(copy.totalLessons)
            }
            return copy
        }

        totalStars = zones.reduce(0) { $0 + $1.completedLessons }
        updateIslandStatesFromZones()
        computeAdaptiveRecommendation()

        presenter?.presentRefreshProgress(.init(
            zones: zones,
            totalStars: totalStars,
            dailyStreak: dailyStreak
        ))
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

    private func updateIslandStatesFromZones() {
        zones.forEach { zone in
            if let idx = islands.firstIndex(where: { $0.zoneId == zone.id }) {
                islands[idx].completionFraction = Double(zone.progress)
                islands[idx].isCompleted = zone.progress >= 1.0
            }
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
                icon: "🎵",
                position: CGPoint(x: 0.18, y: 0.88),
                isLocked: false,
                isCompleted: true,
                isCurrentLocation: false,
                completionFraction: 1.0,
                levels: makeVowelLevels()
            ),
            MapIsland(
                id: "island-whistling",
                islandId: .whistling,
                zoneId: "zone-whistling",
                name: String(localized: "worldMap.island.whistling"),
                icon: "🐍",
                position: CGPoint(x: 0.78, y: 0.75),
                isLocked: false,
                isCompleted: false,
                isCurrentLocation: false,
                completionFraction: 0.65,
                levels: makeWhistlingLevels()
            ),
            MapIsland(
                id: "island-hissing",
                islandId: .hissing,
                zoneId: "zone-hissing",
                name: String(localized: "worldMap.island.hissing"),
                icon: "🐝",
                position: CGPoint(x: 0.28, y: 0.60),
                isLocked: false,
                isCompleted: false,
                isCurrentLocation: true,
                completionFraction: 0.30,
                levels: makeHissingLevels()
            )
        ]
    }

    static func makeIslandsPartTwo() -> [MapIsland] {
        [
            MapIsland(
                id: "island-sonorant",
                islandId: .sonorant,
                zoneId: "zone-sonorant",
                name: String(localized: "worldMap.island.sonorant"),
                icon: "🐯",
                position: CGPoint(x: 0.74, y: 0.44),
                isLocked: false,
                isCompleted: false,
                isCurrentLocation: false,
                completionFraction: 0.10,
                levels: makeSonorantLevels()
            ),
            MapIsland(
                id: "island-velar",
                islandId: .velar,
                zoneId: "zone-velar",
                name: String(localized: "worldMap.island.velar"),
                icon: "🦆",
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
                icon: "🌟",
                position: CGPoint(x: 0.60, y: 0.12),
                isLocked: true,
                isCompleted: false,
                isCurrentLocation: false,
                completionFraction: 0.0,
                levels: makeSpecialLevels()
            )
        ]
    }

    // MARK: Level Builders

    static func makeVowelLevels() -> [MapLevel] {
        [
            MapLevel(id: "vowel-l1", name: String(localized: "worldMap.level.isolated"),
                     stage: .isolated, isLocked: false, isCompleted: true, successRate: 1.0, stars: 3),
            MapLevel(id: "vowel-l2", name: String(localized: "worldMap.level.syllable"),
                     stage: .syllable, isLocked: false, isCompleted: true, successRate: 0.95, stars: 3),
            MapLevel(id: "vowel-l3", name: String(localized: "worldMap.level.wordInit"),
                     stage: .wordInit, isLocked: false, isCompleted: true, successRate: 0.92, stars: 3),
            MapLevel(id: "vowel-l4", name: String(localized: "worldMap.level.phrase"),
                     stage: .phrase, isLocked: false, isCompleted: true, successRate: 0.88, stars: 2),
            MapLevel(id: "vowel-l5", name: String(localized: "worldMap.level.story"),
                     stage: .story, isLocked: false, isCompleted: true, successRate: 0.90, stars: 3)
        ]
    }

    static func makeWhistlingLevels() -> [MapLevel] {
        [
            MapLevel(id: "whistle-l1", name: String(localized: "worldMap.level.isolated"),
                     stage: .isolated, isLocked: false, isCompleted: true, successRate: 0.85, stars: 3),
            MapLevel(id: "whistle-l2", name: String(localized: "worldMap.level.syllable"),
                     stage: .syllable, isLocked: false, isCompleted: true, successRate: 0.80, stars: 2),
            MapLevel(id: "whistle-l3", name: String(localized: "worldMap.level.wordInit"),
                     stage: .wordInit, isLocked: false, isCompleted: false, successRate: 0.60, stars: 1),
            MapLevel(id: "whistle-l4", name: String(localized: "worldMap.level.phrase"),
                     stage: .phrase, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "whistle-l5", name: String(localized: "worldMap.level.story"),
                     stage: .story, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0)
        ]
    }

    static func makeHissingLevels() -> [MapLevel] {
        [
            MapLevel(id: "hiss-l1", name: String(localized: "worldMap.level.isolated"),
                     stage: .isolated, isLocked: false, isCompleted: true, successRate: 0.75, stars: 2),
            MapLevel(id: "hiss-l2", name: String(localized: "worldMap.level.syllable"),
                     stage: .syllable, isLocked: false, isCompleted: false, successRate: 0.45, stars: 1),
            MapLevel(id: "hiss-l3", name: String(localized: "worldMap.level.wordInit"),
                     stage: .wordInit, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "hiss-l4", name: String(localized: "worldMap.level.phrase"),
                     stage: .phrase, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "hiss-l5", name: String(localized: "worldMap.level.story"),
                     stage: .story, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0)
        ]
    }

    static func makeSonorantLevels() -> [MapLevel] {
        [
            MapLevel(id: "sono-l1", name: String(localized: "worldMap.level.isolated"),
                     stage: .isolated, isLocked: false, isCompleted: false, successRate: 0.30, stars: 0),
            MapLevel(id: "sono-l2", name: String(localized: "worldMap.level.syllable"),
                     stage: .syllable, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "sono-l3", name: String(localized: "worldMap.level.wordInit"),
                     stage: .wordInit, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "sono-l4", name: String(localized: "worldMap.level.phrase"),
                     stage: .phrase, isLocked: true, isCompleted: false, successRate: 0.0, stars: 0),
            MapLevel(id: "sono-l5", name: String(localized: "worldMap.level.story"),
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

    // MARK: Zones (legacy, kept for Presenter compatibility)

    static func makeSeedZones() -> [WorldZone] {
        makeSeedZonesPartOne() + makeSeedZonesPartTwo()
    }

    private static func makeSeedZonesPartOne() -> [WorldZone] {
        [
            WorldZone(
                id: "zone-vowels",
                name: String(localized: "worldMap.zone.vowels"),
                icon: "🎵",
                sounds: ["А", "О", "У", "И", "Э", "Ы"],
                progress: 1.0,
                completedLessons: 10,
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
                icon: "🐍",
                sounds: ["С", "Сь", "З", "Зь", "Ц"],
                progress: 0.65,
                completedLessons: 13,
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
            WorldZone(
                id: "zone-hissing",
                name: String(localized: "worldMap.zone.hissing"),
                icon: "🐝",
                sounds: ["Ш", "Ж", "Ч", "Щ"],
                progress: 0.30,
                completedLessons: 6,
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

    private static func makeSeedZonesPartTwo() -> [WorldZone] {
        [
            WorldZone(
                id: "zone-sonorant",
                name: String(localized: "worldMap.zone.sonorant"),
                icon: "🐯",
                sounds: ["Р", "Рь", "Л", "Ль"],
                progress: 0.10,
                completedLessons: 2,
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
                icon: "🦆",
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
                icon: "📚",
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
