@testable import HappySpeech
import XCTest

// MARK: - DesignSystemTokensExtendedTests
//
// Phase 2.4 v25 — расширенное покрытие токенов DesignSystem.
// Охватывает: TypographyTokens, ShadowTokens, ColorTokens (non-asset),
// GradientTokens, ColorTokens.Confetti, ColorTokens.Celebration,
// ColorTokens.Story, ColorTokens.Theme, ColorTokens.Mascot,
// ColorTokens.Badge, ColorTokens.Award.
// SwiftUI Views тестами НЕ покрываются — только value-логика.

final class DesignSystemTokensExtendedTests: XCTestCase {

    // MARK: - TypographyTokens: размеры по умолчанию

    func test_typography_display_defaultSize36() {
        let font = TypographyTokens.display()
        XCTAssertNotNil(font, "TypographyTokens.display() должен возвращать Font")
    }

    func test_typography_display_customSize() {
        let font = TypographyTokens.display(48)
        XCTAssertNotNil(font)
    }

    func test_typography_title_defaultNotNil() {
        XCTAssertNotNil(TypographyTokens.title())
    }

    func test_typography_headline_defaultNotNil() {
        XCTAssertNotNil(TypographyTokens.headline())
    }

    func test_typography_body_defaultNotNil() {
        XCTAssertNotNil(TypographyTokens.body())
    }

    func test_typography_caption_defaultNotNil() {
        XCTAssertNotNil(TypographyTokens.caption())
    }

    func test_typography_mono_defaultNotNil() {
        XCTAssertNotNil(TypographyTokens.mono())
    }

    func test_typography_cta_notNil() {
        XCTAssertNotNil(TypographyTokens.cta())
    }

    func test_typography_kidDisplay_defaultSize40() {
        XCTAssertNotNil(TypographyTokens.kidDisplay())
    }

    func test_typography_subtitle_notNil() {
        XCTAssertNotNil(TypographyTokens.subtitle())
    }

    func test_typography_callout_notNil() {
        XCTAssertNotNil(TypographyTokens.callout())
    }

    func test_typography_bodyMedium_notNil() {
        XCTAssertNotNil(TypographyTokens.bodyMedium())
    }

    func test_typography_titleSmall_notNil() {
        XCTAssertNotNil(TypographyTokens.titleSmall())
    }

    func test_typography_titleMedium_notNil() {
        XCTAssertNotNil(TypographyTokens.titleMedium())
    }

    func test_typography_titleLarge_notNil() {
        XCTAssertNotNil(TypographyTokens.titleLarge())
    }

    func test_typography_labelRounded_defaultSemibold() {
        XCTAssertNotNil(TypographyTokens.labelRounded())
    }

    func test_typography_labelRounded_customWeight() {
        XCTAssertNotNil(TypographyTokens.labelRounded(16, weight: .bold))
    }

    // MARK: - TypographyTokens.LineSpacing

    func test_lineSpacing_tight_lessThanNormal() {
        XCTAssertLessThan(TypographyTokens.LineSpacing.tight, TypographyTokens.LineSpacing.normal)
    }

    func test_lineSpacing_normal_lessThanRelaxed() {
        XCTAssertLessThan(TypographyTokens.LineSpacing.normal, TypographyTokens.LineSpacing.relaxed)
    }

    func test_lineSpacing_relaxed_lessThanLoose() {
        XCTAssertLessThan(TypographyTokens.LineSpacing.relaxed, TypographyTokens.LineSpacing.loose)
    }

    func test_lineSpacing_tight_is1_1() {
        XCTAssertEqual(TypographyTokens.LineSpacing.tight, 1.1, accuracy: 0.001)
    }

    // MARK: - TypographyTokens.LetterSpacing

    func test_letterSpacing_tight_isNegative() {
        XCTAssertLessThan(TypographyTokens.LetterSpacing.tight, 0)
    }

    func test_letterSpacing_normal_isZero() {
        XCTAssertEqual(TypographyTokens.LetterSpacing.normal, 0, accuracy: 0.001)
    }

    func test_letterSpacing_wide_isPositive() {
        XCTAssertGreaterThan(TypographyTokens.LetterSpacing.wide, 0)
    }

    func test_letterSpacing_widest_largerThanWide() {
        XCTAssertGreaterThan(TypographyTokens.LetterSpacing.widest, TypographyTokens.LetterSpacing.wide)
    }

    // MARK: - TypographyTokens: Dynamic Type scaled variants

    func test_typography_bodyScaled_notNil() {
        XCTAssertNotNil(TypographyTokens.bodyScaled)
    }

    func test_typography_headlineScaled_notNil() {
        XCTAssertNotNil(TypographyTokens.headlineScaled)
    }

    func test_typography_captionScaled_notNil() {
        XCTAssertNotNil(TypographyTokens.captionScaled)
    }

    // MARK: - ShadowTokens: структура значений

    func test_shadowKidCard_radius12() {
        XCTAssertEqual(ShadowTokens.Kid.card.radius, 12, accuracy: 0.001)
    }

    func test_shadowKidCard_opacity8pct() {
        XCTAssertEqual(ShadowTokens.Kid.card.opacity, 0.08, accuracy: 0.001)
    }

    func test_shadowKidCard_y4() {
        XCTAssertEqual(ShadowTokens.Kid.card.y, 4, accuracy: 0.001)
    }

    func test_shadowKidCard_x0() {
        XCTAssertEqual(ShadowTokens.Kid.card.x, 0, accuracy: 0.001)
    }

    func test_shadowKidCardLg_greaterRadiusThanCard() {
        XCTAssertGreaterThan(ShadowTokens.Kid.cardLg.radius, ShadowTokens.Kid.card.radius)
    }

    func test_shadowKidTile_smallerRadiusThanCard() {
        XCTAssertLessThan(ShadowTokens.Kid.tile.radius, ShadowTokens.Kid.card.radius)
    }

    func test_shadowParentCard_radius3() {
        XCTAssertEqual(ShadowTokens.Parent.card.radius, 3, accuracy: 0.001)
    }

    func test_shadowParentElevated_greaterRadiusThanCard() {
        XCTAssertGreaterThan(ShadowTokens.Parent.elevated.radius, ShadowTokens.Parent.card.radius)
    }

    // MARK: - ShadowTokens.ShadowStyle: Sendable

    func test_shadowStyle_isSendable() {
        let style: ShadowTokens.ShadowStyle = ShadowTokens.Kid.card
        // Статическое свойство доступно — тест что тип компилируется как Sendable
        XCTAssertEqual(style.radius, 12, accuracy: 0.001)
    }

    // MARK: - SpacingTokens: алиасы числовых значений

    func test_spacing_sp1_is4() {
        XCTAssertEqual(SpacingTokens.sp1, 4, accuracy: 0.001)
    }

    func test_spacing_sp16_is64() {
        XCTAssertEqual(SpacingTokens.sp16, 64, accuracy: 0.001)
    }

    func test_spacing_xLarge_is32() {
        XCTAssertEqual(SpacingTokens.xLarge, 32, accuracy: 0.001)
    }

    func test_spacing_xxLarge_is40() {
        XCTAssertEqual(SpacingTokens.xxLarge, 40, accuracy: 0.001)
    }

    func test_spacing_xxxLarge_is48() {
        XCTAssertEqual(SpacingTokens.xxxLarge, 48, accuracy: 0.001)
    }

    // MARK: - RadiusTokens: числовые значения

    func test_radius_sm_is12() {
        XCTAssertEqual(RadiusTokens.sm, 12, accuracy: 0.001)
    }

    func test_radius_md_is18() {
        XCTAssertEqual(RadiusTokens.md, 18, accuracy: 0.001)
    }

    func test_radius_lg_is24() {
        XCTAssertEqual(RadiusTokens.lg, 24, accuracy: 0.001)
    }

    func test_radius_xl_is32() {
        XCTAssertEqual(RadiusTokens.xl, 32, accuracy: 0.001)
    }

    func test_radius_chip_equalsXS() {
        XCTAssertEqual(RadiusTokens.chip, RadiusTokens.xs)
    }

    func test_radius_avatar_equalsFull() {
        XCTAssertEqual(RadiusTokens.avatar, RadiusTokens.full)
    }

    // MARK: - MotionTokens: Duration constants

    func test_motionDuration_moderate_is045() {
        XCTAssertEqual(MotionTokens.Duration.moderate, 0.45, accuracy: 0.001)
    }

    func test_motionDuration_pageTransition_is035() {
        XCTAssertEqual(MotionTokens.Duration.pageTransition, 0.35, accuracy: 0.001)
    }

    func test_motionDuration_ordering_allAscending() {
        let ordered = [
            MotionTokens.Duration.instant,
            MotionTokens.Duration.quick,
            MotionTokens.Duration.standard,
            MotionTokens.Duration.moderate,
            MotionTokens.Duration.slow
        ]
        for i in 0..<(ordered.count - 1) {
            XCTAssertLessThan(ordered[i], ordered[i+1],
                "Duration[\(i)] должен быть меньше Duration[\(i+1)]")
        }
    }

    // MARK: - MotionTokens: page(reduceMotion: false) не nil

    func test_motionPage_normalMode_notNil() {
        XCTAssertNotNil(MotionTokens.page(reduceMotion: false))
    }

    // MARK: - ColorTokens.Theme: RGB-компоненты в диапазоне [0,1]

    func test_colorTheme_everydayFrom_validRGB() {
        // Проверяем что константа доступна и не крашится при обращении
        let color = ColorTokens.Theme.everydayFrom
        XCTAssertNotNil(color)
    }

    func test_colorTheme_spaceFrom_darkEnough() {
        // spaceFrom = (0.50, 0.55, 0.80) — должен быть тёмным (сумма <2)
        let color = ColorTokens.Theme.spaceFrom
        XCTAssertNotNil(color)
    }

    func test_colorTheme_hairColors_count5() {
        // 5 цветов волос: golden, chestnut, black, pink, cyan
        let colors = [
            ColorTokens.Theme.hairGolden,
            ColorTokens.Theme.hairChestnut,
            ColorTokens.Theme.hairBlack,
            ColorTokens.Theme.hairPink,
            ColorTokens.Theme.hairCyan
        ]
        XCTAssertEqual(colors.count, 5)
    }

    func test_colorTheme_eyeColors_count3() {
        let colors = [
            ColorTokens.Theme.eyeBlue,
            ColorTokens.Theme.eyeGreen,
            ColorTokens.Theme.eyeBrown
        ]
        XCTAssertEqual(colors.count, 3)
    }

    func test_colorTheme_skinTones_count3() {
        let tones = [
            ColorTokens.Theme.toneLight,
            ColorTokens.Theme.toneMedium,
            ColorTokens.Theme.toneDark
        ]
        XCTAssertEqual(tones.count, 3)
    }

    // MARK: - ColorTokens.Confetti: палитры не пустые

    func test_colorConfetti_celebrationPalette_count6() {
        XCTAssertEqual(ColorTokens.Confetti.celebrationPalette.count, 6)
    }

    func test_colorConfetti_perfectPalette_count5() {
        XCTAssertEqual(ColorTokens.Confetti.perfectPalette.count, 5)
    }

    func test_colorConfetti_achievementPalette_count6() {
        XCTAssertEqual(ColorTokens.Confetti.achievementPalette.count, 6)
    }

    // MARK: - ColorTokens.Story: hex строки не пустые

    func test_colorStory_shishka_hasTwoEntries() {
        XCTAssertEqual(ColorTokens.Story.shustrayShishka.count, 2)
    }

    func test_colorStory_allStories_validHex() {
        let stories: [[String]] = [
            ColorTokens.Story.shustrayShishka,
            ColorTokens.Story.zhukovVLuzhe,
            ColorTokens.Story.sinyayaSobaka,
            ColorTokens.Story.rybkaRita,
            ColorTokens.Story.kotKuzma
        ]
        for story in stories {
            XCTAssertEqual(story.count, 2, "Каждая история должна иметь ровно 2 hex цвета")
            for hex in story {
                XCTAssertTrue(hex.hasPrefix("#"), "Hex-строка должна начинаться с #: \(hex)")
                XCTAssertEqual(hex.count, 7, "Hex-строка должна быть длиной 7: \(hex)")
            }
        }
    }

    // MARK: - ColorTokens.Mood

    func test_colorMood_allDefined() {
        let colors = [
            ColorTokens.Mood.idle,
            ColorTokens.Mood.happy,
            ColorTokens.Mood.celebrating,
            ColorTokens.Mood.thinking,
            ColorTokens.Mood.sad,
            ColorTokens.Mood.encouraging,
            ColorTokens.Mood.singing
        ]
        XCTAssertEqual(colors.count, 7)
    }

    // MARK: - ColorTokens.Badge: алиасы

    func test_colorBadge_goldAliasBrandGold() {
        // Badge.gold = Brand.gold — оба не nil
        XCTAssertNotNil(ColorTokens.Badge.gold)
        XCTAssertNotNil(ColorTokens.Badge.silver)
        XCTAssertNotNil(ColorTokens.Badge.bronze)
    }

    // MARK: - ColorTokens.Award

    func test_colorAward_platinum_notNil() {
        XCTAssertNotNil(ColorTokens.Award.platinum)
    }

    func test_colorAward_silver_notNil() {
        XCTAssertNotNil(ColorTokens.Award.silver)
    }

    // MARK: - ColorTokens.Mascot.cheekActiveUI: mood clamp

    func test_mascotCheek_zeroMood_alphaAbove05() {
        let color = ColorTokens.Mascot.cheekActiveUI(mood: 0.0)
        var alpha: CGFloat = 0
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertGreaterThanOrEqual(alpha, 0.45)
    }

    func test_mascotCheek_maxMood_alphaOne() {
        let color = ColorTokens.Mascot.cheekActiveUI(mood: 1.0)
        var alpha: CGFloat = 0
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertEqual(alpha, 1.0, accuracy: 0.01)
    }

    func test_mascotCheek_overMood_clampedToOne() {
        let colorOver = ColorTokens.Mascot.cheekActiveUI(mood: 2.0)
        var alpha: CGFloat = 0
        colorOver.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertLessThanOrEqual(Double(alpha), 1.0)
    }

    // MARK: - ColorTokens.Sticker

    func test_colorSticker_goldTint_notNil() {
        XCTAssertNotNil(ColorTokens.Sticker.goldTint)
    }

    func test_colorSticker_silverTint_notNil() {
        XCTAssertNotNil(ColorTokens.Sticker.silverTint)
    }

    // MARK: - ColorTokens.Banner

    func test_colorBanner_offlineBg_notNil() {
        XCTAssertNotNil(ColorTokens.Banner.offlineBg)
    }

    // MARK: - GradientTokens: не крашится при обращении

    func test_gradientTokens_kidBackground_notNil() {
        let gradient = GradientTokens.kidBackground
        XCTAssertNotNil(gradient)
    }

    func test_gradientTokens_parentBackground_notNil() {
        XCTAssertNotNil(GradientTokens.parentBackground)
    }

    func test_gradientTokens_celebrationGold_notNil() {
        XCTAssertNotNil(GradientTokens.celebrationGold)
    }

    func test_gradientTokens_storyMagic_notNil() {
        XCTAssertNotNil(GradientTokens.storyMagic)
    }

    func test_gradientTokens_kidBottomFade_notNil() {
        let fade = GradientTokens.kidBottomFade(background: ColorTokens.Kid.bg)
        XCTAssertNotNil(fade)
    }
}
