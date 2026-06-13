import SwiftUI

// MARK: - KidGameCanvasScaffold
//
// РЕДИЗАЙН класса «kid-game-canvas» (Волна 2026-06-13).
//
// Единый каркас для интерактивных игровых экранов-«холстов»: один большой
// игровой холст в центре, тонкий верхний оверлей (выход + задание + прогресс),
// маскот с репликой, нижняя панель инструментов и коралловый CTA. По эталону
// `references/kid-game-canvas.html` — паттерн «Интерактивный холст».
//
// Покрывает: LetterTracing, LetterTrace, LetterPaintingFun, PuzzleReveal,
// SoundHunter, ObjectHunt, Rhythm, Logorhythmics, MusicalSoundDrums,
// AudioMemoryGame.
//
// Дизайн-инварианты (соблюдаются каркасом):
//   • Фон — статичный однотонный тёплый (`KidGameCanvasBackground`).
//   • Холст — спокойная тёплая карточка `KidGameCanvasSurface` (НЕ радуга).
//   • Симметричные отступы слева=справа, SE-safe (375pt), без обрезки текста.
//   • Round tools ≥ 56pt, CTA ≥ 56pt.
//   • Light + Dark через `ColorTokens.Kid`.
//   • Reduced Motion учитывается у вложенных анимаций (внутри клиентов).
//
// Использование:
// ```swift
// KidGameCanvasScaffold(
//     title: AttributedString("Обведи букву «Р»"),
//     subtitle: "Задание 3 из 5",
//     progress: 0.6,
//     onExit: { exitGame() }
// ) {
//     // holst (canvas) — игровая поверхность
// } toolbar: {
//     KidGameToolButton(systemImage: "arrow.uturn.backward", label: "Отменить") { ... }
//     KidGameToolButton(systemImage: "play.circle", label: "Показать") { ... }
//     KidGameCTAButton(title: "Дальше") { ... }
// }
// ```
@available(iOS 17.0, *)
struct KidGameCanvasScaffold<Canvas: View, Toolbar: View>: View {

    // MARK: - Input

    private let title: Text
    private let subtitle: String?
    private let progress: Double?
    private let stepDots: (current: Int, total: Int)?
    private let palette: HSMeshGradientBackground.Palette
    private let onExit: (() -> Void)?
    private let canvas: Canvas
    private let toolbar: Toolbar

    // MARK: - Init

    init(
        title: Text,
        subtitle: String? = nil,
        progress: Double? = nil,
        stepDots: (current: Int, total: Int)? = nil,
        palette: HSMeshGradientBackground.Palette = .kidWarm,
        onExit: (() -> Void)? = nil,
        @ViewBuilder canvas: () -> Canvas,
        @ViewBuilder toolbar: () -> Toolbar
    ) {
        self.title = title
        self.subtitle = subtitle
        self.progress = progress
        self.stepDots = stepDots
        self.palette = palette
        self.onExit = onExit
        self.canvas = canvas()
        self.toolbar = toolbar()
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            KidGameCanvasBackground(palette: palette)

            VStack(spacing: SpacingTokens.regular) {
                topOverlay
                    .padding(.horizontal, SpacingTokens.regular)
                    .padding(.top, SpacingTokens.tiny)

                KidGameCanvasSurface {
                    canvas
                }
                .padding(.horizontal, SpacingTokens.regular)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomToolbar
                    .padding(.horizontal, SpacingTokens.regular)
                    .padding(.bottom, SpacingTokens.tiny)
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Top overlay

    private var topOverlay: some View {
        VStack(spacing: SpacingTokens.small) {
            HStack(alignment: .center, spacing: SpacingTokens.small) {
                if let onExit {
                    KidGameRoundIconButton(
                        systemImage: "xmark",
                        accessibilityLabel: String(localized: "kidCanvas.exit"),
                        emphasised: true,
                        action: onExit
                    )
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }

                VStack(spacing: 2) {
                    title
                        .font(TypographyTokens.kidCardTitle(19))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    if let subtitle {
                        Text(subtitle)
                            .font(TypographyTokens.caption(12.5))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                // Симметричный spacer справа (зеркалит кнопку выхода).
                Color.clear.frame(width: 44, height: 44)
            }

            if let progress {
                HSProgressBar(value: progress, style: .kid, tint: ColorTokens.Brand.primary)
                    .frame(height: 12)
                    .padding(.horizontal, SpacingTokens.micro)
            }

            if let stepDots, stepDots.total > 1 {
                stepDotsRow(current: stepDots.current, total: stepDots.total)
            }
        }
    }

    private func stepDotsRow(current: Int, total: Int) -> some View {
        HStack(spacing: SpacingTokens.tiny) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(dotColor(index: index, current: current))
                    .frame(width: 7, height: 7)
                    .overlay {
                        if index == current {
                            Circle()
                                .stroke(ColorTokens.Brand.primary.opacity(0.30), lineWidth: 3)
                                .frame(width: 13, height: 13)
                        }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            format: String(localized: "kidCanvas.step %lld %lld"),
            current + 1,
            total
        ))
    }

    private func dotColor(index: Int, current: Int) -> Color {
        index <= current ? ColorTokens.Brand.primary : ColorTokens.Kid.line
    }

    // MARK: - Bottom toolbar

    private var bottomToolbar: some View {
        HStack(alignment: .center, spacing: SpacingTokens.small) {
            toolbar
        }
    }
}

// MARK: - KidGameCanvasBackground
//
// Полноэкранный статичный тёплый фон для игрового холста. Тонкий слой
// `HSMeshGradientBackground` (однотонный, без движения) поверх плоского
// kid-cream baseline.

@available(iOS 17.0, *)
struct KidGameCanvasBackground: View {

    var palette: HSMeshGradientBackground.Palette = .kidWarm

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg
            HSMeshGradientBackground(palette: palette, animated: false)
                .opacity(0.55)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - KidGameCanvasSurface
//
// Большая центральная карточка-«холст». Спокойная тёплая поверхность с очень
// мягкими «прописными» линиями и тёплой виньеткой сверху — как в эталоне.
// Без радуги; цвет — в пределах kid-cream семейства.

@available(iOS 17.0, *)
struct KidGameCanvasSurface<Content: View>: View {

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: RadiusTokens.xl, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .overlay {
                        // Тёплая виньетка сверху — едва заметный коралловый свет.
                        RoundedRectangle(cornerRadius: RadiusTokens.xl, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        ColorTokens.Brand.primaryLo.opacity(0.16),
                                        Color.clear
                                    ],
                                    center: .top,
                                    startRadius: 0,
                                    endRadius: 240
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: RadiusTokens.xl, style: .continuous)
                            .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.xl, style: .continuous))
            .shadow(color: ColorTokens.Overlay.shadow, radius: 18, x: 0, y: 8)
    }
}

// MARK: - KidGameRoundIconButton
//
// Круглая кнопка-иконка верхнего оверлея (выход / звук). 44pt hit-area.

@available(iOS 17.0, *)
struct KidGameRoundIconButton: View {

    let systemImage: String
    let accessibilityLabel: String
    var emphasised: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(emphasised ? ColorTokens.Kid.ink : ColorTokens.Kid.inkMuted)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(ColorTokens.Kid.surface)
                        .overlay(Circle().strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
                        .shadow(color: ColorTokens.Overlay.shadow, radius: 6, x: 0, y: 3)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - KidGameToolButton
//
// Тактильный круглый инструмент нижней панели с подписью (отменить / показать).
// 58pt, плитка с закруглением — как в эталоне.

@available(iOS 17.0, *)
struct KidGameToolButton: View {

    let systemImage: String
    let label: String
    var isMuted: Bool = false
    var isDisabled: Bool = false
    var accessibilityID: String? = nil
    let action: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.micro) {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 58, height: 58)
                    .background {
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .fill(ColorTokens.Kid.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                                    .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                            )
                            .shadow(color: ColorTokens.Overlay.shadow, radius: 6, x: 0, y: 3)
                    }
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1)
            .modifier(OptionalAccessibilityID(id: accessibilityID))

            Text(label)
                .font(TypographyTokens.labelRounded(11, weight: .bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }

    private var tint: Color {
        isMuted ? ColorTokens.Kid.inkSoft : ColorTokens.Kid.ink
    }
}

// MARK: - KidGameCTAButton
//
// Основной коралловый CTA нижней панели (≥56pt, full-flex). Стрелка по умолчанию.

@available(iOS 17.0, *)
struct KidGameCTAButton: View {

    let title: String
    var systemImage: String? = "arrow.right"
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var accessibilityID: String? = nil
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: {
            guard !isLoading, !isDisabled else { return }
            action()
        }) {
            HStack(spacing: SpacingTokens.tiny) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(ColorTokens.Overlay.onAccent)
                        .scaleEffect(0.85)
                } else {
                    Text(title)
                        .font(TypographyTokens.cta())
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 18, weight: .bold))
                    }
                }
            }
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 58)
            .background {
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: ColorTokens.Brand.primary.opacity(0.40), radius: 12, x: 0, y: 6)
            }
            .opacity(isDisabled ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isLoading || isDisabled)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .modifier(OptionalAccessibilityID(id: accessibilityID))
    }
}

// MARK: - OptionalAccessibilityID
//
// Применяет accessibilityIdentifier только когда он задан — сохраняет хуки
// UI-тестов без «пустых» идентификаторов на остальных кнопках.

private struct OptionalAccessibilityID: ViewModifier {
    let id: String?
    func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}

// MARK: - KidGameMascotBubble
//
// Маскот «Ляля» с репликой, прикреплённый снизу-слева холста (как в эталоне).
// Кладётся overlay'ем поверх `KidGameCanvasSurface`.

@available(iOS 17.0, *)
struct KidGameMascotBubble: View {

    let message: String
    var state: LyalyaState = .happy
    var size: CGFloat = 56

    var body: some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.tiny) {
            LyalyaMascotView(state: state, size: size)
                .accessibilityHidden(true)
            Text(message)
                .font(TypographyTokens.labelRounded(13.5, weight: .bold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.small)
                .padding(.vertical, SpacingTokens.tiny)
                .background {
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(ColorTokens.Kid.surfaceAlt)
                        .overlay(
                            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                        )
                        .shadow(color: ColorTokens.Overlay.shadow, radius: 6, x: 0, y: 3)
                }
                .padding(.bottom, SpacingTokens.tiny)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

// MARK: - KidGameTickBadge
//
// Мятная «Молодец!» галочка-плашка для угла холста (микро-фидбэк).

@available(iOS 17.0, *)
struct KidGameTickBadge: View {

    var text: String = String(localized: "kidCanvas.wellDone")

    var body: some View {
        HStack(spacing: SpacingTokens.tiny) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .frame(width: 20, height: 20)
                .background(Circle().fill(ColorTokens.Brand.mint))
            Text(text)
                .font(TypographyTokens.labelRounded(12.5, weight: .bold))
                .foregroundStyle(ColorTokens.Brand.mint)
                .lineLimit(1)
        }
        .padding(.leading, SpacingTokens.tiny)
        .padding(.trailing, SpacingTokens.small)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(ColorTokens.Brand.mint.opacity(0.14))
                .overlay(Capsule().strokeBorder(ColorTokens.Brand.mint.opacity(0.40), lineWidth: 1))
        }
        .accessibilityLabel(text)
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 17.0, *)
#Preview("KidGameCanvasScaffold") {
    KidGameCanvasScaffold(
        title: Text("Обведи букву «Р»"),
        subtitle: "Задание 3 из 5",
        progress: 0.6,
        stepDots: (current: 2, total: 5),
        onExit: {}
    ) {
        ZStack {
            Text("Р")
                .font(.system(size: 200, weight: .bold, design: .rounded))
                .foregroundStyle(ColorTokens.Kid.inkMuted.opacity(0.14))
            VStack {
                HStack {
                    Spacer()
                    KidGameTickBadge()
                }
                Spacer()
                HStack {
                    KidGameMascotBubble(message: "Веди по точкам!", state: .pointing)
                    Spacer()
                }
            }
            .padding(SpacingTokens.small)
        }
    } toolbar: {
        KidGameToolButton(systemImage: "arrow.uturn.backward", label: "Отменить", isMuted: true) {}
        KidGameToolButton(systemImage: "play.circle", label: "Показать") {}
        KidGameCTAButton(title: "Дальше") {}
    }
    .environment(\.circuitContext, .kid)
}
#endif
