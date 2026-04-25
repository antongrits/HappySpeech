import Foundation
import Observation

// MARK: - OnboardingDisplayLogic

@MainActor
protocol OnboardingDisplayLogic: AnyObject {
    func displayLoadOnboarding(_ viewModel: OnboardingModels.LoadOnboarding.ViewModel)
    func displayAdvanceStep(_ viewModel: OnboardingModels.AdvanceStep.ViewModel)
    func displayGoBack(_ viewModel: OnboardingModels.GoBack.ViewModel)
    func displaySetRole(_ viewModel: OnboardingModels.SetRole.ViewModel)
    func displaySetProfile(_ viewModel: OnboardingModels.SetProfile.ViewModel)
    func displayToggleGoal(_ viewModel: OnboardingModels.ToggleGoal.ViewModel)
    func displaySkipPermissions(_ viewModel: OnboardingModels.SkipPermissions.ViewModel)
    func displayStartModelDownload(_ viewModel: OnboardingModels.StartModelDownload.ViewModel)
    func displayCompleteOnboarding(_ viewModel: OnboardingModels.CompleteOnboarding.ViewModel)
}

// MARK: - OnboardingDisplay (Observable Store)

@Observable
@MainActor
final class OnboardingDisplay: OnboardingDisplayLogic {

    // Step
    var currentStep: OnboardingStep = .welcome
    var totalSteps: Int = OnboardingStep.allCases.count
    var progress: Double = 0
    var progressLabel: String = ""

    // Profile
    var profile: OnboardingProfile = OnboardingProfile()

    // CTA
    var canAdvance: Bool = true

    // Model download
    var modelStatus: ModelDownloadStatus = .idle
    var modelStatusLabel: String = ""

    // Routing intent
    var pendingCompleted: Bool = false

    // MARK: - DisplayLogic

    func displayLoadOnboarding(_ viewModel: OnboardingModels.LoadOnboarding.ViewModel) {
        currentStep = viewModel.currentStep
        totalSteps = viewModel.totalSteps
        progress = viewModel.progress
        progressLabel = viewModel.progressLabel
        profile = viewModel.profile
        canAdvance = viewModel.canAdvance
    }

    func displayAdvanceStep(_ viewModel: OnboardingModels.AdvanceStep.ViewModel) {
        currentStep = viewModel.currentStep
        totalSteps = viewModel.totalSteps
        progress = viewModel.progress
        progressLabel = viewModel.progressLabel
        profile = viewModel.profile
        canAdvance = viewModel.canAdvance
        if viewModel.isCompleted { pendingCompleted = true }
    }

    func displayGoBack(_ viewModel: OnboardingModels.GoBack.ViewModel) {
        currentStep = viewModel.currentStep
        totalSteps = viewModel.totalSteps
        progress = viewModel.progress
        progressLabel = viewModel.progressLabel
        canAdvance = viewModel.canAdvance
    }

    func displaySetRole(_ viewModel: OnboardingModels.SetRole.ViewModel) {
        profile = viewModel.profile
        canAdvance = viewModel.canAdvance
    }

    func displaySetProfile(_ viewModel: OnboardingModels.SetProfile.ViewModel) {
        profile = viewModel.profile
        canAdvance = viewModel.canAdvance
    }

    func displayToggleGoal(_ viewModel: OnboardingModels.ToggleGoal.ViewModel) {
        profile = viewModel.profile
        canAdvance = viewModel.canAdvance
    }

    func displaySkipPermissions(_ viewModel: OnboardingModels.SkipPermissions.ViewModel) {
        currentStep = viewModel.currentStep
        totalSteps = viewModel.totalSteps
        progress = viewModel.progress
        progressLabel = viewModel.progressLabel
        canAdvance = viewModel.canAdvance
    }

    func displayStartModelDownload(_ viewModel: OnboardingModels.StartModelDownload.ViewModel) {
        modelStatus = viewModel.status
        canAdvance = viewModel.canAdvance
        modelStatusLabel = viewModel.statusLabel
    }

    func displayCompleteOnboarding(_ viewModel: OnboardingModels.CompleteOnboarding.ViewModel) {
        profile = viewModel.profile
        pendingCompleted = true
    }

    // MARK: - View helpers

    func consumeCompleted() { pendingCompleted = false }
}
