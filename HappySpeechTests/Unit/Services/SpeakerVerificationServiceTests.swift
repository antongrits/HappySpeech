import Foundation
import XCTest
@testable import HappySpeech

// MARK: - SpeakerVerificationServiceTests
//
// Тесты MockSpeakerVerificationService + LiveSpeakerVerificationService.
// Live: модель SpeakerVerification.mlpackage отсутствует в тестовом бандле →
// verify возвращает .unknown, enroll бросает mlModelNotFound.

final class SpeakerVerificationServiceTests: XCTestCase {

    private func makeProfile() -> VoiceProfile {
        VoiceProfile(embedding: Array(repeating: Float(0.125), count: 64), ownerId: "parent-1")
    }

    // MARK: - SpeakerType

    func testSpeakerTypeRawValues() {
        XCTAssertEqual(SpeakerType.parent.rawValue, "parent")
        XCTAssertEqual(SpeakerType.child.rawValue, "child")
        XCTAssertEqual(SpeakerType.unknown.rawValue, "unknown")
    }

    // MARK: - VoiceProfile

    func testVoiceProfileInitAndCodable() throws {
        let profile = VoiceProfile(
            embedding: [0.1, 0.2, 0.3],
            ownerId: "owner-x",
            createdAt: Date(timeIntervalSince1970: 1_000_000)
        )
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(VoiceProfile.self, from: data)
        XCTAssertEqual(decoded.ownerId, "owner-x")
        XCTAssertEqual(decoded.embedding, [0.1, 0.2, 0.3])
        XCTAssertEqual(decoded.createdAt, Date(timeIntervalSince1970: 1_000_000))
    }

    func testVoiceProfileDefaultCreatedAtIsRecent() {
        let profile = VoiceProfile(embedding: [], ownerId: "x")
        XCTAssertLessThan(abs(profile.createdAt.timeIntervalSinceNow), 5.0)
    }

    // MARK: - MockSpeakerVerificationService: child default

    func testMockDefaultIsChild() async {
        let mock = MockSpeakerVerificationService()
        let result = await mock.verify(pcmData: Data(), referenceVoice: makeProfile())
        XCTAssertEqual(result.speakerType, .child)
        XCTAssertFalse(result.isMatch)
        XCTAssertLessThan(result.similarity, 0.5, "Голос ребёнка — similarity ниже unknown-порога-парента")
    }

    func testMockParentReturnsMatch() async {
        let mock = MockSpeakerVerificationService(isParent: true, similarity: 0.9)
        let result = await mock.verify(pcmData: Data(), referenceVoice: makeProfile())
        XCTAssertEqual(result.speakerType, .parent)
        XCTAssertTrue(result.isMatch)
        XCTAssertGreaterThanOrEqual(result.similarity, 0.75)
    }

    func testMockParentSimilarityClampedAboveThreshold() async {
        // Даже при низком mockSimilarity parent-mock не опускается ниже 0.75.
        let mock = MockSpeakerVerificationService(isParent: true, similarity: 0.1)
        let result = await mock.verify(pcmData: Data(), referenceVoice: makeProfile())
        XCTAssertGreaterThanOrEqual(result.similarity, 0.75)
    }

    func testMockChildSimilarityClampedBelowThreshold() async {
        let mock = MockSpeakerVerificationService(isParent: false, similarity: 0.99)
        let result = await mock.verify(pcmData: Data(), referenceVoice: makeProfile())
        XCTAssertLessThanOrEqual(result.similarity, 0.45)
    }

    func testMockEnrollProducesValidProfile() async throws {
        let mock = MockSpeakerVerificationService()
        let profile = try await mock.enroll(pcmData: Data(repeating: 1, count: 100), ownerId: "parent-77")
        XCTAssertEqual(profile.ownerId, "parent-77")
        XCTAssertEqual(profile.embedding.count, 64)
    }

    func testMockMutableProperties() async {
        let mock = MockSpeakerVerificationService()
        mock.isParent = true
        let result = await mock.verify(pcmData: Data(), referenceVoice: makeProfile())
        XCTAssertEqual(result.speakerType, .parent)
    }

    // MARK: - LiveSpeakerVerificationService (model-missing)

    func testLiveVerifyReturnsUnknownWhenModelUnavailable() async {
        let service = LiveSpeakerVerificationService()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let result = await service.verify(pcmData: Data(repeating: 0, count: 1024), referenceVoice: makeProfile())
        XCTAssertEqual(result.speakerType, .unknown, "Без модели — безопасный unknown")
        XCTAssertFalse(result.isMatch)
        XCTAssertEqual(result.similarity, 0.0, accuracy: 0.0001)
    }

    func testLiveEnrollThrowsWhenModelUnavailable() async {
        let service = LiveSpeakerVerificationService()
        try? await Task.sleep(nanoseconds: 50_000_000)
        do {
            _ = try await service.enroll(pcmData: Data(repeating: 0, count: 1024), ownerId: "x")
            XCTFail("enroll должен бросить mlModelNotFound без модели")
        } catch let error as AppError {
            guard case .mlModelNotFound = error else {
                XCTFail("Ожидался mlModelNotFound, получено: \(error)")
                return
            }
        } catch {
            XCTFail("Ожидался AppError, получено: \(error)")
        }
    }

    // MARK: - SpeakerVerificationResult

    func testVerificationResultInit() {
        let result = SpeakerVerificationResult(isMatch: true, similarity: 0.82, speakerType: .parent)
        XCTAssertTrue(result.isMatch)
        XCTAssertEqual(result.similarity, 0.82, accuracy: 0.001)
        XCTAssertEqual(result.speakerType, .parent)
    }
}
