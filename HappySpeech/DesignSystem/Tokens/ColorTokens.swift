import SwiftUI
import UIKit

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
        /// Silver-tier reward — used for silverStar sticker. Light: cool grey, Dark: warm grey.
        public static let silver = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.62, green: 0.66, blue: 0.72, alpha: 1.0)
                : UIColor(red: 0.78, green: 0.82, blue: 0.86, alpha: 1.0)
        })
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
        /// Классический — белый в Light, тёплый кремовый off-white в Dark.
        public static let classic = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.94, green: 0.92, blue: 0.90, alpha: 1.0)
                : UIColor.white
        })
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
    /// Все цвета — **dynamic** через UITraitCollection: автоматически адаптируются к Light/Dark.
    public enum Overlay {
        /// Glass tint поверх dark/medium фона (например glass cards).
        /// Was `Color.white.opacity(0.10-0.15)`. Light: 0.18, Dark: 0.08.
        public static let glass = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.08)
                : UIColor.white.withAlphaComponent(0.18)
        })

        /// Highlight — тонкий border / accent поверх content (pressed states).
        /// Was `Color.white.opacity(0.20-0.30)`. Light: 0.30, Dark: 0.15.
        public static let highlight = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.15)
                : UIColor.white.withAlphaComponent(0.30)
        })

        /// Тонкий scrim (10-20% over bright).
        /// Was `Color.black.opacity(0.05-0.10)`. Light: 0.10, Dark: 0.30.
        public static let dimmer = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.30)
                : UIColor.black.withAlphaComponent(0.10)
        })

        /// Heavy scrim для sheets/modals.
        /// Was `Color.black.opacity(0.40-0.60)`. Light: 0.45, Dark: 0.65.
        public static let dimmerHeavy = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.65)
                : UIColor.black.withAlphaComponent(0.45)
        })

        /// Subtle separator. Was `Color.black.opacity(0.08-0.12)`. Использует `UIColor.separator`.
        public static let separator = Color(uiColor: UIColor.separator)

        /// Стандартный modal dimmer (alias на `dimmerHeavy` для backward compat).
        public static let scrim = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.65)
                : UIColor.black.withAlphaComponent(0.50)
        })

        /// Лёгкое затемнение (для карточек, hover-состояний).
        public static let dimmerLight = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.40)
                : UIColor.black.withAlphaComponent(0.25)
        })

        /// Стеклянный тёмный тинт (для тёмных glass-эффектов поверх светлых картинок).
        public static let glassDark = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.25)
                : UIColor.black.withAlphaComponent(0.15)
        })

        /// Мягкая тень (для card depth, ~0.06-0.10).
        public static let shadow = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.30)
                : UIColor.black.withAlphaComponent(0.08)
        })

        /// Средняя тень (для elevated cards / modals, ~0.15-0.25).
        public static let shadowMedium = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.45)
                : UIColor.black.withAlphaComponent(0.18)
        })

        /// Текст / иконка поверх насыщенных цветных backgrounds (CTA, Brand.primary capsule).
        /// Семантически = static white в обеих темах: на coloured fill контраст всегда нужен максимальный.
        /// Используй вместо `Color.white` для всех "text on coloured button" кейсов.
        public static let onAccent = Color.white

        /// Тёмный текст / иконка поверх светлых hero-фонов (для будущих use-case).
        /// Семантически = static black; alias для completeness API.
        public static let onLight = Color.black
    }

    // MARK: - Session Colors

    /// Used in SessionShell progress indicators and fatigue-detection UI.
    public enum Session {
        public static let progressBar        = Color("SessionProgressBar")
        public static let progressBackground = Color("SessionProgressBackground")
        public static let fatigueWarning     = Color("SessionFatigueWarning")
    }

    // MARK: - Customization Theme Palette

    /// Палитра 16 пастельных пар-градиентов для карточек кастомизации (наряды и скины).
    /// Каждая пара состоит из верхнего (`*From`) и нижнего (`*To`) цвета — используется в
    /// `LinearGradient` плейсхолдеров иллюстраций, когда `Image(named:)` отсутствует.
    /// Все цвета подобраны как мягкие, low-saturation тона, безопасные для детских экранов.
    public enum Theme {

        // MARK: Outfit — Everyday (повседневный наряд) — небесно-голубой
        public static let everydayFrom = Color(red: 0.72, green: 0.87, blue: 0.98)
        public static let everydayTo   = Color(red: 0.50, green: 0.72, blue: 0.92)

        // MARK: Outfit — Beach (пляж) — солнечно-жёлтый → оранжевый
        public static let beachFrom    = Color(red: 0.98, green: 0.92, blue: 0.60)
        public static let beachTo      = Color(red: 0.98, green: 0.75, blue: 0.30)

        // MARK: Outfit — Winter (зима) — морозно-голубой
        public static let winterFrom   = Color(red: 0.82, green: 0.93, blue: 0.98)
        public static let winterTo     = Color(red: 0.60, green: 0.80, blue: 0.95)

        // MARK: Outfit — School (школа) — зелёная олива
        public static let schoolFrom   = Color(red: 0.78, green: 0.87, blue: 0.68)
        public static let schoolTo     = Color(red: 0.55, green: 0.75, blue: 0.45)

        // MARK: Outfit — Birthday (день рождения) — розовый
        public static let birthdayFrom = Color(red: 0.98, green: 0.75, blue: 0.85)
        public static let birthdayTo   = Color(red: 0.95, green: 0.55, blue: 0.70)

        // MARK: Outfit — Space (космос) — фиолетово-синий
        public static let spaceFrom    = Color(red: 0.50, green: 0.55, blue: 0.80)
        public static let spaceTo      = Color(red: 0.20, green: 0.25, blue: 0.55)

        // MARK: Skin — Princess (принцесса) — нежно-розовый
        public static let princessFrom = Color(red: 1.00, green: 0.75, blue: 0.85)
        public static let princessTo   = Color(red: 0.95, green: 0.55, blue: 0.70)

        // MARK: Skin — Scientist (учёный) — мятно-зелёный
        public static let scientistFrom = Color(red: 0.85, green: 0.95, blue: 0.85)
        public static let scientistTo   = Color(red: 0.65, green: 0.88, blue: 0.65)

        // MARK: Skin — Athlete (спортсмен) — солнечно-оранжевый
        public static let athleteFrom  = Color(red: 1.00, green: 0.88, blue: 0.65)
        public static let athleteTo    = Color(red: 0.95, green: 0.70, blue: 0.35)

        // MARK: Skin — Artist (художник) — лавандовый
        public static let artistFrom   = Color(red: 0.90, green: 0.75, blue: 0.95)
        public static let artistTo     = Color(red: 0.75, green: 0.55, blue: 0.90)

        // MARK: Background — Bedroom (спальня) — пурпурно-сиреневый
        public static let bedroomFrom  = Color(red: 0.90, green: 0.82, blue: 0.95)
        public static let bedroomTo    = Color(red: 0.75, green: 0.65, blue: 0.88)

        // MARK: Background — Garden (сад) — травянисто-зелёный
        public static let gardenFrom   = Color(red: 0.80, green: 0.95, blue: 0.72)
        public static let gardenTo     = Color(red: 0.55, green: 0.85, blue: 0.55)

        // MARK: Background — School (школа) — тёплый жёлтый
        public static let schoolBgFrom = Color(red: 0.98, green: 0.93, blue: 0.70)
        public static let schoolBgTo   = Color(red: 0.95, green: 0.82, blue: 0.45)

        // MARK: Background — Ocean (океан) — морская волна
        public static let oceanFrom    = Color(red: 0.65, green: 0.88, blue: 0.98)
        public static let oceanTo      = Color(red: 0.35, green: 0.65, blue: 0.90)

        // MARK: Background — Forest (лес) — лесной зелёный
        public static let forestFrom   = Color(red: 0.60, green: 0.82, blue: 0.62)
        public static let forestTo     = Color(red: 0.30, green: 0.60, blue: 0.35)

        // MARK: Color Variant — Warm (тёплый) — кораллово-абрикосовый
        public static let warmFrom     = Color(red: 1.00, green: 0.878, blue: 0.784)
        public static let warmTo       = Color(red: 1.00, green: 0.816, blue: 0.69)

        // MARK: Color Variant — Cool (прохладный) — голубой
        public static let coolFrom     = Color(red: 0.784, green: 0.91, blue: 1.00)
        public static let coolTo       = Color(red: 0.69, green: 0.847, blue: 0.973)

        // MARK: Color Variant — Nature (природный) — зелёный
        public static let natureFrom   = Color(red: 0.784, green: 0.941, blue: 0.847)
        public static let natureTo     = Color(red: 0.69, green: 0.91, blue: 0.784)

        // MARK: Hair Color — preview swatches
        public static let hairGolden   = Color(red: 0.99, green: 0.88, blue: 0.50)
        public static let hairChestnut = Color(red: 0.56, green: 0.32, blue: 0.18)
        public static let hairBlack    = Color(red: 0.15, green: 0.13, blue: 0.14)
        public static let hairPink     = Color(red: 0.99, green: 0.63, blue: 0.78)
        public static let hairCyan     = Color(red: 0.40, green: 0.84, blue: 0.88)

        // MARK: Eye Color — preview swatches
        public static let eyeBlue      = Color(red: 0.40, green: 0.70, blue: 0.95)
        public static let eyeGreen     = Color(red: 0.37, green: 0.76, blue: 0.43)
        public static let eyeBrown     = Color(red: 0.54, green: 0.32, blue: 0.12)

        // MARK: Skin Tone — preview swatches
        public static let toneLight    = Color(red: 0.98, green: 0.87, blue: 0.79)
        public static let toneMedium   = Color(red: 0.83, green: 0.63, blue: 0.49)
        public static let toneDark     = Color(red: 0.48, green: 0.31, blue: 0.20)

        // MARK: Body color (UIColor variants for RealityKit SimpleMaterial)
        public static let bodyWarmUI   = UIColor(red: 0.788, green: 0.659, blue: 0.941, alpha: 1)
        public static let bodyCoolUI   = UIColor(red: 0.612, green: 0.780, blue: 0.941, alpha: 1)
        public static let bodyNatureUI = UIColor(red: 0.612, green: 0.851, blue: 0.710, alpha: 1)
    }

    // MARK: - Confetti Palette

    /// Палитра конфетти-частиц для `ConfettiEmitterView`.
    /// Три стиля: celebration (тёплые цвета), perfect (золото), achievement (бренд-цвета).
    public enum Confetti {

        // MARK: Celebration — тёплая радостная палитра
        /// Кораллово-красный (#FF6B6B)
        public static let coral     = Color(red: 1.00, green: 0.42, blue: 0.42)
        /// Солнечно-жёлтый (#FFD93D)
        public static let yellow    = Color(red: 1.00, green: 0.85, blue: 0.24)
        /// Оранжевый (#FF9E4F)
        public static let orange    = Color(red: 1.00, green: 0.62, blue: 0.31)
        /// Лиловый (#C77DFF)
        public static let lilac     = Color(red: 0.78, green: 0.49, blue: 1.00)
        /// Hot pink (#FF69B4)
        public static let hotPink   = Color(red: 1.00, green: 0.41, blue: 0.71)
        /// Light salmon (#FFA07A)
        public static let salmon    = Color(red: 1.00, green: 0.63, blue: 0.48)

        // MARK: Perfect — золотая палитра
        /// Чистое золото (#FFD700)
        public static let gold      = Color(red: 1.00, green: 0.84, blue: 0.00)
        /// Кремово-жёлтый (#FFF176)
        public static let cream     = Color(red: 1.00, green: 0.95, blue: 0.46)
        /// Янтарный (#FFCA28)
        public static let amber     = Color(red: 1.00, green: 0.79, blue: 0.16)
        /// Светло-янтарный (#FFE082)
        public static let amberSoft = Color(red: 1.00, green: 0.88, blue: 0.51)
        /// Тёмно-оранжевый (#FF8F00)
        public static let darkAmber = Color(red: 1.00, green: 0.56, blue: 0.00)

        // MARK: Achievement — бренд-палитра
        /// Голубой (#4D96FF)
        public static let blue      = Color(red: 0.30, green: 0.59, blue: 1.00)
        /// Травянистый (#6BCB77)
        public static let green     = Color(red: 0.42, green: 0.80, blue: 0.47)

        // MARK: Готовые палитры (для удобного pickColor)
        public static let celebrationPalette: [Color] = [coral, yellow, orange, lilac, hotPink, salmon]
        public static let perfectPalette: [Color]     = [gold, cream, amber, amberSoft, darkAmber]
        public static let achievementPalette: [Color] = [blue, green, lilac, coral, yellow, orange]
    }

    // MARK: - Celebration Palette

    /// Цвета для `CelebrationOverlayView` и preview-фонов празднования.
    public enum Celebration {
        /// Цвет CTA-кнопки «Продолжить» — голубой (#4D96FF).
        public static let primaryButton  = Color(red: 0.30, green: 0.59, blue: 1.00)
        /// Цвет звезды (соответствует Confetti.yellow #FFD93D).
        public static let star           = Color(red: 1.00, green: 0.85, blue: 0.24)
        /// Глубокий пурпурный фон preview (3 stars) — #2C1A6B.
        public static let backdropDeep   = Color(red: 0.173, green: 0.102, blue: 0.420)
        /// Тёмно-зелёный фон preview (1 star) — #1A3A2B.
        public static let backdropForest = Color(red: 0.102, green: 0.227, blue: 0.169)
        /// Глубокий индиго фон preview (achievement) — #0A1A3B.
        public static let backdropIndigo = Color(red: 0.039, green: 0.102, blue: 0.231)
        /// Глубокий зелёный фон preview (perfect) — #1A2A1A.
        public static let backdropMoss   = Color(red: 0.102, green: 0.165, blue: 0.102)
        /// Глубокий пурпурный фон preview (celebration) — #1A0A3B.
        public static let backdropNight  = Color(red: 0.102, green: 0.039, blue: 0.231)
    }

    // MARK: - Badge Palette

    /// Палитра наград для пьедестала и leaderboard (`PronunciationLeaderboardView`).
    /// Gold / Silver используют существующие brand-tokens; Bronze — отдельный warm-orange.
    public enum Badge {
        /// 1-е место — золото (alias на `Brand.gold`).
        public static let gold   = ColorTokens.Brand.gold
        /// 2-е место — серебро (alias на `Brand.silver`).
        public static let silver = ColorTokens.Brand.silver
        /// 3-е место — бронза (warm orange-brown).
        public static let bronze = Color(red: 0.80, green: 0.50, blue: 0.20)
    }

    // MARK: - Story Backgrounds

    /// Палитра градиентов для 20 анимированных историй (`StoryLibrary`).
    ///
    /// Каждая константа — пара hex-строк `[top, bottom]`, потребляемая
    /// `AnimatedStoryPlayerView` через `Color(hex:)`. Тип `[String]` сохранён
    /// для совместимости с `AnimatedStory.backgroundGradient: [String]` (Codable).
    ///
    /// Истории сгруппированы по фонетическим семействам:
    /// шипящие → свистящие → соноры Р → соноры Л → заднеязычные → бонусные.
    public enum Story {
        // MARK: Шипящие
        /// «Шустрая шишка» — Ш — light-salmon → tomato (тёплый осенний лес).
        public static let shustrayShishka: [String]   = ["#FFA07A", "#FF6347"]
        /// «Жучок в луже» — Ж — sky-blue → royal-blue (дождливая лужа).
        public static let zhukovVLuzhe: [String]      = ["#87CEEB", "#4169E1"]
        /// «Щенок и щётка» — Щ — gold → orange (тёплая комната).
        public static let shchenokIShchetka: [String] = ["#FFD700", "#FFA500"]
        /// «Чайник-чудак» — Ч — coral → indian-red (горячий чай).
        public static let chaynikChudak: [String]     = ["#FF8C69", "#CD5C5C"]

        // MARK: Свистящие
        /// «Синяя собака» — С — sky-blue → dodger-blue (синий сад).
        public static let sinyayaSobaka: [String]     = ["#87CEEB", "#1E90FF"]
        /// «Зайчик на зарядке» — З — light-green → forest-green (зелёная полянка).
        public static let zaychikNaZaryadke: [String] = ["#90EE90", "#228B22"]
        /// «Цыплёнок Цезарь» — Ц — gold → dark-orange (солнечный птичий двор).
        public static let tsyplyonokTsezar: [String]  = ["#FFD700", "#FF8C00"]

        // MARK: Соноры Р
        /// «Рыбка Рита» — Р — dark-turquoise → light-sea-green (морская глубина).
        public static let rybkaRita: [String]         = ["#00CED1", "#20B2AA"]
        /// «Ракета Рыжик» — Р — midnight-blue → indigo (звёздное небо).
        public static let raketaRyzhik: [String]      = ["#191970", "#4B0082"]

        // MARK: Соноры Л
        /// «Лиса и лягушка» — Л — lawn-green → forest-green (лесная поляна).
        public static let lisaIlyagushka: [String]    = ["#7CFC00", "#228B22"]
        /// «Луна Лена» — Л — midnight-slate → purple-mauve (ночное небо).
        public static let lunaIlena: [String]         = ["#2C3E50", "#8E44AD"]

        // MARK: Заднеязычные
        /// «Кот Кузьма» — К — sunset-coral → warm-red (домашний уют).
        public static let kotKuzma: [String]          = ["#FF9966", "#FF5E62"]
        /// «Гусь Гриша» — Г — meadow-green → light-green (зелёный луг).
        public static let gusGrisha: [String]         = ["#56AB2F", "#A8E063"]
        /// «Хомяк Храбрый» — Х — sand-tan → sienna (норка хомяка).
        public static let khomyakKhrabry: [String]    = ["#D4A056", "#A0522D"]

        // MARK: Бонусные (смешанные / грамматика)
        /// «Мишка и мишутка» — Ш — saddle-brown → chocolate (медвежий шалаш).
        public static let mishkaIMishutka: [String]   = ["#8B4513", "#D2691E"]
        /// «Пингвин Пётр» — П — deep-sky-blue → light-sky-blue (ледяной океан).
        public static let pingvinPyotr: [String]      = ["#00BFFF", "#87CEFA"]
        /// «Ёжик Егор» — Е — dark-olive → dark-sea-green (хвойный лес).
        public static let yozhikEgor: [String]        = ["#556B2F", "#8FBC8F"]
        /// «Бабочка Белла» — Б — hot-pink → orchid (цветочный сад).
        public static let babochkaBella: [String]     = ["#FF69B4", "#DA70D6"]
        /// «Дракон Дима» — Д — fire-brick → orange-red (драконий огонь).
        public static let drakonDima: [String]        = ["#B22222", "#FF4500"]
        /// «Тигр Тимур» — Т — dark-orange → orange-red (тропический закат).
        public static let tigrTimur: [String]         = ["#FF8C00", "#FF4500"]
    }

    // MARK: - Mascot Aura

    /// Цвета ауры маскота «Ляля» (`MoodAuraView` в HSMascotView).
    /// Каждое настроение имеет уникальный halo-цвет. Значения совпадают
    /// с теми, что использовались до миграции через `Color(hex:)`.
    public enum Mood {
        /// Idle — светло-голубой (#B0C4FF).
        public static let idle        = Color(red: 0.69, green: 0.77, blue: 1.00)
        /// Happy / waving — золотой (#FFD700).
        public static let happy       = Color(red: 1.00, green: 0.84, blue: 0.00)
        /// Celebrating / explaining / pointing — тёплый коралл (#FF9E70).
        public static let celebrating = Color(red: 1.00, green: 0.62, blue: 0.44)
        /// Thinking — лавандовый (#C3B1E1).
        public static let thinking    = Color(red: 0.76, green: 0.69, blue: 0.88)
        /// Sad — мягкий голубой (#A8C8FF).
        public static let sad         = Color(red: 0.66, green: 0.78, blue: 1.00)
        /// Encouraging — лимонно-зелёный (#90EE90).
        public static let encouraging = Color(red: 0.56, green: 0.93, blue: 0.56)
        /// Singing — нежно-розовый (#FFB6D9).
        public static let singing     = Color(red: 1.00, green: 0.71, blue: 0.85)
    }

    // MARK: - Sticker

    /// Цвета иконок стикеров в `HSSticker`.
    public enum Sticker {
        /// Иконка золотой звезды / короны / трофея (#E5A000).
        public static let goldTint   = Color(red: 0.90, green: 0.63, blue: 0.00)
        /// Иконка серебряной звезды (#8899AA).
        public static let silverTint = Color(red: 0.53, green: 0.60, blue: 0.67)
    }

    // MARK: - Banner

    /// Цвета баннеров уведомлений (`HSOfflineBanner` и др.).
    public enum Banner {
        /// Фон offline-плашки — тёплый красно-оранжевый (#E85D35).
        public static let offlineBg = Color(red: 0.91, green: 0.36, blue: 0.21)
    }

    // MARK: - Wood / 3D Materials

    /// 3D-материалы для RealityKit сцен. `UI`-суффикс означает статичный
    /// `UIColor` для `SimpleMaterial`.
    public enum Wood {
        /// Полка шкафа наград (`FamilyAwardsCabinet`) — тёплый коричневый.
        public static let shelfUI = UIColor(red: 0.42, green: 0.30, blue: 0.20, alpha: 1.0)
    }

    // MARK: - Mascot Materials (RealityKit)

    /// Дополнительные оттенки 3D-маскота (`LyalyaRealityKitView`).
    public enum Mascot {
        /// Базовый розоватый тон щёк маскота (idle), alpha = 0.3.
        public static let cheekIdleUI = UIColor(red: 0.95, green: 0.82, blue: 0.82, alpha: 0.3)
        /// Цвет щёк маскота при celebrating с заданной интенсивностью настроения.
        /// - Parameter mood: 0…1 — степень счастья (контролирует alpha).
        public static func cheekActiveUI(mood: Float) -> UIColor {
            UIColor(red: 1.0, green: 0.65, blue: 0.65, alpha: min(1.0, 0.5 + Double(mood) * 0.5))
        }
    }

    // MARK: - Award (FamilyAwardsCabinet tiers)

    /// Платиновый и расширенный серебряный тон для `FamilyAwardsCabinet` наград.
    /// Gold уже доступен через `ColorTokens.Brand.gold`, Bronze — через `ColorTokens.Badge.bronze`.
    public enum Award {
        /// Платиновый — холодный светло-серый (#D9DBEB).
        public static let platinum = Color(red: 0.85, green: 0.86, blue: 0.92)
        /// Серебряный — нейтральный для AwardTier (отдельно от `Badge.silver`,
        /// который адаптивен через UITraitCollection).
        public static let silver = Color(red: 0.79, green: 0.81, blue: 0.84)
    }

    // MARK: - Lyalya Scene (SceneKit / SwiftUI)

    /// Цвета сцены SceneKit плейсхолдера Ляли (`LyalyaSceneView`).
    /// Используются как `UIColor` для SCNMaterial и как SwiftUI `Color` для preview-фонов.
    public enum LyalyaScene {
        /// Ambient light — тёплый сиренево-белый. (UIColor — статичный для SceneKit материала.)
        public static let ambientUI  = UIColor(red: 0.95, green: 0.93, blue: 1.00, alpha: 1)
        /// Цвет тела (pastel lilac). (UIColor — статичный для SceneKit материала.)
        public static let bodyUI     = UIColor(red: 0.76, green: 0.63, blue: 0.95, alpha: 1)
        /// Цвет зрачков (тёмно-фиолетовый). (UIColor — статичный для SceneKit материала.)
        public static let pupilUI    = UIColor(red: 0.15, green: 0.10, blue: 0.25, alpha: 1)
        /// Preview-фон idle — светло-сиреневый (Light: #F3EEFF, Dark: #2A1F3D — глубокий ночной фиолет).
        public static let backdropIdle = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.165, green: 0.122, blue: 0.239, alpha: 1.0)
                : UIColor(red: 0.953, green: 0.933, blue: 1.000, alpha: 1.0)
        })
        /// Preview-фон celebrating — тёплый кремово-жёлтый (Light: #FFF8E0, Dark: #3D3520 — тёплый ночной янтарь).
        public static let backdropCelebrate = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.239, green: 0.208, blue: 0.125, alpha: 1.0)
                : UIColor(red: 1.000, green: 0.973, blue: 0.878, alpha: 1.0)
        })
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
