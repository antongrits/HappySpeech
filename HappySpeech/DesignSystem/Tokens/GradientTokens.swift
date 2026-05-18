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
/// // Родительский фон
/// GradientTokens.parentBackground
///     .ignoresSafeArea()
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

    /// Акцентный фон героя: primary → primaryLo (topLeading → bottomTrailing).
    /// Используется для декоративных ellipse-элементов на auth-экранах.
    public static let kidHeroDecoration = LinearGradient(
        colors: [
            ColorTokens.Brand.primary.opacity(0.9),
            ColorTokens.Brand.primaryLo.opacity(0.7)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Глубокий детский фон: bgDeep → bg (тёмный к светлому снизу вверх).
    public static let kidDeep = LinearGradient(
        colors: [ColorTokens.Kid.bgDeep, ColorTokens.Kid.bg],
        startPoint: .bottom,
        endPoint: .top
    )

    /// Splash-фон: трёхцветный диагональный градиент primary → primaryHi → rose.
    /// Заменяет плоский моноцветный coral на splash-экране — задаёт современную
    /// планку первого впечатления (v27-spec, изменение #3).
    public static let splashHero = LinearGradient(
        colors: [
            ColorTokens.Brand.primary,
            ColorTokens.Brand.primaryHi,
            ColorTokens.Brand.rose
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Parent Circuit Backgrounds

    /// Нейтральный фон родительского контура.
    public static let parentBackground = LinearGradient(
        colors: [ColorTokens.Parent.bg, ColorTokens.Parent.bgDeep],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Celebration / Rewards

    /// Золотой акцент наград: butter → gold (leading → trailing).
    public static let celebrationGold = LinearGradient(
        colors: [ColorTokens.Brand.butter, ColorTokens.Brand.gold],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Burst-фон для экрана достижений: butter → rose (topLeading → bottomTrailing).
    public static let rewardBurst = LinearGradient(
        colors: [ColorTokens.Brand.butter.opacity(0.8), ColorTokens.Brand.rose.opacity(0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Story / AR

    /// Магический фон истории: lilac → sky (top → bottom).
    /// Используется в AnimatedStoryPlayerView как fallback вместо Color.blue/purple.
    public static let storyMagic = LinearGradient(
        colors: [ColorTokens.Brand.lilac.opacity(0.85), ColorTokens.Brand.sky.opacity(0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// AR-сцена фон: lilac → mint (top → bottom).
    public static let arScene = LinearGradient(
        colors: [ColorTokens.Brand.lilac, ColorTokens.Brand.mint],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Functional Gradients

    /// Стеклянный оверлей (glassmorphic): white → white (прозрачный).
    public static let glassMorphic = LinearGradient(
        colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Спокойный синий: skyBlue → mint (top → bottom).
    public static let calmBlue = LinearGradient(
        colors: [ColorTokens.Brand.sky, ColorTokens.Brand.mint],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Тёплый закат: peach → rose (leading → trailing).
    public static let warmSunset = LinearGradient(
        colors: [ColorTokens.Brand.primaryLo, ColorTokens.Brand.rose],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Энергичный оранжевый: honey → peach (topLeading → bottomTrailing).
    public static let energeticOrange = LinearGradient(
        colors: [ColorTokens.Brand.butter, ColorTokens.Brand.primaryLo],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Specialist Circuit

    /// Нейтральный фон специалиста.
    public static let specBackground = LinearGradient(
        colors: [ColorTokens.Spec.bg, ColorTokens.Spec.panel],
        startPoint: .top,
        endPoint: .bottom
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
