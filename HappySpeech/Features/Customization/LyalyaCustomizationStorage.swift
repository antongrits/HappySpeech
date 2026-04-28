import Foundation
import Observation

// MARK: - LyalyaCustomizationStorage

/// Shared observable state кастомизации Ляли.
/// Читается в LyalyaMascotView и любых других вью, которым нужен текущий облик Ляли.
/// Пишется только через CustomizationInteractor.
///
/// Паттерн: @Observable singleton — изменения автоматически обновляют все подписчики.
/// AppStorage ключи: "lyalya.skin", "lyalya.color", "lyalya.voice" —
/// для персистентности между запусками до Realm-инициализации.
@Observable
@MainActor
public final class LyalyaCustomizationStorage {

    // MARK: - Shared instance

    public static let shared = LyalyaCustomizationStorage()

    // MARK: - State

    public private(set) var skin: LyalyaSkin = .classic
    public private(set) var colorVariant: LyalyaColorVariant = .warm
    public private(set) var voice: LyalyaVoice = .classic

    // MARK: - Init

    private init() {
        // Restore from UserDefaults on startup (fast path before Realm opens)
        if let rawSkin = UserDefaults.standard.string(forKey: "lyalya.skin"),
           let parsed = LyalyaSkin(rawValue: rawSkin) {
            skin = parsed
        }
        if let rawColor = UserDefaults.standard.string(forKey: "lyalya.color"),
           let parsed = LyalyaColorVariant(rawValue: rawColor) {
            colorVariant = parsed
        }
        if let rawVoice = UserDefaults.standard.string(forKey: "lyalya.voice"),
           let parsed = LyalyaVoice(rawValue: rawVoice) {
            voice = parsed
        }
    }

    // MARK: - Apply

    /// Применяет DTO из Realm/Firestore. Вызывается из CustomizationInteractor.
    func apply(dto: CustomizationDTO) {
        skin = dto.skinEnum
        colorVariant = dto.colorEnum
        voice = dto.voiceEnum

        // Persist fast-path для следующего холодного старта
        UserDefaults.standard.set(dto.skin, forKey: "lyalya.skin")
        UserDefaults.standard.set(dto.colorVariant, forKey: "lyalya.color")
        UserDefaults.standard.set(dto.voice, forKey: "lyalya.voice")
    }

    // MARK: - Computed display helpers

    /// Краткое описание для ячейки Settings: «Классическая · Тёплая»
    public var settingsSubtitle: String {
        "\(skin.localizedName) · \(colorVariant.localizedName)"
    }
}
