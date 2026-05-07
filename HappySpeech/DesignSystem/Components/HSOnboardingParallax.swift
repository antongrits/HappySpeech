import SwiftUI

// MARK: - HSOnboardingParallax
//
// Block O v16 — onboarding с параллакс-эффектом и MeshGradient фоном.
//
// Полноэкранный pageable onboarding. Каждая страница содержит фоновую
// иллюстрацию (parallax-слой смещается медленнее переднего плана) + заголовок
// + подзаголовок + опциональный CTA. Между страницами анимируется MeshGradient
// фона (iOS 18+) или статический LinearGradient (iOS 17).
//
// Параллакс реализован через `.scrollTransition` (iOS 17): при выходе страницы
// из viewport бэкграунд смещается на 30% от translation, передний план — нет.
//
// Usage:
// ```swift
// HSOnboardingParallax(pages: [
//     .init(image: "onboarding-1", title: "Привет!", subtitle: "Давай знакомиться"),
//     .init(image: "onboarding-2", title: "Игры", subtitle: "Учись через игру"),
//     .init(image: "onboarding-3", title: "Старт", subtitle: "Начнём?")
// ]) {
//     coordinator.completeOnboarding()
// }
// ```
//
// References:
// - kavsoft.dev (Parallax Carousel)
// - SwiftLee — Dynamic Pager View Onboarding
// - Hacking with Swift — MeshGradient
// - Apple WWDC23 — Beyond scroll views

@available(iOS 17.0, *)
public struct HSOnboardingParallax: View {

    // MARK: - Page

    public struct Page: Identifiable {
        public let id = UUID()
        public let imageName: String
        public let title: LocalizedStringKey
        public let subtitle: LocalizedStringKey
        public let mascotState: LyalyaState

        public init(
            imageName: String,
            title: LocalizedStringKey,
            subtitle: LocalizedStringKey,
            mascotState: LyalyaState = .waving
        ) {
            self.imageName = imageName
            self.title = title
            self.subtitle = subtitle
            self.mascotState = mascotState
        }
    }

    // MARK: - Public API

    public let pages: [Page]
    public let onFinish: () -> Void

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State

    @State private var currentIndex: Int = 0

    public init(pages: [Page], onFinish: @escaping () -> Void) {
        self.pages = pages
        self.onFinish = onFinish
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            VStack(spacing: 0) {
                pagerContent
                pageIndicator
                actionButton
            }
        }
    }

    // MARK: - Pager

    @ViewBuilder
    private var pagerContent: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                pageView(page: page)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func pageView(page: Page) -> some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer()

            // Иллюстрация / маскот.
            illustration(for: page)
                .frame(maxWidth: .infinity)
                .frame(height: 260)

            VStack(spacing: SpacingTokens.regular) {
                Text(page.title)
                    .font(TypographyTokens.titleLarge())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ColorTokens.Kid.ink)

                Text(page.subtitle)
                    .font(TypographyTokens.body(16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .padding(.horizontal, SpacingTokens.large)
            }

            Spacer()
        }
        .padding(.horizontal, SpacingTokens.large)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func illustration(for page: Page) -> some View {
        // Параллакс: иллюстрация увеличивается/смещается на scrollTransition.
        ZStack {
            if UIImage(named: page.imageName) != nil {
                Image(page.imageName)
                    .resizable()
                    .scaledToFit()
            } else {
                // Fallback — emoji маскота, если ассет отсутствует.
                Text(page.mascotState.fallbackEmoji)
                    .font(.system(size: 140))
            }
        }
        .scrollTransition(reduceMotion ? .identity : .interactive) { effect, phase in
            effect
                .scaleEffect(reduceMotion ? 1.0 : (1.0 - abs(phase.value) * 0.15))
                .offset(y: reduceMotion ? 0 : phase.value * -40)
                .opacity(reduceMotion ? 1.0 : (1.0 - abs(phase.value) * 0.4))
        }
    }

    // MARK: - Indicator

    @ViewBuilder
    private var pageIndicator: some View {
        HStack(spacing: SpacingTokens.tiny) {
            ForEach(0..<pages.count, id: \.self) { idx in
                Capsule()
                    .fill(idx == currentIndex ? ColorTokens.Brand.primary : ColorTokens.Kid.line)
                    .frame(width: idx == currentIndex ? 24 : 8, height: 8)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8),
                        value: currentIndex
                    )
            }
        }
        .padding(.vertical, SpacingTokens.regular)
    }

    // MARK: - CTA

    @ViewBuilder
    private var actionButton: some View {
        let isLast = currentIndex == pages.count - 1
        HSButton(isLast ? "Начать" : "Дальше", style: .primary) {
            if isLast {
                onFinish()
            } else if reduceMotion {
                currentIndex += 1
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                    currentIndex += 1
                }
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.bottom, SpacingTokens.large)
    }

    // MARK: - Background (MeshGradient on iOS 18+)

    @ViewBuilder
    private var backgroundLayer: some View {
        if #available(iOS 18.0, *) {
            AnimatedMeshBackground(progress: meshProgress)
        } else {
            LinearGradient(
                colors: [
                    ColorTokens.Brand.primaryLo.opacity(0.4),
                    ColorTokens.Kid.bg
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var meshProgress: CGFloat {
        guard !pages.isEmpty else { return 0 }
        return CGFloat(currentIndex) / CGFloat(max(pages.count - 1, 1))
    }
}

// MARK: - Animated Mesh Background (iOS 18+)

@available(iOS 18.0, *)
private struct AnimatedMeshBackground: View {
    let progress: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let palette = palette(for: progress)
        let points: [SIMD2<Float>] = [
            SIMD2(0, 0),   SIMD2(0.5, 0),   SIMD2(1, 0),
            SIMD2(0, 0.5), SIMD2(0.5, 0.5), SIMD2(1, 0.5),
            SIMD2(0, 1),   SIMD2(0.5, 1),   SIMD2(1, 1)
        ]
        MeshGradient(width: 3, height: 3, points: points, colors: palette)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.8),
                value: progress
            )
    }

    private func palette(for progress: CGFloat) -> [Color] {
        let baseA = [
            ColorTokens.Brand.primaryLo, ColorTokens.Brand.butter, ColorTokens.Brand.rose,
            ColorTokens.Brand.mint, ColorTokens.Kid.bg, ColorTokens.Brand.sky,
            ColorTokens.Brand.lilac, ColorTokens.Brand.primary.opacity(0.4), ColorTokens.Brand.butter.opacity(0.6)
        ]
        let baseB = [
            ColorTokens.Brand.lilac.opacity(0.4), ColorTokens.Brand.sky.opacity(0.6), ColorTokens.Brand.mint,
            ColorTokens.Brand.butter, ColorTokens.Kid.bgSofter, ColorTokens.Brand.rose,
            ColorTokens.Brand.primary.opacity(0.5), ColorTokens.Brand.butter, ColorTokens.Brand.lilac
        ]
        return zip(baseA, baseB).map { Color.lerp($0, $1, progress) }
    }
}

// MARK: - Color Helpers

@available(iOS 17.0, *)
private extension Color {
    static func lerp(_ a: Color, _ b: Color, _ t: CGFloat) -> Color {
        // Простой кросс-фейд через `Color(uiColor:)` interpolation.
        let uiA = UIColor(a)
        let uiB = UIColor(b)
        var ra: CGFloat = 0, ga: CGFloat = 0, ba: CGFloat = 0, aa: CGFloat = 0
        var rb: CGFloat = 0, gb: CGFloat = 0, bb: CGFloat = 0, ab: CGFloat = 0
        uiA.getRed(&ra, green: &ga, blue: &ba, alpha: &aa)
        uiB.getRed(&rb, green: &gb, blue: &bb, alpha: &ab)
        return Color(
            red: ra + (rb - ra) * t,
            green: ga + (gb - ga) * t,
            blue: ba + (bb - ba) * t,
            opacity: aa + (ab - aa) * t
        )
    }
}

// MARK: - Preview

#Preview("HSOnboardingParallax") {
    HSOnboardingParallax(pages: [
        .init(imageName: "missing-asset-1", title: "Привет!", subtitle: "Давай знакомиться", mascotState: .waving),
        .init(imageName: "missing-asset-2", title: "Игры", subtitle: "Учись говорить через игру", mascotState: .happy),
        .init(imageName: "missing-asset-3", title: "В путь!", subtitle: "Начнём наше первое занятие", mascotState: .celebrating)
    ]) {
        // onFinish
    }
    .environment(\.circuitContext, .kid)
}
