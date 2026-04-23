import Foundation
import Observation
import OSLog

// MARK: - GuidedTourCoordinator

/// Orchestrates progression through `TourSteps`: tracks current step, handles
/// auto-advance timers, plays Lyalya voice-over on entry, persists completion
/// so the tour is shown once per install (unless user re-triggers via Settings).
///
/// `@Observable` + `@MainActor` — mirrors the app-wide convention; safe to drive
/// SwiftUI views directly.
@MainActor
@Observable
public final class GuidedTourCoordinator {

    // MARK: - State

    /// All steps (currently 11 — see `TourSteps.all`).
    public private(set) var steps: [TourStep]

    /// Index of the currently displayed step; `nil` when the tour is idle.
    public private(set) var currentIndex: Int?

    /// `true` while the tour overlay is on screen.
    public private(set) var isActive: Bool = false

    /// `true` once the user finished or dismissed the tour in this install.
    public private(set) var hasCompleted: Bool

    // MARK: - Dependencies

    private let soundService: any SoundServiceProtocol
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "ru.happyspeech", category: "GuidedTour")

    private var autoAdvanceTask: Task<Void, Never>?

    private static let completionKey = "happyspeech.guidedTour.completed.v1"

    // MARK: - Init

    public init(
        soundService: any SoundServiceProtocol,
        steps: [TourStep] = TourSteps.all,
        defaults: UserDefaults = .standard
    ) {
        self.soundService = soundService
        self.steps = steps
        self.defaults = defaults
        self.hasCompleted = defaults.bool(forKey: Self.completionKey)
    }

    // MARK: - Derived

    public var currentStep: TourStep? {
        guard let index = currentIndex, steps.indices.contains(index) else { return nil }
        return steps[index]
    }

    public var progressFraction: Double {
        guard !steps.isEmpty, let index = currentIndex else { return 0 }
        return Double(index + 1) / Double(steps.count)
    }

    public var isOnLastStep: Bool {
        guard let index = currentIndex else { return false }
        return index == steps.count - 1
    }

    // MARK: - Intents

    /// Starts the tour from the first step. No-op if already active.
    public func start(force: Bool = false) {
        guard !isActive else { return }
        if hasCompleted && !force {
            logger.debug("tour already completed, skipping auto-start")
            return
        }
        logger.info("tour start, steps=\(self.steps.count, privacy: .public)")
        isActive = true
        enter(stepIndex: 0)
    }

    public func next() {
        cancelAutoAdvance()
        guard let index = currentIndex else { return }
        if index + 1 >= steps.count {
            complete()
        } else {
            enter(stepIndex: index + 1)
        }
    }

    public func skip() {
        logger.info("tour skipped at index=\(self.currentIndex ?? -1, privacy: .public)")
        complete()
    }

    public func resetForTesting() {
        defaults.removeObject(forKey: Self.completionKey)
        hasCompleted = false
        isActive = false
        currentIndex = nil
        cancelAutoAdvance()
    }

    // MARK: - Private

    private func enter(stepIndex: Int) {
        currentIndex = stepIndex
        let step = steps[stepIndex]

        if let phraseId = step.lyalyaPhrase, let phrase = LyalyaPhrase(rawValue: phraseId) {
            soundService.playLyalya(phrase)
        }

        if let delay = step.autoAdvanceAfter {
            scheduleAutoAdvance(after: delay)
        }
    }

    private func scheduleAutoAdvance(after delay: TimeInterval) {
        cancelAutoAdvance()
        autoAdvanceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.next() }
        }
    }

    private func cancelAutoAdvance() {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
    }

    private func complete() {
        cancelAutoAdvance()
        currentIndex = nil
        isActive = false
        hasCompleted = true
        defaults.set(true, forKey: Self.completionKey)
        logger.info("tour completed")
    }
}
