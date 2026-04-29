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
        var candidates: [Achievement] = []

        switch event {

        case .sessionCompleted(_, let score, let roundsTotal):
            candidates.append(contentsOf: checkSoundAchievements(profile: profile))
            candidates.append(contentsOf: checkRoundAchievements(totalRounds: roundsTotal))
            if score >= 1.0 {
                candidates.append(contentsOf: checkPerfectRounds(totalRounds: totalRoundsPlayed))
            }

        case .streakUpdated(let days):
            if days >= 3   { candidates.append(.streak3Days) }
            if days >= 7   { candidates.append(.streak7Days) }
            if days >= 14  { candidates.append(.streak14Days) }
            if days >= 30  { candidates.append(.streak30Days) }
            if days >= 100 { candidates.append(.streak100Days) }

        case .arGamePlayed:
            candidates.append(.firstAR)

        case .specialistVisited:
            candidates.append(.firstSpecialist)

        case .screeningDone:
            candidates.append(.screeningCompleted)

        case .fluencyDiaryEntryAdded:
            candidates.append(.firstFluencyDiary)

        case .familyRecordingAdded(let count):
            candidates.append(.firstFamilyRecording)
            if count >= 5 { candidates.append(.fiveFamilyRecordings) }

        case .multiplayerGamePlayed(let won, let winCount):
            if won { candidates.append(.firstSiblingMultiplayer) }
            if winCount >= 5 { candidates.append(.win5MultiplayerGames) }

        case .skinChanged:
            candidates.append(.firstSkinChange)

        case .allSkinsExplored:
            candidates.append(.allSkinsTried)

        case .worldZoneCompleted(let completed, let total):
            if completed >= total { candidates.append(.explorerAllZones) }

        case .sessionCompletedPerfect10Streak(let count):
            if count >= 10 { candidates.append(.perfectionist10Rounds) }

        case .sessionStartedEarlyMorning:
            candidates.append(.earlyBird)

        case .sessionStartedLateEvening:
            candidates.append(.nightOwl)
        }

        let newOnes = candidates.filter { !existingKeys.contains($0.rawValue) }
        return Array(Set(newOnes))
    }

    // MARK: - Private checkers

    private static func checkSoundAchievements(profile: ChildProfileDTO) -> [Achievement] {
        let masteredCount = profile.progressSummary.values.filter { $0 >= 0.8 }.count
        var result: [Achievement] = []
        if masteredCount >= 1 { result.append(.firstSoundMastered) }
        if masteredCount >= 5 { result.append(.fiveSoundsMastered) }
        let allMastered = !profile.progressSummary.isEmpty
            && profile.progressSummary.values.allSatisfy { $0 >= 0.8 }
        if allMastered { result.append(.allSoundsMastered) }
        return result
    }

    private static func checkRoundAchievements(totalRounds: Int) -> [Achievement] {
        var result: [Achievement] = []
        if totalRounds >= 10   { result.append(.played10Rounds) }
        if totalRounds >= 50   { result.append(.played50Rounds) }
        if totalRounds >= 100  { result.append(.played100Rounds) }
        if totalRounds >= 500  { result.append(.played500Rounds) }
        if totalRounds >= 1000 { result.append(.played1000Rounds) }
        return result
    }

    private static func checkPerfectRounds(totalRounds: Int) -> [Achievement] {
        guard totalRounds >= 10 else { return [] }
        return [.perfectionist10Rounds]
    }
}
