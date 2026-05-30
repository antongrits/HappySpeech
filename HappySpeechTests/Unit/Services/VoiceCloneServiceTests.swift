import AVFoundation
import XCTest
@testable import HappySpeech

final class VoiceCloneServiceTests: XCTestCase {

    // MARK: - isCloneSupported

    func testIsCloneSupportedTrueForLive() {
        let service = LiveVoiceCloneService()
        XCTAssertTrue(service.isCloneSupported,
                      "Live service must report TTS as supported (real synthesis works)")
    }

    func testIsCloneSupportedTrueForMock() {
        let service = MockVoiceCloneService()
        XCTAssertTrue(service.isCloneSupported)
    }

    // MARK: - availableModes (Live)

    func testAvailableModesForRussianIncludesSystemTTS() async {
        let service = LiveVoiceCloneService()
        let modes = await service.availableModes(for: "ru-RU")
        // На симуляторе iOS обычно установлен ru-RU голос (Milena). Если по какой-то
        // причине его нет — список может быть пуст; тогда проверяем хотя бы отсутствие
        // personalVoice (ru personal voice невозможен).
        XCTAssertFalse(modes.contains { mode in
            if case .personalVoice = mode { return true }
            return false
        }, "Russian locale must never offer Personal Voice (unsupported language)")
        if !modes.isEmpty {
            XCTAssertTrue(modes.contains { mode in
                if case .systemTTS(let locale) = mode { return locale == "ru-RU" }
                return false
            }, "Russian locale with a voice present must offer systemTTS(ru-RU)")
        }
    }

    func testAvailableModesForEnglishNeverOffersPersonalVoiceWhenUnauthorized() async {
        let service = LiveVoiceCloneService()
        // Personal Voice не авторизован в тестовой среде → его не должно быть в списке.
        let status = service.personalVoiceAuthorizationStatus
        let modes = await service.availableModes(for: "en-US")
        if status != .authorized {
            XCTAssertFalse(modes.contains { mode in
                if case .personalVoice = mode { return true }
                return false
            }, "Personal Voice must not appear unless authorized")
        }
    }

    // MARK: - synthesize systemTTS (Live, real synthesis on simulator)

    func testSystemTTSProducesNonEmptyData() async throws {
        let service = LiveVoiceCloneService()
        // Если ru-RU голос недоступен в среде — пропускаем (синтез невозможен).
        guard LiveVoiceCloneService.bestVoice(for: "ru-RU") != nil else {
            throw XCTSkip("No ru-RU voice installed in this environment — cannot synthesize")
        }
        let data = try await service.synthesize(text: "Привет, мир!", mode: .systemTTS(locale: "ru-RU"))
        XCTAssertFalse(data.isEmpty, "systemTTS must produce non-empty m4a Data")
        // m4a/AAC контейнер начинается с ftyp box (sanity check на ненулевой заголовок).
        XCTAssertGreaterThan(data.count, 64, "Synthesized audio should be more than a stub")
    }

    func testSystemTTSEmptyTextThrows() async {
        let service = LiveVoiceCloneService()
        do {
            _ = try await service.synthesize(text: "   ", mode: .systemTTS(locale: "ru-RU"))
            XCTFail("Expected emptyText error")
        } catch VoiceCloneError.emptyText {
            // OK
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSystemTTSUnavailableLocaleThrows() async {
        let service = LiveVoiceCloneService()
        // Заведомо несуществующая локаль — голос не найдётся.
        do {
            _ = try await service.synthesize(text: "test", mode: .systemTTS(locale: "zz-ZZ"))
            XCTFail("Expected voiceUnavailable error for bogus locale")
        } catch VoiceCloneError.voiceUnavailable {
            // OK
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - familyVoice / bundledAudio (Live)

    func testFamilyVoiceMissingFileThrows() async {
        let service = LiveVoiceCloneService()
        do {
            _ = try await service.synthesize(
                text: "ignored",
                mode: .familyVoice(audioFilePath: "family_recordings/does-not-exist.m4a")
            )
            XCTFail("Expected fileNotFound for missing family recording")
        } catch VoiceCloneError.fileNotFound {
            // OK
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testBundledAudioMissingResourceThrows() async {
        let service = LiveVoiceCloneService()
        do {
            _ = try await service.synthesize(
                text: "ignored",
                mode: .bundledAudio(resourceName: "definitely_not_a_real_resource_xyz")
            )
            XCTFail("Expected fileNotFound for missing bundled resource")
        } catch VoiceCloneError.fileNotFound {
            // OK
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - cloneVoice routes to systemTTS

    func testCloneVoiceInvalidSpeakerThrows() async {
        let service = LiveVoiceCloneService()
        do {
            _ = try await service.cloneVoice(text: "x", speakerIndex: 99)
            XCTFail("Expected unsupportedSpeaker(99)")
        } catch VoiceCloneError.unsupportedSpeaker(99) {
            // OK
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Fallback chain

    func testFallbackChainEmptyModesThrows() async {
        let mock = MockVoiceCloneService()
        let chain = FallbackVoiceSynthesisChain(service: mock)
        do {
            _ = try await chain.synthesize(text: "hi", modes: [])
            XCTFail("Expected synthesisFailed for empty modes")
        } catch VoiceCloneError.synthesisFailed {
            // OK
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFallbackChainUsesFirstSuccessfulMode() async throws {
        // familyVoice провалится (нет файла), systemTTS вернёт mock-данные.
        let mock = MockVoiceCloneService()
        let chain = FallbackVoiceSynthesisChain(service: mock)
        let data = try await chain.synthesize(
            text: "Слушай и повторяй",
            modes: [.systemTTS(locale: "ru-RU"), .bundledAudio(resourceName: "x")]
        )
        XCTAssertFalse(data.isEmpty, "Chain must return data from first successful mode")
        let count = await mock.synthesizeCallCount
        XCTAssertEqual(count, 1, "First successful mode should short-circuit the chain")
    }

    func testFallbackChainAdvancesPastFailingMode() async throws {
        // Live-сервис: familyVoice провалится (нет файла), systemTTS либо синтезирует,
        // либо тоже провалится при отсутствии голоса. Проверяем, что цепочка переходит
        // ко второму режиму после неудачи первого.
        let service = LiveVoiceCloneService()
        guard LiveVoiceCloneService.bestVoice(for: "ru-RU") != nil else {
            throw XCTSkip("No ru-RU voice — cannot validate fallback advancement via systemTTS")
        }
        let chain = FallbackVoiceSynthesisChain(service: service)
        let data = try await chain.synthesize(
            text: "Слушай и повторяй",
            modes: [
                .familyVoice(audioFilePath: "family_recordings/missing.m4a"),
                .systemTTS(locale: "ru-RU")
            ]
        )
        XCTAssertFalse(data.isEmpty,
                       "Chain must skip failing familyVoice and succeed on systemTTS")
    }

    func testFallbackChainAllFailThrowsLastError() async {
        let mock = MockVoiceCloneService(stubbedError: .synthesisFailed)
        let chain = FallbackVoiceSynthesisChain(service: mock)
        do {
            _ = try await chain.synthesize(
                text: "hi",
                modes: [.systemTTS(locale: "ru-RU"), .bundledAudio(resourceName: "x")]
            )
            XCTFail("Expected error when all modes fail")
        } catch VoiceCloneError.synthesisFailed {
            // OK
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Mock behaviour

    func testMockAvailableModesRussian() async {
        let mock = MockVoiceCloneService()
        let modes = await mock.availableModes(for: "ru-RU")
        XCTAssertTrue(modes.contains { mode in
            if case .systemTTS(let l) = mode { return l == "ru-RU" }
            return false
        })
        XCTAssertFalse(modes.contains { mode in
            if case .personalVoice = mode { return true }
            return false
        }, "ru-RU must never include Personal Voice in mock")
    }

    func testMockAvailableModesEnglishAuthorizedIncludesPersonalVoice() async {
        let mock = MockVoiceCloneService(stubbedPersonalVoiceStatus: .authorized)
        let modes = await mock.availableModes(for: "en-US")
        XCTAssertTrue(modes.contains { mode in
            if case .personalVoice = mode { return true }
            return false
        }, "Authorized en-US must include Personal Voice")
    }

    func testMockSynthesizeReturnsStubAndRecordsSpies() async throws {
        let stub = Data([0xAA, 0xBB, 0xCC])
        let mock = MockVoiceCloneService(stubbedData: stub)
        let data = try await mock.synthesize(text: "тест", mode: .bundledAudio(resourceName: "x"))
        XCTAssertEqual(data, stub)
        let calls = await mock.synthesizeCallCount
        let lastText = await mock.lastSynthesizedText
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(lastText, "тест")
    }

    func testMockRequestPersonalVoiceAuthorizationReturnsStub() async {
        let mock = MockVoiceCloneService(stubbedPersonalVoiceStatus: .denied)
        let status = await mock.requestPersonalVoiceAuthorization()
        XCTAssertEqual(status, .denied)
        let count = await mock.requestAuthCallCount
        XCTAssertEqual(count, 1)
    }

    // MARK: - VoiceCloneSpeaker

    func testSpeakerCountEqualsReferenceCorpus() {
        XCTAssertEqual(VoiceCloneSpeaker.allCases.count, 10,
                       "Reference corpus содержит 10 голосов (5 Дмитрий + 5 Светлана)")
    }

    func testAllSpeakersHaveNonEmptyDisplayNames() {
        for speaker in VoiceCloneSpeaker.allCases {
            XCTAssertFalse(speaker.displayName.isEmpty,
                           "displayName не должен быть пустым: \(speaker)")
        }
    }

    func testSpeakerRawValuesAreSequential() {
        for (expectedIndex, speaker) in VoiceCloneSpeaker.allCases.enumerated() {
            XCTAssertEqual(speaker.rawValue, expectedIndex,
                           "rawValue диктора \(speaker) должен совпадать с индексом \(expectedIndex)")
        }
    }

    // MARK: - VoiceCloneError localizedDescription

    func testErrorDescriptionsNonEmpty() {
        let errors: [VoiceCloneError] = [
            .notImplemented,
            .referenceNotFound,
            .unsupportedSpeaker(5),
            .unsupportedInVersion10,
            .emptyText,
            .voiceUnavailable(locale: "ru-RU"),
            .synthesisFailed,
            .audioConversionFailed,
            .fileNotFound("x.m4a"),
            .personalVoiceNotAuthorized
        ]
        for err in errors {
            XCTAssertFalse((err.errorDescription ?? "").isEmpty,
                           "errorDescription должен быть непустым для \(err)")
        }
    }
}
