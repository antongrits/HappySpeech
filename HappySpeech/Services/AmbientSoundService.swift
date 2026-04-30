import AVFoundation
import OSLog

// MARK: - AmbientScene

/// Список ambient-сцен приложения.
/// Каждому кейсу соответствует файл `Audio/Ambient/<rawValue>.caf` в бандле.
public enum AmbientScene: String, CaseIterable, Sendable {
    /// Детский дом — мягкий пэд + птички (ChildHome hero).
    case childHome = "childhome"
    /// Лес — шелест листьев + ветер (Хэллоуин, лесные сцены).
    case forest = "forest"
    /// Океан — волны + чайки (Underwater AR, морские истории).
    case ocean = "ocean"
    /// Космос — космический дрон + мерцание (NarrativeQuest space).
    case space = "space"
    /// Цирк — отдалённый орган + толпа (Circus scenes).
    case circus = "circus"
    /// Тихий дом — мягкое гудение + тиканье часов (Indoor scenes).
    case homeQuiet = "home_quiet"
    /// Сад — жужжание пчёл + листья (Easter spring).
    case garden = "garden"
    /// Зимний ветер — мягкое завывание (New Year scenes).
    case winterWind = "winter_wind"
    /// Площадка — отдалённые голоса детей (Sport ball game).
    case playground = "playground"
    /// Тёплый нейтральный — пэд C-E-G (дефолтный fallback).
    case neutralWarm = "neutral_warm"
}

// MARK: - AmbientSoundService Protocol

/// Сервис фонового ambient-звука для создания атмосферы на игровых экранах.
///
/// `AmbientSoundService` воспроизводит зациклённые ambient-треки через `AVAudioPlayer`.
/// AVAudioSession категория `.ambient + .mixWithOthers` гарантирует, что фоновая
/// музыка пользователя (Apple Music, Spotify) не прерывается.
///
/// 10 встроенных сцен (``AmbientScene``): детский дом, лес, океан, космос, цирк,
/// тихий дом, сад, зимний ветер, площадка, нейтральный тёплый.
///
/// Смена сцены выполняется через fade-out старой + fade-in новой.
/// Повторный вызов `play(scene:)` с той же сценой — no-op.
///
/// ## Пример
/// ```swift
/// let service: AmbientSoundService = LiveAmbientSoundService()
///
/// // При открытии экрана WorldMap
/// await service.play(scene: .forest, fadeDuration: 1.5)
///
/// // Смена сцены при переходе в AR
/// await service.play(scene: .ocean, fadeDuration: 0.8)
///
/// // Отключение при сворачивании
/// await service.stop(fadeDuration: 0.5)
/// ```
///
/// ## See Also
/// - ``AmbientScene``
/// - ``HapticService``
public protocol AmbientSoundService: Sendable {
    /// Воспроизвести ambient-сцену с fade-in. Если уже играет та же сцена — ничего не делает.
    func play(scene: AmbientScene, fadeDuration: TimeInterval) async
    /// Остановить воспроизведение с fade-out.
    func stop(fadeDuration: TimeInterval) async
    /// Установить целевую громкость (0.0–1.0). Применяется к текущему плееру.
    func setVolume(_ volume: Float) async
    /// Текущая воспроизводимая сцена (nil если остановлен).
    var currentScene: AmbientScene? { get async }
}

// MARK: - LiveAmbientSoundService

/// Продакшен-реализация. Использует `AVAudioPlayer` с зацикленным воспроизведением.
/// Actor-изоляция обеспечивает thread-safety без дополнительных блокировок.
public actor LiveAmbientSoundService: AmbientSoundService {

    // MARK: Private State

    private var player: AVAudioPlayer?
    private var _currentScene: AmbientScene?
    private var _volume: Float = 0.3

    private let logger = Logger(subsystem: "com.happyspeech", category: "AmbientSoundService")

    // MARK: Init

    public init() {
        Self.configureAudioSession(logger: Logger(subsystem: "com.happyspeech", category: "AmbientSoundService"))
    }

    // MARK: AmbientSoundService

    public var currentScene: AmbientScene? {
        _currentScene
    }

    public func play(scene: AmbientScene, fadeDuration: TimeInterval = 1.5) async {
        guard scene != _currentScene else { return }

        // Fade out предыдущий трек за половину fade-duration
        if player != nil {
            await stop(fadeDuration: max(fadeDuration / 2, 0.3))
        }

        guard let url = Bundle.main.url(
            forResource: scene.rawValue,
            withExtension: "caf",
            subdirectory: "Audio/Ambient"
        ) else {
            logger.warning("Ambient file not found: \(scene.rawValue, privacy: .public).caf in Audio/Ambient/")
            return
        }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1    // бесконечный loop
            newPlayer.volume = 0.0
            newPlayer.prepareToPlay()
            newPlayer.play()

            self.player = newPlayer
            self._currentScene = scene

            await fade(from: 0.0, to: _volume, duration: fadeDuration)
            logger.info("Ambient playing: \(scene.rawValue, privacy: .public)")
        } catch {
            logger.error("Ambient play failed [\(scene.rawValue, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func stop(fadeDuration: TimeInterval = 1.0) async {
        guard let p = player else { return }
        await fade(from: p.volume, to: 0.0, duration: fadeDuration)
        p.stop()
        player = nil
        _currentScene = nil
        logger.info("Ambient stopped")
    }

    public func setVolume(_ volume: Float) async {
        _volume = max(0.0, min(1.0, volume))
        player?.volume = _volume
    }

    // MARK: Private

    /// Плавно изменяет громкость текущего player за `duration` секунд (20 шагов).
    private func fade(from start: Float, to end: Float, duration: TimeInterval) async {
        guard let p = player, duration > 0 else {
            player?.volume = end
            return
        }
        let steps = 20
        let stepNs = UInt64(max(duration / Double(steps), 0.005) * 1_000_000_000)
        for i in 1...steps {
            let progress = Float(i) / Float(steps)
            p.volume = start + (end - start) * progress
            try? await Task.sleep(nanoseconds: stepNs)
        }
    }

    /// Настраивает AVAudioSession: `.ambient` + `.mixWithOthers`.
    /// Не блокирует фоновую музыку пользователя.
    /// `nonisolated static` — вызывается из `init` до захвата actor-контекста.
    private nonisolated static func configureAudioSession(logger: Logger) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        } catch {
            logger.error("AmbientSoundService AVAudioSession setup failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - AmbientVolumeSetting

/// Предустановки громкости ambient для Settings → Звук и тактильные отклики.
public enum AmbientVolumeSetting: String, CaseIterable, Sendable {
    /// Выкл — ambient полностью отключён.
    case off = "off"
    /// Лёгкие — едва слышимый фон (volume 0.15).
    case subtle = "subtle"
    /// Средние — стандартная громкость (volume 0.3, default).
    case medium = "medium"
    /// Полные — максимальная атмосфера (volume 0.5).
    case full = "full"

    public var volume: Float {
        switch self {
        case .off:     return 0.0
        case .subtle:  return 0.15
        case .medium:  return 0.3
        case .full:    return 0.5
        }
    }

    public static let defaultSetting: AmbientVolumeSetting = .medium
    public static let userDefaultsKey = "AmbientSound.volumeSetting"
}

// MARK: - MockAmbientSoundService

/// Мок-реализация для Previews и unit-тестов.
public actor MockAmbientSoundService: AmbientSoundService {
    public private(set) var currentScene: AmbientScene?
    public private(set) var lastPlayedScene: AmbientScene?
    public private(set) var stopCallCount: Int = 0
    private var _volume: Float = 0.3

    public init() {}

    public func play(scene: AmbientScene, fadeDuration: TimeInterval = 1.5) async {
        currentScene = scene
        lastPlayedScene = scene
    }

    public func stop(fadeDuration: TimeInterval = 1.0) async {
        currentScene = nil
        stopCallCount += 1
    }

    public func setVolume(_ volume: Float) async {
        _volume = max(0.0, min(1.0, volume))
    }
}
