@preconcurrency import AVFoundation
@testable import HappySpeech
import XCTest

// MARK: - FamilyVoiceSpeakerTagWorkerTests
//
// Подключение SpeakerVerificationService в COPPA-различение голоса (parent vs child)
// в семейной записи. Проверяет, что:
//   • первая родительская запись регистрирует профиль (enroll) и помечается .parent;
//   • последующие записи сверяются (verify) с профилем;
//   • детская запись помечается .child;
//   • без сервиса / без профиля — безопасные дефолты.

final class FamilyVoiceSpeakerTagWorkerTests: XCTestCase {

    // MARK: - Изолированный UserDefaults на каждый тест

    private func makeDefaults() -> UserDefaults {
        let suite = "speaker-tag-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        return defaults
    }

    /// Записывает валидный WAV (16kHz mono) в Documents и возвращает
    /// относительный путь, как ожидает FamilyVoiceRecorderWorker.resolveFilePath.
    private func makeTempRecording() throws -> String {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "SpeakerTagTest", code: 1)
        }
        let frameCount = AVAudioFrameCount(16_000 * 1.0)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "SpeakerTagTest", code: 2)
        }
        buffer.frameLength = frameCount
        if let channel = buffer.floatChannelData?[0] {
            for index in 0..<Int(frameCount) {
                channel[index] = sin(2.0 * .pi * 220.0 * Float(index) / 16_000.0) * 0.3
            }
        }
        let relativePath = "speaker_test_\(UUID().uuidString).wav"
        let url = try FamilyVoiceRecorderWorker.resolveFilePath(relativePath)
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return relativePath
    }

    // MARK: - VoiceProfileStore round-trip

    func test_voiceProfileStore_saveLoadClear() {
        let defaults = makeDefaults()
        XCTAssertNil(VoiceProfileStore.load(ownerId: "p1", defaults: defaults))

        let profile = VoiceProfile(embedding: Array(repeating: 0.125, count: 64), ownerId: "p1")
        VoiceProfileStore.save(profile, defaults: defaults)

        let loaded = VoiceProfileStore.load(ownerId: "p1", defaults: defaults)
        XCTAssertEqual(loaded?.ownerId, "p1")
        XCTAssertEqual(loaded?.embedding.count, 64)

        VoiceProfileStore.clear(ownerId: "p1", defaults: defaults)
        XCTAssertNil(VoiceProfileStore.load(ownerId: "p1", defaults: defaults))
    }

    func test_voiceProfileStore_emptyOwner_isNoOp() {
        let defaults = makeDefaults()
        VoiceProfileStore.save(VoiceProfile(embedding: [], ownerId: ""), defaults: defaults)
        XCTAssertNil(VoiceProfileStore.load(ownerId: "", defaults: defaults))
    }

    // MARK: - tagParentRecording

    func test_tagParentRecording_firstTime_enrollsProfile_andTagsParent() async throws {
        let defaults = makeDefaults()
        let sv = MockSpeakerVerificationService(isParent: true, similarity: 0.9)
        let worker = FamilyVoiceSpeakerTagWorker(speakerVerification: sv, defaults: defaults)
        let path = try makeTempRecording()
        defer { try? FileManager.default.removeItem(at: FamilyVoiceRecorderWorker.resolveFilePath(path)) }

        // Профиля ещё нет → enroll + .parent.
        XCTAssertNil(VoiceProfileStore.load(ownerId: "parent-1", defaults: defaults))
        let tag = await worker.tagParentRecording(audioPath: path, ownerId: "parent-1")
        XCTAssertEqual(tag, .parent, "Первая родительская запись регистрирует профиль и помечается .parent")
        XCTAssertNotNil(
            VoiceProfileStore.load(ownerId: "parent-1", defaults: defaults),
            "После первой записи профиль родителя должен сохраниться"
        )
    }

    func test_tagParentRecording_secondTime_verifiesAgainstProfile() async throws {
        let defaults = makeDefaults()
        // Предзаполняем профиль, чтобы пойти по пути verify (не enroll).
        VoiceProfileStore.save(
            VoiceProfile(embedding: Array(repeating: 0.125, count: 64), ownerId: "parent-1"),
            defaults: defaults
        )
        let sv = MockSpeakerVerificationService(isParent: true, similarity: 0.85)
        let worker = FamilyVoiceSpeakerTagWorker(speakerVerification: sv, defaults: defaults)
        let path = try makeTempRecording()
        defer { try? FileManager.default.removeItem(at: FamilyVoiceRecorderWorker.resolveFilePath(path)) }

        let tag = await worker.tagParentRecording(audioPath: path, ownerId: "parent-1")
        XCTAssertEqual(tag, .parent, "Совпадение с профилем → .parent")
    }

    func test_tagParentRecording_noService_returnsUnknown() async throws {
        let defaults = makeDefaults()
        let worker = FamilyVoiceSpeakerTagWorker(speakerVerification: nil, defaults: defaults)
        let path = try makeTempRecording()
        defer { try? FileManager.default.removeItem(at: FamilyVoiceRecorderWorker.resolveFilePath(path)) }
        let tag = await worker.tagParentRecording(audioPath: path, ownerId: "parent-1")
        XCTAssertEqual(tag, .unknown, "Без сервиса верификации — .unknown (graceful)")
    }

    // MARK: - tagChildRecording

    func test_tagChildRecording_noParentProfile_defaultsToChild() async throws {
        let defaults = makeDefaults()
        let sv = MockSpeakerVerificationService(isParent: false)
        let worker = FamilyVoiceSpeakerTagWorker(speakerVerification: sv, defaults: defaults)
        let path = try makeTempRecording()
        defer { try? FileManager.default.removeItem(at: FamilyVoiceRecorderWorker.resolveFilePath(path)) }
        // Профиля родителя нет → безопасный дефолт COPPA: .child.
        let tag = await worker.tagChildRecording(audioPath: path, parentOwnerId: "parent-1")
        XCTAssertEqual(tag, .child)
    }

    func test_tagChildRecording_withProfile_childVoice_tagsChild() async throws {
        let defaults = makeDefaults()
        VoiceProfileStore.save(
            VoiceProfile(embedding: Array(repeating: 0.125, count: 64), ownerId: "parent-1"),
            defaults: defaults
        )
        // Mock с isParent=false → speakerType .child.
        let sv = MockSpeakerVerificationService(isParent: false, similarity: 0.3)
        let worker = FamilyVoiceSpeakerTagWorker(speakerVerification: sv, defaults: defaults)
        let path = try makeTempRecording()
        defer { try? FileManager.default.removeItem(at: FamilyVoiceRecorderWorker.resolveFilePath(path)) }

        let tag = await worker.tagChildRecording(audioPath: path, parentOwnerId: "parent-1")
        XCTAssertEqual(tag, .child, "Несовпадение с родительским профилем → .child")
    }

    func test_tagChildRecording_noService_defaultsToChild() async throws {
        let defaults = makeDefaults()
        let worker = FamilyVoiceSpeakerTagWorker(speakerVerification: nil, defaults: defaults)
        let path = try makeTempRecording()
        defer { try? FileManager.default.removeItem(at: FamilyVoiceRecorderWorker.resolveFilePath(path)) }
        let tag = await worker.tagChildRecording(audioPath: path, parentOwnerId: "parent-1")
        XCTAssertEqual(tag, .child, "Без сервиса — детская область → .child (COPPA-safe)")
    }

    func test_speakerTag_rawValues() {
        XCTAssertEqual(SpeakerTag.parent.rawValue, "parent")
        XCTAssertEqual(SpeakerTag.child.rawValue, "child")
        XCTAssertEqual(SpeakerTag.unknown.rawValue, "unknown")
    }
}
