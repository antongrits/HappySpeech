@testable import HappySpeech
import XCTest

// MARK: - PhonemeAudioWorkerTests
//
// PhonemeAudioWorker воспроизводит звук через AVAudioPlayer или, при
// отсутствии bundle-файла, через записанный голос Ляли (LessonVoiceWorker).
// Siri TTS больше не используется (v25): usedFallbackTTS всегда false.
// В тест-бандле нет m4a-файлов — тестируем fallback-путь и stop().

// MARK: - PhonemeEntry builder

private func makeEntry(
    cyrillic: String = "С",
    audioResourceName: String? = nil
) -> PhonemeEntry {
    PhonemeEntry(
        id: "test-\(cyrillic)",
        cyrillic: cyrillic,
        ipa: "s",
        group: .whistling,
        exampleWord: "солнце",
        exampleSyllable: "са",
        articulationNoteKey: "test.articulation",
        audioResourceName: audioResourceName
    )
}

@MainActor
final class PhonemeAudioWorkerTests: XCTestCase {

    private var sut: PhonemeAudioWorker!

    override func setUp() {
        super.setUp()
        sut = PhonemeAudioWorker()
    }

    // MARK: - playSample: fallback на голос Ляли (нет bundle-файла)

    func test_playSample_withoutBundleFile_returnsTrueAndNoSiriFallback() async {
        let entry = makeEntry(cyrillic: "С", audioResourceName: nil)
        let (success, usedFallback) = await sut.playSample(for: entry)

        XCTAssertTrue(success, "При fallback на голос Ляли success должен быть true")
        XCTAssertFalse(usedFallback, "Siri TTS не используется — usedFallbackTTS всегда false")
    }

    func test_playSample_withNonexistentBundleFile_fallsBackToLyalyaVoice() async {
        let entry = makeEntry(cyrillic: "Ш", audioResourceName: "sound_sh_nonexistent")
        let (success, usedFallback) = await sut.playSample(for: entry)

        XCTAssertTrue(success, "При отсутствии bundle-файла fallback на голос Ляли отрабатывает")
        XCTAssertFalse(usedFallback, "Несуществующий bundle-файл → голос Ляли, не Siri")
    }

    // MARK: - stop: не крашит без предварительного play

    func test_stop_withoutPlay_doesNotCrash() {
        XCTAssertNoThrow(sut.stop(), "stop() без play не должен крашить")
    }

    // MARK: - stop: после play не крашит

    func test_stop_afterPlay_doesNotCrash() async {
        let entry = makeEntry(cyrillic: "Р")
        _ = await sut.playSample(for: entry)
        XCTAssertNoThrow(sut.stop())
    }

    // MARK: - Разные фонемы

    func test_playSample_differentPhonemes_allReturnTrue() async {
        let phonemes = ["С", "Ш", "Р", "Л", "З"]
        for p in phonemes {
            let entry = makeEntry(cyrillic: p)
            let (success, _) = await sut.playSample(for: entry)
            XCTAssertTrue(success, "playSample для \(p) должен возвращать true")
        }
    }

    // MARK: - PhonemeEntry: поля

    func test_phonemeEntry_audioResourceNameNilByDefault() {
        let entry = makeEntry()
        XCTAssertNil(entry.audioResourceName,
                     "По умолчанию audioResourceName должен быть nil")
    }

    func test_phonemeEntry_cyrillicPreserved() {
        let entry = makeEntry(cyrillic: "Щ")
        XCTAssertEqual(entry.cyrillic, "Щ")
    }
}
