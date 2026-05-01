import CoreHaptics
import OSLog
import UIKit

// MARK: - HapticPattern

/// 15 именованных паттернов. rawValue совпадает с именем .ahap файла в Resources/Haptics/.
public enum HapticPattern: String, CaseIterable, Sendable {
    case celebration
    case perfectRound
    case wrong
    case lyalyaTap
    case achievementUnlock
    case breathingInhale
    case breathingExhale
    case buttonTap
    case cardSelect
    case levelUp
    case rewardCollected
    case confetti
    case heartbeat
    case notification
    case errorBuzz
}

// MARK: - HapticIntensityLevel

/// Три уровня интенсивности из Settings.
public enum HapticIntensityLevel: String, CaseIterable, Sendable {
    case off
    case subtle
    case full

    public var scale: Float {
        switch self {
        case .off:    return 0.0
        case .subtle: return 0.5
        case .full:   return 1.0
        }
    }

    public static func from(scale: Double) -> HapticIntensityLevel {
        switch scale {
        case ..<0.01: return .off
        case ..<0.75: return .subtle
        default:      return .full
        }
    }
}

// MARK: - LiveHapticService

/// CHHapticEngine-реализация. Используется на iPhone 8+ и iPad mini 5+ с Taptic Engine.
public final class LiveHapticService: HapticService, @unchecked Sendable {

    // MARK: - Private state
    // nonisolated(unsafe) — доступ только из последовательного Task-контекста (Main или dedicated).
    nonisolated(unsafe) private var engine: CHHapticEngine?
    nonisolated(unsafe) private var intensityScale: Float = 1.0
    private let logger = Logger(subsystem: "ru.happyspeech", category: "HapticService")

    // MARK: - Init

    public init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let eng = try CHHapticEngine()
            eng.stoppedHandler = { [weak self] reason in
                self?.logger.info("CHHapticEngine stopped: \(reason.rawValue, privacy: .public)")
            }
            eng.resetHandler = { [weak self] in
                self?.logger.info("CHHapticEngine reset — restarting")
            }
            engine = eng
        } catch {
            logger.error("CHHapticEngine init failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - HapticService

    public var isAvailable: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    public func play(pattern: HapticPattern) async {
        guard let eng = engine, isAvailable, intensityScale > 0 else { return }
        guard let url = Bundle.main.url(forResource: pattern.rawValue, withExtension: "ahap") else {
            logger.warning("AHAP not found: \(pattern.rawValue, privacy: .public)")
            return
        }
        do {
            try await eng.start()
            try eng.playPattern(from: url)
        } catch {
            logger.error("play \(pattern.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func setIntensityScale(_ scale: Float) {
        intensityScale = max(0, min(1, scale))
        logger.debug("intensityScale → \(scale, privacy: .public)")
    }

    public func stop() async {
        try? await engine?.stop()
    }

    // MARK: - Legacy shim: backward compat с существующими call sites

    public func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let pattern: HapticPattern
        switch style {
        case .heavy:  pattern = .cardSelect
        case .medium: pattern = .cardSelect
        case .rigid:  pattern = .buttonTap
        case .soft:   pattern = .buttonTap
        default:      pattern = .buttonTap
        }
        Task { @MainActor in await self.play(pattern: pattern) }
    }

    public func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let pattern: HapticPattern
        switch type {
        case .success: pattern = .celebration
        case .warning: pattern = .wrong
        case .error:   pattern = .errorBuzz
        default:       pattern = .notification
        }
        Task { @MainActor in await self.play(pattern: pattern) }
    }

    public func selection() {
        Task { @MainActor in await self.play(pattern: .cardSelect) }
    }
}

// MARK: - FallbackHapticService

/// UIImpactFeedbackGenerator fallback для устройств без CHHapticEngine
/// (iPhone 7 и старше, iPad без Taptic Engine, все симуляторы).
/// @unchecked Sendable — UIKit feedback generators создаются и вызываются только на MainActor.
public final class FallbackHapticService: HapticService, @unchecked Sendable {

    nonisolated(unsafe) private var intensityScale: Float = 1.0
    private let logger = Logger(subsystem: "ru.happyspeech", category: "HapticServiceFallback")

    public init() {}

    public var isAvailable: Bool { true }

    public func play(pattern: HapticPattern) async {
        guard intensityScale > 0 else { return }
        await MainActor.run {
            switch pattern {
            case .celebration, .perfectRound, .achievementUnlock, .levelUp, .confetti:
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            case .cardSelect, .rewardCollected, .heartbeat, .errorBuzz:
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case .wrong:
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case .lyalyaTap, .buttonTap, .notification, .breathingInhale, .breathingExhale:
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    public func setIntensityScale(_ scale: Float) {
        intensityScale = max(0, min(1, scale))
    }

    public func stop() async {}

    // MARK: - Legacy shim

    public func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard intensityScale > 0 else { return }
        Task { @MainActor in UIImpactFeedbackGenerator(style: style).impactOccurred() }
    }

    public func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard intensityScale > 0 else { return }
        Task { @MainActor in UINotificationFeedbackGenerator().notificationOccurred(type) }
    }

    public func selection() {
        guard intensityScale > 0 else { return }
        Task { @MainActor in UISelectionFeedbackGenerator().selectionChanged() }
    }
}
