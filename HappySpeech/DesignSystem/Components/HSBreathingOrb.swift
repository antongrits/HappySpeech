import SwiftUI

// MARK: - HSBreathingPhase

/// Фаза дыхательного цикла, которую ведёт орб.
public enum HSBreathingPhase: Equatable {
    case inhale
    case hold
    case exhale
    case rest
}

// MARK: - HSBreathingOrb
//
// Единый «дыхательный ориентир» для всего класса дыхательных упражнений
// (Breathing, BreatheAndSpeak, BreathingAR-fallback, BreathingTree, SoftOnset,
// Pacing). Большой растущий/сжимающийся орб с тёплым коралл→роза градиентом,
// мягким сиянием, кольцом тайминга и лепестками — по эталону
// `kid-game-breathing`.
//
// Управляется снаружи через `expansion` (0…1) — доля раскрытия. Анимация роста
// гейтится `accessibilityReduceMotion`: при включённом Reduced Motion орб
// замирает в текущем значении без пульсации.
//
// Палитра — только тёплая (Brand.primaryHi → Brand.rose), допустимый мягкий
// двухстоповый градиент на hero (исключение для дыхания, согласовано с брифом).
public struct HSBreathingOrb: View {

    /// Доля раскрытия 0…1 (0 — максимально сжат, 1 — максимально раскрыт).
    private let expansion: CGFloat
    /// Прогресс кольца тайминга 0…1.
    private let ringProgress: CGFloat
    /// Заголовок в центре орба («Вдох…», «Выдох…», «Держи…»).
    private let phaseTitle: String
    /// Подпись-счёт под заголовком («1 · 2 · 3»), опционально.
    private let phaseCount: String?
    /// Диаметр области орба.
    private let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        expansion: CGFloat,
        ringProgress: CGFloat = 0,
        phaseTitle: String,
        phaseCount: String? = nil,
        size: CGFloat = 240
    ) {
        self.expansion = max(0, min(1, expansion))
        self.ringProgress = max(0, min(1, ringProgress))
        self.phaseTitle = phaseTitle
        self.phaseCount = phaseCount
        self.size = size
    }

    // Масштаб орба: от 0.66 (сжат) до 1.0 (раскрыт) — как в эталоне.
    private var orbScale: CGFloat { 0.66 + 0.34 * expansion }
    // Масштаб/прозрачность лепестков следуют за дыханием.
    private var petalScale: CGFloat { 0.78 + 0.34 * expansion }
    private var petalOpacity: Double { 0.42 + 0.36 * Double(expansion) }

    private var growthAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.6)
    }

    public var body: some View {
        ZStack {
            glow
            timingRing
            petals
            orb
        }
        .frame(width: size, height: size)
        .animation(growthAnimation, value: expansion)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: phaseTitle))
        .accessibilityValue(Text(verbatim: phaseCount ?? ""))
    }

    // MARK: - Glow halo

    private var glow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        ColorTokens.Brand.primary.opacity(0.20),
                        ColorTokens.Brand.primary.opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.62
                )
            )
            .scaleEffect(0.85 + 0.25 * expansion)
            .accessibilityHidden(true)
    }

    // MARK: - Timing ring

    private var timingRing: some View {
        ZStack {
            Circle()
                .stroke(ColorTokens.Kid.line, lineWidth: 4)
                .opacity(0.7)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    ColorTokens.Brand.primary,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .opacity(0.85)
                .rotationEffect(.degrees(-90))
                .animation(growthAnimation, value: ringProgress)
        }
        .frame(width: size * 0.92, height: size * 0.92)
        .accessibilityHidden(true)
    }

    // MARK: - Petals

    private var petals: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ColorTokens.Brand.primaryLo, ColorTokens.Brand.rose],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: size * 0.12, height: size * 0.26)
                    .offset(y: -size * 0.40)
                    .rotationEffect(.degrees(Double(index) / 8 * 360))
            }
        }
        .scaleEffect(petalScale)
        .opacity(petalOpacity)
        .accessibilityHidden(true)
    }

    // MARK: - Orb

    private var orb: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.rose],
                    center: UnitPoint(x: 0.38, y: 0.30),
                    startRadius: 0,
                    endRadius: size * 0.42
                )
            )
            .overlay {
                // Мягкий внутренний блик.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.5), .clear],
                            center: UnitPoint(x: 0.34, y: 0.28),
                            startRadius: 0,
                            endRadius: size * 0.16
                        )
                    )
            }
            .frame(width: size * 0.78, height: size * 0.78)
            .shadow(
                color: ColorTokens.Brand.primary.opacity(0.45),
                radius: 24, x: 0, y: 14
            )
            .scaleEffect(orbScale)
            .overlay { phaseLabel }
    }

    private var phaseLabel: some View {
        VStack(spacing: SpacingTokens.sp1) {
            Text(verbatim: phaseTitle)
                .font(TypographyTokens.kidHero(28))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let phaseCount {
                Text(verbatim: phaseCount)
                    .font(TypographyTokens.headline(16).monospacedDigit())
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, SpacingTokens.sp4)
        .shadow(color: ColorTokens.Brand.primary.opacity(0.4), radius: 6, y: 1)
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview("HSBreathingOrb") {
    ZStack {
        ColorTokens.Kid.bg.ignoresSafeArea()
        VStack(spacing: 40) {
            HSBreathingOrb(
                expansion: 1.0, ringProgress: 0.95,
                phaseTitle: "Вдох…", phaseCount: "1 · 2 · 3"
            )
            HSBreathingOrb(
                expansion: 0.0, ringProgress: 0.1,
                phaseTitle: "Выдох…", phaseCount: "1 · 2 · 3 · 4", size: 180
            )
        }
    }
}
