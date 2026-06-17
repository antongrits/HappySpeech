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
    /// v19: цвет волос (`LyalyaHairColor.rawValue`). Раньше выбор не сохранялся.
    @Persisted var hairColor: String = LyalyaHairColor.golden.rawValue
    /// v19: цвет глаз (`LyalyaEyeColor.rawValue`).
    @Persisted var eyeColor: String = LyalyaEyeColor.blue.rawValue
    /// v19: тон кожи (`LyalyaSkinTone.rawValue`).
    @Persisted var skinTone: String = LyalyaSkinTone.light.rawValue
    /// v19: включённые аксессуары — rawValues через запятую (Set сериализуется
    /// детерминированно, в отсортированном виде). Пустая строка = нет аксессуаров.
    @Persisted var accessories: String = ""
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
    /// v19: цвет волос / глаз / тон кожи / аксессуары — раньше не сохранялись
    /// (откатывались в дефолт при перезаходе). Аксессуары — rawValues через `,`.
    let hairColor: String
    let eyeColor: String
    let skinTone: String
    let accessories: String
    let updatedAt: Date

    init(object: CustomizationObject) {
        self.skin = object.skin
        self.colorVariant = object.colorVariant
        self.voice = object.voice
        self.outfit = object.outfit
        self.background = object.background
        self.hairColor = object.hairColor
        self.eyeColor = object.eyeColor
        self.skinTone = object.skinTone
        self.accessories = object.accessories
        self.updatedAt = object.updatedAt
    }

    init(
        skin: String,
        colorVariant: String,
        voice: String,
        outfit: String = LyalyaOutfit.everyday.rawValue,
        background: String = LyalyaBackground.meadow.rawValue,
        hairColor: String = LyalyaHairColor.golden.rawValue,
        eyeColor: String = LyalyaEyeColor.blue.rawValue,
        skinTone: String = LyalyaSkinTone.light.rawValue,
        accessories: String = "",
        updatedAt: Date = Date()
    ) {
        self.skin = skin
        self.colorVariant = colorVariant
        self.voice = voice
        self.outfit = outfit
        self.background = background
        self.hairColor = hairColor
        self.eyeColor = eyeColor
        self.skinTone = skinTone
        self.accessories = accessories
        self.updatedAt = updatedAt
    }

    var skinEnum: LyalyaSkin { LyalyaSkin(rawValue: skin) ?? .classic }
    var colorEnum: LyalyaColorVariant { LyalyaColorVariant(rawValue: colorVariant) ?? .warm }
    var voiceEnum: LyalyaVoice { LyalyaVoice(rawValue: voice) ?? .classic }
    var outfitEnum: LyalyaOutfit { LyalyaOutfit(rawValue: outfit) ?? .everyday }
    var backgroundEnum: LyalyaBackground { LyalyaBackground(rawValue: background) ?? .meadow }
    var hairColorEnum: LyalyaHairColor { LyalyaHairColor(rawValue: hairColor) ?? .golden }
    var eyeColorEnum: LyalyaEyeColor { LyalyaEyeColor(rawValue: eyeColor) ?? .blue }
    var skinToneEnum: LyalyaSkinTone { LyalyaSkinTone(rawValue: skinTone) ?? .light }

    /// Декодирует включённые аксессуары из сериализованной строки rawValues.
    var accessorySet: Set<LyalyaAccessory> {
        Set(
            accessories
                .split(separator: ",")
                .compactMap { LyalyaAccessory(rawValue: String($0).trimmingCharacters(in: .whitespaces)) }
        )
    }

    /// Сериализует набор аксессуаров в детерминированную строку rawValues.
    static func encodeAccessories(_ set: Set<LyalyaAccessory>) -> String {
        set.map(\.rawValue).sorted().joined(separator: ",")
    }
}
