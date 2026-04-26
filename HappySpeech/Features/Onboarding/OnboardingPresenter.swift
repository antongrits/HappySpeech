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
    func presentSetAge(_ response: OnboardingModels.SetAge.Response)
    func presentToggleGoal(_ response: OnboardingModels.ToggleGoal.Response)
    func presentToggleSound(_ response: OnboardingModels.ToggleSound.Response)
    func presentSetSchedule(_ response: OnboardingModels.SetSchedule.Response)
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
            canAdvance: canAdvance,
            mascotText: mascotText(for: response.initialStep)
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
            isCompleted: response.isCompleted,
            mascotText: mascotText(for: response.currentStep)
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
            canAdvance: canAdvance,
            mascotText: mascotText(for: response.currentStep)
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
            canAdvance: canAdvance(from: .childName, profile: response.profile)
        ))
    }

    func presentSetAge(_ response: OnboardingModels.SetAge.Response) {
        display?.displaySetAge(.init(
            profile: response.profile,
            canAdvance: canAdvance(from: .childAge, profile: response.profile)
        ))
    }

    func presentToggleGoal(_ response: OnboardingModels.ToggleGoal.Response) {
        display?.displayToggleGoal(.init(
            profile: response.profile,
            canAdvance: canAdvance(from: .goals, profile: response.profile)
        ))
    }

    func presentToggleSound(_ response: OnboardingModels.ToggleSound.Response) {
        display?.displayToggleSound(.init(
            profile: response.profile,
            canAdvance: canAdvance(from: .sounds, profile: response.profile)
        ))
    }

    func presentSetSchedule(_ response: OnboardingModels.SetSchedule.Response) {
        display?.displaySetSchedule(.init(
            profile: response.profile,
            canAdvance: canAdvance(from: .schedule, profile: response.profile)
        ))
    }

    func presentSkipPermissions(_ response: OnboardingModels.SkipPermissions.Response) {
        let total = OnboardingStep.allCases.count
        display?.displaySkipPermissions(.init(
            currentStep: response.currentStep,
            totalSteps: total,
            progress: progress(from: response.currentStep, total: total),
            progressLabel: progressLabel(from: response.currentStep, total: total),
            canAdvance: canAdvance(from: response.currentStep, profile: response.profile),
            mascotText: mascotText(for: response.currentStep)
        ))
    }

    func presentStartModelDownload(_ response: OnboardingModels.StartModelDownload.Response) {
        let label: String
        let canAdvance: Bool
        switch response.status {
        case .idle:
            label = String(localized: "onboarding.model.idle")
            canAdvance = true
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
        case .childName:
            return profile.childName.trimmingCharacters(in: .whitespaces).count >= 2
        case .childAge:
            // Возраст всегда задан default'ом, но дополнительно валидируем диапазон.
            return OnboardingProfile.availableAges.contains(profile.childAge)
        case .goals:
            // Goals — обязательный шаг (хотя бы одна цель).
            return !profile.goals.isEmpty
        case .sounds:
            return true   // звуки опциональны
        case .schedule:
            return OnboardingProfile.availableSchedules.contains(profile.dailyMinutes)
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

    /// Фраза Ляли для каждого шага онбординга.
    /// Используется в mascot-пузырьке под шагом.
    private func mascotText(for step: OnboardingStep) -> String {
        switch step {
        case .welcome:       return String(localized: "onboarding.mascot.welcome")
        case .role:          return String(localized: "onboarding.mascot.role")
        case .childName:     return String(localized: "onboarding.mascot.name")
        case .childAge:      return String(localized: "onboarding.mascot.age")
        case .goals:         return String(localized: "onboarding.mascot.goals")
        case .sounds:        return String(localized: "onboarding.mascot.sounds")
        case .schedule:      return String(localized: "onboarding.mascot.schedule")
        case .permissions:   return String(localized: "onboarding.mascot.permissions")
        case .modelDownload: return String(localized: "onboarding.mascot.download")
        case .completion:    return String(localized: "onboarding.mascot.complete")
        }
    }
}
