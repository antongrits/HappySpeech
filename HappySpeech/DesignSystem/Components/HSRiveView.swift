import SwiftUI
import RiveRuntime

// MARK: - MascotMood (расширение — индекс для Rive state machine)

extension MascotMood {
    /// Числовой индекс для Rive input "mood" (0-based, соответствует LyalyaSM)
    public var rivIndex: Int {
        switch self {
        case .idle:        return 0
        case .happy:       return 1
        case .celebrating: return 2
        case .thinking:    return 3
        case .sad:         return 4
        case .encouraging: return 5
        case .waving:      return 6
        case .explaining:  return 7
        case .singing:     return 8
        case .pointing:    return 9
        }
    }
}

// MARK: - HSRiveView

/// Rive-обёртка для маскота Ляли.
/// Управляется через state machine "LyalyaSM" с inputs:
///   mood (number 0-9), mouthOpen (number 0-1), blink (trigger)
///
/// Если .riv ассет не загрузился — view возвращает EmptyView.
/// Reduced Motion: анимации останавливаются, Rive рисует static first frame.
public struct HSRiveView: View {

    // MARK: - Properties

    public let fileName: String
    public let stateMachine: String

    @Binding public var mood: MascotMood
    public let mouthOpen: Float

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var riveModel: RiveModel

    // MARK: - Init

    public init(
        fileName: String = "lyalya",
        stateMachine: String = "LyalyaSM",
        mood: Binding<MascotMood>,
        mouthOpen: Float = 0
    ) {
        self.fileName = fileName
        self.stateMachine = stateMachine
        self._mood = mood
        self.mouthOpen = mouthOpen
        self._riveModel = StateObject(wrappedValue: RiveModel(
            fileName: fileName,
            stateMachine: stateMachine
        ))
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if riveModel.isLoaded {
                riveModel.viewModel.view()
                    .onChange(of: mood) { _, newMood in
                        guard !reduceMotion else { return }
                        riveModel.setMood(newMood)
                    }
                    .onChange(of: mouthOpen) { _, newValue in
                        guard !reduceMotion else { return }
                        riveModel.setMouthOpen(newValue)
                    }
                    .onAppear {
                        riveModel.setMood(mood)
                        if !reduceMotion {
                            riveModel.startBlinkTimer()
                        }
                    }
                    .onDisappear {
                        riveModel.stopBlinkTimer()
                    }
            }
            // Fallback — пустой контейнер (HSMascotView покажет SwiftUI-версию)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - RiveModel (внутренний ObservableObject)

@MainActor
final class RiveModel: ObservableObject {

    @Published private(set) var isLoaded = false

    let viewModel: RiveViewModel
    private var blinkTimer: Timer?

    init(fileName: String, stateMachine: String) {
        self.viewModel = RiveViewModel(
            fileName: fileName,
            stateMachineName: stateMachine
        )
        validateLoad(fileName: fileName)
    }

    private func validateLoad(fileName: String) {
        // Проверяем наличие ресурса в бандле
        if Bundle.main.url(forResource: fileName, withExtension: "riv") != nil {
            isLoaded = true
        }
    }

    func setMood(_ mood: MascotMood) {
        try? viewModel.setInput("mood", value: Double(mood.rivIndex))
    }

    func setMouthOpen(_ value: Float) {
        let clamped = min(max(value, 0), 1)
        try? viewModel.setInput("mouthOpen", value: Double(clamped))
    }

    func triggerBlink() {
        try? viewModel.triggerInput("blink")
    }

    func startBlinkTimer() {
        blinkTimer?.invalidate()
        // Моргание каждые 3–5 секунд (случайный интервал)
        scheduleNextBlink()
    }

    func stopBlinkTimer() {
        blinkTimer?.invalidate()
        blinkTimer = nil
    }

    private func scheduleNextBlink() {
        let interval = Double.random(in: 3.0...5.5)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.triggerBlink()
                self?.scheduleNextBlink()
            }
        }
    }
}

// MARK: - Preview

#Preview("HSRiveView Ляля") {
    @Previewable @State var mood: MascotMood = .idle
    VStack(spacing: 16) {
        HSRiveView(mood: $mood, mouthOpen: 0)
            .frame(width: 200, height: 200)

        Picker("Настроение", selection: $mood) {
            ForEach([
                MascotMood.idle, .happy, .celebrating, .thinking,
                .sad, .encouraging, .waving, .explaining, .singing, .pointing
            ], id: \.rivIndex) { m in
                Text(m.description).tag(m)
            }
        }
        .pickerStyle(.wheel)
    }
    .padding()
}
