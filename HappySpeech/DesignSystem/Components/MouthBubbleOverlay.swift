import SwiftUI

// MARK: - MouthBubbleOverlay

/// Real-time lip-sync оверлей для маскота Ляли.
/// Отображается поверх HSMascotView когда ARFaceAnchor активен (isTracking = true).
///
/// Поведение:
///  - openValue 0...1 → вертикальное растяжение формы рта.
///  - viseme → форма: neutral=овал, open=высокий, wide=плоский, rounded=круг, smile=дуга.
///  - Reduced Motion: анимация отключается, форма статична.
///  - Battery: данный View не запускает таймеры — реагирует только на входящие значения.
public struct MouthBubbleOverlay: View {

    // MARK: - Inputs

    /// Открытость рта 0...1 (из MascotLipSyncState.mouthOpen).
    public let openValue: Float

    /// Текущая визема (из MascotLipSyncState.viseme).
    public let viseme: LipSyncViseme

    /// Базовый размер маскота (вписывается в frame size * mouthSizeRatio).
    public let mascotSize: CGFloat

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Init

    public init(openValue: Float, viseme: LipSyncViseme, mascotSize: CGFloat = 120) {
        self.openValue = openValue
        self.viseme = viseme
        self.mascotSize = mascotSize
    }

    // MARK: - Constants

    private var scale: CGFloat { mascotSize / 120 }

    /// Базовая ширина рта в единицах, нормированных по размеру маскота.
    private var baseWidth: CGFloat {
        switch viseme {
        case .neutral: return 8 * scale
        case .open:    return 8 * scale
        case .wide:    return 12 * scale
        case .rounded: return 7 * scale
        case .smile:   return 10 * scale
        }
    }

    /// Базовая высота рта — зависит от openValue и визема.
    private var computedHeight: CGFloat {
        let openFactor = CGFloat(openValue)
        switch viseme {
        case .neutral: return max(2 * scale, openFactor * 5 * scale)
        case .open:    return max(4 * scale, openFactor * 10 * scale)
        case .wide:    return max(2 * scale, openFactor * 3 * scale)
        case .rounded: return max(5 * scale, openFactor * 8 * scale)
        case .smile:   return max(2 * scale, openFactor * 5 * scale)
        }
    }

    /// Вертикальная позиция рта относительно центра маскота.
    private var mouthYOffset: CGFloat { -8 * scale }

    // MARK: - Body

    public var body: some View {
        ZStack {
            mouthShape
        }
        .offset(y: mouthYOffset)
    }

    // MARK: - Mouth Shape

    @ViewBuilder
    private var mouthShape: some View {
        switch viseme {
        case .smile:
            smileArcShape
        default:
            capsuleShape
        }
    }

    /// Capsule форма для neutral / open / wide / rounded.
    private var capsuleShape: some View {
        Capsule()
            .fill(ColorTokens.Brand.rose.opacity(0.85))
            .frame(
                width: baseWidth,
                height: computedHeight
            )
            .animation(
                reduceMotion ? nil : .spring(response: 0.15, dampingFraction: 0.7),
                value: openValue
            )
            .animation(
                reduceMotion ? nil : .spring(response: 0.15, dampingFraction: 0.7),
                value: viseme.rawValue
            )
    }

    /// Дуга для smile визема (широкая, немного приподнятая).
    private var smileArcShape: some View {
        let w = baseWidth + CGFloat(openValue) * 4 * scale
        let h = max(2 * scale, CGFloat(openValue) * 4 * scale)

        return ZStack {
            // Сплошное заполнение как контраст
            Path { path in
                path.move(to: CGPoint(x: -w / 2, y: 0))
                path.addQuadCurve(
                    to: CGPoint(x: w / 2, y: 0),
                    control: CGPoint(x: 0, y: -h * 2)
                )
            }
            .stroke(ColorTokens.Brand.rose.opacity(0.85), lineWidth: 1.5 * scale)

            if openValue > 0.1 {
                Capsule()
                    .fill(ColorTokens.Brand.rose.opacity(0.7))
                    .frame(width: w, height: max(1.5 * scale, h))
            }
        }
        .animation(
            reduceMotion ? nil : .spring(response: 0.15, dampingFraction: 0.7),
            value: openValue
        )
    }
}

// MARK: - Preview

#Preview("MouthBubbleOverlay — все виземы") {
    @Previewable @State var openValue: Float = 0.5

    VStack(spacing: 24) {
        Text("Открытость: \(String(format: "%.2f", openValue))")
            .font(.caption)
            .foregroundStyle(.secondary)

        Slider(value: $openValue, in: 0...1)
            .padding(.horizontal)

        HStack(spacing: 20) {
            ForEach(LipSyncViseme.allCases, id: \.rawValue) { viseme in
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 60, height: 60)
                        MouthBubbleOverlay(openValue: openValue, viseme: viseme, mascotSize: 120)
                    }
                    Text(viseme.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
            }
        }
    }
    .padding()
}
