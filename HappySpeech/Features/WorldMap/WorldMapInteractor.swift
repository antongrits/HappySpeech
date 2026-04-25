import Foundation
import OSLog

// MARK: - WorldMapBusinessLogic

@MainActor
protocol WorldMapBusinessLogic: AnyObject {
    func loadMap(_ request: WorldMapModels.LoadMap.Request)
    func selectZone(_ request: WorldMapModels.SelectZone.Request)
}

// MARK: - WorldMapInteractor

/// Бизнес-логика карты звуков.
///
/// На текущем спринте — статический seed (5 зон). На следующем подключаем
/// `ChildRepository.getZoneProgress(childId:)` поверх Realm.
@MainActor
final class WorldMapInteractor: WorldMapBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any WorldMapPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "WorldMap")

    // MARK: - State

    private var zones: [WorldZone] = []
    private var totalStars: Int = 0
    private var dailyStreak: Int = 0

    // MARK: - BusinessLogic

    func loadMap(_ request: WorldMapModels.LoadMap.Request) {
        logger.info("loadMap childId=\(request.childId, privacy: .private(mask: .hash))")
        zones = Self.makeSeedZones()
        totalStars = zones.reduce(0) { $0 + $1.completedLessons }
        dailyStreak = 4

        let highlightedId = request.highlightedSound.flatMap { sound in
            zones.first(where: { $0.sounds.contains(sound) })?.id
        }

        let response = WorldMapModels.LoadMap.Response(
            zones: zones,
            totalStars: totalStars,
            highlightedZoneId: highlightedId,
            dailyStreak: dailyStreak
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
}

// MARK: - Seed

private extension WorldMapInteractor {

    static func makeSeedZones() -> [WorldZone] {
        [
            WorldZone(
                id: "zone-whistling",
                name: String(localized: "worldMap.zone.whistling"),
                icon: "🐍",
                sounds: ["С", "З", "Ц"],
                progress: 0.65,
                completedLessons: 13,
                totalLessons: 20,
                colorName: "mint",
                isLocked: false
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
                isLocked: false
            ),
            WorldZone(
                id: "zone-sonorant",
                name: String(localized: "worldMap.zone.sonorant"),
                icon: "🐯",
                sounds: ["Р", "Л"],
                progress: 0.10,
                completedLessons: 2,
                totalLessons: 20,
                colorName: "lilac",
                isLocked: false
            ),
            WorldZone(
                id: "zone-velar",
                name: String(localized: "worldMap.zone.velar"),
                icon: "🦆",
                sounds: ["К", "Г", "Х"],
                progress: 0.0,
                completedLessons: 0,
                totalLessons: 15,
                colorName: "coral",
                isLocked: true
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
                isLocked: true
            )
        ]
    }
}
