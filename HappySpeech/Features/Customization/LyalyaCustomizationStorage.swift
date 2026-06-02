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
    /// Выбранный наряд — читается hero-вью на ключевых экранах (приветствие,
    /// превью кастомизации), чтобы смена одежды видимо меняла героя.
    public private(set) var outfit: LyalyaOutfit = .everyday
    /// Выбранная фоновая сцена — применяется за героем в кастомизации-превью.
    public private(set) var background: LyalyaBackground = .meadow

    // MARK: - UserDefaults keys

    private enum Keys {
        static let skin = "lyalya.skin"
        static let color = "lyalya.color"
        static let voice = "lyalya.voice"
        static let outfit = "lyalya.outfit"
        static let background = "lyalya.background"
    }

    // MARK: - Init

    private init() {
        // Restore from UserDefaults on startup (fast path before Realm opens)
        if let rawSkin = UserDefaults.standard.string(forKey: Keys.skin),
           let parsed = LyalyaSkin(rawValue: rawSkin) {
            skin = parsed
        }
        if let rawColor = UserDefaults.standard.string(forKey: Keys.color),
           let parsed = LyalyaColorVariant(rawValue: rawColor) {
            colorVariant = parsed
        }
        if let rawVoice = UserDefaults.standard.string(forKey: Keys.voice),
           let parsed = LyalyaVoice(rawValue: rawVoice) {
            voice = parsed
        }
        if let rawOutfit = UserDefaults.standard.string(forKey: Keys.outfit),
           let parsed = LyalyaOutfit(rawValue: rawOutfit) {
            outfit = parsed
        }
        if let rawBg = UserDefaults.standard.string(forKey: Keys.background),
           let parsed = LyalyaBackground(rawValue: rawBg) {
            background = parsed
        }
    }

    // MARK: - Apply

    /// Применяет DTO из Realm/Firestore. Вызывается из CustomizationInteractor.
    func apply(dto: CustomizationDTO) {
        skin = dto.skinEnum
        colorVariant = dto.colorEnum
        voice = dto.voiceEnum
        outfit = dto.outfitEnum
        background = dto.backgroundEnum

        // Persist fast-path для следующего холодного старта
        UserDefaults.standard.set(dto.skin, forKey: Keys.skin)
        UserDefaults.standard.set(dto.colorVariant, forKey: Keys.color)
        UserDefaults.standard.set(dto.voice, forKey: Keys.voice)
        UserDefaults.standard.set(dto.outfit, forKey: Keys.outfit)
        UserDefaults.standard.set(dto.background, forKey: Keys.background)
    }

    // MARK: - Computed display helpers

    /// Краткое описание для ячейки Settings: «Классическая · Тёплая»
    public var settingsSubtitle: String {
        "\(skin.localizedName) · \(colorVariant.localizedName)"
    }

    /// Имя статичной иллюстрации героя, отражающей выбранный наряд
    /// (`lyalya_outfit_<id>`). Используется hero-вью на экранах-приветствиях,
    /// где смена одежды должна быть видимой. На анимированных позах остаётся
    /// канон `mascot_lyalya_*` (ре-риг невозможен).
    public var heroOutfitIllustrationName: String {
        outfit.illustrationName
    }
}
