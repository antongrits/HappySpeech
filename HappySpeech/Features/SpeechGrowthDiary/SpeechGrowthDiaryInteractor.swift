import Foundation
import OSLog

// MARK: - SpeechGrowthDiaryInteractor

@MainActor
final class SpeechGrowthDiaryInteractor {

    private let presenter: SpeechGrowthDiaryPresenter
    private let realmActor: RealmActor
    private let encryption: DiaryEncryptionWorker
    private let storage: DiaryStorage
    private let shareIssuer: DiaryShareTokenIssuer
    private let childId: String
    private let logger = Logger(
        subsystem: "ru.happyspeech", category: "Diary.Interactor"
    )

    init(
        presenter: SpeechGrowthDiaryPresenter,
        realmActor: RealmActor,
        childId: String,
        encryption: DiaryEncryptionWorker = DiaryEncryptionWorker(),
        storage: DiaryStorage = DiaryStorage(),
        shareIssuer: DiaryShareTokenIssuer? = nil
    ) {
        self.presenter = presenter
        self.realmActor = realmActor
        self.encryption = encryption
        self.storage = storage
        self.shareIssuer = shareIssuer ?? DiaryShareTokenIssuer(encryption: encryption)
        self.childId = childId
    }

    // MARK: - List

    func loadClips() async {
        let clips = await realmActor.fetchEncryptedVideoClips(childId: childId)
        await presenter.presentList(response: .init(clips: clips))
    }

    // MARK: - Save

    /// Принимает sourceFileURL (обычно временный .mov из AVCaptureMovieFileOutput) +
    /// thumbnailFileURL (опционально), шифрует оба, удаляет исходники, пишет
    /// в Realm.
    @discardableResult
    func saveClip(
        sourceFileURL: URL,
        thumbnailFileURL: URL?,
        durationSeconds: Double,
        topicTag: String,
        targetSound: String,
        note: String
    ) async -> EncryptedVideoClipData? {
        do {
            let id = UUID().uuidString
            let clipData = try Data(contentsOf: sourceFileURL)
            let encryptedClip = try await encryption.encrypt(data: clipData,
                                                             childId: childId)
            let clipPath = try await storage.writeEncryptedClip(encryptedClip, id: id)
            var thumbPath = ""
            if let thumbURL = thumbnailFileURL,
               let thumbData = try? Data(contentsOf: thumbURL) {
                let encThumb = try await encryption.encrypt(data: thumbData,
                                                            childId: childId)
                thumbPath = try await storage.writeEncryptedThumbnail(encThumb, id: id)
            }
            // Удаляем исходники — никакого нешифрованного остатка на диске.
            try? FileManager.default.removeItem(at: sourceFileURL)
            if let thumbURL = thumbnailFileURL {
                try? FileManager.default.removeItem(at: thumbURL)
            }
            let data = EncryptedVideoClipData(
                id: id,
                childId: childId,
                recordedAt: Date(),
                durationSeconds: durationSeconds,
                encryptedClipPath: clipPath,
                encryptedThumbnailPath: thumbPath,
                topicTag: topicTag,
                targetSound: targetSound,
                note: note,
                shareToken: nil,
                shareTokenExpiresAt: nil
            )
            await realmActor.persistEncryptedVideoClip(data)
            await loadClips()
            return data
        } catch {
            logger.error("saveClip failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Шифрует и сохраняет «сырые» байты (для тестов и для случаев, когда
    /// видео взято не из файла).
    @discardableResult
    func saveClipFromData(
        clipBytes: Data,
        thumbnailBytes: Data?,
        durationSeconds: Double,
        topicTag: String,
        targetSound: String,
        note: String
    ) async -> EncryptedVideoClipData? {
        do {
            let id = UUID().uuidString
            let encryptedClip = try await encryption.encrypt(data: clipBytes,
                                                             childId: childId)
            let clipPath = try await storage.writeEncryptedClip(encryptedClip, id: id)
            var thumbPath = ""
            if let thumbBytes = thumbnailBytes {
                let encThumb = try await encryption.encrypt(data: thumbBytes,
                                                            childId: childId)
                thumbPath = try await storage.writeEncryptedThumbnail(encThumb, id: id)
            }
            let data = EncryptedVideoClipData(
                id: id,
                childId: childId,
                recordedAt: Date(),
                durationSeconds: durationSeconds,
                encryptedClipPath: clipPath,
                encryptedThumbnailPath: thumbPath,
                topicTag: topicTag,
                targetSound: targetSound,
                note: note,
                shareToken: nil,
                shareTokenExpiresAt: nil
            )
            await realmActor.persistEncryptedVideoClip(data)
            await loadClips()
            return data
        } catch {
            logger.error("saveClipFromData failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Decrypt

    /// Расшифровывает клип в память. Возвращает Data байт видео.
    func decryptClip(id: String) async throws -> Data {
        let encryptedClip = try await storage.readEncryptedClip(id: id)
        return try await encryption.decrypt(data: encryptedClip, childId: childId)
    }

    // MARK: - Delete

    func deleteClip(id: String) async {
        await realmActor.deleteEncryptedVideoClip(id: id)
        try? await storage.deleteClipFiles(id: id)
        await loadClips()
    }

    // MARK: - Share

    /// Выдаёт share-token для клипа на N часов.
    func issueShareToken(clipId: String, durationHours: Int) async -> SpeechGrowthDiaryModels.Share.Response? {
        do {
            let result = try await shareIssuer.issue(
                clipId: clipId, childId: childId, durationHours: durationHours
            )
            await realmActor.updateEncryptedClipShareToken(
                id: clipId, token: result.token, expiresAt: result.expiresAt
            )
            await loadClips()
            await presenter.presentShare(
                response: .init(
                    clipId: clipId,
                    token: result.token,
                    expiresAt: result.expiresAt
                )
            )
            return .init(clipId: clipId, token: result.token, expiresAt: result.expiresAt)
        } catch {
            logger.error("issueShareToken failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Отзывает share — затирает токен.
    func revokeShareToken(clipId: String) async {
        await realmActor.updateEncryptedClipShareToken(
            id: clipId, token: nil, expiresAt: nil
        )
        await loadClips()
    }

    /// Проверяет валидность share-токена. Используется специалистом при
    /// принятии.
    func validate(token: String) async -> DiaryShareTokenIssuer.ValidationResult {
        await shareIssuer.validate(token: token, childId: childId)
    }
}
