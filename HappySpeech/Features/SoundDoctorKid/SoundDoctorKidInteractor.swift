import Foundation
import OSLog

// MARK: - SoundDoctorKidInteractor

/// Бизнес-логика игры «Звуковой доктор».
///
/// Случаи подбираются под рабочие звуки ребёнка (`SoundDoctorKidContent` через
/// `ChildRepository`). Каждый выбор фиксируется в интервальном планировщике
/// повторов, по завершении — итоговый SM-2 результат. Без репозитория
/// (Preview/тесты) экран показывает базовый набор случаев.
@MainActor
@Observable
final class SoundDoctorKidInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundDoctorKid"
    )

    let childId: String
    var state: SoundDoctorKidModels.ViewState = .initial

    private let childRepository: (any ChildRepository)?
    private let adaptivePlanner: (any AdaptivePlannerService)?

    init(
        childId: String,
        childRepository: (any ChildRepository)? = nil,
        adaptivePlanner: (any AdaptivePlannerService)? = nil
    ) {
        self.childId = childId
        self.childRepository = childRepository
        self.adaptivePlanner = adaptivePlanner
    }

    func load() async {
        var targets: [String] = []
        if let childRepository, !childId.isEmpty {
            do {
                targets = try await childRepository.fetch(id: childId).targetSounds
            } catch {
                Self.logger.error("child fetch failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        state.cases = SoundDoctorKidContent.cases(forTargetSounds: targets)
        state.currentCaseIndex = 0
        state.cured = 0
        state.isLoaded = true
        Self.logger.info("loaded \(self.state.cases.count, privacy: .public) cases")
    }

    @discardableResult
    func choose(_ optionId: String) -> Bool {
        guard let kase = state.currentCase,
              let option = kase.options.first(where: { $0.id == optionId })
        else { return false }
        if option.isCorrect {
            state.cured += 1
        }
        recordOutcome(kase: kase, correct: option.isCorrect)
        state.currentCaseIndex = min(state.currentCaseIndex + 1, state.cases.count)
        Self.logger.info("choose \(optionId, privacy: .public) correct=\(option.isCorrect)")
        if state.isComplete {
            recordSession()
        }
        return option.isCorrect
    }

    func reset() {
        state.currentCaseIndex = 0
        state.cured = 0
    }

    // MARK: - Persistence

    private func recordOutcome(kase: SoundDoctorKidModels.Case, correct: Bool) {
        guard let planner = adaptivePlanner, !childId.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            await planner.recordItemOutcome(
                childId: self.childId,
                itemId: "doctor-\(kase.sound)",
                sound: kase.sound,
                correct: correct
            )
        }
    }

    private func recordSession() {
        guard let planner = adaptivePlanner, !childId.isEmpty, !state.cases.isEmpty else { return }
        let rate = Double(state.cured) / Double(state.cases.count)
        let quality = SM2Quality.fromSuccessRate(rate)
        let sound = state.cases.first?.sound ?? "С"
        Task { [weak self] in
            guard let self else { return }
            do {
                try await planner.recordSessionResult(
                    childId: self.childId,
                    soundTarget: sound,
                    qualityScore: quality
                )
            } catch {
                Self.logger.error("recordSession failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
