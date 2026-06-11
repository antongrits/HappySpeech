@testable import HappySpeech
import AVFoundation
import XCTest

// MARK: - CustomizationVoicePreviewWorkerTests
//
// CustomizationVoicePreviewWorker воспроизводит m4a из bundle через AVAudioPlayer.
// Preview-файлы голосов Ляли (Chirp3-HD-Aoede) присутствуют в бандле
// (Resources/Audio/Voice/lyalya_voice_{classic,soft,cheerful}_preview.m4a),
// поэтому play() запускает реальное воспроизведение. Тестируем наблюдаемую
// логику без зависимости от завершения аудио:
//  1. Первый вызов play() устанавливает currentVoice (воспроизведение начато).
//  2. Повторный вызов play() с тем же голосом останавливает (toggle → nil).
//  3. stop() сбрасывает currentVoice.
//  4. onPlaybackFinished вызывается делегатом по завершении (асинхронно), а не
//     синхронно в play(); проверяется через ожидание состояния.

@MainActor
final class CustomizationVoicePreviewWorkerTests: XCTestCase {

    private var sut: CustomizationVoicePreviewWorker!

    override func setUp() async throws {
        try await super.setUp()
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

    // MARK: - play() с существующим preview-файлом → воспроизведение начато

    func test_play_setsCurrentVoiceToRequestedVoice() {
        sut.play(voice: .classic)
        // Preview-файл существует → реальное воспроизведение: currentVoice = .classic
        XCTAssertEqual(sut.currentVoice, .classic,
                       "play() должен установить currentVoice в запрошенный голос")
    }

    func test_play_eachVoice_setsCurrentVoice() {
        for voice in LyalyaVoice.allCases {
            sut.stop()
            sut.play(voice: voice)
            XCTAssertEqual(sut.currentVoice, voice,
                           "play() должен установить currentVoice=\(voice.rawValue)")
        }
    }

    // MARK: - Повторный play() с тем же голосом → toggle/stop

    func test_play_sameVoiceTwice_stopsAndResetsCurrentVoice() {
        // Первый вызов запускает воспроизведение (currentVoice=.soft).
        sut.play(voice: .soft)
        XCTAssertEqual(sut.currentVoice, .soft)
        // Второй с тем же голосом — toggle → stop() → currentVoice=nil.
        sut.play(voice: .soft)
        XCTAssertNil(sut.currentVoice)
    }

    // MARK: - stop() явный вызов

    func test_stop_setsCurrentVoiceToNil() {
        // После play() (silent skip) currentVoice уже nil — stop дополнительно проверяется.
        sut.play(voice: .cheerful)
        sut.stop()
        XCTAssertNil(sut.currentVoice, "stop() должен сбрасывать currentVoice")
    }

    // MARK: - onPlaybackFinished вызывается делегатом по завершении

    func test_onPlaybackFinished_firesOnPlaybackCompletion() async {
        var captured: LyalyaVoice?
        sut.onPlaybackFinished = { captured = $0 }
        sut.play(voice: .soft)
        XCTAssertEqual(sut.currentVoice, .soft)

        // Эмулируем естественное завершение воспроизведения через делегат
        // AVAudioPlayer (детерминированно, без ожидания реального аудио).
        let player = try? AVAudioPlayer(
            contentsOf: Bundle.main.url(
                forResource: LyalyaVoice.soft.previewFile,
                withExtension: "m4a",
                subdirectory: "Audio/Voice"
            ) ?? URL(fileURLWithPath: "/dev/null")
        )
        if let player {
            sut.audioPlayerDidFinishPlaying(player, successfully: true)
        }
        // Делегат хопает на MainActor через Task — ждём состояние.
        await waitUntil(timeout: 2.0) { self.sut.currentVoice == nil }
        XCTAssertNil(sut.currentVoice,
                     "После завершения воспроизведения currentVoice должен сброситься")
        XCTAssertEqual(captured, .soft,
                       "onPlaybackFinished должен вызваться с проигранным голосом")
    }

    /// Опрашивает условие до выполнения либо до таймаута (шаг 20мс).
    private func waitUntil(
        timeout: TimeInterval,
        _ condition: () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
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
