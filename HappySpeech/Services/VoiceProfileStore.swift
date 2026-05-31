import Foundation
import OSLog

// MARK: - VoiceProfileStore

/// Локальное хранилище зарегистрированного голосового профиля родителя
/// (d-vector эмбеддинг ECAPA для ``SpeakerVerificationServiceProtocol``).
///
/// ### Почему UserDefaults, а не Realm
/// Профиль — это 64-мерный нормализованный вектор без аудио и без PII (только
/// `ownerId`). Это конфигурация безопасности контура, а не синхронизируемый
/// прогресс ребёнка. Тот же приём, что и в ``SpeechDisorderStore``: per-owner
/// ключ в `UserDefaults`, без bump-а `RealmSchemaVersion`.
///
/// ### COPPA
/// Профиль родителя никогда не покидает устройство — он используется только
/// для локального различения «родитель против ребёнка» при семейной записи
/// голоса, чтобы детские записи не помечались как родительские.
public enum VoiceProfileStore {

    private static let keyPrefix = "voice.profile."

    private static func key(for ownerId: String) -> String {
        keyPrefix + ownerId
    }

    /// Сохраняет голосовой профиль владельца.
    public static func save(
        _ profile: VoiceProfile,
        defaults: UserDefaults = .standard
    ) {
        guard !profile.ownerId.isEmpty else { return }
        guard let data = try? JSONEncoder().encode(profile) else {
            HSLogger.ml.error("VoiceProfileStore: не удалось закодировать профиль")
            return
        }
        defaults.set(data, forKey: key(for: profile.ownerId))
        HSLogger.ml.info(
            "VoiceProfileStore: профиль сохранён ownerId=\(profile.ownerId.prefix(8), privacy: .private)"
        )
    }

    /// Возвращает голосовой профиль владельца; `nil`, если ещё не зарегистрирован.
    public static func load(
        ownerId: String,
        defaults: UserDefaults = .standard
    ) -> VoiceProfile? {
        guard !ownerId.isEmpty,
              let data = defaults.data(forKey: key(for: ownerId)),
              let profile = try? JSONDecoder().decode(VoiceProfile.self, from: data)
        else {
            return nil
        }
        return profile
    }

    /// Удаляет профиль (например, при выходе из аккаунта или сбросе).
    public static func clear(ownerId: String, defaults: UserDefaults = .standard) {
        guard !ownerId.isEmpty else { return }
        defaults.removeObject(forKey: key(for: ownerId))
    }
}
