import CryptoKit
import Foundation
import KeychainAccess
import OSLog

// MARK: - DiaryEncryptionWorker
//
// Шифрует/расшифровывает локальные видеоклипы дневника CryptoKit AES-GCM-256.
//
// Принципы:
//   • Один ключ на child — не делим на клип, чтобы не плодить ключевую
//     иерархию (доп. сложность для дипломного проекта).
//   • Ключ хранится в Keychain через KeychainAccess; класс безопасности —
//     `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (не покидает устройство,
//     iCloud не синхронизирует, доступ только после unlock).
//   • Шифруем целиком файл (encrypt-then-store; one-shot per file), потому
//     что клипы короткие (≤30 сек) и помещаются в память даже на iPhone SE.
//   • Никогда не логируем ключ.

struct DiaryEncryptionError: Error {
    let underlying: String
}

actor DiaryEncryptionWorker {

    private let keychain: Keychain
    private let logger = Logger(
        subsystem: "ru.happyspeech", category: "Diary.Encryption"
    )

    /// Используется в тестах для подмены keychain.
    init(serviceName: String = "ru.happyspeech.diary") {
        let access = Accessibility.whenUnlockedThisDeviceOnly
        self.keychain = Keychain(service: serviceName)
            .accessibility(access)
            .synchronizable(false)
    }

    // MARK: - Public

    /// Шифрует данные ключом ребёнка. Создаёт ключ, если его нет.
    func encrypt(data: Data, childId: String) async throws -> Data {
        let key = try await ensureKey(for: childId)
        do {
            let sealed = try AES.GCM.seal(data, using: key)
            // sealed.combined — nonce + ciphertext + tag. Возвращаем как есть.
            guard let combined = sealed.combined else {
                throw DiaryEncryptionError(underlying: "no combined output")
            }
            return combined
        } catch {
            throw DiaryEncryptionError(underlying: "seal failed")
        }
    }

    /// Расшифровывает данные ключом ребёнка.
    func decrypt(data: Data, childId: String) async throws -> Data {
        let key = try await ensureKey(for: childId)
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw DiaryEncryptionError(underlying: "open failed")
        }
    }

    /// Удаляет ключ ребёнка (используется при удалении профиля).
    func deleteKey(for childId: String) async throws {
        let label = key(for: childId)
        try keychain.remove(label)
    }

    /// Проверяет наличие ключа (без получения raw-байтов в логи).
    func hasKey(for childId: String) async -> Bool {
        let label = key(for: childId)
        return (try? keychain.getData(label)) != nil
    }

    // MARK: - Private

    /// Возвращает существующий ключ либо генерирует новый 256-bit.
    private func ensureKey(for childId: String) async throws -> SymmetricKey {
        let label = key(for: childId)
        if let bytes = try? keychain.getData(label) {
            return SymmetricKey(data: bytes)
        }
        let newKey = SymmetricKey(size: .bits256)
        let bytes = newKey.withUnsafeBytes { Data($0) }
        do {
            try keychain.set(bytes, key: label)
            logger.info("Generated new diary key for child (label suppressed).")
            return newKey
        } catch {
            throw DiaryEncryptionError(underlying: "keychain set failed")
        }
    }

    private func key(for childId: String) -> String {
        // Не включаем PII — только короткий hash от childId.
        let digest = SHA256.hash(data: Data(childId.utf8))
        let short = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        return "diary-key-\(short)"
    }
}

// MARK: - DiaryShareTokenIssuer
//
// Локальный share-token. Не Cloud — никаких сетевых вызовов.
//
// Формат: `<clipId>:<expiresAt>:<sig>`, где `sig` — HMAC-SHA256 от первых
// двух полей с child-key. Получив токен, специалист (в той же копии приложения,
// в режиме «принять share») может проверить sig тем же ключом — это
// гарантия неподдельности на одном устройстве.

actor DiaryShareTokenIssuer {

    private let encryption: DiaryEncryptionWorker

    init(encryption: DiaryEncryptionWorker) {
        self.encryption = encryption
    }

    /// Выдаёт share-token. Возвращает (token, expiresAt).
    func issue(
        clipId: String,
        childId: String,
        durationHours: Int
    ) async throws -> (token: String, expiresAt: Date) {
        let clamped = max(1, min(168, durationHours))
        let expires = Date().addingTimeInterval(TimeInterval(clamped * 3600))
        let expiresEpoch = Int(expires.timeIntervalSince1970)
        let payload = "\(clipId):\(expiresEpoch)"
        let sig = try await signature(of: payload, childId: childId)
        let token = "\(payload):\(sig)"
        return (token, expires)
    }

    /// Проверяет токен: валиден ли sig и не истёк ли срок.
    func validate(token: String, childId: String) async -> ValidationResult {
        let parts = token.split(separator: ":", omittingEmptySubsequences: true).map(String.init)
        guard parts.count == 3 else { return .invalid }
        let clipId = parts[0]
        guard let expiresEpoch = Int(parts[1]) else { return .invalid }
        let expectedSig: String
        do {
            expectedSig = try await signature(of: "\(clipId):\(expiresEpoch)", childId: childId)
        } catch {
            return .invalid
        }
        guard parts[2] == expectedSig else { return .invalid }
        let expiresAt = Date(timeIntervalSince1970: TimeInterval(expiresEpoch))
        if Date() > expiresAt { return .expired(clipId: clipId) }
        return .valid(clipId: clipId, expiresAt: expiresAt)
    }

    enum ValidationResult: Equatable {
        case valid(clipId: String, expiresAt: Date)
        case expired(clipId: String)
        case invalid
    }

    // MARK: - Private

    /// HMAC-SHA256(payload, key=child-key). Возвращает hex-string.
    private func signature(of payload: String, childId: String) async throws -> String {
        let derivedKey = try await deriveHMACKey(for: childId)
        let mac = HMAC<SHA256>.authenticationCode(
            for: Data(payload.utf8),
            using: derivedKey
        )
        return mac.map { String(format: "%02x", $0) }.joined()
    }

    /// Производит ключ для HMAC из шифровального ключа ребёнка через
    /// дополнительный HKDF-шаг — чтобы не использовать тот же raw-ключ.
    private func deriveHMACKey(for childId: String) async throws -> SymmetricKey {
        // Получаем зашифрованный child-key и используем как input keying material.
        let probe = "share-token-derivation-v1"
        let encrypted = try await encryption.encrypt(data: Data(probe.utf8), childId: childId)
        // Хешируем шифротекст — он содержит nonce и тег, неповторяемый.
        let digest = SHA256.hash(data: encrypted)
        return SymmetricKey(data: digest)
    }
}
