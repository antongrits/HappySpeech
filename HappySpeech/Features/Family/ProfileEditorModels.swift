import Foundation
import SwiftUI

// MARK: - ProfileEditor VIP Models

enum ProfileEditor {

    // MARK: - Requests

    struct LoadRequest {
        let childId: String
    }

    struct SaveRequest {
        let childId: String
        let name: String
        let age: Int
        let avatarStyle: String
        let colorTheme: String
    }

    // MARK: - Responses

    struct LoadResponse {
        let childId: String
        let name: String
        let age: Int
        let avatarStyle: String
        let colorTheme: String
        let targetSounds: [String]
    }

    struct SaveResponse {
        let success: Bool
        let errorMessage: String?
    }

    // MARK: - Domain: Avatar presets

    struct AvatarPreset: Identifiable {
        let id: String                // rawValue
        let illustrationName: String  // Asset catalog name (Block D v16: replaces emoji)
        let localizedName: String
    }

    // Block D v16 / G v18: иллюстрационные ассеты для аватаров.
    //   butterfly → mascot_lyalya_wave (Lyalya — бабочка)
    //   star      → reward_gold_star
    //   rocket    → reward_rocket
    //   dragon    → reward_brave_heart (fallback)
    //   unicorn   → reward_rainbow (fallback)
    static let avatarPresets: [AvatarPreset] = [
        AvatarPreset(id: "butterfly", illustrationName: "mascot_lyalya_wave",
                     localizedName: String(localized: "avatar.butterfly")),
        AvatarPreset(id: "star",      illustrationName: "reward_gold_star",
                     localizedName: String(localized: "avatar.star")),
        AvatarPreset(id: "rocket",    illustrationName: "reward_rocket",
                     localizedName: String(localized: "avatar.rocket")),
        AvatarPreset(id: "dragon",    illustrationName: "reward_brave_heart",
                     localizedName: String(localized: "avatar.dragon")),
        AvatarPreset(id: "unicorn",   illustrationName: "reward_rainbow",
                     localizedName: String(localized: "avatar.unicorn"))
    ]

    // MARK: - Domain: Theme presets

    struct ThemePreset: Identifiable {
        let id: String
        let localizedName: String
        let color: Color
    }

    static let themePresets: [ThemePreset] = [
        ThemePreset(id: "coral",   localizedName: String(localized: "theme.coral"),   color: ColorTokens.Brand.primary),
        ThemePreset(id: "blue",    localizedName: String(localized: "theme.blue"),    color: ColorTokens.Brand.sky),
        ThemePreset(id: "green",   localizedName: String(localized: "theme.green"),   color: ColorTokens.Brand.mint),
        ThemePreset(id: "yellow",  localizedName: String(localized: "theme.yellow"),  color: ColorTokens.Brand.butter),
        ThemePreset(id: "purple",  localizedName: String(localized: "theme.purple"),  color: ColorTokens.Brand.lilac)
    ]
}

// MARK: - ProfileEditorViewModel

@Observable
@MainActor
final class ProfileEditorViewModel {
    var childId: String = ""
    var name: String = ""
    var age: Int = 6
    var selectedAvatarId: String = "butterfly"
    var selectedThemeId: String = "coral"
    var targetSounds: [String] = []
    var isSaving: Bool = false
    var isSaved: Bool = false
    var errorMessage: String?
    var isLoading: Bool = false

    var hasChanges: Bool {
        !isSaving && !isLoading
    }

    var selectedThemeColor: Color {
        ProfileEditor.themePresets
            .first { $0.id == selectedThemeId }?.color ?? ColorTokens.Brand.primary
    }

    var selectedAvatarIllustration: String {
        ProfileEditor.avatarPresets
            .first { $0.id == selectedAvatarId }?.illustrationName ?? "mascot_lyalya_happy"
    }
}
