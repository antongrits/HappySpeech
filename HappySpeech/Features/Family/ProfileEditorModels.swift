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

    // D-14 v27: нейтральные аватар-иллюстрации (звери), без reward-бейджей.
    //   butterfly → mascot_lyalya_wave (Lyalya — бабочка)
    //   cat       → word_cat
    //   fox       → word_fox
    //   bear      → word_bear
    //   frog      → word_frog
    static let avatarPresets: [AvatarPreset] = [
        AvatarPreset(id: "butterfly", illustrationName: "mascot_lyalya_wave",
                     localizedName: String(localized: "avatar.butterfly")),
        AvatarPreset(id: "cat",       illustrationName: "word_cat",
                     localizedName: String(localized: "avatar.cat")),
        AvatarPreset(id: "fox",       illustrationName: "word_fox",
                     localizedName: String(localized: "avatar.fox")),
        AvatarPreset(id: "bear",      illustrationName: "word_bear",
                     localizedName: String(localized: "avatar.bear")),
        AvatarPreset(id: "frog",      illustrationName: "word_frog",
                     localizedName: String(localized: "avatar.frog"))
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
