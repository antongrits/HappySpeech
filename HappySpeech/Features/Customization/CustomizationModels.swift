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
        String(localized: String.LocalizationValue("customization.skin.\(rawValue)"))
    }

    public var illustrationName: String { "lyalya_\(rawValue)" }
}

// MARK: - LyalyaColorVariant

public enum LyalyaColorVariant: String, CaseIterable, Identifiable, Sendable {
    case warm
    case cool
    case nature

    public var id: String { rawValue }

    public var localizedName: String {
        String(localized: String.LocalizationValue("customization.color.\(rawValue)"))
    }

    public var gradientColors: (Color, Color) {
        switch self {
        case .warm:   return (Color(red: 1.0, green: 0.878, blue: 0.784), Color(red: 1.0, green: 0.816, blue: 0.69))
        case .cool:   return (Color(red: 0.784, green: 0.91, blue: 1.0), Color(red: 0.69, green: 0.847, blue: 0.973))
        case .nature: return (Color(red: 0.784, green: 0.941, blue: 0.847), Color(red: 0.69, green: 0.91, blue: 0.784))
        }
    }

    public var previewGradient: LinearGradient {
        let (from, to) = gradientColors
        return LinearGradient(colors: [from, to], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - LyalyaVoice

public enum LyalyaVoice: String, CaseIterable, Identifiable, Sendable {
    case classic
    case soft
    case cheerful

    public var id: String { rawValue }

    public var localizedName: String {
        String(localized: String.LocalizationValue("customization.voice.\(rawValue)"))
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

// MARK: - CustomizationViewModel

public struct CustomizationViewModel: Sendable {
    public var selectedSkin: LyalyaSkin
    public var selectedColor: LyalyaColorVariant
    public var selectedVoice: LyalyaVoice
    public var isSaving: Bool
    public var isUnchanged: Bool
    public var toastMessage: String?
    public var toastIsError: Bool
    public var playingVoice: LyalyaVoice?
    public var showCelebration: Bool

    public init(
        selectedSkin: LyalyaSkin = .classic,
        selectedColor: LyalyaColorVariant = .warm,
        selectedVoice: LyalyaVoice = .classic,
        isSaving: Bool = false,
        isUnchanged: Bool = true,
        toastMessage: String? = nil,
        toastIsError: Bool = false,
        playingVoice: LyalyaVoice? = nil,
        showCelebration: Bool = false
    ) {
        self.selectedSkin = selectedSkin
        self.selectedColor = selectedColor
        self.selectedVoice = selectedVoice
        self.isSaving = isSaving
        self.isUnchanged = isUnchanged
        self.toastMessage = toastMessage
        self.toastIsError = toastIsError
        self.playingVoice = playingVoice
        self.showCelebration = showCelebration
    }
}

// MARK: - Request types

public enum Customization {

    public struct LoadRequest {}

    public struct SaveRequest: Sendable {
        public let skin: LyalyaSkin
        public let color: LyalyaColorVariant
        public let voice: LyalyaVoice

        public init(skin: LyalyaSkin, color: LyalyaColorVariant, voice: LyalyaVoice) {
            self.skin = skin
            self.color = color
            self.voice = voice
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

    public struct PreviewVoiceRequest: Sendable {
        public let voice: LyalyaVoice
        public init(voice: LyalyaVoice) { self.voice = voice }
    }

    // MARK: - Response types

    public struct LoadResponse: Sendable {
        public let skin: LyalyaSkin
        public let color: LyalyaColorVariant
        public let voice: LyalyaVoice

        public init(skin: LyalyaSkin, color: LyalyaColorVariant, voice: LyalyaVoice) {
            self.skin = skin
            self.color = color
            self.voice = voice
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
