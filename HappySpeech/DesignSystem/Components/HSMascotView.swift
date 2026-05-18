import SwiftUI

// MARK: - MascotMood
// 10 состояний маскота Ляли. Каждое маппируется в 2D-иллюстрацию
// mascot_lyalya_* — единый канон облика, согласованный с AppIcon (D-3 v27).

public enum MascotMood: Sendable {
    case idle           // 0 — нежное парение, крылья медленно
    case happy          // 1 — радость, частые взмахи
    case celebrating    // 2 — кружение + sparkles
    case thinking       // 3 — наклон головы + вопросительный пузырь
    case sad            // 4 — опущенные антенны, сложенные крылья
    case encouraging    // 5 — поддержка (при ошибке ребёнка — НЕ ругать)
    case waving         // 6 — машет крылом «привет»
    case explaining     // 7 — жестикуляция + fallback lip-sync
    case singing        // 8 — ритмичный рот + покачивание
    case pointing       // 9 — указывает (используй pointingDirection для уточнения)
}

// MARK: - PointingDirection

public enum PointingDirection: Sendable {
    case left, right, up
}

// MARK: - MascotMood+LyalyaState

public extension MascotMood {
    /// Маппинг MascotMood → LyalyaState для передачи в LyalyaMascotView / LyalyaHeroView.
    var lyalyaState: LyalyaState {
        switch self {
        case .idle:        return .idle
        case .happy:       return .happy
        case .celebrating: return .celebrating
        case .thinking:    return .thinking
        case .sad:         return .sad
        case .encouraging: return .encouraging
        case .waving:      return .waving
        case .explaining:  return .explaining
        case .singing:     return .singing
        case .pointing:    return .pointing
        }
    }

    /// Маппинг MascotMood → имя 2D-иллюстрации в Assets.xcassets/Illustrations/.
    /// idle → sleep (ближайший аналог покоя; lyalya_idle отсутствует).
    /// encouraging → wave (жест поддержки совпадает с wave-иллюстрацией).
    ///
    /// Block I v19: mascot_lyalya_listen удалён из маппинга — этот ассет содержит
    /// персонажа с другим арт-стилем (медведеобразный, голубые глаза, без антенн),
    /// несовместимым с остальными 2D иллюстрациями Ляли. Заменён на mascot_lyalya_happy.
    /// mascot_lyalya_listen остаётся в Assets как legacy — не удаляем, чтобы не сломать
    /// content-ссылки, но в маппинге не используется.
    var illustrationName: String {
        switch self {
        case .idle:        return "mascot_lyalya_sleep"
        case .happy:       return "mascot_lyalya_happy"
        case .celebrating: return "mascot_lyalya_celebrate"
        case .thinking:    return "mascot_lyalya_think"
        case .sad:         return "mascot_lyalya_sad"
        case .encouraging: return "mascot_lyalya_wave"
        case .waving:      return "mascot_lyalya_wave"
        case .explaining:  return "mascot_lyalya_happy"
        case .singing:     return "mascot_lyalya_sing"
        case .pointing:    return "mascot_lyalya_read"
        }
    }
}

// MARK: - HSMascotView

/// Рендер маскота Ляли — 3D-модель поверх 2D-канона + mood aura.
///
/// `HSMascotView` — низкоуровневый рендер-компонент. На экранах фич используйте
/// ``LyalyaMascotView`` вместо прямого обращения к `HSMascotView`.
///
/// ### Канон облика (ADR-V29-MASCOT-3D)
/// Канон Ляли — профессиональная 3D-модель `lyalya3d_v3.usdz` (создана в Blender
/// по `AppIcon`: кремово-белая пчёлка-фея с большими глазами, антеннами,
/// розовыми щёчками и янтарными крылышками). 2D-иллюстрации `mascot_lyalya_*`
/// остаются fallback-слоем.
///
/// ### Архитектура слоёв (снизу вверх в ZStack)
///
/// 1. `MoodAuraView` — ambient radial glow под маскотом, цвет зависит от настроения
/// 2. 2D-иллюстрация (`mascot_lyalya_*`) — fallback-слой; виден при ошибке
///    загрузки 3D-модели или при Reduce Motion
/// 3. ``LyalyaRealityKitView`` — 3D-модель Ляли с запечённой idle-анимацией;
///    скрывает 2D-слой, когда модель успешно загружена
///
/// ### Lip-sync
/// AR lip-sync рисуется отдельным 2D-оверлеем `MouthBubbleOverlay` поверх
/// маскота внутри ``LyalyaMascotView`` (когда `MascotLipSyncState.isTracking`).
/// 3D-модель не содержит blendshapes рта, поэтому lip-sync остаётся на 2D-слое.
///
/// ### Reduced Motion
/// При `accessibilityReduceMotion` 3D-слой не запускает idle-анимацию
/// (модель замирает статично) — см. ``LyalyaRealityKitView``.
///
/// ## Пример
/// ```swift
/// // Обычно используется через LyalyaMascotView:
/// LyalyaMascotView(state: .celebrating, size: 160)
///
/// // Прямое использование (только в компонентах DS):
/// HSMascotView(mood: .happy, size: 120, audioAmplitude: $amplitude)
/// ```
///
/// ## See Also
/// - ``LyalyaMascotView``
/// - ``MascotMood``
/// - ``MascotLipSyncState``
/// - ``MascotEyeContactState``
public struct HSMascotView: View {

    // MARK: - Public API

    public let mood: MascotMood
    public let size: CGFloat
    public let audioAmplitude: Binding<Float>?
    public let pointingDirection: PointingDirection

    // MARK: - Private state

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Entrance / transition animation (плавное появление слоёв)
    @State private var entranceScale: CGFloat = 0.85
    @State private var entranceOpacity: Double = 0
    @State private var moodTransitionID: Int = 0

    // 3D-слой: nil — загрузка не завершена; true — модель загружена (показываем 3D);
    // false — ошибка загрузки (остаётся 2D-fallback). ADR-V29-MASCOT-3D.
    @State private var is3DReady: Bool?

    // MARK: - Init

    public init(
        mood: MascotMood = .idle,
        size: CGFloat = 120,
        audioAmplitude: Binding<Float>? = nil,
        pointingDirection: PointingDirection = .up
    ) {
        self.mood = mood
        self.size = size
        self.audioAmplitude = audioAmplitude
        self.pointingDirection = pointingDirection
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Layer 1: ambient mood aura (под маскотом)
            if !reduceMotion {
                MoodAuraView(mood: mood, size: size)
            }

            // Layer 2: 2D-иллюстрация маскота — fallback-слой (ADR-V29-MASCOT-3D).
            // Виден при ошибке загрузки 3D-модели или при Reduce Motion.
            // Иллюстрация выбирается по настроению через `MascotMood.illustrationName`.
            Image(mood.illustrationName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .scaleEffect(entranceScale)
                .opacity(twoDLayerOpacity)
                .id(moodTransitionID)
                .accessibilityHidden(true)

            // Layer 3: 3D-модель Ляли (lyalya3d_v3.usdz) с запечённой idle-анимацией.
            // Скрывает 2D-слой при успешной загрузке. Reduce Motion: idle-анимация
            // не запускается (модель статична) — обрабатывается внутри LyalyaRealityKitView.
            LyalyaRealityKitView(onLoadResult: { ok in
                is3DReady = ok
            })
            .frame(width: size, height: size)
            .opacity(is3DReady == true ? entranceOpacity : 0)
            .accessibilityHidden(true)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHidden(false)
        .onAppear {
            playEntrance()
        }
        .onChange(of: mood) { _, _ in
            playMoodTransition()
        }
    }

    // MARK: - Layer compositing

    /// Непрозрачность 2D fallback-слоя. Пока 3D загружается (`is3DReady == nil`)
    /// или при ошибке загрузки — 2D виден. При успешной загрузке 3D — 2D скрыт.
    private var twoDLayerOpacity: Double {
        is3DReady == true ? 0 : entranceOpacity
    }

    // MARK: - Entrance animation

    private func playEntrance() {
        guard !reduceMotion else {
            entranceScale = 1.0
            entranceOpacity = 1.0
            return
        }
        entranceScale = 0.82
        entranceOpacity = 0
        withAnimation(MotionTokens.bounce) {
            entranceScale = 1.0
            entranceOpacity = 1.0
        }
    }

    // MARK: - Mood transition

    private func playMoodTransition() {
        guard !reduceMotion else { return }
        moodTransitionID += 1
        withAnimation(MotionTokens.bounce) {
            entranceScale = 1.0
            entranceOpacity = 1.0
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        switch mood {
        case .idle:        return "Ляля отдыхает"
        case .happy:       return "Ляля радуется"
        case .celebrating: return "Ляля празднует победу"
        case .thinking:    return "Ляля думает"
        case .sad:         return "Ляля грустит"
        case .encouraging: return "Ляля поддерживает"
        case .waving:      return "Ляля машет крылышком"
        case .explaining:  return "Ляля объясняет"
        case .singing:     return "Ляля поёт"
        case .pointing:    return "Ляля показывает направление"
        }
    }
}

// MARK: - MoodAuraView (ambient glow под маскотом)

/// Радиальный градиент-halo под маскотом — цвет и непрозрачность зависят от состояния.
/// Reduced Motion: вью не отображается (родитель скрывает через `if !reduceMotion`).
///
/// Plan v21 Block J: удалена `idlePulse.repeatForever` анимация — пульсация ауры
/// воспринималась как «мигание» 2D-слоя. Аура статична; цвет меняется по `mood`
/// через `spring` (с guard на reduceMotion). Subtle breathing допустим, но
/// repeatForever на 2D-элементах запрещён по правилу «2D героев нельзя анимировать».
private struct MoodAuraView: View {
    let mood: MascotMood
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var auraColor: Color {
        switch mood {
        case .idle:        return ColorTokens.Mood.idle
        case .happy:       return ColorTokens.Mood.happy
        case .celebrating: return ColorTokens.Mood.celebrating
        case .thinking:    return ColorTokens.Mood.thinking
        case .sad:         return ColorTokens.Mood.sad
        case .encouraging: return ColorTokens.Mood.encouraging
        case .waving:      return ColorTokens.Mood.happy
        case .explaining:  return ColorTokens.Mood.celebrating
        case .singing:     return ColorTokens.Mood.singing
        case .pointing:    return ColorTokens.Mood.celebrating
        }
    }

    private var targetOpacity: Double {
        switch mood {
        case .celebrating: return 0.35
        case .happy, .waving, .singing: return 0.25
        case .idle, .thinking: return 0.12
        case .encouraging: return 0.28
        case .sad: return 0.10
        default: return 0.18
        }
    }

    var body: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [auraColor.opacity(targetOpacity), auraColor.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.58
                )
            )
            .frame(width: size * 1.4, height: size * 0.55)
            .offset(y: size * 0.32)
            .animation(reduceMotion ? .none : MotionTokens.spring, value: mood)
    }
}

// MARK: - MascotMood + helpers

extension MascotMood: CustomStringConvertible {
    public var description: String {
        switch self {
        case .idle:        return "Покой"
        case .happy:       return "Радость"
        case .celebrating: return "Праздник"
        case .thinking:    return "Думает"
        case .sad:         return "Грустит"
        case .encouraging: return "Поддержка"
        case .waving:      return "Привет"
        case .explaining:  return "Объясняет"
        case .singing:     return "Поёт"
        case .pointing:    return "Указывает"
        }
    }
}

// Conformance for ForEach stability
extension MascotMood: CaseIterable {
    public static var allCases: [MascotMood] {
        [.idle, .happy, .celebrating, .thinking, .sad,
         .encouraging, .waving, .explaining, .singing, .pointing]
    }
}

// MARK: - Preview

#Preview("Все настроения Ляли") {
    ScrollView(.horizontal) {
        HStack(spacing: 24) {
            ForEach(MascotMood.allCases, id: \.description) { mood in
                VStack(spacing: 8) {
                    HSMascotView(mood: mood, size: 100)
                    Text(mood.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

#Preview("Lip-sync демо") {
    @Previewable @State var amplitude: Float = 0

    VStack(spacing: 24) {
        HSMascotView(
            mood: .explaining,
            size: 160,
            audioAmplitude: $amplitude
        )
        Slider(value: $amplitude, in: 0...1) {
            Text("Амплитуда")
        }
        .padding(.horizontal)
    }
    .padding()
}

#Preview("Настроения маскота") {
    @Previewable @State var selectedMood: MascotMood = .celebrating

    VStack(spacing: 20) {
        HSMascotView(mood: selectedMood, size: 180)
            .frame(height: 220)

        Picker("Настроение", selection: $selectedMood) {
            ForEach(MascotMood.allCases, id: \.description) { mood in
                Text(mood.description).tag(mood)
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 100)
    }
    .padding()
}
