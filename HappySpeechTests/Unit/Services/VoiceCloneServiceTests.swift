import XCTest
@testable import HappySpeech

final class VoiceCloneServiceTests: XCTestCase {

    // MARK: - isCloneSupported

    func testIsCloneSupportedFalseInV10() {
        let service = VoiceCloneServicePlaceholder()
        XCTAssertFalse(service.isCloneSupported,
                       "v1.0 placeholder must return isCloneSupported = false")
    }

    // MARK: - loadReference

    func testLoadReferenceValidSpeaker() async {
        // В unit-test bundle Bundle.main не содержит voice_clone_reference.wav —
        // тест ожидает либо успешный URL, либо referenceNotFound (оба корректны).
        let service = VoiceCloneServicePlaceholder()
        do {
            let url = try await service.loadReference(speakerIndex: 0)
            XCTAssertTrue(url.lastPathComponent.contains("voice_clone_reference"),
                          "URL должен указывать на voice_clone_reference файл")
        } catch VoiceCloneError.referenceNotFound {
            // Ожидаемо в XCTest bundle где WAV не копируется — OK
        } catch {
            XCTFail("Неожиданная ошибка: \(error)")
        }
    }

    func testLoadReferenceAllSpeakersInRange() async {
        // В unit-test bundle Bundle.main не содержит voice_clone_reference.wav —
        // тест проверяет только что bound-check работает корректно.
        let service = VoiceCloneServicePlaceholder()
        for index in 0..<VoiceCloneSpeaker.allCases.count {
            do {
                let url = try await service.loadReference(speakerIndex: index)
                XCTAssertFalse(url.path.isEmpty,
                               "speakerIndex=\(index): URL не должен быть пустым")
            } catch VoiceCloneError.referenceNotFound {
                // Ожидаемо в XCTest bundle — OK
            } catch {
                XCTFail("speakerIndex=\(index): неожиданная ошибка: \(error)")
            }
        }
    }

    func testLoadReferenceNegativeIndexThrows() async {
        let service = VoiceCloneServicePlaceholder()
        do {
            _ = try await service.loadReference(speakerIndex: -1)
            XCTFail("Ожидалась ошибка unsupportedSpeaker(-1)")
        } catch VoiceCloneError.unsupportedSpeaker(-1) {
            // OK
        } catch {
            XCTFail("Неожиданная ошибка: \(error)")
        }
    }

    func testLoadReferenceOutOfBoundsIndexThrows() async {
        let service = VoiceCloneServicePlaceholder()
        do {
            _ = try await service.loadReference(speakerIndex: 99)
            XCTFail("Ожидалась ошибка unsupportedSpeaker(99)")
        } catch VoiceCloneError.unsupportedSpeaker(99) {
            // OK
        } catch {
            XCTFail("Неожиданная ошибка: \(error)")
        }
    }

    // MARK: - cloneVoice

    func testCloneVoiceThrowsUnsupportedInVersion10() async {
        let service = VoiceCloneServicePlaceholder()
        do {
            _ = try await service.cloneVoice(text: "Привет мир", speakerIndex: 0)
            XCTFail("Ожидалась ошибка unsupportedInVersion10")
        } catch VoiceCloneError.unsupportedInVersion10 {
            // OK — корректное поведение placeholder v1.0
        } catch {
            XCTFail("Неожиданная ошибка: \(error)")
        }
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
            .unsupportedInVersion10
        ]
        for err in errors {
            XCTAssertFalse((err.errorDescription ?? "").isEmpty,
                           "errorDescription должен быть непустым для \(err)")
        }
    }
}
