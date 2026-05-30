@testable import HappySpeech
import XCTest

// MARK: - DiaryShareTokenIssuerTests
//
// Verifies the issue → validate round-trip of the local diary share-token.
//
// Regression context: deriveHMACKey previously derived the HMAC key from an
// AES-GCM encryption of a probe string. AES-GCM injects a random nonce on every
// call, so the ciphertext (and thus the derived key) differed between issue and
// validate — a freshly issued token could NEVER validate. The fix derives the
// HMAC key deterministically (HKDF-SHA256 over the stable child key), so the same
// child always produces the same signing key.
//
// Each test uses a unique childId + per-test keychain service name so tests are
// isolated from each other and from the device's real diary keys.

final class DiaryShareTokenIssuerTests: XCTestCase {

    private var childId: String!
    private var serviceName: String!

    override func setUp() async throws {
        try await super.setUp()
        let unique = UUID().uuidString
        childId = "child-\(unique)"
        serviceName = "ru.happyspeech.diary.test.\(unique)"
    }

    private func makeIssuer() -> DiaryShareTokenIssuer {
        let encryption = DiaryEncryptionWorker(serviceName: serviceName)
        return DiaryShareTokenIssuer(encryption: encryption)
    }

    // MARK: - Round-trip

    func test_issuedToken_passesValidation() async throws {
        let issuer = makeIssuer()
        let (token, expiresAt) = try await issuer.issue(
            clipId: "clip-1", childId: childId, durationHours: 24
        )
        let result = await issuer.validate(token: token, childId: childId)
        guard case let .valid(clipId, validExpires) = result else {
            return XCTFail("Expected .valid, got \(result)")
        }
        XCTAssertEqual(clipId, "clip-1")
        // Epoch is second-truncated inside the token, so compare at second granularity.
        XCTAssertEqual(
            Int(validExpires.timeIntervalSince1970),
            Int(expiresAt.timeIntervalSince1970)
        )
    }

    func test_signatureIsDeterministicAcrossCalls() async throws {
        // Two independent issuers over the SAME childId/keychain must produce the
        // same signature for the same payload — i.e. the derived HMAC key is stable.
        let encryption = DiaryEncryptionWorker(serviceName: serviceName)
        let issuerA = DiaryShareTokenIssuer(encryption: encryption)
        let issuerB = DiaryShareTokenIssuer(encryption: encryption)

        let (tokenA, _) = try await issuerA.issue(
            clipId: "clip-X", childId: childId, durationHours: 1
        )
        // A token issued by A must validate via B (same child, same stable key).
        let resultViaB = await issuerB.validate(token: tokenA, childId: childId)
        guard case .valid = resultViaB else {
            return XCTFail("Token issued by A failed to validate via B: \(resultViaB)")
        }
    }

    // MARK: - Expiry

    func test_expiredToken_isRejected() async throws {
        // durationHours is clamped to >= 1h, so we cannot mint an already-expired
        // token via issue(). Instead we craft a token with a past expiry but a
        // VALID signature, proving expiry is enforced independently of the signature.
        let issuer = makeIssuer()
        let clipId = "clip-expired"
        let pastEpoch = Int(Date().addingTimeInterval(-3600).timeIntervalSince1970)
        let sig = try await issuer.makeSignatureForTesting(
            payload: "\(clipId):\(pastEpoch)", childId: childId
        )
        let token = "\(clipId):\(pastEpoch):\(sig)"

        let result = await issuer.validate(token: token, childId: childId)
        XCTAssertEqual(result, .expired(clipId: clipId))
    }

    // MARK: - Tampering

    func test_tamperedSignature_isRejected() async throws {
        let issuer = makeIssuer()
        let (token, _) = try await issuer.issue(
            clipId: "clip-2", childId: childId, durationHours: 24
        )
        // Flip the last hex char of the signature.
        var chars = Array(token)
        let last = chars[chars.count - 1]
        chars[chars.count - 1] = last == "0" ? "1" : "0"
        let tampered = String(chars)

        let result = await issuer.validate(token: tampered, childId: childId)
        XCTAssertEqual(result, .invalid)
    }

    func test_tamperedClipId_isRejected() async throws {
        let issuer = makeIssuer()
        let (token, _) = try await issuer.issue(
            clipId: "clip-3", childId: childId, durationHours: 24
        )
        let parts = token.split(separator: ":").map(String.init)
        let forged = "clip-EVIL:\(parts[1]):\(parts[2])"

        let result = await issuer.validate(token: forged, childId: childId)
        XCTAssertEqual(result, .invalid)
    }

    func test_validToken_failsForDifferentChild() async throws {
        let issuer = makeIssuer()
        let (token, _) = try await issuer.issue(
            clipId: "clip-4", childId: childId, durationHours: 24
        )
        // A token signed with childId's key must not validate under another child,
        // because the derived HMAC key differs.
        let result = await issuer.validate(token: token, childId: "child-other")
        XCTAssertEqual(result, .invalid)
    }

    func test_malformedToken_isRejected() async {
        let issuer = makeIssuer()
        let r1 = await issuer.validate(token: "garbage", childId: childId)
        let r2 = await issuer.validate(token: "a:b", childId: childId)
        let r3 = await issuer.validate(token: "clip:notanumber:deadbeef", childId: childId)
        XCTAssertEqual(r1, .invalid)
        XCTAssertEqual(r2, .invalid)
        XCTAssertEqual(r3, .invalid)
    }
}
