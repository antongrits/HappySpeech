import Foundation
import OSLog
import RealmSwift

// MARK: - CustomizationStorageWorker

/// Отвечает за чтение/запись кастомизации в Realm и синхронизацию с Firestore.
///
/// Firestore-схема: `users/{uid}/customization` (single document)
/// ```json
/// {
///   "skin": "classic",
///   "color": "warm",
///   "voice": "classic",
///   "updatedAt": <Timestamp>
/// }
/// ```
/// Примечание: Firestore-ключ — `color` (по rules), Realm-поле — `colorVariant` (локальное).
/// Конфликт-стратегия: remote wins (берём запись с более поздним updatedAt).
actor CustomizationStorageWorker {

    // MARK: - Dependencies

    private let realmActor: RealmActor
    private let authService: any AuthService

    private let logger = Logger(subsystem: "ru.happyspeech", category: "CustomizationStorageWorker")

    // MARK: - Init

    init(realmActor: RealmActor, authService: any AuthService) {
        self.realmActor = realmActor
        self.authService = authService
    }

    // MARK: - Load

    /// Загружает текущую кастомизацию из Realm.
    /// Если запись отсутствует — возвращает дефолтный DTO.
    func load() async -> CustomizationDTO {
        do {
            if let dto = try await realmActor.fetchMapped(
                CustomizationObject.self,
                primaryKey: "local",
                map: { CustomizationDTO(object: $0) }
            ) {
                return dto
            }
        } catch {
            logger.error("CustomizationStorageWorker.load failed: \(error)")
        }
        return CustomizationDTO(skin: LyalyaSkin.classic.rawValue,
                                colorVariant: LyalyaColorVariant.warm.rawValue,
                                voice: LyalyaVoice.classic.rawValue)
    }

    // MARK: - Save local

    /// Сохраняет кастомизацию в Realm и обновляет LyalyaCustomizationStorage.
    func saveLocal(dto: CustomizationDTO) async throws {
        try await realmActor.writeVoid { realm in
            let obj = realm.object(ofType: CustomizationObject.self, forPrimaryKey: "local")
                ?? CustomizationObject()
            if obj.id != "local" { obj.id = "local" }
            obj.skin = dto.skin
            obj.colorVariant = dto.colorVariant
            obj.voice = dto.voice
            obj.updatedAt = dto.updatedAt
            realm.add(obj, update: .modified)
        }
        logger.info("CustomizationStorageWorker: saved local skin=\(dto.skin) color=\(dto.colorVariant) voice=\(dto.voice)")
    }

    // MARK: - Cloud sync

    /// Отправляет кастомизацию в облако, если пользователь аутентифицирован.
    /// Возвращает true, если sync прошёл успешно.
    ///
    /// Кастомизация (skin/color/voice) хранится в Realm и полностью работает
    /// офлайн. Облачная синхронизация настроек кастомизации отнесена в
    /// post-v1.0 (см. ADR-V25-SYNC): для анонимного пользователя — no-op.
    func syncToCloud(dto: CustomizationDTO) async -> Bool {
        let user = authService.currentUser
        guard user != nil, user?.isAnonymous == false else {
            logger.info("CustomizationStorageWorker: skipping cloud sync (anonymous user)")
            return false
        }
        return false
    }

    // MARK: - Fetch from cloud

    /// Получает кастомизацию из облака и применяет merge (remote wins по updatedAt).
    /// Облачная синхронизация кастомизации — post-v1.0 (см. ADR-V25-SYNC).
    func fetchAndMergeFromCloud() async {
        let user = authService.currentUser
        guard user != nil, user?.isAnonymous == false else { return }
    }
}
