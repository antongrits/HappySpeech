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
}

// MARK: - Private Anchor

private final class TestBundleAnchor {}
