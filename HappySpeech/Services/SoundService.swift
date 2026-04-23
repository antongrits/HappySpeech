import AVFoundation
import OSLog

// MARK: - UISound

/// Все 16 UI-звуков приложения.
/// Файлы: HappySpeech/Resources/Audio/UI/<rawValue>.caf
public enum UISound: String, CaseIterable, Sendable {
    /// Мягкий тик при нажатии на кнопку (40 мс).
    case tap = "tap"
    /// Восходящий аккорд C5→E5→G5 — правильный ответ (200 мс).
    case correct = "correct"
    /// Мягкий нисходящий wobble — неправильный ответ, не пугающий (150 мс).
    case incorrect = "incorrect"
    /// Спаркл-фанфара — награда за серию/очки (500 мс).
    case reward = "reward"
    /// Восходящее арпеджио — серия правильных ответов (400 мс).
    case streak = "streak"
    /// Торжественный sound — переход на новый уровень (600 мс).
    case levelUp = "level_up"
    /// Спокойный колокол — начало разминки (300 мс).
    case warmupStart = "warmup_start"
    /// Мягкий чайм — конец разминки (250 мс).
    case warmupEnd = "warmup_end"
    /// Completion jingle — завершение всей сессии (700 мс).
    case complete = "complete"
    /// Мягкий клик — пауза (80 мс).
    case pause = "pause"
    /// Нежный пинг — системное уведомление (200 мс).
    case notification = "notification"
    /// Whoosh вперёд — переход к следующему экрану (150 мс).
    case transitionNext = "transition_next"
    /// Whoosh назад — возврат на предыдущий экран (150 мс).
    case transitionBack = "transition_back"
    /// Мягкий поп — захват элемента drag-and-drop (60 мс).
    case dragPick = "drag_pick"
    /// Мягкий thud — отпускание элемента drag-and-drop (80 мс).
    case dragDrop = "drag_drop"
    /// Мягкий низкий buzz — ошибка, без агрессии (100 мс).
    case error = "error"
}

// MARK: - LyalyaPhrase

/// 100 голосовых фраз маскота «Ляли».
/// Файлы: HappySpeech/Resources/Audio/Lyalya/lyalya_<rawValue>.m4a
/// Голос: ru-RU-SvetlanaNeural (Microsoft Edge TTS, royalty-free).
public enum LyalyaPhrase: String, CaseIterable, Sendable {

    // Приветствия
    case greeting01 = "greeting_01"
    case greeting02 = "greeting_02"
    case greeting03 = "greeting_03"
    case greeting04 = "greeting_04"
    case greeting05 = "greeting_05"
    case greeting06 = "greeting_06"
    case greeting07 = "greeting_07"
    case greeting08 = "greeting_08"
    case greeting09 = "greeting_09"
    case greeting10 = "greeting_10"
    case greeting11 = "greeting_11"
    case greeting12 = "greeting_12"
    case greeting13 = "greeting_13"
    case greeting14 = "greeting_14"
    case greeting15 = "greeting_15"

    // Поощрения
    case praise01 = "praise_01"
    case praise02 = "praise_02"
    case praise03 = "praise_03"
    case praise04 = "praise_04"
    case praise05 = "praise_05"
    case praise06 = "praise_06"
    case praise07 = "praise_07"
    case praise08 = "praise_08"
    case praise09 = "praise_09"
    case praise10 = "praise_10"
    case praise11 = "praise_11"
    case praise12 = "praise_12"
    case praise13 = "praise_13"
    case praise14 = "praise_14"
    case praise15 = "praise_15"
    case praise16 = "praise_16"
    case praise17 = "praise_17"
    case praise18 = "praise_18"
    case praise19 = "praise_19"
    case praise20 = "praise_20"

    // Подсказки и инструкции
    case hint01 = "hint_01"
    case hint02 = "hint_02"
    case hint03 = "hint_03"
    case hint04 = "hint_04"
    case hint05 = "hint_05"
    case hint06 = "hint_06"
    case hint07 = "hint_07"
    case hint08 = "hint_08"
    case hint09 = "hint_09"
    case hint10 = "hint_10"
    case hint11 = "hint_11"
    case hint12 = "hint_12"
    case hint13 = "hint_13"
    case hint14 = "hint_14"
    case hint15 = "hint_15"
    case hint16 = "hint_16"
    case hint17 = "hint_17"
    case hint18 = "hint_18"
    case hint19 = "hint_19"
    case hint20 = "hint_20"
    case hint21 = "hint_21"
    case hint22 = "hint_22"
    case hint23 = "hint_23"
    case hint24 = "hint_24"
    case hint25 = "hint_25"

    // Завершение сессии
    case sessionEnd01 = "session_end_01"
    case sessionEnd02 = "session_end_02"
    case sessionEnd03 = "session_end_03"
    case sessionEnd04 = "session_end_04"
    case sessionEnd05 = "session_end_05"
    case sessionEnd06 = "session_end_06"
    case sessionEnd07 = "session_end_07"
    case sessionEnd08 = "session_end_08"
    case sessionEnd09 = "session_end_09"
    case sessionEnd10 = "session_end_10"
    case sessionEnd11 = "session_end_11"
    case sessionEnd12 = "session_end_12"
    case sessionEnd13 = "session_end_13"
    case sessionEnd14 = "session_end_14"
    case sessionEnd15 = "session_end_15"

    // Истории и нарративы
    case story01 = "story_01"
    case story02 = "story_02"
    case story03 = "story_03"
    case story04 = "story_04"
    case story05 = "story_05"
    case story06 = "story_06"
    case story07 = "story_07"
    case story08 = "story_08"
    case story09 = "story_09"
    case story10 = "story_10"
    case story11 = "story_11"
    case story12 = "story_12"
    case story13 = "story_13"
    case story14 = "story_14"
    case story15 = "story_15"

    // Переходы между упражнениями
    case transition01 = "transition_01"
    case transition02 = "transition_02"
    case transition03 = "transition_03"
    case transition04 = "transition_04"
    case transition05 = "transition_05"
    case transition06 = "transition_06"
    case transition07 = "transition_07"
    case transition08 = "transition_08"
    case transition09 = "transition_09"
    case transition10 = "transition_10"

    // Артикуляционные инструкции
    case artic01 = "artic_01"
    case artic02 = "artic_02"
    case artic03 = "artic_03"
    case artic04 = "artic_04"
    case artic05 = "artic_05"
    case artic06 = "artic_06"
    case artic07 = "artic_07"
    case artic08 = "artic_08"
    case artic09 = "artic_09"
    case artic10 = "artic_10"

    // Подбадривание при ошибке
    case encourage01 = "encourage_01"
    case encourage02 = "encourage_02"
    case encourage03 = "encourage_03"
    case encourage04 = "encourage_04"
    case encourage05 = "encourage_05"
    case encourage06 = "encourage_06"
    case encourage07 = "encourage_07"
    case encourage08 = "encourage_08"
    case encourage09 = "encourage_09"
    case encourage10 = "encourage_10"
}

// MARK: - SoundServiceProtocol

public protocol SoundServiceProtocol: Sendable {
    /// Воспроизводит UI-звук. Возвращает немедленно (fire-and-forget).
    func playUISound(_ sound: UISound)
    /// Воспроизводит фразу маскота Ляли. Возвращает немедленно.
    func playLyalya(_ phrase: LyalyaPhrase)
    /// Отключает/включает все звуки (настройка пользователя).
    var isMuted: Bool { get }
    func setMuted(_ muted: Bool)
}

// MARK: - LiveSoundService

/// Производственная реализация. Использует NSLock вместо actor, потому что
/// `SoundServiceProtocol.playUISound` — `nonisolated`, а `isMuted: Bool { get }`
/// должен быть синхронно читаемым из любого контекста. Actor-изоляция не
/// подходит для такого контракта (getter требовал бы `async`).
///
/// Внутреннее состояние (`uiPlayerCache`, `lyalyaPlayer`, `isMuted`) защищено
/// единым `lock`. AVAudioPlayer / AVPlayer сами по себе потокобезопасны для
/// `play()` / `currentTime`, но мутация словаря-кэша требует синхронизации.
public final class LiveSoundService: SoundServiceProtocol, @unchecked Sendable {

    private let logger = Logger(subsystem: "com.happyspeech", category: "SoundService")
    private let lock = NSLock()

    // Guarded by `lock`
    private var uiPlayerCache: [String: AVAudioPlayer] = [:]
    private var lyalyaPlayer: AVPlayer?
    private var _isMuted: Bool = false

    public var isMuted: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isMuted
    }

    public init() {
        configureAudioSession()
    }

    // MARK: - Public API

    public func playUISound(_ sound: UISound) {
        guard !isMuted else { return }

        let filename = sound.rawValue

        lock.lock()
        let cached = uiPlayerCache[filename]
        lock.unlock()

        if let cached {
            cached.currentTime = 0
            cached.play()
            return
        }

        guard let url = Bundle.main.url(
            forResource: filename,
            withExtension: "caf",
            subdirectory: "Audio/UI"
        ) else {
            logger.warning("UI sound not found: \(filename, privacy: .public).caf in Audio/UI/")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            lock.lock()
            uiPlayerCache[filename] = player
            lock.unlock()
        } catch {
            logger.error("Failed to play UI sound \(filename, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    public func playLyalya(_ phrase: LyalyaPhrase) {
        guard !isMuted else { return }

        let filename = "lyalya_\(phrase.rawValue)"

        guard let url = Bundle.main.url(
            forResource: filename,
            withExtension: "m4a",
            subdirectory: "Audio/Lyalya"
        ) else {
            logger.warning("Lyalya phrase not found: \(filename, privacy: .public).m4a")
            return
        }

        let player = AVPlayer(url: url)
        lock.lock()
        lyalyaPlayer = player
        lock.unlock()
        player.play()
    }

    public func setMuted(_ muted: Bool) {
        lock.lock()
        _isMuted = muted
        lock.unlock()
    }

    // MARK: - Audio session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            logger.error("Failed to configure AVAudioSession: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - MockSoundService

/// Мок для Preview и Unit-тестов. Логирует вызовы, не воспроизводит звук.
public final class MockSoundService: SoundServiceProtocol, @unchecked Sendable {

    private let logger = Logger(subsystem: "com.happyspeech", category: "MockSoundService")
    public private(set) var isMuted: Bool = false

    public init() {}

    public func playUISound(_ sound: UISound) {
        logger.debug("[Mock] playUISound: \(sound.rawValue)")
    }

    public func playLyalya(_ phrase: LyalyaPhrase) {
        logger.debug("[Mock] playLyalya: \(phrase.rawValue)")
    }

    public func setMuted(_ muted: Bool) {
        isMuted = muted
    }
}
