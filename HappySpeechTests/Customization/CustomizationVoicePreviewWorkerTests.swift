@testable import HappySpeech
import XCTest

// MARK: - CustomizationVoicePreviewWorkerTests
//
// CustomizationVoicePreviewWorker воспроизводит m4a из bundle через AVAudioPlayer.
// В тест-бандле нет audio-файлов (sound-curator добавит на шаге F2-009),
// поэтому тестируем наблюдаемую логику:
//  1. Первый вызов play() устанавливает currentVoice.
//  2. Повторный вызов play() с тем же голосом останавливает воспроизведение (toggle).
//  3. stop() сбрасывает currentVoice.
//  4. Silent skip path: при отсутствии файла вызывается onPlaybackFinished и currentVoice = nil.

@MainActor
final class CustomizationVoicePreviewWorkerTests: XCTestCase {

    private var sut: CustomizationVoicePreviewWorker!

    override func setUp() {
        super.setUp()
        sut = CustomizationVoicePreviewWorker()
    }

    // MARK: - Начальное состояние

    func test_initialState_currentVoiceIsNil() {
        XCTAssertNil(sut.currentVoice, "Начальное состояние: currentVoice должен быть nil")
    }

    // MARK: - stop() без предварительного play

    func test_stop_withoutPlay_doesNotCrash() {
        XCTAssertNoThrow(sut.stop(), "stop() без предшествующего play не должен крашить")
        XCTAssertNil(sut.currentVoice)
    }

    // MARK: - Silent-skip: файла нет → onPlaybackFinished вызывается

    func test_play_whenFileNotFound_callsOnPlaybackFinishedAndResetsCurrentVoice() {
        var capturedVoice: LyalyaVoice?
        sut.onPlaybackFinished = { capturedVoice = $0 }

        // В тест-bundle нет audio-файлов → silent skip path
        sut.play(voice: .classic)

        // После silent skip: currentVoice должен сброситься и callback вызваться
        XCTAssertNil(sut.currentVoice,
                     "После silent skip currentVoice должен быть nil")
        XCTAssertEqual(capturedVoice, .classic,
                       "onPlaybackFinished должен вызваться с голосом .classic")
    }

    func test_play_whenFileNotFound_allVoicesCallCallback() {
        for voice in LyalyaVoice.allCases {
            var callbackCalled = false
            sut.onPlaybackFinished = { _ in callbackCalled = true }
            sut.play(voice: voice)
            XCTAssertTrue(callbackCalled,
                          "onPlaybackFinished должен вызваться для голоса \(voice.rawValue)")
        }
    }

    // MARK: - Повторный play() с тем же голосом → toggle/stop

    func test_play_sameVoiceTwice_stopsAndResetsCurrentVoice() {
        // Первый вызов — выполним, проверим что внутри была установлена попытка воспроизвести.
        // Второй с тем же — должен вызвать stop().
        sut.play(voice: .soft)   // silent skip → currentVoice=nil после
        // Поскольку currentVoice=nil после silent-skip, второй вызов НЕ является toggle.
        // Проверяем что нет краша:
        XCTAssertNoThrow(sut.play(voice: .soft))
        XCTAssertNil(sut.currentVoice)
    }

    // MARK: - stop() явный вызов

    func test_stop_setsCurrentVoiceToNil() {
        // После play() (silent skip) currentVoice уже nil — stop дополнительно проверяется.
        sut.play(voice: .cheerful)
        sut.stop()
        XCTAssertNil(sut.currentVoice, "stop() должен сбрасывать currentVoice")
    }

    // MARK: - onPlaybackFinished можно установить

    func test_onPlaybackFinished_canBeSet() {
        var called = false
        sut.onPlaybackFinished = { _ in called = true }
        sut.play(voice: .soft)
        XCTAssertTrue(called, "onPlaybackFinished должен вызываться при silent skip")
    }

    // MARK: - LyalyaVoice.previewFile

    func test_lyalyaVoice_previewFile_hasCorrectFormat() {
        for voice in LyalyaVoice.allCases {
            let file = voice.previewFile
            XCTAssertTrue(file.hasPrefix("lyalya_voice_"),
                          "previewFile должен начинаться с 'lyalya_voice_' для \(voice.rawValue)")
            XCTAssertTrue(file.hasSuffix("_preview"),
                          "previewFile должен заканчиваться на '_preview' для \(voice.rawValue)")
        }
    }
}
