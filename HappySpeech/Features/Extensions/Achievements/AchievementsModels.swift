import Foundation

// MARK: - AchievementRarity

enum AchievementRarity: String, Sendable, CaseIterable {
    case common
    case rare
    case legendary

    var localizedTitle: String {
        switch self {
        case .common:    return String(localized: "achievements.section.common")
        case .rare:      return String(localized: "achievements.section.rare")
        case .legendary: return String(localized: "achievements.section.legendary")
        }
    }

    var sortOrder: Int {
        switch self {
        case .legendary: return 0
        case .rare:      return 1
        case .common:    return 2
        }
    }
}

// MARK: - Achievement

enum Achievement: String, CaseIterable, Sendable {

    // Звуки
    case firstSoundMastered
    case fiveSoundsMastered
    case allSoundsMastered

    // Streaks
    case streak3Days
    case streak7Days
    case streak14Days
    case streak30Days
    case streak100Days

    // Rounds
    case played10Rounds
    case played50Rounds
    case played100Rounds
    case played500Rounds
    case played1000Rounds

    // Games
    case firstAR
    case allARGames
    case firstSpecialist
    case screeningCompleted

    // Stuttering
    case firstFluencyDiary
    case week5StutteringPractice

    // Family
    case firstFamilyRecording
    case fiveFamilyRecordings
    case firstSiblingMultiplayer
    case win5MultiplayerGames

    // Customization
    case firstSkinChange
    case allSkinsTried

    // Seasonal
    case halloweenCompleted
    case newYearCompleted
    case easterCompleted

    // Special
    case explorerAllZones
    case perfectionist10Rounds
    case earlyBird
    case nightOwl

    var localizedTitle: String {
        String(localized: "achievement.title.\(rawValue)")
    }

    var localizedDescription: String {
        String(localized: "achievement.description.\(rawValue)")
    }

    var iconName: String {
        switch self {
        case .firstSoundMastered:      return "speaker.wave.2.fill"
        case .fiveSoundsMastered:      return "speaker.wave.3.fill"
        case .allSoundsMastered:       return "star.circle.fill"
        case .streak3Days:             return "flame"
        case .streak7Days:             return "flame.fill"
        case .streak14Days:            return "bolt.fill"
        case .streak30Days:            return "bolt.circle.fill"
        case .streak100Days:           return "crown.fill"
        case .played10Rounds:          return "gamecontroller"
        case .played50Rounds:          return "gamecontroller.fill"
        case .played100Rounds:         return "trophy"
        case .played500Rounds:         return "trophy.fill"
        case .played1000Rounds:        return "medal.fill"
        case .firstAR:                 return "camera.metering.matrix"
        case .allARGames:              return "arkit"
        case .firstSpecialist:         return "person.badge.clock.fill"
        case .screeningCompleted:      return "checkmark.seal.fill"
        case .firstFluencyDiary:       return "book.fill"
        case .week5StutteringPractice: return "figure.mind.and.body"
        case .firstFamilyRecording:    return "mic.fill"
        case .fiveFamilyRecordings:    return "mic.badge.plus"
        case .firstSiblingMultiplayer: return "person.2.fill"
        case .win5MultiplayerGames:    return "person.2.wave.2.fill"
        case .firstSkinChange:         return "paintbrush.fill"
        case .allSkinsTried:           return "swatchpalette.fill"
        case .halloweenCompleted:      return "moon.stars.fill"
        case .newYearCompleted:        return "fireworks"
        case .easterCompleted:         return "cloud.sun.fill"
        case .explorerAllZones:        return "map.fill"
        case .perfectionist10Rounds:   return "target"
        case .earlyBird:               return "sunrise.fill"
        case .nightOwl:                return "moon.fill"
        }
    }

    var rarity: AchievementRarity {
        switch self {
        case .streak100Days, .played1000Rounds, .allSoundsMastered, .allARGames,
             .allSkinsTried, .explorerAllZones, .perfectionist10Rounds:
            return .legendary
        case .streak30Days, .played500Rounds, .fiveSoundsMastered, .win5MultiplayerGames,
             .week5StutteringPractice, .newYearCompleted, .halloweenCompleted, .easterCompleted:
            return .rare
        default:
            return .common
        }
    }
}

// MARK: - AchievementEvent

enum AchievementEvent: Sendable {
    case sessionCompleted(soundId: String, score: Double, roundsTotal: Int)
    case streakUpdated(days: Int)
    case arGamePlayed
    case specialistVisited
    case screeningDone
    case fluencyDiaryEntryAdded
    case familyRecordingAdded(count: Int)
    case multiplayerGamePlayed(won: Bool, winCount: Int)
    case skinChanged
    case allSkinsExplored
    case worldZoneCompleted(totalCompleted: Int, totalZones: Int)
    case sessionCompletedPerfect10Streak(count: Int)
    case sessionStartedEarlyMorning
    case sessionStartedLateEvening
}

// MARK: - AchievementDTO (Sendable DTO)

struct AchievementDTO: Identifiable, Sendable {
    let id: String                   // Achievement.rawValue
    let achievement: Achievement
    let isUnlocked: Bool
    let unlockedAt: Date?
}

// MARK: - RepetitionScheduleDTO

struct RepetitionScheduleDTO: Sendable {
    let childId: String
    let entries: [RepetitionEntryDTO]
}

struct RepetitionEntryDTO: Identifiable, Sendable {
    let id: String
    let soundId: String
    let nextSessionDate: Date
    let intervalDays: Int
    let lastScore: Double
}

// MARK: - AchievementsModels (VIP scenes)

enum AchievementsModels {

    enum Load {
        struct Request { let childId: String }

        struct Response {
            let childId: String
            let achievements: [AchievementDTO]
            let totalUnlocked: Int
            let totalCount: Int
            let sessions: [SessionDayEntry]
            let siblingProfiles: [SiblingProgressDTO]
        }

        struct ViewModel {
            let progressText: String
            let sections: [AchievementSection]
            let leaderboardDays: [LeaderboardDayEntry]
            let siblingLeaderboard: [SiblingLeaderboardEntry]
            let showFamilyLeaderboard: Bool
        }
    }

    enum ToastUnlocked {
        struct Response { let achievement: Achievement }
        struct ViewModel { let message: String; let iconName: String }
    }
}

// MARK: - Supporting types for ViewModel

struct AchievementSection: Identifiable, Sendable {
    var id: String { rarity.rawValue }
    let rarity: AchievementRarity
    let items: [AchievementCellViewModel]
}

struct AchievementCellViewModel: Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
    let iconName: String
    let rarity: AchievementRarity
    let isUnlocked: Bool
    let unlockedAt: Date?
    let unlockedDateFormatted: String?
}

struct LeaderboardDayEntry: Identifiable, Sendable {
    let id: String
    let date: Date
    let label: String
    let roundsCompleted: Int
    let successRate: Double
}

struct SiblingProgressDTO: Identifiable, Sendable {
    let id: String
    let name: String
    let totalUnlocked: Int
}

struct SiblingLeaderboardEntry: Identifiable, Sendable {
    let id: String
    let childName: String
    let totalAchievements: Int
    let rank: Int
}

struct SessionDayEntry: Identifiable, Sendable {
    let id: String
    let date: Date
    let roundsCompleted: Int
    let successRate: Double
}
