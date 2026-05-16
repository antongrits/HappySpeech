@testable import HappySpeech
import XCTest

// MARK: - LessonVoiceWorkerExtendedTests
//
// LessonVoiceWorker использует AVAudioPlayer + AVAudioSession + Bundle.main —
// всё это недоступно в unit-target без настройки real audio session.
//
// Тестируем:
//   - speak("") → silent skip (не крашит)
//   - stop() → idempotent
//   - speak с enableSystemTTSFallback=false → silent skip
//   - shared instance singleton
//   - familyParentId/realmActor свойства
// НЕ тестируем: фактическое воспроизведение звука (hardware-only).

@MainActor
final class LessonVoiceWorkerExtendedTests: XCTestCase {

    // MARK: - speak empty string → silent skip, no crash

    func test_speak_emptyString_doesNotCrash() async {
        await LessonVoiceWorker.shared.speak("")
        // Нет ассерта — просто не должен крашиться
    }

    // MARK: - speak missing m4a without TTS fallback → silent skip

    func test_speak_missingM4a_noTTSFallback_silentSkip() async {
        await LessonVoiceWorker.shared.speak(
            "тестовое_слово_отсутствует_в_маппинге",
            enableSystemTTSFallback: false
        )
    }

    // MARK: - stop is idempotent

    func test_stop_firstCall_doesNotCrash() {
        LessonVoiceWorker.shared.stop()
    }

    func test_stop_secondCall_doesNotCrash() {
        LessonVoiceWorker.shared.stop()
        LessonVoiceWorker.shared.stop()
    }

    // MARK: - speak with lessonType context → no crash

    func test_speak_withLessonType_doesNotCrash() async {
        await LessonVoiceWorker.shared.speak(
            "тест",
            lessonType: "bingo",
            enableSystemTTSFallback: false
        )
    }

    // MARK: - speak with rate parameter → no crash

    func test_speak_withRate_doesNotCrash() async {
        await LessonVoiceWorker.shared.speak(
            "тест",
            rate: 0.8,
            enableSystemTTSFallback: false
        )
    }

    // MARK: - shared instance is singleton

    func test_sharedInstance_isSameObject() {
        let a = LessonVoiceWorker.shared
        let b = LessonVoiceWorker.shared
        XCTAssertTrue(a === b, "shared должен возвращать тот же экземпляр")
    }

    // MARK: - familyParentId: can be set

    func test_familyParentId_canBeSet() {
        LessonVoiceWorker.shared.familyParentId = "test-parent-999"
        XCTAssertEqual(LessonVoiceWorker.shared.familyParentId, "test-parent-999")
        // Восстанавливаем дефолт
        LessonVoiceWorker.shared.familyParentId = "local-parent"
    }

    // MARK: - realmActor: опциональное свойство, set/get согласованы
    //
    // LessonVoiceWorker.shared — синглтон; в test-host приложение-хост может
    // проинициализировать realmActor через AppContainer. Поэтому тест проверяет
    // не «nil по умолчанию», а согласованность присваивания: сброс в nil
    // действительно делает свойство nil. Исходное значение восстанавливается.

    func test_realmActor_isOptionalAndAssignable() {
        let original = LessonVoiceWorker.shared.realmActor
        defer { LessonVoiceWorker.shared.realmActor = original }

        LessonVoiceWorker.shared.realmActor = nil
        XCTAssertNil(LessonVoiceWorker.shared.realmActor,
                     "После присваивания nil свойство realmActor должно быть nil")
    }
}
