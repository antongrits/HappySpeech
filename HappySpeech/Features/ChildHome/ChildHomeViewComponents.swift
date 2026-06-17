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
// iOS 18+: MeshGradient — органичный многоточечный тёплый фон (СТАТИЧНЫЙ).
// iOS 17 fallback: GradientTokens.kidBackground (LinearGradient).
//
// Defect #3 / стандинг-ордер владельца: фон ДОЛЖЕН быть статичным и тёплым —
// никакой «дышащей»/волновой анимации фазы. Mesh-точки фиксированы, цвета —
// только тёплые ColorTokens. Никаких растровых подложек.

struct KidBackgroundView: View {

    var body: some View {
        if #available(iOS 18.0, *) {
            meshBackground
        } else {
            GradientTokens.kidBackground
        }
    }

    @available(iOS 18.0, *)
    private var meshBackground: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                SIMD2(0, 0),        SIMD2(0.5, 0),        SIMD2(1, 0),
                SIMD2(0, 0.5),      SIMD2(0.5, 0.5),      SIMD2(1, 0.5),
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

// MARK: - ReactiveMascot

struct ChildHomeReactiveMascot: View {

    let mood: MascotMood
    let reduceMotion: Bool

    @State private var bobOffset: CGFloat = 0

    var body: some View {
        // D-3 v27: hero-маскот на главном экране ребёнка через единый 2D-канон
        // Ляли (LyalyaHeroView → LyalyaMascotView, иллюстрация mascot_lyalya_*,
        // согласованная с AppIcon). Size 160pt — заметный hero на 320pt SE.
        // Cad-task-2: LyalyaOutfitHeroView показывает статичный lyalya_outfit_<id>
        // когда выбран наряд ≠ повседневный — смена одежды видимо меняет героя.
        LyalyaOutfitHeroView(state: mood.lyalyaState, size: 160)
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

// MARK: - MascotBubble
//
// Эталон childhome_ref.png: пузырь-речь с хвостом-стрелкой слева →
// к маскоту, текст + подпись «— Ляля» мелким цветом снизу.
// Layout: mini-аватар внизу слева (якорь для хвоста), карточка с хвостом
// и текстом, подпись «— Ляля» ниже основного текста.

struct ChildHomeMascotBubble: View {

    let text: String

    var body: some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.sp2) {
            // Мини-аватар Ляли — источник хвоста пузыря.
            LyalyaMascotView(state: .explaining, size: 40)
                .accessibilityHidden(true)

            bubbleCard
        }
        .padding(.horizontal, SpacingTokens.sp6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text + ". " + String(localized: "child.home.mascot.name",
                                                  defaultValue: "Ляля"))
    }

    // Карточка пузыря с хвостом-треугольником слева и подписью.
    private var bubbleCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                // Пузырь
                VStack(alignment: .leading, spacing: 2) {
                    Text(text)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)

                    // Подпись «— Ляля» (эталон childhome_ref.png)
                    Text(String(localized: "child.home.mascot.signature",
                                defaultValue: "— Ляля"))
                        .font(TypographyTokens.caption(12).weight(.semibold))
                        .foregroundStyle(ColorTokens.Brand.primary.opacity(0.75))
                        .lineLimit(1)
                }
                .padding(.horizontal, SpacingTokens.sp4)
                .padding(.vertical, SpacingTokens.sp3)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                        .fill(ColorTokens.Kid.surface)
                        .kidTileShadow()
                )

                // Хвост-треугольник, указывающий влево-вниз к маскоту.
                BubbleTail()
                    .fill(ColorTokens.Kid.surface)
                    .frame(width: 12, height: 10)
                    .offset(x: -8, y: 0)
                    .accessibilityHidden(true)
            }
        }
    }
}

// MARK: - BubbleTail

/// Хвост речевого пузыря — треугольник, указывающий влево-вниз к маскоту.
private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Точки: правый-нижний → правый-верхний → левый-нижний (хвост влево).
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
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
                    .hsSymbolEffect(.bounce, value: streak)
                    .accessibilityHidden(true)

                // Fix #3a — chip-капсула не должна резать двузначные
                // streak ("12", "100"): lineLimit(1) + minimumScaleFactor чтобы
                // цифра подстраивалась, а внутренние горизонтальные отступы +24
                // расширены — chip перестаёт «жать» цифру визуально.
                Text("\(streak)")
                    .font(TypographyTokens.caption(14).weight(.bold))
                    .foregroundStyle(ColorTokens.Semantic.warning)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText(value: Double(streak)))
                    .animation(reduceMotion ? nil : MotionTokens.snappy, value: streak)
            }
            .padding(.horizontal, SpacingTokens.sp5)
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

// MARK: - StartStreakBadge (первый запуск — приглашение начать серию)
//
// Показывается в hero справа, когда streak == 0 и миссия ещё не закрыта.
// Дружелюбный «Начни!» вместо пустого кольца прогресса, чтобы экран новичка
// не выглядел уныло (defect #4). Тёплый коралловый акцент.

struct ChildHomeStartStreakBadge: View {

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(ColorTokens.Brand.primary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "flame")
                    .font(TypographyTokens.title(20).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)
            }

            Text(String(localized: "child.home.streak.start.short"))
                .font(TypographyTokens.caption(11).weight(.bold))
                .foregroundStyle(ColorTokens.Brand.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 56)
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
