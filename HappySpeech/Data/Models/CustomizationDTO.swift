import Foundation
import RealmSwift

// MARK: - CustomizationObject

/// Realm-объект для хранения кастомизации Ляли.
/// Primary key: "local" — один объект на всё приложение.
/// Realm schema v4 — добавлен объект; v14 — добавлены `outfit` и `background`
/// (наряд и фоновая сцена), чтобы выбор отражался на всех экранах героя.
final class CustomizationObject: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = "local"
    @Persisted var skin: String = LyalyaSkin.classic.rawValue
    @Persisted var colorVariant: String = LyalyaColorVariant.warm.rawValue
    @Persisted var voice: String = LyalyaVoice.classic.rawValue
    /// v14: выбранный наряд (`LyalyaOutfit.rawValue`). По умолчанию — повседневный.
    @Persisted var outfit: String = LyalyaOutfit.everyday.rawValue
    /// v14: выбранная фоновая сцена (`LyalyaBackground.rawValue`).
    @Persisted var background: String = LyalyaBackground.meadow.rawValue
    @Persisted var updatedAt: Date = Date()
}

// MARK: - CustomizationDTO (Sendable snapshot)

/// Sendable DTO для безопасного пересечения actor-границ.
struct CustomizationDTO: Sendable {
    let skin: String
    let colorVariant: String
    let voice: String
    let outfit: String
    let background: String
    let updatedAt: Date

    init(object: CustomizationObject) {
        self.skin = object.skin
        self.colorVariant = object.colorVariant
        self.voice = object.voice
        self.outfit = object.outfit
        self.background = object.background
        self.updatedAt = object.updatedAt
    }

    init(
        skin: String,
        colorVariant: String,
        voice: String,
        outfit: String = LyalyaOutfit.everyday.rawValue,
        background: String = LyalyaBackground.meadow.rawValue,
        updatedAt: Date = Date()
    ) {
        self.skin = skin
        self.colorVariant = colorVariant
        self.voice = voice
        self.outfit = outfit
        self.background = background
        self.updatedAt = updatedAt
    }

    var skinEnum: LyalyaSkin { LyalyaSkin(rawValue: skin) ?? .classic }
    var colorEnum: LyalyaColorVariant { LyalyaColorVariant(rawValue: colorVariant) ?? .warm }
    var voiceEnum: LyalyaVoice { LyalyaVoice(rawValue: voice) ?? .classic }
    var outfitEnum: LyalyaOutfit { LyalyaOutfit(rawValue: outfit) ?? .everyday }
    var backgroundEnum: LyalyaBackground { LyalyaBackground(rawValue: background) ?? .meadow }
}
