import SwiftUI

// MARK: - ColorTokens

/// Семантическая цветовая система HappySpeech — единственный источник цветов в фичах.
///
/// `ColorTokens` содержит три пространства имён (контура) + Brand-палитру.
/// Все цвета ссылаются на `Color(Asset Catalog name)` и автоматически
/// адаптируются к Light / Dark теме через именованные ассеты.
///
/// > Important: Никогда не используй hex-литералы в фичах.
/// > Только `ColorTokens.*` — это требование DoD и SwiftLint-правило.
///
/// ### Пространства имён
/// - `ColorTokens.Brand` — брендовые акценты (coral, mint, lilac, gold...)
/// - `ColorTokens.Kid` — тёплая кремовая палитра детского контура
/// - `ColorTokens.Parent` — нейтральная холодная палитра родительского контура
/// - `ColorTokens.Spec` — аналитическая палитра специалистского контура
///
/// ## Пример
/// ```swift
/// // CTA кнопка
/// Text("Начать").foregroundStyle(ColorTokens.Brand.primary)
///
/// // Фон детского экрана
/// Color(ColorTokens.Kid.bg)
///
/// // Акцент специалиста
/// Rectangle().fill(ColorTokens.Spec.accent)
/// ```
///
/// ## See Also
/// - ``TypographyTokens``
/// - ``SpacingTokens``
/// - ``HSButton``
public enum ColorTokens {

    // MARK: - Brand

    public enum Brand {
        /// Coral-apricot — mascot wings, main CTA
        public static let primary    = Color("BrandPrimary")
        public static let primaryHi  = Color("BrandPrimaryHi")
        public static let primaryLo  = Color("BrandPrimaryLo")
        /// Success, progress
        public static let mint       = Color("BrandMint")
        /// Info, links
        public static let sky        = Color("BrandSky")
        /// Magic / AR accent
        public static let lilac      = Color("BrandLilac")
        /// Rewards, streaks
        public static let butter     = Color("BrandButter")
        /// Warmth on cards
        public static let rose       = Color("BrandRose")
        /// Achievement gold — rewards, home-task highlight
        public static let gold       = Color("BrandGold")
    }

    // MARK: - Kid Circuit (warm cream world)

    public enum Kid {
        public static let bg         = Color("KidBg")
        public static let bgDeep     = Color("KidBgDeep")
        public static let bgSoft     = Color("KidBgSoft")
        public static let bgSofter   = Color("KidBgSofter")
        public static let surface    = Color("KidSurface")
        public static let surfaceAlt = Color("KidSurfaceAlt")
        public static let ink        = Color("KidInk")
        public static let inkMuted   = Color("KidInkMuted")
        public static let inkSoft    = Color("KidInkSoft")
        public static let line       = Color("KidLine")
    }

    // MARK: - Parent Circuit (cool, neutral, focused)

    public enum Parent {
        public static let bg         = Color("ParentBg")
        public static let bgDeep     = Color("ParentBgDeep")
        public static let surface    = Color("ParentSurface")
        public static let ink        = Color("ParentInk")
        public static let inkMuted   = Color("ParentInkMuted")
        public static let inkSoft    = Color("ParentInkSoft")
        public static let line       = Color("ParentLine")
        public static let lineStrong = Color("ParentLineStrong")
        public static let accent     = Color("ParentAccent")
    }

    // MARK: - Specialist Circuit (neutral cool, data-dense)

    public enum Spec {
        public static let bg         = Color("SpecBg")
        public static let surface    = Color("SpecSurface")
        public static let panel      = Color("SpecPanel")
        public static let ink        = Color("SpecInk")
        public static let inkMuted   = Color("SpecInkMuted")
        public static let line       = Color("SpecLine")
        public static let grid       = Color("SpecGrid")
        public static let accent     = Color("SpecAccent")
        public static let waveform   = Color("SpecWaveform")
        public static let target     = Color("SpecTarget")
    }

    // MARK: - Semantic

    public enum Semantic {
        public static let success    = Color("SemSuccess")
        public static let successBg  = Color("SemSuccessBg")
        public static let error      = Color("SemError")
        public static let errorBg    = Color("SemErrorBg")
        public static let warning    = Color("SemWarning")
        public static let warningBg  = Color("SemWarningBg")
        public static let info       = Color("SemInfo")
        public static let infoBg     = Color("SemInfoBg")
    }

    // MARK: - Sound Family Palettes

    public enum SoundFamilyColors {
        public enum Whistling {
            public static let hue  = Color("SoundWhistlingHue")
            public static let bg   = Color("SoundWhistlingBg")
        }
        public enum Hissing {
            public static let hue  = Color("SoundHissingHue")
            public static let bg   = Color("SoundHissingBg")
        }
        public enum Sonorant {
            public static let hue  = Color("SoundSonorantHue")
            public static let bg   = Color("SoundSonorantBg")
        }
        public enum Velar {
            public static let hue  = Color("SoundVelarHue")
            public static let bg   = Color("SoundVelarBg")
        }
        public enum Vowels {
            public static let hue  = Color("SoundVowelsHue")
            public static let bg   = Color("SoundVowelsBg")
        }
    }

    // MARK: - Game Colors

    /// Each game template has a dedicated accent colour shown on its tile/header.
    public enum Games {
        /// ListenAndChoose — teal
        public static let listenAndChoose  = Color("GameListenAndChoose")
        /// RepeatAfterModel — coral
        public static let repeatAfterModel = Color("GameRepeatAfterModel")
        /// Memory — lilac
        public static let memory           = Color("GameMemory")
        /// Breathing exercises — soft green
        public static let breathing        = Color("GameBreathing")
        /// Rhythm games — gold
        public static let rhythm           = Color("GameRhythm")
        /// Sorting — orange
        public static let sorting          = Color("GameSorting")
        /// PuzzleReveal — blue-teal
        public static let puzzle           = Color("GamePuzzle")
        /// AR activities — purple
        public static let arGames          = Color("GameAR")
    }

    // MARK: - Feedback Colors

    /// Used in game feedback overlays, tile borders, and result screens.
    public enum Feedback {
        /// Correct answer — green
        public static let correct   = Color("FeedbackCorrect")
        /// Incorrect answer — soft coral (never harsh red — child-friendly)
        public static let incorrect = Color("FeedbackIncorrect")
        /// Neutral / no answer yet — light grey-blue
        public static let neutral   = Color("FeedbackNeutral")
        /// Excellent score (>90%) — gold
        public static let excellent = Color("FeedbackExcellent")
    }

    // MARK: - Skin Tint Colors

    /// Цветовые варианты тела маскота «Ляля».
    /// Используются в `LyalyaMascotView` для skinTintColor.
    public enum Skin {
        /// Тёплый оттенок — слегка розоватый
        public static let warm    = Color(red: 1.0, green: 0.95, blue: 0.95)
        /// Прохладный оттенок — слегка голубоватый
        public static let cool    = Color(red: 0.95, green: 0.97, blue: 1.0)
        /// Природный оттенок — слегка зелёный
        public static let nature  = Color(red: 0.95, green: 1.0,  blue: 0.95)
        /// Классический — белый
        public static let classic = Color.white
    }

    // MARK: - Session Colors

    /// Used in SessionShell progress indicators and fatigue-detection UI.
    public enum Session {
        public static let progressBar        = Color("SessionProgressBar")
        public static let progressBackground = Color("SessionProgressBackground")
        public static let fatigueWarning     = Color("SessionFatigueWarning")
    }
}

// MARK: - Convenience Extension for SoundFamily

public extension ColorTokens.SoundFamilyColors {
    static func hue(for family: SoundFamily) -> Color {
        switch family {
        case .whistling: return Whistling.hue
        case .hissing:   return Hissing.hue
        case .sonorant:  return Sonorant.hue
        case .velar:     return Velar.hue
        }
    }

    static func background(for family: SoundFamily) -> Color {
        switch family {
        case .whistling: return Whistling.bg
        case .hissing:   return Hissing.bg
        case .sonorant:  return Sonorant.bg
        case .velar:     return Velar.bg
        }
    }
}
