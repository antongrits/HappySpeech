import SwiftUI

// MARK: - WorldMapIslandsCanvas
//
// «Остров звуков» — визуальный канвас с координатами зон, соединительной
// dash-линией маршрута и Ляля-маскотом на текущем острове.
//
// Используется в WorldMapView как альтернатива grid-сетке (по флагу).
// Сетка остаётся как fallback для accessibility size class и iPad.
//
// Чистый SwiftUI: GeometryReader + ZStack + Path. Никакой бизнес-логики —
// получает уже готовые `WorldZoneCard` из Presenter и пробрасывает tap наверх.

struct WorldMapIslandsCanvas: View {

    // MARK: - Inputs

    let cards: [WorldZoneCard]
    let appeared: Bool
    let reduceMotion: Bool
    let onTapZone: (String) -> Void

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let canvasSize = proxy.size
            ZStack {
                routePath(in: canvasSize)
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    islandNode(card: card, index: index, in: canvasSize)
                }
            }
        }
        .frame(height: canvasHeight)
    }

    // MARK: - Layout constants

    /// Высота канваса. На стандартный iPhone 17 Pro даёт читаемое расположение.
    private var canvasHeight: CGFloat { 520 }
    private var nodeDiameter: CGFloat { 96 }
    private var ringDiameter: CGFloat { 116 }

    // MARK: - Route path (dash line between islands)

    @ViewBuilder
    private func routePath(in size: CGSize) -> some View {
        Path { path in
            let points = cards.map { absolutePoint(for: $0.position, in: size) }
            guard let first = points.first else { return }
            path.move(to: first)
            for next in points.dropFirst() {
                path.addLine(to: next)
            }
        }
        .stroke(
            ColorTokens.Brand.lilac.opacity(0.55),
            style: StrokeStyle(
                lineWidth: 3,
                lineCap: .round,
                lineJoin: .round,
                dash: [6, 10]
            )
        )
        .opacity(appeared ? 1 : 0)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.6).delay(0.15),
            value: appeared
        )
    }

    // MARK: - Island node

    @ViewBuilder
    private func islandNode(card: WorldZoneCard, index: Int, in size: CGSize) -> some View {
        let center = absolutePoint(for: card.position, in: size)
        IslandBubble(
            card: card,
            diameter: nodeDiameter,
            ringDiameter: ringDiameter,
            reduceMotion: reduceMotion,
            onTap: { onTapZone(card.id) }
        )
        .position(center)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.6)
        .animation(
            reduceMotion
                ? nil
                : .spring(response: 0.55, dampingFraction: 0.74)
                    .delay(0.18 + Double(index) * 0.08),
            value: appeared
        )
    }

    // MARK: - Helpers

    /// Перевод нормализованной координаты [0..1] в пиксели канваса с inset.
    private func absolutePoint(for normalized: CGPoint, in size: CGSize) -> CGPoint {
        let inset: CGFloat = nodeDiameter / 2 + 8
        let usableWidth = max(size.width - inset * 2, 1)
        let usableHeight = max(size.height - inset * 2, 1)
        let absX = inset + normalized.x * usableWidth
        let absY = inset + normalized.y * usableHeight
        return CGPoint(x: absX, y: absY)
    }
}

// MARK: - IslandBubble
//
// Один остров-кружок: цветной круг с emoji внутри, progress-ring вокруг,
// плашка с названием снизу и Ляля-маскот сверху для текущего острова.

private struct IslandBubble: View {

    let card: WorldZoneCard
    let diameter: CGFloat
    let ringDiameter: CGFloat
    let reduceMotion: Bool
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Pulsing ring под текущим островом — «здесь стоит ребёнок».
            if card.isCurrentLocation && !card.isLocked {
                Circle()
                    .stroke(ColorTokens.Brand.primary, lineWidth: 3)
                    .frame(width: ringDiameter + 14, height: ringDiameter + 14)
                    .opacity(pulse ? 0.0 : 0.55)
                    .scaleEffect(pulse ? 1.18 : 1.0)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 1.6).repeatForever(autoreverses: false),
                        value: pulse
                    )
                    .onAppear { pulse = true }
                    .accessibilityHidden(true)
            }

            // Progress ring вокруг острова.
            ringLayer
                .frame(width: ringDiameter, height: ringDiameter)

            // Цветной диск-остров.
            Button(action: onTap) {
                discContent
            }
            .buttonStyle(.plain)
            .frame(width: diameter, height: diameter)
            .scaleEffect(isPressed && !reduceMotion ? 0.94 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
                value: isPressed
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )

            // Подпись и Ляля сверху.
            overlayLabels
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.accessibilityLabel)
        .accessibilityHint(card.accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Disc

    private var discContent: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: card.isLocked
                            ? [
                                ColorTokens.Kid.inkSoft.opacity(0.55),
                                ColorTokens.Kid.inkSoft.opacity(0.35)
                            ]
                            : [
                                card.backgroundColor,
                                card.backgroundColor.opacity(0.78)
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(
                    color: card.backgroundColor.opacity(card.isLocked ? 0 : 0.32),
                    radius: 10, x: 0, y: 5
                )

            if card.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Text(card.icon)
                    .font(.system(size: 38))
                    .accessibilityHidden(true)
            }

            if card.isCompleted && !card.isLocked {
                completedBadge
                    .offset(x: diameter / 2 - 10, y: -diameter / 2 + 10)
            }
        }
    }

    // MARK: - Progress ring

    @ViewBuilder
    private var ringLayer: some View {
        if !card.isLocked {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: max(0.001, min(1, card.progress)))
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 0.7),
                        value: card.progress
                    )
            }
        } else {
            Circle()
                .stroke(
                    ColorTokens.Kid.line.opacity(0.5),
                    style: StrokeStyle(lineWidth: 5, dash: [4, 6])
                )
        }
    }

    // MARK: - Overlay labels

    private var overlayLabels: some View {
        VStack(spacing: SpacingTokens.tiny) {
            // Ляля над текущим островом.
            if card.isCurrentLocation && !card.isLocked {
                LyalyaMascotView(state: .waving, size: 56)
                    .offset(y: 4)
                    .accessibilityHidden(true)
            } else {
                Color.clear.frame(height: 1)
            }

            Spacer(minLength: 0)

            // Название и подпись «Ты здесь / Заблокировано / Пройдено».
            VStack(spacing: 2) {
                Text(card.name)
                    .font(TypographyTokens.caption(12).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                statusChip
            }
            .frame(maxWidth: 140)
            .padding(.horizontal, SpacingTokens.tiny)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .offset(y: ringDiameter / 2 + 16)
        }
        .frame(width: 160, height: ringDiameter + 80)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var statusChip: some View {
        if card.isLocked {
            Text(String(localized: "worldmap.island.locked"))
                .font(TypographyTokens.caption(10).weight(.medium))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        } else if card.isCurrentLocation {
            Text(String(localized: "worldmap.island.current"))
                .font(TypographyTokens.caption(10).weight(.semibold))
                .foregroundStyle(ColorTokens.Brand.primary)
        } else if card.isCompleted {
            Text(String(localized: "worldmap.island.completed"))
                .font(TypographyTokens.caption(10).weight(.semibold))
                .foregroundStyle(ColorTokens.Brand.mint)
        } else {
            Text(card.progressLabel)
                .font(TypographyTokens.mono(10).weight(.semibold))
                .foregroundStyle(card.backgroundColor)
        }
    }

    // MARK: - Completed badge (gold star)

    private var completedBadge: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.Brand.gold)
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview("WorldMapIslandsCanvas — populated") {
    let mockCards: [WorldZoneCard] = [
        .init(
            id: "z1",
            name: String(localized: "worldmap.island.vowels"),
            icon: "🎵",
            soundsLabel: "А · О · У · И",
            progress: 1.0,
            progressLabel: "100%",
            lessonsLabel: "10 / 10",
            backgroundColor: ColorTokens.Brand.sky,
            foregroundColor: .white,
            isLocked: false,
            isHighlighted: false,
            position: CGPoint(x: 0.18, y: 0.86),
            isCurrentLocation: false,
            isCompleted: true,
            accessibilityLabel: "Гласные",
            accessibilityHint: ""
        ),
        .init(
            id: "z2",
            name: String(localized: "worldmap.island.sibilants"),
            icon: "🐍",
            soundsLabel: "С · З · Ц",
            progress: 0.65,
            progressLabel: "65%",
            lessonsLabel: "13 / 20",
            backgroundColor: ColorTokens.Brand.mint,
            foregroundColor: .white,
            isLocked: false,
            isHighlighted: false,
            position: CGPoint(x: 0.74, y: 0.74),
            isCurrentLocation: false,
            isCompleted: false,
            accessibilityLabel: "Свистящие",
            accessibilityHint: ""
        ),
        .init(
            id: "z3",
            name: String(localized: "worldmap.island.hissing"),
            icon: "🐝",
            soundsLabel: "Ш · Ж",
            progress: 0.30,
            progressLabel: "30%",
            lessonsLabel: "6 / 20",
            backgroundColor: ColorTokens.Brand.butter,
            foregroundColor: ColorTokens.Kid.ink,
            isLocked: false,
            isHighlighted: false,
            position: CGPoint(x: 0.30, y: 0.56),
            isCurrentLocation: true,
            isCompleted: false,
            accessibilityLabel: "Шипящие",
            accessibilityHint: ""
        ),
        .init(
            id: "z4",
            name: String(localized: "worldmap.island.sonorant.r"),
            icon: "🐯",
            soundsLabel: "Р · Рь",
            progress: 0.10,
            progressLabel: "10%",
            lessonsLabel: "2 / 20",
            backgroundColor: ColorTokens.Brand.lilac,
            foregroundColor: .white,
            isLocked: false,
            isHighlighted: false,
            position: CGPoint(x: 0.78, y: 0.40),
            isCurrentLocation: false,
            isCompleted: false,
            accessibilityLabel: "Сонор Р",
            accessibilityHint: ""
        ),
        .init(
            id: "z5",
            name: String(localized: "worldmap.island.velar"),
            icon: "🦆",
            soundsLabel: "К · Г · Х",
            progress: 0.0,
            progressLabel: "0%",
            lessonsLabel: "0 / 15",
            backgroundColor: ColorTokens.Brand.primary,
            foregroundColor: .white,
            isLocked: true,
            isHighlighted: false,
            position: CGPoint(x: 0.32, y: 0.24),
            isCurrentLocation: false,
            isCompleted: false,
            accessibilityLabel: "Заднеязычные",
            accessibilityHint: ""
        ),
        .init(
            id: "z6",
            name: "Грамматика",
            icon: "📚",
            soundsLabel: "Падежи",
            progress: 0.0,
            progressLabel: "0%",
            lessonsLabel: "0 / 12",
            backgroundColor: ColorTokens.Brand.gold,
            foregroundColor: ColorTokens.Kid.ink,
            isLocked: true,
            isHighlighted: false,
            position: CGPoint(x: 0.78, y: 0.10),
            isCurrentLocation: false,
            isCompleted: false,
            accessibilityLabel: "Грамматика",
            accessibilityHint: ""
        )
    ]
    return WorldMapIslandsCanvas(
        cards: mockCards,
        appeared: true,
        reduceMotion: false,
        onTapZone: { _ in }
    )
    .padding(.horizontal, SpacingTokens.screenEdge)
    .background(ColorTokens.Kid.bg)
}
