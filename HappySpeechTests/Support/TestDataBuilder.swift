import Foundation
@testable import HappySpeech

/// Test data builder для HappySpeech unit/integration tests.
/// Используется в Plan v22 Block 4.1-4.5 для closing 14 XCTSkip.
///
/// Все методы возвращают реальные domain-типы проекта (не отдельные DTO-обёртки),
/// адаптированные под тестовые сценарии через именованные параметры.
public enum TestDataBuilder {

    // MARK: - ChildProfile

    public static func childProfile(
        id: String = UUID().uuidString,
        name: String = "Маша",
        age: Int = 6,
        targetSounds: [String] = ["Р", "Ш"],
        parentId: String = "test-parent-001",
        progressSummary: [String: Double] = [:],
        avatarStyle: String = "butterfly",
        colorTheme: String = "coral",
        sensitivityLevel: Int = 1,
        totalSessionMinutes: Int = 0,
        currentStreak: Int = 0,
        lastSessionAt: Date? = nil
    ) -> ChildProfileDTO {
        ChildProfileDTO(
            id: id,
            name: name,
            age: age,
            targetSounds: targetSounds,
            createdAt: Date(),
            parentId: parentId,
            progressSummary: progressSummary,
            avatarStyle: avatarStyle,
            colorTheme: colorTheme,
            sensitivityLevel: sensitivityLevel,
            totalSessionMinutes: totalSessionMinutes,
            currentStreak: currentStreak,
            lastSessionAt: lastSessionAt
        )
    }

    // MARK: - Session

    public static func session(
        id: String = UUID().uuidString,
        childId: String = "test-child-001",
        date: Date = Date(),
        templateType: String = TemplateType.listenAndChoose.rawValue,
        targetSound: String = "Р",
        stage: String = CorrectionStage.wordInit.rawValue,
        durationSeconds: Int = 180,
        totalAttempts: Int = 10,
        correctAttempts: Int = 8,
        fatigueDetected: Bool = false,
        isSynced: Bool = false,
        attempts: [AttemptDTO] = []
    ) -> SessionDTO {
        SessionDTO(
            id: id,
            childId: childId,
            date: date,
            templateType: templateType,
            targetSound: targetSound,
            stage: stage,
            durationSeconds: durationSeconds,
            totalAttempts: totalAttempts,
            correctAttempts: correctAttempts,
            fatigueDetected: fatigueDetected,
            isSynced: isSynced,
            attempts: attempts
        )
    }

    // MARK: - Attempt

    public static func attempt(
        id: String = UUID().uuidString,
        word: String = "рак",
        audioLocalPath: String = "/tmp/test_audio.m4a",
        audioStoragePath: String = "",
        asrTranscript: String = "рак",
        asrScore: Double = 0.92,
        pronunciationScore: Double = 0.85,
        manualScore: Double = -1.0,
        isCorrect: Bool = true,
        timestamp: Date = Date()
    ) -> AttemptDTO {
        AttemptDTO(
            id: id,
            word: word,
            audioLocalPath: audioLocalPath,
            audioStoragePath: audioStoragePath,
            asrTranscript: asrTranscript,
            asrScore: asrScore,
            pronunciationScore: pronunciationScore,
            manualScore: manualScore,
            isCorrect: isCorrect,
            timestamp: timestamp
        )
    }

    // MARK: - AuthUser

    public static func authUser(
        uid: String = "test-user-uid-001",
        email: String? = "test@example.com",
        displayName: String? = "Тестовый родитель",
        isAnonymous: Bool = false,
        isEmailVerified: Bool = true
    ) -> AuthUser {
        AuthUser(
            uid: uid,
            email: email,
            displayName: displayName,
            isAnonymous: isAnonymous,
            isEmailVerified: isEmailVerified
        )
    }

    // MARK: - UnlockedAchievement

    public static func unlockedAchievement(
        id: String = UUID().uuidString,
        childId: String = "test-child-001",
        achievementKey: String = Achievement.firstSoundMastered.rawValue,
        unlockedAt: Date = Date()
    ) -> UnlockedAchievementData {
        UnlockedAchievementData(
            id: id,
            childId: childId,
            achievementKey: achievementKey,
            unlockedAt: unlockedAt
        )
    }

    // MARK: - WAV / audio data loader

    /// Загружает тестовый WAV из test-bundle.
    /// Fallback — 1 секунда тишины (16000 сэмплов × 2 байта = 32000 байт).
    public static func loadTestWAV(_ resourceName: String) -> Data {
        let bundle = Bundle(for: TestBundleAnchor.self)
        if let url = bundle.url(forResource: resourceName, withExtension: nil),
           let data = try? Data(contentsOf: url) {
            return data
        }
        // 1-second silence: 16kHz mono PCM16
        return Data(repeating: 0, count: 16000 * 2)
    }

    // MARK: - PronunciationScore

    public static func pronunciationScore(value: Double = 0.82) -> PronunciationScore {
        PronunciationScore(rawValue: value)
    }

    // MARK: - FluencySessionData (StutteringModule)

    static func fluencySession(
        id: String = UUID().uuidString,
        date: Date = Date(),
        dysfluencyCount: Int = 2,
        totalSyllables: Int = 40,
        rate: Float = 5.0,
        transcript: String = "Тестовая фраза для дневника плавности"
    ) -> FluencySessionData {
        FluencySessionData(
            id: id,
            date: date,
            dysfluencyCount: dysfluencyCount,
            totalSyllables: totalSyllables,
            rate: rate,
            transcript: transcript
        )
    }

    // MARK: - DysfluencyAnalysis (StutteringModule)

    static func dysfluencyAnalysis(
        repetitions: Int = 1,
        prolongations: Int = 1,
        insideWordPauses: Int = 0,
        totalSyllables: Int = 40,
        rate: Float = 5.0,
        isStub: Bool = false
    ) -> DysfluencyAnalysis {
        DysfluencyAnalysis(
            repetitions: repetitions,
            prolongations: prolongations,
            insideWordPauses: insideWordPauses,
            totalSyllables: totalSyllables,
            rate: rate,
            isStub: isStub
        )
    }

    // MARK: - VoiceSampleData (VoiceCloning)

    static func voiceSample(
        id: String = UUID().uuidString,
        childId: String = "test-child-001",
        word: String = "рыба",
        targetSound: String = "Р",
        audioFilePath: String = "VoiceArchive/test/sample.m4a",
        durationSeconds: Double = 5.0,
        recordedAt: Date = Date(),
        note: String = ""
    ) -> VoiceSampleData {
        VoiceSampleData(
            id: id,
            childId: childId,
            word: word,
            targetSound: targetSound,
            audioFilePath: audioFilePath,
            durationSeconds: durationSeconds,
            recordedAt: recordedAt,
            note: note
        )
    }

    // MARK: - SessionRecord (SessionHistory)

    static func sessionRecord(
        id: String = UUID().uuidString,
        date: Date = Date(),
        gameType: TemplateType = .listenAndChoose,
        soundTarget: String = "Р",
        score: Float = 0.85,
        durationSec: Int = 180,
        attempts: Int = 10,
        isPassed: Bool = true
    ) -> SessionRecord {
        SessionRecord(
            id: id,
            date: date,
            gameType: gameType,
            soundTarget: soundTarget,
            score: score,
            durationSec: durationSec,
            attempts: attempts,
            isPassed: isPassed
        )
    }

    // MARK: - SessionAttemptRecord (SessionHistory)

    static func sessionAttemptRecord(
        id: String = UUID().uuidString,
        word: String = "рак",
        score: Float = 0.88,
        isCorrect: Bool = true,
        durationMs: Int = 1_200
    ) -> SessionAttemptRecord {
        SessionAttemptRecord(
            id: id,
            word: word,
            score: score,
            isCorrect: isCorrect,
            durationMs: durationMs
        )
    }

    // MARK: - AdaptiveRoute / RouteStepItem (AdaptivePlanner)

    public static func routeStep(
        templateType: TemplateType = .listenAndChoose,
        targetSound: String = "Р",
        stage: CorrectionStage = .wordInit,
        difficulty: Int = 2,
        wordCount: Int = 10,
        durationTargetSec: Int = 180
    ) -> RouteStepItem {
        RouteStepItem(
            templateType: templateType,
            targetSound: targetSound,
            stage: stage,
            difficulty: difficulty,
            wordCount: wordCount,
            durationTargetSec: durationTargetSec
        )
    }

    public static func adaptiveRoute(
        steps: [RouteStepItem]? = nil,
        maxDurationSec: Int = 900,
        fatigueLevel: FatigueLevel = .fresh
    ) -> AdaptiveRoute {
        AdaptiveRoute(
            steps: steps ?? [routeStep(), routeStep(templateType: .repeatAfterModel)],
            maxDurationSec: maxDurationSec,
            fatigueLevel: fatigueLevel
        )
    }
}

// MARK: - Private Anchor

private final class TestBundleAnchor {}
