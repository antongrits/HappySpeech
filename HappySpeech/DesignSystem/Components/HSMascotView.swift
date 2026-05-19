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

/// Рендер маскота Ляли — профессионально анимированный 2D-канон + mood aura.
///
/// `HSMascotView` — низкоуровневый рендер-компонент. На экранах фич используйте
/// ``LyalyaMascotView`` вместо прямого обращения к `HSMascotView`.
///
/// ### Канон облика (ADR-V30-MASCOT-2D)
/// Канон Ляли — единый набор 2D-иллюстраций `mascot_lyalya_*` (кремово-белая
/// пчёлка-фея с большими глазами, антеннами, розовыми щёчками и янтарными
/// крылышками), согласованный с `AppIcon`. 3D-рендер (`LyalyaRealityKitView` +
/// `lyalya3d_v3.usdz`) удалён: процедурная USDZ-модель выглядела непрофессионально
/// и вызывала видимый 2D/3D-«мигающий» переход при асинхронной загрузке.
/// ADR-V30-MASCOT-2D сменяет ADR-V29-MASCOT-3D.
///
/// ### Архитектура слоёв (снизу вверх в ZStack)
///
/// 1. `MoodAuraView` — ambient radial glow под маскотом, цвет зависит от настроения
/// 2. Анимированная 2D-иллюстрация (`mascot_lyalya_*`) — единственный слой облика
///
/// ### «Живость» маскота
/// 2D-иллюстрация оживляется процедурной SwiftUI-анимацией:
/// - **дыхание** — лёгкое непрерывное масштабирование (breathe loop);
/// - **парение** — мягкое вертикальное покачивание;
/// - **микро-наклон** — едва заметный поворот, создаёт ощущение «дышит»;
/// - **squash-stretch** — упругая реакция при смене настроения;
/// - **кроссфейд** — плавный переход между PNG разных настроений (без жёсткой
///   склейки и без пересоздания слоя — никакого «мигания»).
///
/// ### Reduced Motion
/// При `accessibilityReduceMotion` все процедурные анимации отключаются —
/// маскот статичен, переход настроений мгновенный.
///
/// ## Пример
/// ```swift
/// // Обычно используется через LyalyaMascotView:
/// LyalyaMascotView(state: .celebrating, size: 160)
///
/// // Прямое использование (только в компонентах DS):
/// HSMascotView(mood: .happy, size: 120)
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
    public let pointingDirection: PointingDirection

    // MARK: - Private state

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Entrance animation (плавное появление слоя облика).
    @State private var entranceScale: CGFloat = 0.85
    @State private var entranceOpacity: Double = 0

    // Idle «живость»: дыхание, парение, микро-наклон. Запускаются циклично
    // в onAppear; при Reduce Motion остаются в нейтральных значениях.
    @State private var breathePhase: Bool = false
    @State private var floatPhase: Bool = false
    @State private var tiltPhase: Bool = false

    // Squash-stretch — упругая реакция при смене настроения.
    @State private var reactionScale: CGFloat = 1.0

    // MARK: - Init

    public init(
        mood: MascotMood = .idle,
        size: CGFloat = 120,
        pointingDirection: PointingDirection = .up
    ) {
        self.mood = mood
        self.size = size
        self.pointingDirection = pointingDirection
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Layer 1: ambient mood aura (под маскотом).
            if !reduceMotion {
                MoodAuraView(mood: mood, size: size)
            }

            // Layer 2: анимированная 2D-иллюстрация маскота — единый канон облика.
            // Иллюстрация выбирается по настроению через `MascotMood.illustrationName`.
            // `.id` на слое НЕ ставится — иначе SwiftUI пересоздавал бы вью на каждой
            // смене настроения (жёсткая склейка). Вместо этого crossfade обеспечивается
            // сменой ресурса внутри одного стабильного `Image` + `.animation`.
            Image(mood.illustrationName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .scaleEffect(entranceScale * breatheScale * reactionScale)
                .rotationEffect(.degrees(tiltAngle))
                .offset(y: floatOffset)
                .opacity(entranceOpacity)
                .accessibilityHidden(true)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHidden(false)
        .animation(reduceMotion ? .none : MotionTokens.bounce, value: mood)
        .onAppear {
            playEntrance()
            startIdleLoops()
        }
        .onChange(of: mood) { _, _ in
            playMoodReaction()
        }
    }

    // MARK: - Idle «живость» (дыхание / парение / наклон)

    /// Масштаб дыхания: едва заметная пульсация (±1.5%).
    private var breatheScale: CGFloat {
        breathePhase ? 1.015 : 0.985
    }

    /// Вертикальное парение: мягкое покачивание относительно размера.
    private var floatOffset: CGFloat {
        floatPhase ? -size * 0.022 : size * 0.022
    }

    /// Микро-наклон: едва заметный поворот корпуса.
    private var tiltAngle: Double {
        tiltPhase ? 1.6 : -1.6
    }

    /// Запускает зацикленные idle-анимации. При Reduce Motion циклы не стартуют —
    /// маскот остаётся статичным в нейтральной позе.
    private func startIdleLoops() {
        guard !reduceMotion else { return }

        withAnimation(
            .easeInOut(duration: MotionTokens.Mascot.breatheDuration)
                .repeatForever(autoreverses: true)
        ) {
            breathePhase = true
        }

        withAnimation(
            .easeInOut(duration: MotionTokens.Mascot.breatheDuration * 1.35)
                .repeatForever(autoreverses: true)
        ) {
            floatPhase = true
        }

        withAnimation(
            .easeInOut(duration: MotionTokens.Mascot.breatheDuration * 1.8)
                .repeatForever(autoreverses: true)
        ) {
            tiltPhase = true
        }
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

    // MARK: - Mood reaction (squash-stretch)

    /// Упругая реакция при смене настроения: маскот коротко «подпрыгивает».
    /// Кроссфейд между PNG обеспечивается `.animation(...)` на `Image`.
    private func playMoodReaction() {
        guard !reduceMotion else { return }
        withAnimation(MotionTokens.Mascot.celebrateSpring) {
            reactionScale = 1.08
        }
        withAnimation(MotionTokens.spring.delay(MotionTokens.Duration.quick)) {
            reactionScale = 1.0
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
/// через `spring` (с guard на reduceMotion).
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
