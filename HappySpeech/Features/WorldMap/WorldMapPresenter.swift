import Foundation
import SwiftUI
import OSLog

// MARK: - WorldMapPresentationLogic

@MainActor
protocol WorldMapPresentationLogic: AnyObject {
    func presentLoadMap(_ response: WorldMapModels.LoadMap.Response)
    func presentSelectZone(_ response: WorldMapModels.SelectZone.Response)
    func presentFailure(_ response: WorldMapModels.Failure.Response)
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
            summaryAccessibilityLabel: summaryA11y
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

    func presentFailure(_ response: WorldMapModels.Failure.Response) {
        logger.error("worldMap failure: \(response.message, privacy: .public)")
        display?.displayFailure(.init(toastMessage: response.message))
    }

    // MARK: - Helpers

    private func makeCard(_ zone: WorldZone, isHighlighted: Bool) -> WorldZoneCard {
        let bg = backgroundColor(for: zone.colorName)
        let fg = foregroundColor(for: zone.colorName)
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
            backgroundColor: bg,
            foregroundColor: fg,
            isLocked: zone.isLocked,
            isHighlighted: isHighlighted,
            accessibilityLabel: a11yLabel,
            accessibilityHint: a11yHint
        )
    }

    private func backgroundColor(for name: String) -> Color {
        switch name {
        case "mint":   return ColorTokens.Brand.mint
        case "butter": return ColorTokens.Brand.butter
        case "lilac":  return ColorTokens.Brand.lilac
        case "coral":  return ColorTokens.Brand.primary
        case "gold":   return ColorTokens.Brand.gold
        default:       return ColorTokens.Brand.sky
        }
    }

    private func foregroundColor(for name: String) -> Color {
        // Все Brand-цвета достаточно насыщенные для белого текста.
        switch name {
        case "butter", "gold":
            return ColorTokens.Kid.ink
        default:
            return .white
        }
    }
}
