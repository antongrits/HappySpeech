import SwiftUI

// MARK: - LyalyaState

/// Типо-безопасные состояния маскота Ляли для использования на экранах фич.
///
/// `LyalyaState` — высокоуровневый псевдоним над ``MascotMood``. Каждый кейс
/// маппируется в соответствующий `MascotMood` и передаётся в ``HSMascotView``
/// через ``LyalyaMascotView``.
///
/// При добавлении нового состояния обновить:
/// 1. `rivIndex` в `HSRiveView.swift` (Rive state machine input)
/// 2. `fallbackSFSymbol` — для accessibility и SwiftUI-fallback
/// 3. `localizedDescription` — для Preview и VoiceOver
///
/// ## Пример
/// ```swift
/// LyalyaMascotView(state: .celebrating, size: 160)
/// LyalyaMascotView(state: .thinking)
/// ```
///
/// ## See Also
/// - ``LyalyaMascotView``
/// - ``MascotMood``
/// - ``HSMascotView``
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

    /// SF Symbol fallback для каждого состояния
    /// (используется в accessibilityLabel и в SwiftUI fallback UI).
    /// Plan v21 Block C: эмодзи запрещены в DesignSystem — только SF Symbols.
    public var fallbackSFSymbol: String {
        switch self {
        case .idle:        return "face.smiling"
        case .waving:      return "hand.wave.fill"
        case .celebrating: return "party.popper.fill"
        case .thinking:    return "questionmark.bubble.fill"
        case .explaining:  return "speaker.wave.2.fill"
        case .singing:     return "music.note"
        case .sad:         return "face.dashed"
        case .pointing:    return "hand.point.up.left.fill"
        case .happy:       return "star.fill"
        case .encouraging: return "hands.sparkles.fill"
        }
    }

    /// Человекочитаемое описание (для Preview / accessibility).
    /// Ключи: `lyalya.state.idle`, `lyalya.state.waving`, и т.д.
    public var localizedDescription: String {
        String(localized: String.LocalizationValue("lyalya.state.\(rawValue)"))
    }
}

// MARK: - LyalyaMascotView

/// Маскот Ляля — высокоуровневая обёртка над ``HSMascotView`` с lip-sync поддержкой.
///
/// `LyalyaMascotView` — основной способ отображать маскота на экранах детского контура.
/// Принимает ``LyalyaState`` (10 состояний), размер и опциональный `Binding<Float>`
/// для real-time синхронизации рта с аудиоамплитудой (TTS или запись голоса).
///
/// Внутри использует ``HSMascotView`` (7-слойный рендер: Rive + aura + particles)
/// и `MouthBubbleOverlay` для ARFaceAnchor lip-sync, когда AR-сессия активна.
///
/// Поддерживает `@Environment(\.accessibilityReduceMotion)` — все анимации отключаются.
/// Кастомизация (скин, цвет) читается из `@Environment(LyalyaCustomizationStorage.self)`.
///
/// ## Пример
/// ```swift
/// // Стандартное использование
/// LyalyaMascotView(state: .celebrating, size: 160)
///
/// // С lip-sync при воспроизведении TTS
/// LyalyaMascotView(
///     state: .explaining,
///     size: 120,
///     mouthAmplitude: $audioAmplitude
/// )
///
/// // С tap-обработчиком
/// LyalyaMascotView(state: .idle, onTap: {
///     interactor.lyalyaTapped()
/// })
/// ```
///
/// ## See Also
/// - ``HSMascotView``
/// - ``LyalyaState``
/// - ``MascotLipSyncState``
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
    @Environment(\.mascotLipSyncState) private var lipSyncState
    // HapticServiceKey.defaultValue = FallbackHapticService() — crash-safe, работает без AppContainer.
    @Environment(\.hapticService) private var hapticService

    // MARK: - Animation state

    // ADR-V29-MASCOT-3D: idle-движение маскота живёт в запечённой анимации
    // 3D-модели (LyalyaRealityKitView). 2D PNG-fallback остаётся статичным.

    // v12: haptic feedback при переходе между состояниями
    @State private var previousState: LyalyaState = .idle

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
            // Layer 1-5: Rive/SwiftUI маскот + skin tint + skin overlay
            HSMascotView(
                mood: state.mascotMood,
                size: size,
                audioAmplitude: mouthAmplitude,
                pointingDirection: pointingDirection
            )
            .colorMultiply(skinTintColor)

            skinDecorativeOverlay

            // Layer 6: Real-time lip-sync оверлей (ARFaceAnchor → MascotLipSyncState).
            // Отображается только когда ARSession активна (isTracking = true).
            // Reduced Motion: анимация внутри оверлея отключается, форма статична.
            // Устройства без TrueDepth: isTracking всегда false → оверлей скрыт.
            if lipSyncState.isTracking {
                MouthBubbleOverlay(
                    openValue: lipSyncState.mouthOpen,
                    viseme: lipSyncState.viseme,
                    mascotSize: size
                )
                .opacity(Double(lipSyncState.confidence))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onAppear {
            previousState = state
        }
        .onChange(of: state) { oldState, newState in
            guard !reduceMotion else { return }
            playHapticFeedback(for: newState)
            previousState = oldState
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

    // MARK: - Haptic feedback (v12 → T: HIG P1-1 — через HapticService)
    // Мягкая тактильная обратная связь при переходе между состояниями.
    // Kids-friendly: лёгкая при обычных переходах, средняя при celebrating.
    // Reduced Motion: не вызывается (проверка в onChange).

    private func playHapticFeedback(for newState: LyalyaState) {
        switch newState {
        case .celebrating:
            hapticService.notification(.success)
        case .encouraging:
            hapticService.impact(.light)
        case .waving, .happy:
            hapticService.impact(.light)
        case .idle, .thinking, .sad, .pointing, .explaining, .singing:
            break
        }
    }

    // MARK: - Skin tint

    private var skinTintColor: Color {
        switch customization?.colorVariant {
        case .warm:
            return ColorTokens.Skin.warm
        case .cool:
            return ColorTokens.Skin.cool
        case .nature:
            return ColorTokens.Skin.nature
        case .none:
            return ColorTokens.Skin.classic
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
                .foregroundStyle(ColorTokens.Brand.butter)
                .shadow(color: ColorTokens.Brand.butter.opacity(0.4), radius: 3, y: 1)
                .offset(y: topOffset)
                .accessibilityHidden(true)
        case .scientist:
            Image(systemName: "eyeglasses")
                .font(.system(size: overlaySize * 1.2))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .offset(y: -(size * 0.08))
                .accessibilityHidden(true)
        case .athlete:
            Image(systemName: "figure.run")
                .font(.system(size: overlaySize))
                .foregroundStyle(ColorTokens.Brand.rose)
                .offset(y: topOffset)
                .accessibilityHidden(true)
        case .artist:
            Image(systemName: "paintbrush.pointed.fill")
                .font(.system(size: overlaySize))
                .foregroundStyle(ColorTokens.Brand.lilac)
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
                    Image(systemName: lyalyaState.fallbackSFSymbol)
                        .font(.title2)
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .symbolRenderingMode(.hierarchical)
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

        HStack(spacing: SpacingTokens.small) {
            Text("Состояние: \(lyalyaState.localizedDescription)")
            Image(systemName: lyalyaState.fallbackSFSymbol)
                .foregroundStyle(ColorTokens.Brand.primary)
                .symbolRenderingMode(.hierarchical)
        }
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
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous))
}
