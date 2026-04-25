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
            if riveModel.isLoaded, let vm = riveModel.viewModel {
                vm.view()
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

    // Опциональный — создаётся только если .riv найден в бандле.
    // RiveViewModel.init бросает `try!` краш при невалидном артборде,
    // поэтому инициализируем его ТОЛЬКО после проверки Bundle.main.url.
    private(set) var viewModel: RiveViewModel?
    private var blinkTimer: Timer?

    init(fileName: String, stateMachine: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "riv") else {
            // Файл отсутствует — остаёмся в isLoaded = false, viewModel = nil.
            return
        }
        // Проверяем минимальный размер файла перед инициализацией:
        // корректный .riv всегда > 512 байт. Пустой placeholder вызовет ObjC-краш
        // внутри RiveRuntime, поэтому мы обходим это превентивно.
        let minValidSize: Int = 512
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attrs[.size] as? Int,
              fileSize > minValidSize else {
            return
        }
        // Файл найден и имеет достаточный размер — создаём RiveViewModel.
        let vm = RiveViewModel(fileName: fileName, stateMachineName: stateMachine)
        self.viewModel = vm
        self.isLoaded = true
    }

    func setMood(_ mood: MascotMood) {
        try? viewModel?.setInput("mood", value: Double(mood.rivIndex))
    }

    func setMouthOpen(_ value: Float) {
        let clamped = min(max(value, 0), 1)
        try? viewModel?.setInput("mouthOpen", value: Double(clamped))
    }

    func triggerBlink() {
        try? viewModel?.triggerInput("blink")
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
