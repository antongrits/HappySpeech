@testable import HappySpeech
import XCTest

// MARK: - BilingualTTSWorkerTests
//
// Покрывает контракт BilingualTTSWorker (ADR-V32-CHIRP3-AOEDE — pre-recorded m4a,
// Siri TTS удалён):
//   - voiceAvailable по всем языкам;
//   - speak: ранний выход на пустом тексте / .off (возвращает bcp47, не падает);
//   - speak: silent skip при отсутствии m4a-ассета в тест-бандле (возвращает bcp47);
//   - stop безопасен в idle.
//
// ПОКРЫТО НЕ ВСЁ: фактическое воспроизведение m4a через AVAudioPlayer и
// completion-continuation требует наличия ассетов Audio/Bilingual/* в бандле
// (они в Bundle.main приложения, не в тест-хосте) и реального аудио-устройства;
// в CI/симуляторе это нестабильно. Поэтому проверяем graceful silent-skip
// контракт (метод не блокируется, возвращает корректный bcp47).

@MainActor
final class BilingualTTSWorkerTests: XCTestCase {

    // MARK: - voiceAvailable

    func test_voiceAvailable_off_false() {
        let sut = BilingualTTSWorker()
        XCTAssertFalse(sut.voiceAvailable(for: .off))
    }

    func test_voiceAvailable_englishAndBelarusian_true() {
        let sut = BilingualTTSWorker()
        // Оба языка pre-recorded → всегда доступны (контракт ADR-V32).
        XCTAssertTrue(sut.voiceAvailable(for: .english))
        XCTAssertTrue(sut.voiceAvailable(for: .belarusian))
    }

    // MARK: - speak: early exits

    func test_speak_emptyText_returnsBcp47WithoutPlaying() async {
        let sut = BilingualTTSWorker()
        let used = await sut.speak("", language: .english, wordId: "mama")
        XCTAssertEqual(used, "en-US", "Пустой текст → ранний выход, возвращает bcp47")
    }

    func test_speak_off_returnsOffBcp47() async {
        let sut = BilingualTTSWorker()
        let used = await sut.speak("мама", language: .off, wordId: "mama")
        XCTAssertEqual(used, BilingualSecondLanguage.off.bcp47)
    }

    // MARK: - speak: silent skip (asset missing in test bundle)

    func test_speak_english_missingAsset_silentSkipReturnsEnUS() async {
        let sut = BilingualTTSWorker()
        // Ассета lyalya_bil_en_* нет в тест-бандле → silent skip, без краша.
        let used = await sut.speak("mom", language: .english, wordId: "nonexistent_word_id")
        XCTAssertEqual(used, "en-US")
    }

    func test_speak_belarusian_missingAsset_silentSkipReturnsBeBY() async {
        let sut = BilingualTTSWorker()
        let used = await sut.speak("мама", language: .belarusian, wordId: "nonexistent_word_id")
        XCTAssertEqual(used, "be-BY")
    }

    // MARK: - stop

    func test_stop_whenIdle_doesNotCrash() {
        let sut = BilingualTTSWorker()
        sut.stop()
        sut.stop()
        // Контракт: stop идемпотентен и безопасен без активного воспроизведения.
        XCTAssertTrue(true)
    }

    // MARK: - bcp47 mapping invariant

    func test_secondLanguage_bcp47_mapping() {
        XCTAssertEqual(BilingualSecondLanguage.english.bcp47, "en-US")
        XCTAssertEqual(BilingualSecondLanguage.belarusian.bcp47, "be-BY")
        XCTAssertEqual(BilingualSecondLanguage.off.bcp47, "off")
    }
}
