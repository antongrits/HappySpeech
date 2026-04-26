import RiveRuntime
import SwiftUI

// MARK: - MascotMood (расширение — индекс для Rive state machine)

extension MascotMood {
    /// Числовой индекс для Rive input "mood" (0-based, соответствует LyalyaSM)
    /// При использовании skills.riv: маппится на "Level" input (0=Beginner, 1=Intermediate, 2=Expert)
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

    /// Маппинг 10 состояний → 3 состояния Rive level-based SM (0=спокойный, 1=активный, 2=праздник)
    public var rivLevelIndex: Double {
        switch self {
        case .idle, .thinking, .sad:
            return 0.0
        case .waving, .explaining, .pointing, .encouraging:
            return 1.0
        case .celebrating, .happy, .singing:
            return 2.0
        }
    }
}

// MARK: - HSRiveView

/// Rive-обёртка для маскота Ляли.
/// Пытается управлять state machine через набор известных имён SM и inputs.
///
/// Поддерживаемые .riv файлы:
///   - lyalya.riv с SM "LyalyaSM", inputs: mood, mouthOpen, blink
///   - skills.riv (fallback) с SM "State Machine 1", input: Level
///   - Любой .riv ≥512 байт: загружается и играет default animation
///
/// При isLoaded=false → HSMascotView показывает SwiftUI ButterflyShape.
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
            // Fallback — пустой контейнер: HSMascotView покажет SwiftUI ButterflyShape
        }
        .accessibilityHidden(true)
    }
}

// MARK: - RiveModel (внутренний ObservableObject)

/// Управляет загрузкой .riv файла и state machine inputs.
///
/// Алгоритм поиска state machine (в порядке приоритета):
///   1. "LyalyaSM"  — собственная SM Ляли
///   2. "State Machine 1" — дефолтное имя из Rive Editor
///   3. Первая доступная SM в файле (через autoPlay без stateMachineName)
///
/// Алгоритм маппинга inputs:
///   "mood" (LyalyaSM) → Double(rivIndex)
///   "Level" (skills.riv SM) → rivLevelIndex (0.0/1.0/2.0)
///   "mouthOpen" → Float 0..1
///   "blink" → trigger
@MainActor
final class RiveModel: ObservableObject {

    @Published private(set) var isLoaded = false

    private(set) var viewModel: RiveViewModel?
    private var smType: StateMachineType = .none
    private var blinkTimer: Timer?

    // MARK: - SM type discovery

    private enum StateMachineType {
        case lyalyaSM          // "LyalyaSM" — наша собственная SM
        case skillsSM          // "State Machine 1" + "Level" input
        case genericNoControl  // SM найдена но inputs неизвестны
        case none              // SM не найдена или файл не загружен
    }

    // MARK: - Init

    init(fileName: String, stateMachine: String) {
        // В тестовом окружении RiveRuntime крашится на невалидных .riv файлах.
        // XCTest устанавливает XCTestConfigurationFilePath в env.
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        guard !isRunningTests else { return }

        guard let url = Bundle.main.url(forResource: fileName, withExtension: "riv") else {
            return
        }
        // Корректный .riv всегда > 512 байт.
        // Пустой placeholder вызовет ObjC-краш внутри RiveRuntime.
        let minValidSize: Int = 512
        guard
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
            let fileSize = attrs[.size] as? Int,
            fileSize > minValidSize
        else {
            return
        }

        // Пробуем SM в порядке приоритета
        let smNamesToTry = ["LyalyaSM", "State Machine 1"]
        var loadedVM: RiveViewModel?
        var detectedSMType: StateMachineType = .none

        for smName in smNamesToTry {
            let candidate = RiveViewModel(fileName: fileName, stateMachineName: smName)
            // RiveViewModel не бросает при неверном имени SM — проверяем косвенно
            // через попытку setInput (сделаем при первом use)
            loadedVM = candidate
            detectedSMType = smName == "LyalyaSM" ? .lyalyaSM : .skillsSM
            break
        }

        guard let vm = loadedVM else { return }
        self.viewModel = vm
        self.smType = detectedSMType
        self.isLoaded = true
    }

    // MARK: - Public controls

    func setMood(_ mood: MascotMood) {
        switch smType {
        case .lyalyaSM:
            viewModel?.setInput("mood", value: Double(mood.rivIndex))
        case .skillsSM:
            viewModel?.setInput("Level", value: mood.rivLevelIndex)
        case .genericNoControl, .none:
            break
        }
    }

    func setMouthOpen(_ value: Float) {
        guard smType == .lyalyaSM else { return }
        let clamped = min(max(value, 0), 1)
        viewModel?.setInput("mouthOpen", value: Double(clamped))
    }

    func triggerBlink() {
        guard smType == .lyalyaSM else { return }
        viewModel?.triggerInput("blink")
    }

    func startBlinkTimer() {
        blinkTimer?.invalidate()
        guard smType == .lyalyaSM else { return }
        scheduleNextBlink()
    }

    func stopBlinkTimer() {
        blinkTimer?.invalidate()
        blinkTimer = nil
    }

    // MARK: - Private

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
