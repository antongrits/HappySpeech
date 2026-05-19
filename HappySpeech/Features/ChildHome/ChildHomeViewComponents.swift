import OSLog
import SwiftUI

// MARK: - ChildHomeViewComponents
//
// Подкомпоненты для `ChildHomeView`. Все компоненты — `internal` внутри
// модуля HappySpeech (не `private`), чтобы быть доступными из
// `ChildHomeView.swift`. Каждый — самодостаточный view без бизнес-логики.
//
// Block K.1 v16: файл разделён для удержания LOC ≤500. Mission/QuickPlay
// компоненты вынесены в `ChildHomeViewMissionComponents.swift`, списки и
// баннеры — в `ChildHomeViewListComponents.swift`. Здесь остались только
// фоны, маскот, badges и общие helpers/extensions.

// MARK: - KidBackgroundView
//
// iOS 18+: MeshGradient — органичный многоточечный тёплый фон.
// iOS 17 fallback: GradientTokens.kidBackground (LinearGradient).
// Reduced Motion: анимация фазы отключается, но градиент остаётся.

struct KidBackgroundView: View {

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if #available(iOS 18.0, *) {
            meshBackground
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                        phase = .pi
                    }
                }
        } else {
            GradientTokens.kidBackground
        }
    }

    @available(iOS 18.0, *)
    private var meshBackground: some View {
        let s = Float(sin(phase) * 0.08)
        let c = Float(cos(phase) * 0.08)
        return MeshGradient(
            width: 3,
            height: 3,
            points: [
                SIMD2(0, 0),        SIMD2(0.5, 0),        SIMD2(1, 0),
                SIMD2(0, 0.5 + s),  SIMD2(0.5, 0.5),      SIMD2(1, 0.5 - c),
                SIMD2(0, 1),        SIMD2(0.5, 1),         SIMD2(1, 1)
            ],
            colors: [
                ColorTokens.Kid.bgSofter, ColorTokens.Brand.primaryLo.opacity(0.25), ColorTokens.Kid.bgSoft,
                ColorTokens.Brand.rose.opacity(0.15), ColorTokens.Kid.bg, ColorTokens.Brand.butter.opacity(0.15),
                ColorTokens.Kid.bgDeep.opacity(0.6), ColorTokens.Kid.bgSoft, ColorTokens.Kid.bgSofter
            ]
        )
    }
}

// MARK: - CloudDecoration

struct ChildHomeCloudDecoration: View {

    private struct CloudSpec {
        let width: CGFloat
        let height: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat
        let blur: CGFloat
        let opacity: Double
    }

    private static let specs: [CloudSpec] = [
        .init(width: 140, height: 70, offsetX: -90, offsetY: 80, blur: 22, opacity: 0.6),
        .init(width: 100, height: 50, offsetX: 110, offsetY: 110, blur: 18, opacity: 0.45),
        .init(width: 80, height: 40, offsetX: -40, offsetY: 200, blur: 16, opacity: 0.35)
    ]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(0..<Self.specs.count, id: \.self) { index in
                cloud(spec: Self.specs[index])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .offset(x: phase)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                phase = 12
            }
        }
    }

    private func cloud(spec: CloudSpec) -> some View {
        Ellipse()
            .fill(ColorTokens.Overlay.onAccent.opacity(spec.opacity))
            .frame(width: spec.width, height: spec.height)
            .blur(radius: spec.blur)
            .offset(x: spec.offsetX, y: spec.offsetY)
            .accessibilityHidden(true)
    }
}

// MARK: - ReactiveMascot

struct ChildHomeReactiveMascot: View {

    let mood: MascotMood
    let reduceMotion: Bool

    @State private var bobOffset: CGFloat = 0

    var body: some View {
        // D-3 v27: hero-маскот на главном экране ребёнка через единый 2D-канон
        // Ляли (LyalyaHeroView → LyalyaMascotView, иллюстрация mascot_lyalya_*,
        // согласованная с AppIcon). Size 160pt — заметный hero на 320pt SE.
        LyalyaHeroView(state: mood.lyalyaState, size: 160)
        .offset(y: bobOffset)
        .onAppear { startBobbing() }
        .onChange(of: mood) { _, _ in startBobbing() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "child.home.mascot.a11y"))
    }

    private func startBobbing() {
        guard !reduceMotion else {
            bobOffset = 0
            return
        }
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            bobOffset = -6
        }
    }
}

// MARK: - MascotBubble (BUG-009: добавлен аватар Ляли слева от bubble)

struct ChildHomeMascotBubble: View {

    let text: String

    var body: some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.sp2) {
            LyalyaMascotView(state: .explaining, size: 40)
                .accessibilityHidden(true)

            HStack(spacing: 0) {
                Text(text)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, SpacingTokens.sp4)
                    .padding(.vertical, SpacingTokens.sp3)
            }
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .kidTileShadow()
            )
        }
        .padding(.horizontal, SpacingTokens.sp6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

// MARK: - StreakBadge (with optional pulse ring)

struct ChildHomeStreakBadge: View {

    let streak: Int
    let isHot: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.55

    var body: some View {
        ZStack {
            if isHot {
                Circle()
                    .stroke(ColorTokens.Semantic.warning.opacity(pulseOpacity), lineWidth: 2)
                    .scaleEffect(pulse)
                    .frame(width: 60, height: 60)
                    .onAppear { startPulse() }
                    .accessibilityHidden(true)
            }

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(TypographyTokens.caption(14))
                    .foregroundStyle(ColorTokens.Semantic.warning)
                    .accessibilityHidden(true)

                Text("\(streak)")
                    .font(TypographyTokens.caption(14).weight(.bold))
                    .foregroundStyle(ColorTokens.Semantic.warning)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(streak)))
                    .animation(reduceMotion ? nil : MotionTokens.snappy, value: streak)
            }
            .padding(.horizontal, SpacingTokens.sp3)
            .padding(.vertical, SpacingTokens.sp2)
            .background(Capsule().fill(ColorTokens.Semantic.warning.opacity(0.12)))
        }
        .accessibilityLabel(Text(String.localizedStringWithFormat(
            String(localized: "child.home.streak.a11y"),
            streak
        )))
    }

    private func startPulse() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            pulse = 1.25
            pulseOpacity = 0.0
        }
    }
}

// MARK: - SoundLetterBadge

struct ChildHomeSoundLetterBadge: View {

    let letter: String
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Brand.primary.opacity(0.15))

            Text(letter)
                .font(TypographyTokens.kidDisplay(size * 0.5))
                .foregroundStyle(ColorTokens.Brand.primary)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Helpers / extensions (shared with ChildHomeView)

extension String {
    var capitalizedFirstLetter: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
}

extension ColorTokens {
    /// Маппинг QuickPlayAccent → Color (используется в `ChildHomeQuickPlayCard`).
    static func color(for accent: ChildHomeModels.QuickPlayAccent) -> Color {
        switch accent {
        case .coral:  return ColorTokens.Brand.primary
        case .mint:   return ColorTokens.Brand.mint
        case .sky:    return ColorTokens.Brand.sky
        case .butter: return ColorTokens.Brand.butter
        case .lilac:  return ColorTokens.Brand.lilac
        case .gold:   return ColorTokens.Brand.gold
        case .rose:   return ColorTokens.Brand.rose
        }
    }
}
