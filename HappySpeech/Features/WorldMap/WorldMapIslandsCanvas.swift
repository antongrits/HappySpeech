import SwiftUI

// MARK: - WorldMapIslandsCanvas (redesign — vertical quest path)
//
// «Карта островов звуков» — вертикальный путь-квест снизу вверх (redesign-spec
// §1). Раньше острова позиционировались абсолютно в GeometryReader/ZStack и
// сбивались в левый верхний угол с перекрытием. Теперь они выкладываются в
// VStack внутри ScrollView с зигзагом ±32pt, а соединительный bezier-путь
// рисуется позади карточек.
//
// Чистый SwiftUI: ScrollView + ZStack(ConnectingPathView, VStack of IslandCard).
// Никакой бизнес-логики — получает готовые `WorldZoneCard` из Presenter и
// пробрасывает tap наверх.

struct WorldMapIslandsCanvas: View {

    // MARK: - Inputs

    let cards: [WorldZoneCard]
    let appeared: Bool
    let reduceMotion: Bool
    let onTapZone: (String) -> Void

    // MARK: - Layout constants (redesign-spec §1.14)

    /// Карточка одного острова.
    private let cardWidth: CGFloat = 280
    private let cardHeight: CGFloat = 200
    /// Горизонтальный зигзаг-сдвиг чётных/нечётных островов.
    private let zigzag: CGFloat = SpacingTokens.xLarge   // 32pt
    /// Вертикальный зазор между карточками.
    private let cardGap: CGFloat = SpacingTokens.xLarge   // 32pt

    // MARK: - Body
    //
    // Острова выводятся снизу вверх (онтогенетический порядок: ранние звуки
    // внизу, поздние — вверху), поэтому исходный массив разворачивается.

    /// Id острова, к которому нужно прокрутить при появлении (текущий → первый
    /// открытый). Используется как `task(id:)`, чтобы scroll сработал и когда
    /// карточки приходят асинхронно после bootstrap.
    private var focusIslandId: String? {
        cards.first(where: { $0.isCurrentLocation && !$0.isLocked })?.id
            ?? cards.first(where: { !$0.isLocked })?.id
    }

    var body: some View {
        let ordered = Array(cards.reversed())

        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .top) {
                    ConnectingPathView(
                        count: ordered.count,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        cardGap: cardGap,
                        zigzag: zigzag,
                        appeared: appeared,
                        reduceMotion: reduceMotion
                    )

                    VStack(spacing: cardGap) {
                        ForEach(Array(ordered.enumerated()), id: \.element.id) { index, card in
                            IslandCard(
                                card: card,
                                reduceMotion: reduceMotion,
                                onTap: { onTapZone(card.id) }
                            )
                            .frame(width: cardWidth, height: cardHeight)
                            // Зигзаг: нечётные смещаются влево, чётные вправо.
                            .offset(x: index.isMultiple(of: 2) ? zigzag : -zigzag)
                            .frame(maxWidth: .infinity)
                            .id(card.id)
                            // Stagger entrance: scale 0.88→1, opacity 0→1.
                            .scaleEffect(appeared ? 1.0 : 0.88)
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                reduceMotion
                                    ? .easeOut(duration: 0.2)
                                    : MotionTokens.playful.delay(Double(index) * 0.08),
                                value: appeared
                            )
                        }
                    }
                    .padding(.vertical, SpacingTokens.large)
                }
                .frame(maxWidth: .infinity)
            }
            .task(id: focusIslandId) {
                guard let target = focusIslandId else { return }
                // Скроллим к текущему острову. task(id:) перезапускается, когда
                // карточки приходят асинхронно после bootstrap. Небольшая задержка —
                // чтобы VStack успел разложиться и scrollTo попал в верный offset.
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) {
                    proxy.scrollTo(target, anchor: .center)
                }
            }
        }
    }
}

// MARK: - IslandCard
//
// Одна карточка острова: цветной круг с тематической иллюстрацией в верхней
// половине, 270° дуга прогресса, флаг «Ты здесь» и плашка-лейбл СНИЗУ круга
// (не перекрывает иллюстрацию). redesign-spec §1.3.

private struct IslandCard: View {

    let card: WorldZoneCard
    let reduceMotion: Bool
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var pulse = false
    @State private var shake: CGFloat = 0

    private let circleDiameter: CGFloat = 160
    private let arcDiameter: CGFloat = 168
    private let illustrationSize: CGFloat = 96

    var body: some View {
        ZStack(alignment: .center) {
            // Pulsing border под текущим островом — «здесь стоит ребёнок».
            if card.isCurrentLocation && !card.isLocked {
                Circle()
                    .stroke(ColorTokens.Brand.primary, lineWidth: 2)
                    .frame(width: arcDiameter + 12, height: arcDiameter + 12)
                    .opacity(pulse ? 0.0 : 0.6)
                    .scaleEffect(pulse ? 1.12 : 1.0)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 1.6).repeatForever(autoreverses: false),
                        value: pulse
                    )
                    .onAppear { pulse = true }
                    .accessibilityHidden(true)
            }

            // Цветной круг острова.
            Circle()
                .fill(gradient)
                .frame(width: circleDiameter, height: circleDiameter)
                .shadow(color: ColorTokens.Overlay.shadow, radius: 8, y: 4)

            // Тематическая иллюстрация в верхней половине круга.
            Image(illustrationAsset)
                .resizable()
                .scaledToFit()
                .frame(width: illustrationSize, height: illustrationSize)
                .grayscale(card.isLocked ? 1.0 : 0.0)
                .opacity(card.isLocked ? 0.4 : 1.0)
                .offset(y: -32)
                .accessibilityHidden(true)

            // Замок поверх locked-острова.
            if card.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .shadow(color: ColorTokens.Overlay.shadowMedium, radius: 2, y: 1)
                    .accessibilityHidden(true)
            }

            // 270° дуга прогресса поверх круга (только у открытых островов).
            if !card.isLocked {
                ProgressArc(progress: card.progress)
                    .stroke(arcTint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: arcDiameter, height: arcDiameter)
                    .animation(reduceMotion ? nil : MotionTokens.smooth, value: card.progress)
            }

            // Золотая звезда у пройденного острова.
            if card.isCompleted && !card.isLocked {
                completedStar
                    .offset(x: circleDiameter / 2 - 12, y: -circleDiameter / 2 + 12)
            }

            // Флаг «Ты здесь» — правый верхний угол, не перекрывает иллюстрацию.
            if card.isCurrentLocation && !card.isLocked {
                youAreHereFlag
                    .offset(x: 48, y: -80)
                    .accessibilityHidden(true)
            }

            // Плашка-лейбл СНИЗУ круга (выступает ниже, y +16 от центра круга).
            labelPlate
                .offset(y: circleDiameter / 2 + 16)
        }
        .frame(width: 280, height: 200)
        .contentShape(Rectangle())
        .offset(x: shake)
        .scaleEffect(isPressed && !reduceMotion ? 0.94 : 1.0)
        .animation(reduceMotion ? nil : MotionTokens.pressSpring, value: isPressed)
        .onTapGesture { handleTap() }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.accessibilityLabel)
        .accessibilityHint(card.accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Tap

    private func handleTap() {
        if card.isLocked && !reduceMotion {
            // Лёгкий shake для locked-острова (0→−4→4→0, ~150ms).
            Task { @MainActor in
                withAnimation(MotionTokens.snappy) { shake = -4 }
                try? await Task.sleep(for: .milliseconds(70))
                withAnimation(MotionTokens.snappy) { shake = 4 }
                try? await Task.sleep(for: .milliseconds(70))
                withAnimation(MotionTokens.snappy) { shake = 0 }
            }
        }
        onTap()
    }

    // MARK: - Label plate (below circle)

    private var labelPlate: some View {
        VStack(spacing: 2) {
            Text(card.name)
                .font(TypographyTokens.headline(17).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            statusLine
        }
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.vertical, SpacingTokens.tiny)
        .background(
            Capsule(style: .continuous)
                .fill(ColorTokens.Kid.surface)
                .shadow(color: ColorTokens.Overlay.shadow, radius: 6, y: 3)
        )
        .frame(maxWidth: 240)
    }

    @ViewBuilder
    private var statusLine: some View {
        if card.isLocked {
            Text(String(localized: "worldmap.island.locked"))
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else if !card.soundsLabel.isEmpty {
            Text(card.soundsLabel)
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else {
            Text(card.progressLabel)
                .font(TypographyTokens.caption(13).weight(.semibold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    // MARK: - «Ты здесь» flag

    private var youAreHereFlag: some View {
        Text(String(localized: "worldmap.island.current"))
            .font(TypographyTokens.caption(13).weight(.bold))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, SpacingTokens.small)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(ColorTokens.Brand.primary)
                    .shadow(color: ColorTokens.Brand.primary.opacity(0.4), radius: 4, y: 2)
            )
    }

    // MARK: - Completed star

    private var completedStar: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.Kid.surface)
                .frame(width: 30, height: 30)
                .shadow(color: ColorTokens.Overlay.shadowMedium, radius: 2, y: 1)
            Image(systemName: "star.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(ColorTokens.Brand.gold)
                .hsSymbolEffect(.bounce, value: card.isCompleted)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Visual mapping (zone id → illustration + gradient)

    private var illustrationAsset: String {
        WorldMapIslandVisuals.illustration(for: card.id)
    }

    private var gradient: LinearGradient {
        if card.isLocked {
            return LinearGradient(
                colors: [
                    ColorTokens.Kid.bgSoft,
                    ColorTokens.Kid.inkSoft.opacity(0.45)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        let pair = WorldMapIslandVisuals.gradientColors(for: card.id)
        return LinearGradient(
            colors: [pair.from, pair.to],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var arcTint: Color {
        WorldMapIslandVisuals.arcTint(for: card.id)
    }
}

// MARK: - ProgressArc
//
// 270° дуга прогресса: трек от −135° до +135° (старт снизу-слева), заполнение
// пропорционально progress. redesign-spec §1.4.

private struct ProgressArc: Shape {

    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let startAngle = Angle.degrees(135)            // снизу-слева
        let sweep = 270.0 * max(0, min(1, progress))
        let endAngle = Angle.degrees(135 + sweep)

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

// MARK: - ConnectingPathView
//
// Пунктирный bezier-зигзаг между центрами кругов островов (позади карточек).
// redesign-spec §1.5. Центры рассчитываются из тех же констант лейаута, что и
// в `IslandsStackView`, чтобы линия совпадала с расположением кругов.

private struct ConnectingPathView: View {

    let count: Int
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let cardGap: CGFloat
    let zigzag: CGFloat
    let appeared: Bool
    let reduceMotion: Bool

    private let circleCenterFromCardTop: CGFloat = 84   // ≈ круг по центру верх. зоны карточки

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            Path { path in
                let centers = islandCenters(in: width)
                guard let first = centers.first else { return }
                path.move(to: first)
                for idx in 1..<centers.count {
                    let prev = centers[idx - 1]
                    let curr = centers[idx]
                    let midY = (prev.y + curr.y) / 2
                    path.addCurve(
                        to: curr,
                        control1: CGPoint(x: prev.x, y: midY),
                        control2: CGPoint(x: curr.x, y: midY)
                    )
                }
            }
            .stroke(
                ColorTokens.Brand.lilac.opacity(0.5),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [6, 10])
            )
        }
        .opacity(appeared ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.6).delay(0.15), value: appeared)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func islandCenters(in width: CGFloat) -> [CGPoint] {
        guard count >= 1 else { return [] }
        let axisX = width / 2
        var result: [CGPoint] = []
        // VStack начинается с верхнего padding (SpacingTokens.large) внутри ZStack.
        let topPadding = SpacingTokens.large
        for index in 0..<count {
            let cardTop = topPadding + CGFloat(index) * (cardHeight + cardGap)
            let y = cardTop + circleCenterFromCardTop
            let x = axisX + (index.isMultiple(of: 2) ? zigzag : -zigzag)
            result.append(CGPoint(x: x, y: y))
        }
        return result
    }
}

// MARK: - WorldMapIslandVisuals (View-layer mapping helper)
//
// Маппинг id зоны → ключ иллюстрации острова и градиент группы звуков.
// redesign-spec §1.10 / §1.11. Все цвета — токены DesignSystem.

enum WorldMapIslandVisuals {

    static func illustration(for zoneId: String) -> String {
        switch zoneId {
        case "zone-whistling":  return "island_whistling"
        case "zone-hissing":    return "island_hissing"
        case "zone-affricates": return "island_affricate"
        case "zone-sonorant":   return "island_sonorant"
        case "zone-velar":      return "island_velar"
        case "zone-grammar":    return "island_grammar"
        case "zone-vowels":     return "island_grammar"   // гласные → облачный мотив
        default:                return "island_grammar"
        }
    }

    static func gradientColors(for zoneId: String) -> (from: Color, to: Color) {
        switch zoneId {
        case "zone-whistling":
            // Свистящие: тёплый жёлтый (SoundWhistlingHue = синий → заменён на butter/gold)
            return (ColorTokens.Brand.butter.opacity(0.45), ColorTokens.Brand.gold)
        case "zone-hissing":
            return (ColorTokens.SoundFamilyColors.Hissing.bg,
                    ColorTokens.SoundFamilyColors.Hissing.hue)
        case "zone-sonorant":
            // Сонорные: тёплый лавандовый (SoundSonorantHue = зелёный → заменён на lilac)
            return (ColorTokens.Brand.lilac.opacity(0.45), ColorTokens.Brand.lilac)
        case "zone-velar":
            return (ColorTokens.SoundFamilyColors.Velar.bg,
                    ColorTokens.SoundFamilyColors.Velar.hue)
        case "zone-vowels":
            return (ColorTokens.SoundFamilyColors.Vowels.bg,
                    ColorTokens.SoundFamilyColors.Vowels.hue)
        case "zone-affricates":
            return (ColorTokens.Brand.butter.opacity(0.45), ColorTokens.Brand.gold)
        case "zone-grammar":
            return (ColorTokens.Brand.gold.opacity(0.45), ColorTokens.Brand.gold)
        default:
            return (ColorTokens.Brand.gold.opacity(0.45), ColorTokens.Brand.gold)
        }
    }

    static func arcTint(for zoneId: String) -> Color {
        switch zoneId {
        case "zone-whistling":  return ColorTokens.Brand.gold        // было Whistling.hue (синий)
        case "zone-hissing":    return ColorTokens.SoundFamilyColors.Hissing.hue
        case "zone-sonorant":   return ColorTokens.Brand.lilac       // было Sonorant.hue (зелёный)
        case "zone-velar":      return ColorTokens.SoundFamilyColors.Velar.hue
        case "zone-vowels":     return ColorTokens.SoundFamilyColors.Vowels.hue
        case "zone-affricates": return ColorTokens.Brand.gold
        case "zone-grammar":    return ColorTokens.Brand.gold         // было Brand.sky
        default:                return ColorTokens.Brand.gold
        }
    }
}

// MARK: - Preview

#Preview("WorldMapIslandsCanvas — vertical path") {
    let mockCards: [WorldZoneCard] = [
        .init(
            id: "zone-vowels",
            name: String(localized: "worldmap.island.vowels"),
            icon: "music.note",
            soundsLabel: "А · О · У · И",
            progress: 1.0,
            progressLabel: "100%",
            lessonsLabel: "10 / 10",
            colorName: "primary",
            isLocked: false,
            isHighlighted: false,
            position: .zero,
            isCurrentLocation: false,
            isCompleted: true,
            accessibilityLabel: String(localized: "worldmap.preview.vowels.a11y"),
            accessibilityHint: ""
        ),
        .init(
            id: "zone-whistling",
            name: String(localized: "worldmap.island.sibilants"),
            icon: "leaf.fill",
            soundsLabel: "С · З · Ц",
            progress: 0.65,
            progressLabel: "65%",
            lessonsLabel: "13 / 20",
            colorName: "butter",
            isLocked: false,
            isHighlighted: false,
            position: .zero,
            isCurrentLocation: false,
            isCompleted: false,
            accessibilityLabel: String(localized: "worldmap.preview.sibilants.a11y"),
            accessibilityHint: ""
        ),
        .init(
            id: "zone-hissing",
            name: String(localized: "worldmap.island.hissing"),
            icon: "ant.fill",
            soundsLabel: "Ш · Ж",
            progress: 0.30,
            progressLabel: "30%",
            lessonsLabel: "6 / 20",
            colorName: "gold",
            isLocked: false,
            isHighlighted: false,
            position: .zero,
            isCurrentLocation: true,
            isCompleted: false,
            accessibilityLabel: String(localized: "worldmap.preview.hissing.a11y"),
            accessibilityHint: ""
        ),
        .init(
            id: "zone-sonorant",
            name: String(localized: "worldmap.island.sonorant.r"),
            icon: "flame.fill",
            soundsLabel: "Р · Рь · Л",
            progress: 0.10,
            progressLabel: "10%",
            lessonsLabel: "2 / 20",
            colorName: "lilac",
            isLocked: false,
            isHighlighted: false,
            position: .zero,
            isCurrentLocation: false,
            isCompleted: false,
            accessibilityLabel: String(localized: "worldmap.preview.sonorant.a11y"),
            accessibilityHint: ""
        ),
        .init(
            id: "zone-velar",
            name: String(localized: "worldmap.island.velar"),
            icon: "bird.fill",
            soundsLabel: "К · Г · Х",
            progress: 0.0,
            progressLabel: "0%",
            lessonsLabel: "0 / 15",
            colorName: "primary",
            isLocked: true,
            isHighlighted: false,
            position: .zero,
            isCurrentLocation: false,
            isCompleted: false,
            accessibilityLabel: String(localized: "worldmap.preview.velar.a11y"),
            accessibilityHint: ""
        ),
        .init(
            id: "zone-grammar",
            name: String(localized: "worldmap.preview.grammar"),
            icon: "books.vertical.fill",
            soundsLabel: String(localized: "worldmap.preview.cases"),
            progress: 0.0,
            progressLabel: "0%",
            lessonsLabel: "0 / 12",
            colorName: "gold",
            isLocked: true,
            isHighlighted: false,
            position: .zero,
            isCurrentLocation: false,
            isCompleted: false,
            accessibilityLabel: String(localized: "worldmap.preview.grammar.a11y"),
            accessibilityHint: ""
        )
    ]
    return WorldMapIslandsCanvas(
        cards: mockCards,
        appeared: true,
        reduceMotion: false,
        onTapZone: { _ in }
    )
    .background(ColorTokens.Kid.bg)
}
