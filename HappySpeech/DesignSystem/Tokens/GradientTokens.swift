import SwiftUI

// MARK: - GradientTokens

/// Именованные градиенты HappySpeech — единственный источник градиентных фонов.
///
/// `GradientTokens` собирает все фоновые, оверлейные и акцентные градиенты
/// из брендовой палитры `ColorTokens`. Использование именованных градиентов
/// обеспечивает единый визуальный язык на всех экранах.
///
/// > Important: Не создавай inline `LinearGradient` в фичах.
/// > Используй `GradientTokens.*` — это требование DoD.
///
/// ## Пример
/// ```swift
/// // Детский фон
/// GradientTokens.kidBackground
///     .ignoresSafeArea()
///
/// // Золотой акцент наград
/// GradientTokens.celebrationGold
/// ```
public enum GradientTokens {

    // MARK: - Kid Circuit Backgrounds

    /// Основной фон детского контура: sky → peach (topLeading → bottomTrailing).
    /// Используется в ChildHome как iOS 17 fallback (вместо MeshGradient).
    public static let kidBackground = LinearGradient(
        colors: [ColorTokens.Kid.bgSoft, ColorTokens.Kid.bgSofter],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Глубокий детский фон: bgDeep → bg (тёмный к светлому снизу вверх).
    public static let kidDeep = LinearGradient(
        colors: [ColorTokens.Kid.bgDeep, ColorTokens.Kid.bg],
        startPoint: .bottom,
        endPoint: .top
    )

    // MARK: - Celebration / Rewards

    /// Золотой акцент наград: butter → gold (leading → trailing).
    public static let celebrationGold = LinearGradient(
        colors: [ColorTokens.Brand.butter, ColorTokens.Brand.gold],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Story

    /// Магический фон истории: lilac → sky (top → bottom).
    /// Используется в AnimatedStoryPlayerView как fallback вместо Color.blue/purple.
    public static let storyMagic = LinearGradient(
        colors: [ColorTokens.Brand.lilac.opacity(0.85), ColorTokens.Brand.sky.opacity(0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Functional Gradients

    /// Тёплый закат: peach → rose (leading → trailing).
    public static let warmSunset = LinearGradient(
        colors: [ColorTokens.Brand.primaryLo, ColorTokens.Brand.rose],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Card Tint Presets (v32 — design-modernization Wave A)
    //
    // Тёплые градиентные пресеты для `HSCard(.gradientTinted(...))`.
    // Используются вместо плоского `HSCard(.elevated)` на hero- и summary-карточках
    // детского контура, чтобы создать визуальную глубину без конкуренции с контентом.
    // Все значения opacity подобраны так, чтобы текст на карточке оставался читаемым
    // в light и dark режимах (цвет фона — всегда surface, поверх него градиент).

    /// Коралл → butter — тёплый дефолт для hero-карточек детского контура.
    public static let cardCoralButter = LinearGradient(
        colors: [
            ColorTokens.Brand.primaryLo.opacity(0.18),
            ColorTokens.Brand.butter.opacity(0.10)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Butter → gold — стрик, достижения, золотые награды.
    public static let cardGold = LinearGradient(
        colors: [
            ColorTokens.Brand.butter.opacity(0.22),
            ColorTokens.Brand.gold.opacity(0.10)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Lilac → rose — магия, AR-активности, игры воображения.
    public static let cardLilacRose = LinearGradient(
        colors: [
            ColorTokens.Brand.lilac.opacity(0.18),
            ColorTokens.Brand.rose.opacity(0.10)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Rose → primary — праздник, завершение сессии, поздравления.
    public static let cardRosePrimary = LinearGradient(
        colors: [
            ColorTokens.Brand.rose.opacity(0.18),
            ColorTokens.Brand.primary.opacity(0.10)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Functional fade overlays

    /// Нижний fade-оверлей для action footer (top = прозрачный, bottom = заданный цвет).
    /// Используется в Onboarding для плавного перехода между контентом и кнопками.
    /// - Parameter background: Цвет нижнего края (обычно последний цвет фонового градиента).
    public static func kidBottomFade(background: Color) -> LinearGradient {
        LinearGradient(
            colors: [background.opacity(0), background],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
