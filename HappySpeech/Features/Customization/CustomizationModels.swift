import AVFoundation
import Foundation
import SwiftUI

// MARK: - LyalyaSkin

public enum LyalyaSkin: String, CaseIterable, Identifiable, Sendable {
    case classic
    case princess
    case scientist
    case athlete
    case artist

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .classic:    return String(localized: "customization.skin.classic")
        case .princess:   return String(localized: "customization.skin.princess")
        case .scientist:  return String(localized: "customization.skin.scientist")
        case .athlete:    return String(localized: "customization.skin.athlete")
        case .artist:     return String(localized: "customization.skin.artist")
        }
    }

    public var illustrationName: String { "lyalya_\(rawValue)" }
}

// MARK: - LyalyaOutfit

/// Наряды Ляли. Некоторые требуют разблокировки через достижения.
public enum LyalyaOutfit: String, CaseIterable, Identifiable, Sendable {
    case everyday    // повседневная (по умолчанию, всегда открыта)
    case beach       // пляж
    case winter      // зима
    case school      // школа
    case birthday    // день рождения
    case space       // космос

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .everyday:  return String(localized: "customization.outfit.everyday")
        case .beach:     return String(localized: "customization.outfit.beach")
        case .winter:    return String(localized: "customization.outfit.winter")
        case .school:    return String(localized: "customization.outfit.school")
        case .birthday:  return String(localized: "customization.outfit.birthday")
        case .space:     return String(localized: "customization.outfit.space")
        }
    }

    public var illustrationName: String { "lyalya_outfit_\(rawValue)" }

    /// Стоимость в звёздочках (0 — бесплатно)
    public var starCost: Int {
        switch self {
        case .everyday: return 0
        case .beach:    return 10
        case .winter:   return 15
        case .school:   return 5
        case .birthday: return 20
        case .space:    return 30
        }
    }

    /// Минимальное количество завершённых уроков подряд для разблокировки
    public var requiredStreak: Int {
        switch self {
        case .everyday: return 0
        case .beach:    return 3
        case .winter:   return 5
        case .school:   return 2
        case .birthday: return 7
        case .space:    return 14
        }
    }

    /// Описание условия разблокировки для отображения пользователю
    public var unlockHint: String {
        guard requiredStreak > 0 else { return "" }
        return String(
            format: String(localized: "customization.outfit.unlock_hint"),
            requiredStreak
        )
    }
}

// MARK: - LyalyaHairColor

/// Цвет волос Ляли — пастельные оттенки.
public enum LyalyaHairColor: String, CaseIterable, Identifiable, Sendable {
    case golden    // золотистый
    case chestnut  // каштановый
    case black     // чёрный
    case pink      // розовый
    case cyan      // бирюзовый

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .golden:   return String(localized: "customization.hair.golden")
        case .chestnut: return String(localized: "customization.hair.chestnut")
        case .black:    return String(localized: "customization.hair.black")
        case .pink:     return String(localized: "customization.hair.pink")
        case .cyan:     return String(localized: "customization.hair.cyan")
        }
    }

    public var previewColor: Color {
        switch self {
        case .golden:   return ColorTokens.Theme.hairGolden
        case .chestnut: return ColorTokens.Theme.hairChestnut
        case .black:    return ColorTokens.Theme.hairBlack
        case .pink:     return ColorTokens.Theme.hairPink
        case .cyan:     return ColorTokens.Theme.hairCyan
        }
    }
}

// MARK: - LyalyaEyeColor

public enum LyalyaEyeColor: String, CaseIterable, Identifiable, Sendable {
    case blue
    case green
    case brown

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .blue:  return String(localized: "customization.eye.blue")
        case .green: return String(localized: "customization.eye.green")
        case .brown: return String(localized: "customization.eye.brown")
        }
    }

    public var previewColor: Color {
        switch self {
        case .blue:  return ColorTokens.Theme.eyeBlue
        case .green: return ColorTokens.Theme.eyeGreen
        case .brown: return ColorTokens.Theme.eyeBrown
        }
    }
}

// MARK: - LyalyaSkinTone

public enum LyalyaSkinTone: String, CaseIterable, Identifiable, Sendable {
    case light
    case medium
    case dark

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .light:  return String(localized: "customization.skintone.light")
        case .medium: return String(localized: "customization.skintone.medium")
        case .dark:   return String(localized: "customization.skintone.dark")
        }
    }

    public var previewColor: Color {
        switch self {
        case .light:  return ColorTokens.Theme.toneLight
        case .medium: return ColorTokens.Theme.toneMedium
        case .dark:   return ColorTokens.Theme.toneDark
        }
    }
}

// MARK: - LyalyaAccessory

/// Аксессуары — toggle on/off. Некоторые требуют достижений.
public enum LyalyaAccessory: String, CaseIterable, Identifiable, Sendable {
    case glasses   // очки
    case hat       // шапка
    case bow       // бабочка
    case bag       // сумка

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .glasses: return String(localized: "customization.accessory.glasses")
        case .hat:     return String(localized: "customization.accessory.hat")
        case .bow:     return String(localized: "customization.accessory.bow")
        case .bag:     return String(localized: "customization.accessory.bag")
        }
    }

    public var iconName: String {
        switch self {
        case .glasses: return "eyeglasses"
        case .hat:     return "hat.widebrim"
        case .bow:     return "gift"
        case .bag:     return "bag"
        }
    }

    /// Требуемое достижение для разблокировки (nil — открыто сразу)
    var requiredAchievement: Achievement? {
        switch self {
        case .glasses: return nil
        case .hat:     return .streak3Days
        case .bow:     return .played10Rounds
        case .bag:     return .streak7Days
        }
    }
}

// MARK: - LyalyaBackground

/// Фоновые сцены для детского контура.
public enum LyalyaBackground: String, CaseIterable, Identifiable, Sendable {
    case bedroom   // спальня
    case garden    // сад
    case school    // школа
    case ocean     // океан
    case forest    // лес

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .bedroom: return String(localized: "customization.background.bedroom")
        case .garden:  return String(localized: "customization.background.garden")
        case .school:  return String(localized: "customization.background.school")
        case .ocean:   return String(localized: "customization.background.ocean")
        case .forest:  return String(localized: "customization.background.forest")
        }
    }

    public var illustrationName: String { "bg_\(rawValue)" }

    public var previewGradient: LinearGradient {
        switch self {
        case .bedroom:
            return LinearGradient(
                colors: [ColorTokens.Theme.bedroomFrom, ColorTokens.Theme.bedroomTo],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .garden:
            return LinearGradient(
                colors: [ColorTokens.Theme.gardenFrom, ColorTokens.Theme.gardenTo],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .school:
            return LinearGradient(
                colors: [ColorTokens.Theme.schoolBgFrom, ColorTokens.Theme.schoolBgTo],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .ocean:
            return LinearGradient(
                colors: [ColorTokens.Theme.oceanFrom, ColorTokens.Theme.oceanTo],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .forest:
            return LinearGradient(
                colors: [ColorTokens.Theme.forestFrom, ColorTokens.Theme.forestTo],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - LyalyaColorVariant

public enum LyalyaColorVariant: String, CaseIterable, Identifiable, Sendable {
    case warm
    case cool
    case nature

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .warm:   return String(localized: "customization.color.warm")
        case .cool:   return String(localized: "customization.color.cool")
        case .nature: return String(localized: "customization.color.nature")
        }
    }

    public var gradientColors: (Color, Color) {
        switch self {
        case .warm:   return (ColorTokens.Theme.warmFrom, ColorTokens.Theme.warmTo)
        case .cool:   return (ColorTokens.Theme.coolFrom, ColorTokens.Theme.coolTo)
        case .nature: return (ColorTokens.Theme.natureFrom, ColorTokens.Theme.natureTo)
        }
    }

    public var previewGradient: LinearGradient {
        let (from, to) = gradientColors
        return LinearGradient(colors: [from, to], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// UIColor тела Ляли для передачи в RealityKit SimpleMaterial.
    public var uiColor: UIColor {
        switch self {
        case .warm:   return ColorTokens.Theme.bodyWarmUI
        case .cool:   return ColorTokens.Theme.bodyCoolUI
        case .nature: return ColorTokens.Theme.bodyNatureUI
        }
    }
}

// MARK: - LyalyaVoice

public enum LyalyaVoice: String, CaseIterable, Identifiable, Sendable {
    case classic
    case soft
    case cheerful

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .classic:  return String(localized: "customization.voice.classic")
        case .soft:     return String(localized: "customization.voice.soft")
        case .cheerful: return String(localized: "customization.voice.cheerful")
        }
    }

    public var previewFile: String { "lyalya_voice_\(rawValue)_preview" }

    public var speechPitch: Float {
        switch self {
        case .classic:  return 1.0
        case .soft:     return 0.85
        case .cheerful: return 1.2
        }
    }
}

// MARK: - UnlockStatus

/// Статус доступности элемента кастомизации
public enum UnlockStatus: Sendable {
    case available             // доступно сразу
    case unlocked              // разблокировано через достижение
    case locked(hint: String)  // заблокировано, с подсказкой

    var isAccessible: Bool {
        switch self {
        case .available, .unlocked: return true
        case .locked: return false
        }
    }
}

// MARK: - OutfitItemViewModel

public struct OutfitItemViewModel: Identifiable, Sendable {
    public let id: String
    public let outfit: LyalyaOutfit
    public let localizedName: String
    public let illustrationName: String
    public let starCost: Int
    public let unlockStatus: UnlockStatus
    public let isSelected: Bool
}

// MARK: - AccessoryItemViewModel

public struct AccessoryItemViewModel: Identifiable, Sendable {
    public let id: String
    public let accessory: LyalyaAccessory
    public let localizedName: String
    public let iconName: String
    public let unlockStatus: UnlockStatus
    public let isEnabled: Bool
}

// MARK: - BackgroundItemViewModel

public struct BackgroundItemViewModel: Identifiable, Sendable {
    public let id: String
    public let background: LyalyaBackground
    public let localizedName: String
    public let illustrationName: String
    public let isSelected: Bool
}

// MARK: - CustomizationViewModel

public struct CustomizationViewModel: Sendable {
    public var selectedSkin: LyalyaSkin
    public var selectedColor: LyalyaColorVariant
    public var selectedVoice: LyalyaVoice
    public var selectedOutfit: LyalyaOutfit
    public var selectedHairColor: LyalyaHairColor
    public var selectedEyeColor: LyalyaEyeColor
    public var selectedSkinTone: LyalyaSkinTone
    public var enabledAccessories: Set<LyalyaAccessory>
    public var selectedBackground: LyalyaBackground
    public var outfitItems: [OutfitItemViewModel]
    public var accessoryItems: [AccessoryItemViewModel]
    public var backgroundItems: [BackgroundItemViewModel]
    public var isSaving: Bool
    public var isUnchanged: Bool
    public var toastMessage: String?
    public var toastIsError: Bool
    public var playingVoice: LyalyaVoice?
    public var showCelebration: Bool
    public var lyalyaPrompt: String?

    public init(
        selectedSkin: LyalyaSkin = .classic,
        selectedColor: LyalyaColorVariant = .warm,
        selectedVoice: LyalyaVoice = .classic,
        selectedOutfit: LyalyaOutfit = .everyday,
        selectedHairColor: LyalyaHairColor = .golden,
        selectedEyeColor: LyalyaEyeColor = .blue,
        selectedSkinTone: LyalyaSkinTone = .light,
        enabledAccessories: Set<LyalyaAccessory> = [],
        selectedBackground: LyalyaBackground = .bedroom,
        outfitItems: [OutfitItemViewModel] = [],
        accessoryItems: [AccessoryItemViewModel] = [],
        backgroundItems: [BackgroundItemViewModel] = [],
        isSaving: Bool = false,
        isUnchanged: Bool = true,
        toastMessage: String? = nil,
        toastIsError: Bool = false,
        playingVoice: LyalyaVoice? = nil,
        showCelebration: Bool = false,
        lyalyaPrompt: String? = nil
    ) {
        self.selectedSkin = selectedSkin
        self.selectedColor = selectedColor
        self.selectedVoice = selectedVoice
        self.selectedOutfit = selectedOutfit
        self.selectedHairColor = selectedHairColor
        self.selectedEyeColor = selectedEyeColor
        self.selectedSkinTone = selectedSkinTone
        self.enabledAccessories = enabledAccessories
        self.selectedBackground = selectedBackground
        self.outfitItems = outfitItems
        self.accessoryItems = accessoryItems
        self.backgroundItems = backgroundItems
        self.isSaving = isSaving
        self.isUnchanged = isUnchanged
        self.toastMessage = toastMessage
        self.toastIsError = toastIsError
        self.playingVoice = playingVoice
        self.showCelebration = showCelebration
        self.lyalyaPrompt = lyalyaPrompt
    }
}

// MARK: - Request types

public enum Customization {

    public struct LoadRequest {
        public let childStreakDays: Int
        public let unlockedAchievements: Set<String>
        public init(childStreakDays: Int = 0, unlockedAchievements: Set<String> = []) {
            self.childStreakDays = childStreakDays
            self.unlockedAchievements = unlockedAchievements
        }
    }

    public struct SaveRequest: Sendable {
        public let skin: LyalyaSkin
        public let color: LyalyaColorVariant
        public let voice: LyalyaVoice
        public let outfit: LyalyaOutfit
        public let hairColor: LyalyaHairColor
        public let eyeColor: LyalyaEyeColor
        public let skinTone: LyalyaSkinTone
        public let enabledAccessories: Set<LyalyaAccessory>
        public let background: LyalyaBackground

        public init(
            skin: LyalyaSkin,
            color: LyalyaColorVariant,
            voice: LyalyaVoice,
            outfit: LyalyaOutfit = .everyday,
            hairColor: LyalyaHairColor = .golden,
            eyeColor: LyalyaEyeColor = .blue,
            skinTone: LyalyaSkinTone = .light,
            enabledAccessories: Set<LyalyaAccessory> = [],
            background: LyalyaBackground = .bedroom
        ) {
            self.skin = skin
            self.color = color
            self.voice = voice
            self.outfit = outfit
            self.hairColor = hairColor
            self.eyeColor = eyeColor
            self.skinTone = skinTone
            self.enabledAccessories = enabledAccessories
            self.background = background
        }
    }

    public struct SelectSkinRequest: Sendable {
        public let skin: LyalyaSkin
        public init(skin: LyalyaSkin) { self.skin = skin }
    }

    public struct SelectColorRequest: Sendable {
        public let color: LyalyaColorVariant
        public init(color: LyalyaColorVariant) { self.color = color }
    }

    public struct SelectVoiceRequest: Sendable {
        public let voice: LyalyaVoice
        public init(voice: LyalyaVoice) { self.voice = voice }
    }

    public struct SelectOutfitRequest: Sendable {
        public let outfit: LyalyaOutfit
        public init(outfit: LyalyaOutfit) { self.outfit = outfit }
    }

    public struct SelectHairColorRequest: Sendable {
        public let color: LyalyaHairColor
        public init(color: LyalyaHairColor) { self.color = color }
    }

    public struct SelectEyeColorRequest: Sendable {
        public let color: LyalyaEyeColor
        public init(color: LyalyaEyeColor) { self.color = color }
    }

    public struct SelectSkinToneRequest: Sendable {
        public let tone: LyalyaSkinTone
        public init(tone: LyalyaSkinTone) { self.tone = tone }
    }

    public struct ToggleAccessoryRequest: Sendable {
        public let accessory: LyalyaAccessory
        public init(accessory: LyalyaAccessory) { self.accessory = accessory }
    }

    public struct SelectBackgroundRequest: Sendable {
        public let background: LyalyaBackground
        public init(background: LyalyaBackground) { self.background = background }
    }

    public struct PreviewVoiceRequest: Sendable {
        public let voice: LyalyaVoice
        public init(voice: LyalyaVoice) { self.voice = voice }
    }

    public struct ResetRequest: Sendable {
        public init() {}
    }

    // MARK: - Response types

    public struct LoadResponse: Sendable {
        public let skin: LyalyaSkin
        public let color: LyalyaColorVariant
        public let voice: LyalyaVoice
        public let outfit: LyalyaOutfit
        public let hairColor: LyalyaHairColor
        public let eyeColor: LyalyaEyeColor
        public let skinTone: LyalyaSkinTone
        public let enabledAccessories: Set<LyalyaAccessory>
        public let background: LyalyaBackground
        public let childStreakDays: Int
        public let unlockedAchievements: Set<String>

        public init(
            skin: LyalyaSkin,
            color: LyalyaColorVariant,
            voice: LyalyaVoice,
            outfit: LyalyaOutfit = .everyday,
            hairColor: LyalyaHairColor = .golden,
            eyeColor: LyalyaEyeColor = .blue,
            skinTone: LyalyaSkinTone = .light,
            enabledAccessories: Set<LyalyaAccessory> = [],
            background: LyalyaBackground = .bedroom,
            childStreakDays: Int = 0,
            unlockedAchievements: Set<String> = []
        ) {
            self.skin = skin
            self.color = color
            self.voice = voice
            self.outfit = outfit
            self.hairColor = hairColor
            self.eyeColor = eyeColor
            self.skinTone = skinTone
            self.enabledAccessories = enabledAccessories
            self.background = background
            self.childStreakDays = childStreakDays
            self.unlockedAchievements = unlockedAchievements
        }
    }

    public struct SaveResponse: Sendable {
        public let success: Bool
        public let cloudSynced: Bool
        public let errorMessage: String?

        public init(success: Bool, cloudSynced: Bool, errorMessage: String? = nil) {
            self.success = success
            self.cloudSynced = cloudSynced
            self.errorMessage = errorMessage
        }
    }
}
