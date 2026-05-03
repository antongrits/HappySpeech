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
    /// Все цвета адаптируются к Light/Dark теме через именованные ассеты.
    public enum Skin {
        /// Тёплый оттенок — слегка розоватый (Light: rgb(255,242,242), Dark: rgb(255,230,230))
        public static let warm    = Color("SkinWarm")
        /// Прохладный оттенок — слегка голубоватый (Light: rgb(242,247,255), Dark: rgb(230,237,255))
        public static let cool    = Color("SkinCool")
        /// Природный оттенок — слегка зелёный (Light: rgb(242,255,242), Dark: rgb(230,255,230))
        public static let nature  = Color("SkinNature")
        /// Классический — белый
        public static let classic = Color.white
    }

    // MARK: - Nature Colors

    /// Природные цвета для игровых иллюстраций (дерево, трава, ствол).
    /// Адаптируются к Light/Dark теме через именованные ассеты.
    public enum Nature {
        /// Ствол дерева — тёплый коричневый, dark-mode-safe.
        /// Light: rgb(139,90,43), Dark: rgb(180,130,70).
        /// Используется в BreathingTreeView.
        public static let treeTrunk = Color("NatureTreeTrunk")
    }

    // MARK: - Overlay Colors

    /// Семантические оверлейные цвета для модальных затемнений, glass-эффектов и хайлайтов.
    ///
    /// Использование именованных токенов вместо `Color.black.opacity(0.45)` обеспечивает
    /// единый визуальный язык на всех экранах и упрощает тонкую настройку.
    public enum Overlay {
        /// Стандартный modal dimmer (для sheet, fullscreen cover).
        public static let scrim = Color.black.opacity(0.5)
        /// Лёгкое затемнение (для карточек, hover-состояний).
        public static let dimmerLight = Color.black.opacity(0.25)
        /// Стандартное затемнение (для modal, hero overlay).
        public static let dimmer = Color.black.opacity(0.45)
        /// Тёмное затемнение (для video player, fullscreen).
        public static let dimmerHeavy = Color.black.opacity(0.65)
        /// Стеклянный белый тинт (light glass tint).
        public static let glass = Color.white.opacity(0.15)
        /// Стеклянный тёмный тинт (dark glass tint).
        public static let glassDark = Color.black.opacity(0.15)
        /// Хайлайт (для pressed-состояний, активных элементов).
        public static let highlight = Color.white.opacity(0.25)
        /// Мягкая тень (для card depth).
        public static let shadow = Color.black.opacity(0.08)
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
