import Foundation
import OSLog

// MARK: - WorldMapPresentationLogic

@MainActor
protocol WorldMapPresentationLogic: AnyObject {
    func presentLoadMap(_ response: WorldMapModels.LoadMap.Response)
    func presentSelectZone(_ response: WorldMapModels.SelectZone.Response)
    func presentLoadZoneDetail(_ response: WorldMapModels.LoadZoneDetail.Response)
    func presentRefreshProgress(_ response: WorldMapModels.RefreshProgress.Response)
    func presentFailure(_ response: WorldMapModels.Failure.Response)
    func presentVoicePrompt(_ response: WorldMapModels.VoicePrompt.Response)
    func presentCollectTreasure(_ response: WorldMapModels.CollectTreasure.Response)
    func presentSelectLevel(_ response: WorldMapModels.SelectLevel.Response)
    func presentAdaptiveRecommendation(_ response: WorldMapModels.AdaptiveRecommendation.Response)
}

// MARK: - WorldMapPresenter

@MainActor
final class WorldMapPresenter: WorldMapPresentationLogic {

    weak var display: (any WorldMapDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "WorldMapPresenter")

    func presentLoadMap(_ response: WorldMapModels.LoadMap.Response) {
        let cards = response.zones.map { zone in
            makeCard(zone, isHighlighted: zone.id == response.highlightedZoneId)
        }

        let totalLessons = response.zones.reduce(0) { $0 + $1.totalLessons }
        let totalCompleted = response.zones.reduce(0) { $0 + $1.completedLessons }
        let totalProgress = totalLessons > 0
            ? Double(totalCompleted) / Double(totalLessons)
            : 0

        let starsLabel = String(
            format: String(localized: "worldMap.stars.label"),
            response.totalStars
        )
        let streakLabel = String(
            format: String(localized: "worldMap.streak.label"),
            response.dailyStreak
        )
        let summaryA11y = String(
            format: String(localized: "worldMap.a11y.summary"),
            response.totalStars, response.dailyStreak
        )

        let viewModel = WorldMapModels.LoadMap.ViewModel(
            zones: cards,
            highlightedZoneId: response.highlightedZoneId,
            totalStarsLabel: starsLabel,
            totalProgressFraction: totalProgress,
            streakLabel: streakLabel,
            hasStreak: response.dailyStreak > 0,
            summaryAccessibilityLabel: summaryA11y,
            lyalyaIslandId: response.lyalyaIslandId,
            recommendedIslandId: response.recommendedIslandId,
            recommendedLevelId: response.recommendedLevelId
        )
        display?.displayLoadMap(viewModel)
    }

    func presentSelectZone(_ response: WorldMapModels.SelectZone.Response) {
        let toast: String?
        if !response.canOpen {
            toast = String(localized: "worldMap.toast.locked")
        } else {
            toast = nil
        }

        let viewModel = WorldMapModels.SelectZone.ViewModel(
            zoneId: response.zone.id,
            canOpen: response.canOpen,
            toastMessage: toast
        )
        display?.displaySelectZone(viewModel)
    }

    func presentLoadZoneDetail(_ response: WorldMapModels.LoadZoneDetail.Response) {
        let zone = response.zone
        let progressInt = Int((zone.progress * 100).rounded())

        let soundsLabel: String
        if zone.sounds.isEmpty {
            soundsLabel = String(localized: "worldMap.zone.grammarHint")
        } else {
            soundsLabel = zone.sounds.joined(separator: " · ")
        }

        let ctaTitle: String
        if zone.isLocked {
            ctaTitle = String(localized: "worldMap.detail.ctaLocked")
        } else if zone.progress >= 1.0 {
            ctaTitle = String(localized: "worldMap.detail.ctaReview")
        } else if zone.progress > 0 {
            ctaTitle = String(localized: "worldMap.detail.ctaContinue")
        } else {
            ctaTitle = String(localized: "worldMap.detail.ctaStart")
        }

        let prereqHint: String?
        if let prereq = response.prerequisiteZoneName {
            prereqHint = String(
                format: String(localized: "worldMap.detail.prerequisiteHint"),
                prereq
            )
        } else {
            prereqHint = nil
        }

        let progressLabel = String(
            format: String(localized: "worldMap.zone.progressPercent"),
            progressInt
        )
        let lessonsLabel = String(
            format: String(localized: "worldMap.zone.lessons"),
            zone.completedLessons, zone.totalLessons
        )
        let recommendedLabel = String(
            format: String(localized: "worldMap.detail.recommendedLessons"),
            response.recommendedLessonCount
        )
        let durationLabel = String(
            format: String(localized: "worldMap.detail.sessionDuration"),
            response.estimatedMinutesPerSession
        )

        let a11yLabel = zone.isLocked
            ? String(format: String(localized: "worldMap.a11y.lockedZone"), zone.name)
            : String(format: String(localized: "worldMap.a11y.unlockedZone"), zone.name, progressInt)

        let viewModel = WorldMapModels.LoadZoneDetail.ViewModel(
            zoneId: zone.id,
            name: zone.name,
            icon: zone.icon,
            description: zone.description,
            soundsLabel: soundsLabel,
            progressLabel: progressLabel,
            progress: Double(zone.progress),
            lessonsLabel: lessonsLabel,
            recommendedLabel: recommendedLabel,
            durationLabel: durationLabel,
            isLocked: zone.isLocked,
            prerequisiteHint: prereqHint,
            ctaTitle: ctaTitle,
            colorName: zone.colorName,
            accessibilityLabel: a11yLabel,
            levels: response.levels,
            recommendedLevelId: response.recommendedLevelId,
            unlocksNeeded: response.unlocksNeeded
        )
        display?.displayLoadZoneDetail(viewModel)
    }

    func presentRefreshProgress(_ response: WorldMapModels.RefreshProgress.Response) {
        let cards = response.zones.map { zone in
            makeCard(zone, isHighlighted: false)
        }

        let totalLessons = response.zones.reduce(0) { $0 + $1.totalLessons }
        let totalCompleted = response.zones.reduce(0) { $0 + $1.completedLessons }
        let totalProgress = totalLessons > 0
            ? Double(totalCompleted) / Double(totalLessons)
            : 0

        let starsLabel = String(
            format: String(localized: "worldMap.stars.label"),
            response.totalStars
        )
        let streakLabel = String(
            format: String(localized: "worldMap.streak.label"),
            response.dailyStreak
        )
        let summaryA11y = String(
            format: String(localized: "worldMap.a11y.summary"),
            response.totalStars, response.dailyStreak
        )

        let viewModel = WorldMapModels.RefreshProgress.ViewModel(
            zones: cards,
            totalStarsLabel: starsLabel,
            totalProgressFraction: totalProgress,
            streakLabel: streakLabel,
            hasStreak: response.dailyStreak > 0,
            summaryAccessibilityLabel: summaryA11y
        )
        display?.displayRefreshProgress(viewModel)
    }

    func presentFailure(_ response: WorldMapModels.Failure.Response) {
        logger.error("worldMap failure: \(response.message, privacy: .public)")
        display?.displayFailure(.init(toastMessage: response.message))
    }

    func presentVoicePrompt(_ response: WorldMapModels.VoicePrompt.Response) {
        display?.displayVoicePrompt(.init(text: response.text, isLyalya: response.isLyalya))
    }

    func presentCollectTreasure(_ response: WorldMapModels.CollectTreasure.Response) {
        // Block D v16: эмодзи коллекционных предметов → SF Symbols.
        let icon: String
        switch response.collectible.type {
        case .goldPebble: icon = "circle.fill"     // FALLBACK: gold pebble
        case .magicShell: icon = "shell.fill"
        case .speechCrystal: icon = "diamond.fill"
        }
        let toast = String(
            format: String(localized: "worldMap.collectible.toast"),
            icon, response.collectible.starValue
        )
        let starsLabel = String(
            format: String(localized: "worldMap.stars.label"),
            response.totalStars
        )
        display?.displayCollectTreasure(.init(
            collectibleIcon: icon,
            totalStarsLabel: starsLabel,
            toastMessage: toast,
            remainingCollectibles: response.remainingCollectibles
        ))
    }

    func presentSelectLevel(_ response: WorldMapModels.SelectLevel.Response) {
        display?.displaySelectLevel(.init(
            levelId: response.level.id,
            islandId: response.islandId,
            zoneId: response.zoneId,
            levelName: response.level.name
        ))
    }

    func presentAdaptiveRecommendation(_ response: WorldMapModels.AdaptiveRecommendation.Response) {
        display?.displayAdaptiveRecommendation(.init(
            recommendedIslandId: response.recommendedIslandId,
            recommendedLevelId: response.recommendedLevelId,
            voiceHint: response.voiceHint
        ))
    }

    // MARK: - Helpers

    private func makeCard(_ zone: WorldZone, isHighlighted: Bool) -> WorldZoneCard {
        let progressInt = Int((zone.progress * 100).rounded())

        let progressLabel = String(
            format: String(localized: "worldMap.zone.progressPercent"),
            progressInt
        )
        let lessonsLabel = String(
            format: String(localized: "worldMap.zone.lessons"),
            zone.completedLessons, zone.totalLessons
        )
        let soundsLabel: String
        if zone.sounds.isEmpty {
            soundsLabel = String(localized: "worldMap.zone.grammarHint")
        } else {
            soundsLabel = zone.sounds.joined(separator: " · ")
        }

        let a11yLabel: String
        let a11yHint: String
        if zone.isLocked {
            a11yLabel = String(
                format: String(localized: "worldMap.a11y.lockedZone"),
                zone.name
            )
            a11yHint = String(localized: "worldMap.a11y.lockedHint")
        } else {
            a11yLabel = String(
                format: String(localized: "worldMap.a11y.unlockedZone"),
                zone.name, progressInt
            )
            a11yHint = String(localized: "worldMap.a11y.unlockedHint")
        }

        return WorldZoneCard(
            id: zone.id,
            name: zone.name,
            icon: zone.icon,
            soundsLabel: soundsLabel,
            progress: Double(zone.progress),
            progressLabel: progressLabel,
            lessonsLabel: lessonsLabel,
            colorName: zone.colorName,
            isLocked: zone.isLocked,
            isHighlighted: isHighlighted,
            position: zone.position,
            isCurrentLocation: zone.isCurrentLocation,
            isCompleted: zone.progress >= 1.0,
            accessibilityLabel: a11yLabel,
            accessibilityHint: a11yHint
        )
    }
}
