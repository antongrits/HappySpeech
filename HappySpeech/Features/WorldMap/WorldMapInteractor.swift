import Foundation
import OSLog

// MARK: - WorldMapBusinessLogic

@MainActor
protocol WorldMapBusinessLogic: AnyObject {
    func loadMap(_ request: WorldMapModels.LoadMap.Request)
    func selectZone(_ request: WorldMapModels.SelectZone.Request)
    func loadZoneDetail(_ request: WorldMapModels.LoadZoneDetail.Request)
    func refreshProgress(_ request: WorldMapModels.RefreshProgress.Request)
}

// MARK: - WorldMapInteractor

/// Бизнес-логика карты звуков. Использует in-memory seed (5 зон).
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

        logger.info("loadZoneDetail id=\(zone.id, privacy: .public)")
        presenter?.presentLoadZoneDetail(.init(
            zone: zone,
            recommendedLessonCount: zone.recommendedLessonCount,
            estimatedMinutesPerSession: zone.estimatedMinutesPerSession,
            prerequisiteZoneName: prereqName
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

        presenter?.presentRefreshProgress(.init(
            zones: zones,
            totalStars: totalStars,
            dailyStreak: dailyStreak
        ))
    }
}

// MARK: - Seed

private extension WorldMapInteractor {

    /// Сид-данные карты звуков. 7 зон → 7 островов на «канвасе».
    /// Порядок — последовательность логопедической работы.
    static func makeSeedZones() -> [WorldZone] {
        seedZonesPartOne() + seedZonesPartTwo()
    }

    private static func seedZonesPartOne() -> [WorldZone] {
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

    private static func seedZonesPartTwo() -> [WorldZone] {
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
            ),
            WorldZone(
                id: "zone-ar",
                name: String(localized: "worldMap.zone.ar"),
                icon: "🌟",
                sounds: [],
                progress: 0.0,
                completedLessons: 0,
                totalLessons: 8,
                colorName: "primary",
                isLocked: true,
                position: CGPoint(x: 0.50, y: 0.05),
                isCurrentLocation: false,
                description: String(localized: "worldMap.zone.ar.desc"),
                prerequisiteZoneId: "zone-grammar",
                recommendedLessonCount: 8,
                estimatedMinutesPerSession: 10
            )
        ]
    }
}
