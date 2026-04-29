import SwiftUI

// MARK: - LyalyaState
//
// Типо-безопасный псевдоним над MascotMood для использования
// в контексте конкретных экранов. Маппинг → MascotMood прямой.
// Добавление нового состояния: обновить rivIndex в HSRiveView.swift.

public enum LyalyaState: String, CaseIterable, Sendable {
    case idle
    case waving
    case pointing
    case celebrating
    case thinking
    case explaining
    case singing
    case sad
    case happy
    case encouraging

    /// Маппинг в MascotMood для передачи в HSMascotView / HSRiveView
    public var mascotMood: MascotMood {
        switch self {
        case .idle:        return .idle
        case .waving:      return .waving
        case .pointing:    return .pointing
        case .celebrating: return .celebrating
        case .thinking:    return .thinking
        case .explaining:  return .explaining
        case .singing:     return .singing
        case .sad:         return .sad
        case .happy:       return .happy
        case .encouraging: return .encouraging
        }
    }

    /// SF Symbol / emoji fallback для каждого состояния
    /// (используется в accessibilityLabel и в SwiftUI fallback UI)
    public var fallbackEmoji: String {
        switch self {
        case .idle:        return "🦋"
        case .waving:      return "👋"
        case .celebrating: return "🎉"
        case .thinking:    return "🤔"
        case .explaining:  return "📢"
        case .singing:     return "🎵"
        case .sad:         return "😢"
        case .pointing:    return "👆"
        case .happy:       return "😊"
        case .encouraging: return "💪"
        }
    }

    /// Человекочитаемое описание (для Preview / accessibility)
    public var localizedDescription: String {
        switch self {
        case .idle:        return "Покой"
        case .waving:      return "Привет"
        case .pointing:    return "Указывает"
        case .celebrating: return "Праздник"
        case .thinking:    return "Думает"
        case .explaining:  return "Объясняет"
        case .singing:     return "Поёт"
        case .sad:         return "Грустит"
        case .happy:       return "Радость"
        case .encouraging: return "Поддержка"
        }
    }
}

// MARK: - LyalyaMascotView
//
// Высокоуровневая обёртка над HSMascotView.
//
// API для экранов:
//   LyalyaMascotView(state: .celebrating, size: 160)
//   LyalyaMascotView(state: .explaining, size: 120, mouthAmplitude: $amplitude)
//   LyalyaMascotView(state: .idle, onTap: { ... })
//
// Lip-sync: передай Binding<Float> (0.0–1.0) в mouthAmplitude
//           для синхронизации с TTS/аудиоамплитудой.
//
// Reduced Motion: обрабатывается внутри HSMascotView → HSRiveView.

public struct LyalyaMascotView: View {

    // MARK: - Public API

    public var state: LyalyaState
    public var size: CGFloat
    public var mouthAmplitude: Binding<Float>?
    public var pointingDirection: PointingDirection
    public var onTap: (() -> Void)?

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(LyalyaCustomizationStorage.self) private var customization: LyalyaCustomizationStorage?

    // MARK: - Breathing animation state

    @State private var breathingScale: CGFloat = 1.0

    // MARK: - Init

    public init(
        state: LyalyaState = .idle,
        size: CGFloat = 120,
        mouthAmplitude: Binding<Float>? = nil,
        pointingDirection: PointingDirection = .up,
        onTap: (() -> Void)? = nil
    ) {
        self.state = state
        self.size = size
        self.mouthAmplitude = mouthAmplitude
        self.pointingDirection = pointingDirection
        self.onTap = onTap
    }

    // MARK: - Body

    public var body: some View {
        ZStack(alignment: .top) {
            HSMascotView(
                mood: state.mascotMood,
                size: size,
                audioAmplitude: mouthAmplitude,
                pointingDirection: pointingDirection
            )
            .colorMultiply(skinTintColor)

            skinDecorativeOverlay
        }
        .frame(width: size, height: size)
        .scaleEffect(breathingScale)
        .contentShape(Rectangle())
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(MotionTokens.idlePulse) {
                breathingScale = 1.02
            }
        }
        .onTapGesture {
            onTap?()
        }
        .animation(
            reduceMotion ? .none : MotionTokens.spring,
            value: state
        )
        .animation(
            reduceMotion ? .none : MotionTokens.spring,
            value: customization?.skin
        )
        .animation(
            reduceMotion ? .none : MotionTokens.spring,
            value: customization?.colorVariant
        )
        .accessibilityLabel(String(localized: "lyalya.mascot.accessibility.label"))
        .accessibilityHint(
            state == .idle
                ? String(localized: "lyalya.mascot.accessibility.hint.idle")
                : ""
        )
        .accessibilityAddTraits(onTap != nil ? .isButton : [])
    }

    // MARK: - Skin tint

    private var skinTintColor: Color {
        switch customization?.colorVariant {
        case .warm:
            return Color(red: 1.0, green: 0.95, blue: 0.95)
        case .cool:
            return Color(red: 0.95, green: 0.97, blue: 1.0)
        case .nature:
            return Color(red: 0.95, green: 1.0, blue: 0.95)
        case .none:
            return .white
        }
    }

    // MARK: - Decorative overlay

    @ViewBuilder
    private var skinDecorativeOverlay: some View {
        let overlaySize = size * 0.22
        let topOffset = -(size * 0.42)

        switch customization?.skin {
        case .princess:
            Image(systemName: "crown.fill")
                .font(.system(size: overlaySize))
                .foregroundStyle(Color.yellow)
                .shadow(color: .yellow.opacity(0.4), radius: 3, y: 1)
                .offset(y: topOffset)
                .accessibilityHidden(true)
        case .scientist:
            Image(systemName: "eyeglasses")
                .font(.system(size: overlaySize * 1.2))
                .foregroundStyle(Color.gray)
                .offset(y: -(size * 0.08))
                .accessibilityHidden(true)
        case .athlete:
            Image(systemName: "figure.run")
                .font(.system(size: overlaySize))
                .foregroundStyle(Color.red)
                .offset(y: topOffset)
                .accessibilityHidden(true)
        case .artist:
            Image(systemName: "paintbrush.pointed.fill")
                .font(.system(size: overlaySize))
                .foregroundStyle(Color.purple)
                .offset(y: topOffset)
                .accessibilityHidden(true)
        case .classic, .none:
            EmptyView()
        }
    }
}

// MARK: - LyalyaMascotView + Convenience modifiers

public extension LyalyaMascotView {

    /// Быстрое переключение состояния с bouncy-переходом
    func transition(to newState: LyalyaState) -> LyalyaMascotView {
        var copy = self
        copy.state = newState
        return copy
    }

    /// Setter lip-sync без Binding (одиночное float значение, не реактивный)
    /// Используй mouthAmplitude: $binding для реактивного варианта
    func setMouthOpen(_ amplitude: Float) -> LyalyaMascotView {
        self
    }
}

// MARK: - LyalyaState + Equatable (для animation value)

extension LyalyaState: Equatable {}

// MARK: - Preview

#Preview("LyalyaMascotView — все состояния") {
    ScrollView(.horizontal) {
        HStack(spacing: 20) {
            ForEach(LyalyaState.allCases, id: \.rawValue) { lyalyaState in
                VStack(spacing: 8) {
                    LyalyaMascotView(state: lyalyaState, size: 100)
                    Text(lyalyaState.fallbackEmoji)
                        .font(.title2)
                    Text(lyalyaState.localizedDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
                .frame(width: 110)
            }
        }
        .padding()
    }
    .environment(LyalyaCustomizationStorage.shared)
}

#Preview("LyalyaMascotView — skin variants") {
    VStack(spacing: 24) {
        Text("Варианты облика Ляли")
            .font(.headline)

        HStack(spacing: 20) {
            ForEach(LyalyaSkin.allCases) { skin in
                VStack(spacing: 6) {
                    LyalyaMascotView(state: .idle, size: 80)
                        .environment(LyalyaCustomizationStorage.shared)
                    Text(skin.localizedName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
                .frame(width: 90)
            }
        }

        HStack(spacing: 20) {
            ForEach(LyalyaColorVariant.allCases) { colorVariant in
                VStack(spacing: 6) {
                    LyalyaMascotView(state: .idle, size: 60)
                        .environment(LyalyaCustomizationStorage.shared)
                    Text(colorVariant.localizedName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
                .frame(width: 80)
            }
        }
    }
    .padding()
}

#Preview("LyalyaMascotView — lip-sync") {
    @Previewable @State var amplitude: Float = 0
    @Previewable @State var lyalyaState: LyalyaState = .explaining

    VStack(spacing: 24) {
        LyalyaMascotView(
            state: lyalyaState,
            size: 160,
            mouthAmplitude: $amplitude,
            onTap: {
                let states = LyalyaState.allCases
                let current = states.firstIndex(of: lyalyaState) ?? 0
                lyalyaState = states[(current + 1) % states.count]
            }
        )

        Text("Состояние: \(lyalyaState.localizedDescription) \(lyalyaState.fallbackEmoji)")
            .font(.headline)

        VStack(alignment: .leading, spacing: 4) {
            Text("Амплитуда рта: \(String(format: "%.2f", amplitude))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: $amplitude, in: 0...1)
        }
        .padding(.horizontal)

        Text("Нажми на Лялю → следующее состояние")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
    .padding()
}

#Preview("LyalyaMascotView — celebrating") {
    LyalyaMascotView(state: .celebrating, size: 200)
        .padding(40)
        .background(Color.yellow.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 24))
}
