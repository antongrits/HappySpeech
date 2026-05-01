import Foundation
import OSLog
import RealmSwift

// MARK: - AchievementNotificationName

extension Notification.Name {
    static let achievementEventOccurred = Notification.Name("ru.happyspeech.achievementEvent")
}

// MARK: - AchievementUnlockerWorker

/// Слушает события из других частей приложения и решает, какие достижения разблокировать.
/// Публикует результат через NotificationCenter (чтобы не создавать жёстких зависимостей).
/// Kid circuit — вся логика выполняется локально (COPPA compliant, нет сети).
final class AchievementUnlockerWorker: @unchecked Sendable {

    // MARK: - Static helpers

    /// Проверяет события и возвращает список новых достижений, которые нужно разблокировать.
    /// Сравнивает с уже разблокированными (параметр `existing`).
    static func checkAchievements(
        event: AchievementEvent,
        existingKeys: Set<String>,
        profile: ChildProfileDTO,
        totalRoundsPlayed: Int
    ) -> [Achievement] {
        let candidates = candidates(for: event, profile: profile, totalRoundsPlayed: totalRoundsPlayed)
        let newOnes = candidates.filter { !existingKeys.contains($0.rawValue) }
        return Array(Set(newOnes))
    }

    private static func candidates(
        for event: AchievementEvent,
        profile: ChildProfileDTO,
        totalRoundsPlayed: Int
    ) -> [Achievement] {
        var result: [Achievement] = []
        switch event {
        case .sessionCompleted(_, let score, let roundsTotal):
            result.append(contentsOf: checkSoundAchievements(profile: profile))
            result.append(contentsOf: checkRoundAchievements(totalRounds: roundsTotal))
            if score >= 1.0 {
                result.append(contentsOf: checkPerfectRounds(totalRounds: totalRoundsPlayed))
            }
        case .streakUpdated(let days):
            result.append(contentsOf: streakAchievements(days: days))
        case .arGamePlayed:
            result.append(.firstAR)
        case .specialistVisited:
            result.append(.firstSpecialist)
        case .screeningDone:
            result.append(.screeningCompleted)
        case .fluencyDiaryEntryAdded:
            result.append(.firstFluencyDiary)
        case .familyRecordingAdded(let count):
            result.append(.firstFamilyRecording)
            if count >= 5 { result.append(.fiveFamilyRecordings) }
        case .multiplayerGamePlayed(let won, let winCount):
            if won { result.append(.firstSiblingMultiplayer) }
            if winCount >= 5 { result.append(.win5MultiplayerGames) }
        case .skinChanged:
            result.append(.firstSkinChange)
        case .allSkinsExplored:
            result.append(.allSkinsTried)
        case .worldZoneCompleted(let completed, let total):
            if completed >= total { result.append(.explorerAllZones) }
        case .sessionCompletedPerfect10Streak(let count):
            if count >= 10 { result.append(.perfectionist10Rounds) }
        case .sessionStartedEarlyMorning:
            result.append(.earlyBird)
        case .sessionStartedLateEvening:
            result.append(.nightOwl)
        }
        return result
    }

    private static func streakAchievements(days: Int) -> [Achievement] {
        var result: [Achievement] = []
        if days >= 3 { result.append(.streak3Days) }
        if days >= 7 { result.append(.streak7Days) }
        if days >= 14 { result.append(.streak14Days) }
        if days >= 30 { result.append(.streak30Days) }
        if days >= 100 { result.append(.streak100Days) }
        return result
    }

    // MARK: - Private checkers

    private static func checkSoundAchievements(profile: ChildProfileDTO) -> [Achievement] {
        let learnedCount = profile.progressSummary.values.filter { $0 >= 0.8 }.count
        var result: [Achievement] = []
        if learnedCount >= 1 { result.append(.firstSoundMastered) }
        if learnedCount >= 5 { result.append(.fiveSoundsMastered) }
        let allLearned = !profile.progressSummary.isEmpty
            && profile.progressSummary.values.allSatisfy { $0 >= 0.8 }
        if allLearned { result.append(.allSoundsMastered) }
        return result
    }

    private static func checkRoundAchievements(totalRounds: Int) -> [Achievement] {
        var result: [Achievement] = []
        if totalRounds >= 10 { result.append(.played10Rounds) }
        if totalRounds >= 50 { result.append(.played50Rounds) }
        if totalRounds >= 100 { result.append(.played100Rounds) }
        if totalRounds >= 500 { result.append(.played500Rounds) }
        if totalRounds >= 1000 { result.append(.played1000Rounds) }
        return result
    }

    private static func checkPerfectRounds(totalRounds: Int) -> [Achievement] {
        guard totalRounds >= 10 else { return [] }
        return [.perfectionist10Rounds]
    }
}
