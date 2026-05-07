import Foundation
import OSLog

// MARK: - GuidedTourInteractor
//
// Block I v16 — VIP Interactor с реальной domain logic.
//
// Ответственности (бизнес-уровень, без UI):
//   1. Управление шагами тура (currentIndex, steps array, переходы).
//   2. Persistence через UserDefaults: completedTours (Set<TourFlavor>),
//      currentStep (resume mid-tour), lastSeenAt (timestamp для analytics).
//   3. Gating logic — показывать тур только если ребёнок ≥N сессий
//      (защита от информационной перегрузки на самой первой сессии).
//   4. Analytics events (через AnalyticsService):
//        - tour_started / tour_resumed
//        - tour_step_viewed (с stepId + index)
//        - tour_skipped (с last_step)
//        - tour_completed (с reached_final flag)
//   5. Multi-tour management (TourFlavor: onboarding, settings, lesson).
//   6. Side-effect: воспроизведение голоса Ляли через SoundServiceProtocol.
//   7. Auto-advance: Task + Task.sleep с защитой от race-condition
//      через `scheduledForIndex`.
//
// Race-condition защита:
//   - Если пользователь жмёт "Next" пока крутится auto-advance таймер,
//     scheduledForIndex != currentIndex → AutoAdvance.Response.kind = .stale,
//     Presenter игнорирует.
//
// COPPA-safety:
//   - Никаких сетевых вызовов.
//   - Analytics локальная (LocalAnalyticsService) — никаких 3rd-party SDK.
//   - childId используется ТОЛЬКО для session count gating через SessionRepository.

@MainActor
final class GuidedTourInteractor: GuidedTourBusinessLogic {

    // MARK: - Persistence keys

    private enum Keys {
        static let completedToursV1 = "happyspeech.guidedTour.completedFlavors.v1"
        static let resumeIndex = "happyspeech.guidedTour.resumeIndex.v1"
        static let resumeFlavor = "happyspeech.guidedTour.resumeFlavor.v1"
        static let lastSeenAt = "happyspeech.guidedTour.lastSeenAt.v1"
        // Legacy — D.3 v15 хранил один bool.
        static let legacyCompleted = "happyspeech.guidedTour.completed.v1"
    }

    /// Минимум завершённых сессий, чтобы показать onboarding-тур.
    /// 0 — всегда показывать (default для дипломной демо-версии). Можно
    /// поднять до 2 в production, чтобы дети сначала попробовали игру.
    static let defaultGatingThreshold: Int = 0

    // MARK: - Collaborators (VIP)

    var presenter: (any GuidedTourPresentationLogic)?

    // MARK: - Dependencies

    private let soundService: any SoundServiceProtocol
    private let analyticsService: any AnalyticsService
    private let sessionRepository: (any SessionRepository)?
    private let defaults: UserDefaults
    private let gatingThreshold: Int
    private let logger = Logger(subsystem: "ru.happyspeech", category: "GuidedTourInteractor")

    // MARK: - State (бизнес-уровень)

    private var flavor: TourFlavor
    private(set) var steps: [TourStep]
    private(set) var currentIndex: Int?
    private(set) var isActive: Bool = false
    private(set) var hasCompletedCurrentFlavor: Bool

    private var autoAdvanceTask: Task<Void, Never>?

    // MARK: - Init

    init(
        soundService: any SoundServiceProtocol,
        analyticsService: any AnalyticsService,
        sessionRepository: (any SessionRepository)? = nil,
        defaults: UserDefaults = .standard,
        gatingThreshold: Int = GuidedTourInteractor.defaultGatingThreshold,
        flavor: TourFlavor = .onboarding,
        steps: [TourStep]? = nil
    ) {
        self.soundService = soundService
        self.analyticsService = analyticsService
        self.sessionRepository = sessionRepository
        self.defaults = defaults
        self.gatingThreshold = max(0, gatingThreshold)
        self.flavor = flavor
        if let steps {
            self.steps = steps
        } else {
            self.steps = TourSteps.steps(for: flavor)
        }

        // Migrate legacy completion flag (D.3 v15) на новый Set<TourFlavor>.
        if defaults.bool(forKey: Keys.legacyCompleted) {
            var completed = Self.readCompletedFlavors(defaults: defaults)
            completed.insert(.onboarding)
            Self.writeCompletedFlavors(completed, defaults: defaults)
            defaults.removeObject(forKey: Keys.legacyCompleted)
        }

        let completed = Self.readCompletedFlavors(defaults: defaults)
        self.hasCompletedCurrentFlavor = completed.contains(.onboarding)
    }

    deinit {
        autoAdvanceTask?.cancel()
    }

    // MARK: - BusinessLogic: LoadTour

    func loadTour(_ request: GuidedTourModels.LoadTour.Request) {
        // 1. Если тур уже активен — no-op.
        guard !isActive else {
            logger.debug("loadTour: already active, ignoring")
            return
        }

        // 2. Проверка persistence: уже завершён → не запускаем (force=true пропускает).
        let completed = Self.readCompletedFlavors(defaults: defaults)
        if !request.force && completed.contains(flavor) {
            logger.debug("loadTour: flavor=\(self.flavor.rawValue, privacy: .public) already completed")
            presenter?.presentLoadTour(.init(
                kind: .alreadyCompleted,
                steps: steps,
                initialIndex: 0
            ))
            return
        }

        // 3. Gating через session count (асинхронно, если childId передан).
        if let childId = request.childId, gatingThreshold > 0, !request.force {
            Task { [weak self] in
                guard let self else { return }
                let count = await self.fetchSessionCount(childId: childId)
                if count < self.gatingThreshold {
                    self.presenter?.presentLoadTour(.init(
                        kind: .gatedBySessionCount(required: self.gatingThreshold, current: count),
                        steps: self.steps,
                        initialIndex: 0
                    ))
                } else {
                    self.startTourSync()
                }
            }
            return
        }

        // 4. Sync-старт.
        startTourSync()
    }

    private func startTourSync() {
        // Resume: если был сохранён индекс прерывания → стартуем оттуда.
        let resumeIndex = readResumeIndex()
        let initialIndex = resumeIndex.flatMap { steps.indices.contains($0) ? $0 : nil } ?? 0
        let isResuming = resumeIndex != nil && initialIndex > 0

        isActive = true
        currentIndex = initialIndex
        defaults.set(Date(), forKey: Keys.lastSeenAt)
        writeResumeIndex(initialIndex)

        track(event: isResuming ? "tour_resumed" : "tour_started", parameters: [
            "flavor": flavor.rawValue,
            "initial_step": "\(initialIndex)",
            "total_steps": "\(steps.count)"
        ])

        playSideEffects(forStepAt: initialIndex)

        presenter?.presentLoadTour(.init(
            kind: .started,
            steps: steps,
            initialIndex: initialIndex
        ))

        scheduleAutoAdvanceIfNeeded(stepIndex: initialIndex)
    }

    // MARK: - BusinessLogic: NextStep

    func nextStep(_ request: GuidedTourModels.NextStep.Request) {
        _ = request
        cancelAutoAdvance()

        guard isActive, let index = currentIndex else {
            presenter?.presentNextStep(.init(kind: .noop, steps: steps, newIndex: nil))
            return
        }

        let nextIdx = index + 1
        if nextIdx >= steps.count {
            // Последний шаг → завершение.
            finalizeCompletion(reachedFinalStep: true)
            presenter?.presentNextStep(.init(kind: .completed, steps: steps, newIndex: nil))
            return
        }

        currentIndex = nextIdx
        writeResumeIndex(nextIdx)
        track(event: "tour_step_viewed", parameters: [
            "flavor": flavor.rawValue,
            "step_id": steps[nextIdx].id,
            "step_index": "\(nextIdx)"
        ])
        playSideEffects(forStepAt: nextIdx)

        presenter?.presentNextStep(.init(kind: .advanced, steps: steps, newIndex: nextIdx))
        scheduleAutoAdvanceIfNeeded(stepIndex: nextIdx)
    }

    // MARK: - BusinessLogic: PreviousStep

    func previousStep(_ request: GuidedTourModels.PreviousStep.Request) {
        _ = request
        cancelAutoAdvance()

        guard isActive, let index = currentIndex else {
            presenter?.presentPreviousStep(.init(kind: .noop, steps: steps, newIndex: nil))
            return
        }

        if index <= 0 {
            presenter?.presentPreviousStep(.init(kind: .atFirstStep, steps: steps, newIndex: index))
            return
        }

        let prev = index - 1
        currentIndex = prev
        writeResumeIndex(prev)
        playSideEffects(forStepAt: prev)
        presenter?.presentPreviousStep(.init(kind: .retreated, steps: steps, newIndex: prev))
        scheduleAutoAdvanceIfNeeded(stepIndex: prev)
    }

    // MARK: - BusinessLogic: SkipTour

    func skipTour(_ request: GuidedTourModels.SkipTour.Request) {
        _ = request
        cancelAutoAdvance()

        let skippedAt = currentIndex ?? -1
        track(event: "tour_skipped", parameters: [
            "flavor": flavor.rawValue,
            "skipped_at_index": "\(skippedAt)",
            "total_steps": "\(steps.count)"
        ])

        finalizeCompletion(reachedFinalStep: false)

        presenter?.presentSkipTour(.init(
            skippedAtIndex: skippedAt,
            totalSteps: steps.count
        ))
    }

    // MARK: - BusinessLogic: CompleteTour

    func completeTour(_ request: GuidedTourModels.CompleteTour.Request) {
        _ = request
        cancelAutoAdvance()
        let reachedFinal = currentIndex == steps.count - 1
        finalizeCompletion(reachedFinalStep: reachedFinal)
        presenter?.presentCompleteTour(.init(reachedFinalStep: reachedFinal))
    }

    // MARK: - BusinessLogic: ResetTour

    func resetTour(_ request: GuidedTourModels.ResetTour.Request) {
        _ = request
        cancelAutoAdvance()

        var completed = Self.readCompletedFlavors(defaults: defaults)
        completed.remove(flavor)
        Self.writeCompletedFlavors(completed, defaults: defaults)
        defaults.removeObject(forKey: Keys.resumeIndex)
        defaults.removeObject(forKey: Keys.resumeFlavor)
        hasCompletedCurrentFlavor = false
        isActive = false
        currentIndex = nil

        track(event: "tour_reset", parameters: ["flavor": flavor.rawValue])
        presenter?.presentResetTour(.init())
    }

    // MARK: - BusinessLogic: AutoAdvance

    func autoAdvance(_ request: GuidedTourModels.AutoAdvance.Request) {
        // Защита от race: если индекс изменился между `Task.sleep` и `await`,
        // считаем `stale` и не двигаемся.
        guard isActive, currentIndex == request.scheduledForIndex else {
            presenter?.presentAutoAdvance(.init(kind: .stale, steps: steps, newIndex: currentIndex))
            return
        }

        let nextIdx = request.scheduledForIndex + 1
        if nextIdx >= steps.count {
            finalizeCompletion(reachedFinalStep: true)
            presenter?.presentAutoAdvance(.init(kind: .completed, steps: steps, newIndex: nil))
            return
        }

        currentIndex = nextIdx
        writeResumeIndex(nextIdx)
        track(event: "tour_step_viewed", parameters: [
            "flavor": flavor.rawValue,
            "step_id": steps[nextIdx].id,
            "step_index": "\(nextIdx)",
            "trigger": "auto_advance"
        ])
        playSideEffects(forStepAt: nextIdx)

        presenter?.presentAutoAdvance(.init(kind: .advanced, steps: steps, newIndex: nextIdx))
        scheduleAutoAdvanceIfNeeded(stepIndex: nextIdx)
    }

    // MARK: - Multi-tour management

    /// Переключение flavor (например, перед запуском settings-тура).
    /// Используется AppContainer DI или Settings View.
    func switchFlavor(_ newFlavor: TourFlavor) {
        cancelAutoAdvance()
        flavor = newFlavor
        steps = TourSteps.steps(for: newFlavor)
        currentIndex = nil
        isActive = false
        let completed = Self.readCompletedFlavors(defaults: defaults)
        hasCompletedCurrentFlavor = completed.contains(newFlavor)
    }

    // MARK: - Derived (бизнес-уровень)

    var currentStep: TourStep? {
        guard let index = currentIndex, steps.indices.contains(index) else { return nil }
        return steps[index]
    }

    var isOnLastStep: Bool {
        guard let index = currentIndex else { return false }
        return index == steps.count - 1
    }

    var progressFraction: Double {
        guard !steps.isEmpty, let index = currentIndex else { return 0 }
        return Double(index + 1) / Double(steps.count)
    }

    // MARK: - Private: side-effects

    private func playSideEffects(forStepAt index: Int) {
        guard steps.indices.contains(index) else { return }
        let step = steps[index]
        if let phraseId = step.lyalyaPhrase, let phrase = LyalyaPhrase(rawValue: phraseId) {
            soundService.playLyalya(phrase)
        }
    }

    // MARK: - Private: auto-advance

    private func scheduleAutoAdvanceIfNeeded(stepIndex: Int) {
        guard steps.indices.contains(stepIndex),
              let delay = steps[stepIndex].autoAdvanceAfter else {
            return
        }
        cancelAutoAdvance()
        let scheduled = stepIndex
        autoAdvanceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.autoAdvance(.init(scheduledForIndex: scheduled))
            }
        }
    }

    private func cancelAutoAdvance() {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
    }

    // MARK: - Private: finalize

    private func finalizeCompletion(reachedFinalStep: Bool) {
        cancelAutoAdvance()
        var completed = Self.readCompletedFlavors(defaults: defaults)
        completed.insert(flavor)
        Self.writeCompletedFlavors(completed, defaults: defaults)
        defaults.removeObject(forKey: Keys.resumeIndex)
        hasCompletedCurrentFlavor = true
        isActive = false
        currentIndex = nil

        track(event: "tour_completed", parameters: [
            "flavor": flavor.rawValue,
            "reached_final": "\(reachedFinalStep)"
        ])
    }

    // MARK: - Private: persistence helpers

    private func writeResumeIndex(_ index: Int) {
        defaults.set(index, forKey: Keys.resumeIndex)
        defaults.set(flavor.rawValue, forKey: Keys.resumeFlavor)
    }

    private func readResumeIndex() -> Int? {
        guard let savedFlavor = defaults.string(forKey: Keys.resumeFlavor),
              savedFlavor == flavor.rawValue else {
            return nil
        }
        let raw = defaults.integer(forKey: Keys.resumeIndex)
        return raw > 0 ? raw : nil
    }

    private static func readCompletedFlavors(defaults: UserDefaults) -> Set<TourFlavor> {
        guard let raw = defaults.array(forKey: Keys.completedToursV1) as? [String] else {
            return []
        }
        return Set(raw.compactMap(TourFlavor.init(rawValue:)))
    }

    private static func writeCompletedFlavors(_ flavors: Set<TourFlavor>, defaults: UserDefaults) {
        let raw = flavors.map(\.rawValue)
        defaults.set(raw, forKey: Keys.completedToursV1)
    }

    // MARK: - Private: gating

    private func fetchSessionCount(childId: String) async -> Int {
        guard let repo = sessionRepository else { return Int.max } // нет репо → не блокируем
        do {
            let sessions = try await repo.fetchAll(childId: childId)
            return sessions.count
        } catch {
            logger.error("fetchSessionCount failed: \(String(describing: error), privacy: .public)")
            return Int.max // при ошибке — лучше показать тур, чем заблокировать
        }
    }

    // MARK: - Private: analytics

    private func track(event name: String, parameters: [String: String]) {
        analyticsService.track(event: AnalyticsEvent(name: name, parameters: parameters))
    }
}
