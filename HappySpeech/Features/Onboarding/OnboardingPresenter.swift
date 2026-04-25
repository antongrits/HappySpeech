import Foundation
import OSLog

// MARK: - OnboardingPresentationLogic

@MainActor
protocol OnboardingPresentationLogic: AnyObject {
    func presentLoadOnboarding(_ response: OnboardingModels.LoadOnboarding.Response)
    func presentAdvanceStep(_ response: OnboardingModels.AdvanceStep.Response)
    func presentGoBack(_ response: OnboardingModels.GoBack.Response)
    func presentSetRole(_ response: OnboardingModels.SetRole.Response)
    func presentSetProfile(_ response: OnboardingModels.SetProfile.Response)
    func presentToggleGoal(_ response: OnboardingModels.ToggleGoal.Response)
    func presentSkipPermissions(_ response: OnboardingModels.SkipPermissions.Response)
    func presentStartModelDownload(_ response: OnboardingModels.StartModelDownload.Response)
    func presentCompleteOnboarding(_ response: OnboardingModels.CompleteOnboarding.Response)
}

// MARK: - OnboardingPresenter

@MainActor
final class OnboardingPresenter: OnboardingPresentationLogic {

    // MARK: - Collaborators

    weak var display: (any OnboardingDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "OnboardingPresenter")

    // MARK: - PresentationLogic

    func presentLoadOnboarding(_ response: OnboardingModels.LoadOnboarding.Response) {
        let total = OnboardingStep.allCases.count
        let canAdvance = canAdvance(from: response.initialStep, profile: response.profile)
        display?.displayLoadOnboarding(.init(
            currentStep: response.initialStep,
            totalSteps: total,
            progress: progress(from: response.initialStep, total: total),
            progressLabel: progressLabel(from: response.initialStep, total: total),
            profile: response.profile,
            canAdvance: canAdvance
        ))
    }

    func presentAdvanceStep(_ response: OnboardingModels.AdvanceStep.Response) {
        let total = OnboardingStep.allCases.count
        let canAdvance = canAdvance(from: response.currentStep, profile: response.profile)
        display?.displayAdvanceStep(.init(
            currentStep: response.currentStep,
            totalSteps: total,
            progress: progress(from: response.currentStep, total: total),
            progressLabel: progressLabel(from: response.currentStep, total: total),
            profile: response.profile,
            canAdvance: canAdvance,
            isCompleted: response.isCompleted
        ))
    }

    func presentGoBack(_ response: OnboardingModels.GoBack.Response) {
        let total = OnboardingStep.allCases.count
        let canAdvance = canAdvance(from: response.currentStep, profile: response.profile)
        display?.displayGoBack(.init(
            currentStep: response.currentStep,
            totalSteps: total,
            progress: progress(from: response.currentStep, total: total),
            progressLabel: progressLabel(from: response.currentStep, total: total),
            canAdvance: canAdvance
        ))
    }

    func presentSetRole(_ response: OnboardingModels.SetRole.Response) {
        display?.displaySetRole(.init(
            profile: response.profile,
            canAdvance: canAdvance(from: .role, profile: response.profile)
        ))
    }

    func presentSetProfile(_ response: OnboardingModels.SetProfile.Response) {
        display?.displaySetProfile(.init(
            profile: response.profile,
            canAdvance: canAdvance(from: .childProfile, profile: response.profile)
        ))
    }

    func presentToggleGoal(_ response: OnboardingModels.ToggleGoal.Response) {
        display?.displayToggleGoal(.init(
            profile: response.profile,
            canAdvance: canAdvance(from: .goals, profile: response.profile)
        ))
    }

    func presentSkipPermissions(_ response: OnboardingModels.SkipPermissions.Response) {
        let total = OnboardingStep.allCases.count
        display?.displaySkipPermissions(.init(
            currentStep: response.currentStep,
            totalSteps: total,
            progress: progress(from: response.currentStep, total: total),
            progressLabel: progressLabel(from: response.currentStep, total: total),
            canAdvance: canAdvance(from: response.currentStep, profile: response.profile)
        ))
    }

    func presentStartModelDownload(_ response: OnboardingModels.StartModelDownload.Response) {
        let label: String
        let canAdvance: Bool
        switch response.status {
        case .idle:
            label = String(localized: "onboarding.model.idle")
            canAdvance = true   // позволено пропустить
        case .downloading(let progress):
            let percent = Int((progress * 100).rounded())
            label = String(format: String(localized: "onboarding.model.downloading"), percent)
            canAdvance = false
        case .completed:
            label = String(localized: "onboarding.model.completed")
            canAdvance = true
        case .failed(let message):
            label = message
            canAdvance = true
        case .skipped:
            label = String(localized: "onboarding.model.skipped")
            canAdvance = true
        }
        display?.displayStartModelDownload(.init(
            status: response.status,
            canAdvance: canAdvance,
            statusLabel: label
        ))
    }

    func presentCompleteOnboarding(_ response: OnboardingModels.CompleteOnboarding.Response) {
        display?.displayCompleteOnboarding(.init(profile: response.profile))
    }

    // MARK: - Private helpers

    /// Можно ли двигаться дальше с текущего шага. На некоторых шагах
    /// блокируем CTA, пока пользователь не заполнил данные.
    private func canAdvance(from step: OnboardingStep, profile: OnboardingProfile) -> Bool {
        switch step {
        case .welcome:
            return true
        case .role:
            return true   // роль всегда выбрана (default = .parent)
        case .childProfile:
            return profile.childName.trimmingCharacters(in: .whitespaces).count >= 2
        case .goals:
            return true   // можно пропустить
        case .permissions:
            return true
        case .modelDownload:
            return true
        case .completion:
            return true
        }
    }

    private func progress(from step: OnboardingStep, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(step.rawValue + 1) / Double(total)
    }

    private func progressLabel(from step: OnboardingStep, total: Int) -> String {
        String(format: String(localized: "onboarding.progress.label"), step.rawValue + 1, total)
    }
}
