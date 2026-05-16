@testable import HappySpeech
import XCTest

// MARK: - AchievementUnlockerWorkerTests
//
// Покрывает статический метод checkAchievements и все ветки кандидатов.

final class AchievementUnlockerWorkerTests: XCTestCase {

    // MARK: - Helpers

    private func makeProfile(
        progressSummary: [String: Double] = [:],
        currentStreak: Int = 0,
        totalSessionMinutes: Int = 0
    ) -> ChildProfileDTO {
        TestDataBuilder.childProfile(
            progressSummary: progressSummary,
            totalSessionMinutes: totalSessionMinutes,
            currentStreak: currentStreak
        )
    }

    // MARK: - sessionCompleted: звуковые достижения

    func test_checkAchievements_firstSoundMastered_whenOneProgressAbove08() {
        let profile = makeProfile(progressSummary: ["Р": 0.9])
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .sessionCompleted(soundId: "Р", score: 0.5, roundsTotal: 5),
            existingKeys: [],
            profile: profile,
            totalRoundsPlayed: 5
        )
        XCTAssertTrue(result.contains(.firstSoundMastered),
                      "Должно выдавать firstSoundMastered при 1 звуке >= 0.8")
    }

    func test_checkAchievements_fiveSoundsMastered_whenFiveProgressAbove08() {
        let progress = ["Р": 0.9, "С": 0.85, "Ш": 0.9, "З": 0.9, "Л": 0.85]
        let profile = makeProfile(progressSummary: progress)
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .sessionCompleted(soundId: "Р", score: 0.5, roundsTotal: 5),
            existingKeys: [],
            profile: profile,
            totalRoundsPlayed: 5
        )
        XCTAssertTrue(result.contains(.fiveSoundsMastered),
                      "Должно выдавать fiveSoundsMastered при 5 звуках >= 0.8")
    }

    func test_checkAchievements_allSoundsMastered_whenAllAbove08() {
        let progress = ["Р": 0.9, "С": 0.85]
        let profile = makeProfile(progressSummary: progress)
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .sessionCompleted(soundId: "Р", score: 0.5, roundsTotal: 5),
            existingKeys: [],
            profile: profile,
            totalRoundsPlayed: 5
        )
        XCTAssertTrue(result.contains(.allSoundsMastered),
                      "Должно выдавать allSoundsMastered если все звуки >= 0.8")
    }

    func test_checkAchievements_noSoundAchievement_whenProgressBelow08() {
        let profile = makeProfile(progressSummary: ["Р": 0.5])
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .sessionCompleted(soundId: "Р", score: 0.5, roundsTotal: 5),
            existingKeys: [],
            profile: profile,
            totalRoundsPlayed: 5
        )
        XCTAssertFalse(result.contains(.firstSoundMastered),
                       "Не должно выдавать firstSoundMastered при прогрессе < 0.8")
    }

    // MARK: - sessionCompleted: round achievements

    func test_checkAchievements_played10Rounds_whenRoundsTotal10() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .sessionCompleted(soundId: "Р", score: 0.5, roundsTotal: 10),
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 10
        )
        XCTAssertTrue(result.contains(.played10Rounds),
                      "Должно выдавать played10Rounds при 10 раундах")
    }

    func test_checkAchievements_played50Rounds_whenRoundsTotal50() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .sessionCompleted(soundId: "Р", score: 0.5, roundsTotal: 50),
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 50
        )
        XCTAssertTrue(result.contains(.played50Rounds))
        XCTAssertTrue(result.contains(.played10Rounds))
    }

    func test_checkAchievements_noDuplicates_whenAlreadyExisting() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .sessionCompleted(soundId: "Р", score: 0.5, roundsTotal: 10),
            existingKeys: [Achievement.played10Rounds.rawValue],
            profile: makeProfile(),
            totalRoundsPlayed: 10
        )
        XCTAssertFalse(result.contains(.played10Rounds),
                       "Уже разблокированное достижение не должно возвращаться")
    }

    // MARK: - sessionCompleted: perfect round achievement

    func test_checkAchievements_perfectionist_whenScore1AndRoundsAtLeast10() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .sessionCompleted(soundId: "Р", score: 1.0, roundsTotal: 10),
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 10
        )
        XCTAssertTrue(result.contains(.perfectionist10Rounds),
                      "Должно выдавать perfectionist10Rounds при score=1.0 и rounds>=10")
    }

    func test_checkAchievements_noPerfectionist_whenRoundsLessThan10() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .sessionCompleted(soundId: "Р", score: 1.0, roundsTotal: 5),
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 9
        )
        XCTAssertFalse(result.contains(.perfectionist10Rounds),
                       "Не должно выдавать perfectionist10Rounds если rounds < 10")
    }

    // MARK: - streakUpdated

    func test_checkAchievements_streak3_whenDaysGte3() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .streakUpdated(days: 3),
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 0
        )
        XCTAssertTrue(result.contains(.streak3Days))
        XCTAssertFalse(result.contains(.streak7Days))
    }

    func test_checkAchievements_streak100_whenDaysGte100() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .streakUpdated(days: 100),
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 0
        )
        XCTAssertTrue(result.contains(.streak100Days))
        XCTAssertTrue(result.contains(.streak30Days))
        XCTAssertTrue(result.contains(.streak14Days))
        XCTAssertTrue(result.contains(.streak7Days))
        XCTAssertTrue(result.contains(.streak3Days))
    }

    // MARK: - Разовые события

    func test_checkAchievements_firstAR_whenARGamePlayed() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .arGamePlayed,
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 0
        )
        XCTAssertTrue(result.contains(.firstAR),
                      "arGamePlayed должно выдавать firstAR")
    }

    func test_checkAchievements_firstSpecialist_whenSpecialistVisited() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .specialistVisited,
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 0
        )
        XCTAssertTrue(result.contains(.firstSpecialist))
    }

    func test_checkAchievements_screeningCompleted_whenScreeningDone() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .screeningDone,
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 0
        )
        XCTAssertTrue(result.contains(.screeningCompleted))
    }

    func test_checkAchievements_firstFluencyDiary_whenDiaryEntryAdded() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .fluencyDiaryEntryAdded,
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 0
        )
        XCTAssertTrue(result.contains(.firstFluencyDiary))
    }

    func test_checkAchievements_firstSkinChange_whenSkinChanged() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .skinChanged,
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 0
        )
        XCTAssertTrue(result.contains(.firstSkinChange))
    }

    func test_checkAchievements_allSkinsTried_whenAllSkinsExplored() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .allSkinsExplored,
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 0
        )
        XCTAssertTrue(result.contains(.allSkinsTried))
    }

    // MARK: - familyRecordingAdded

    func test_checkAchievements_firstFamilyRecording_whenCountGte1() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .familyRecordingAdded(count: 1),
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 0
        )
        XCTAssertTrue(result.contains(.firstFamilyRecording))
        XCTAssertFalse(result.contains(.fiveFamilyRecordings))
    }

    func test_checkAchievements_fiveFamilyRecordings_whenCountGte5() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .familyRecordingAdded(count: 5),
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 0
        )
        XCTAssertTrue(result.contains(.firstFamilyRecording))
        XCTAssertTrue(result.contains(.fiveFamilyRecordings))
    }

    // MARK: - multiplayerGamePlayed

    func test_checkAchievements_firstSiblingMultiplayer_whenWon() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .multiplayerGamePlayed(won: true, winCount: 1),
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 0
        )
        XCTAssertTrue(result.contains(.firstSiblingMultiplayer))
    }

    func test_checkAchievements_noFirstSiblingMultiplayer_whenLost() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .multiplayerGamePlayed(won: false, winCount: 0),
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 0
        )
        XCTAssertFalse(result.contains(.firstSiblingMultiplayer))
    }

    func test_checkAchievements_win5MultiplayerGames_whenWinCountGte5() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .multiplayerGamePlayed(won: true, winCount: 5),
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 0
        )
        XCTAssertTrue(result.contains(.win5MultiplayerGames))
    }

    // MARK: - worldZoneCompleted

    func test_checkAchievements_explorerAllZones_whenAllCompleted() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .worldZoneCompleted(totalCompleted: 5, totalZones: 5),
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 0
        )
        XCTAssertTrue(result.contains(.explorerAllZones))
    }

    func test_checkAchievements_noExplorer_whenNotAllCompleted() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .worldZoneCompleted(totalCompleted: 3, totalZones: 5),
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 0
        )
        XCTAssertFalse(result.contains(.explorerAllZones))
    }

    // MARK: - Ранние/поздние сессии

    func test_checkAchievements_earlyBird_whenSessionStartedEarlyMorning() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .sessionStartedEarlyMorning,
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 0
        )
        XCTAssertTrue(result.contains(.earlyBird))
    }

    func test_checkAchievements_nightOwl_whenSessionStartedLateEvening() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .sessionStartedLateEvening,
            existingKeys: [],
            profile: makeProfile(),
            totalRoundsPlayed: 0
        )
        XCTAssertTrue(result.contains(.nightOwl))
    }

    // MARK: - Пустой список при пустом профиле

    func test_checkAchievements_emptyProgressProfile_noSoundAchievements() {
        let result = AchievementUnlockerWorker.checkAchievements(
            event: .sessionCompleted(soundId: "Р", score: 0.5, roundsTotal: 5),
            existingKeys: [],
            profile: makeProfile(progressSummary: [:]),
            totalRoundsPlayed: 5
        )
        XCTAssertFalse(result.contains(.firstSoundMastered))
        XCTAssertFalse(result.contains(.allSoundsMastered))
    }
}
