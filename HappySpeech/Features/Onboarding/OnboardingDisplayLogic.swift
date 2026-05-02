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
    func displaySetAge(_ viewModel: OnboardingModels.SetAge.ViewModel)
    func displaySetGender(_ viewModel: OnboardingModels.SetGender.ViewModel)
    func displayToggleGoal(_ viewModel: OnboardingModels.ToggleGoal.ViewModel)
    func displayToggleSound(_ viewModel: OnboardingModels.ToggleSound.ViewModel)
    func displaySetSchedule(_ viewModel: OnboardingModels.SetSchedule.ViewModel)
    func displaySetLyalyaPreset(_ viewModel: OnboardingModels.SetLyalyaPreset.ViewModel)
    func displayPermissionsStatus(_ viewModel: OnboardingModels.RequestPermission.ViewModel)
    func displaySkipPermissions(_ viewModel: OnboardingModels.SkipPermissions.ViewModel)
    func displaySetReminderTime(_ viewModel: OnboardingModels.SetReminderTime.ViewModel)
    func displayPrivacyConsent(_ viewModel: OnboardingModels.AcceptPrivacyConsent.ViewModel)
    func displayPrivacyConsentRequired(_ viewModel: OnboardingModels.PrivacyConsentRequired.ViewModel)
    func displayScreeningChoice(_ viewModel: OnboardingModels.SelectScreeningChoice.ViewModel)
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

    // Permissions
    var permissionsStatus: OnboardingPermissionsStatus = OnboardingPermissionsStatus()
    var permissionsMicLabel: String = ""
    var permissionsCameraLabel: String = ""
    var permissionsNotificationsLabel: String = ""

    // Reminder
    var reminderTimeFormatted: String = "17:00"

    // Privacy
    var privacyConsentError: String = ""

    // Screening
    var screeningChoice: Bool = false

    // CTA
    var canAdvance: Bool = true

    // Model download
    var modelStatus: ModelDownloadStatus = .idle
    var modelStatusLabel: String = ""

    // Mascot per-step phrase
    var mascotText: String = ""

    // Screening skip flag (если пользователь нажал «Пропустить скрининг»)
    var screeningSkipped: Bool = false

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
        mascotText = viewModel.mascotText
    }

    func displayAdvanceStep(_ viewModel: OnboardingModels.AdvanceStep.ViewModel) {
        currentStep = viewModel.currentStep
        totalSteps = viewModel.totalSteps
        progress = viewModel.progress
        progressLabel = viewModel.progressLabel
        profile = viewModel.profile
        canAdvance = viewModel.canAdvance
        mascotText = viewModel.mascotText
        if viewModel.isCompleted { pendingCompleted = true }
    }

    func displayGoBack(_ viewModel: OnboardingModels.GoBack.ViewModel) {
        currentStep = viewModel.currentStep
        totalSteps = viewModel.totalSteps
        progress = viewModel.progress
        progressLabel = viewModel.progressLabel
        canAdvance = viewModel.canAdvance
        mascotText = viewModel.mascotText
    }

    func displaySetRole(_ viewModel: OnboardingModels.SetRole.ViewModel) {
        profile = viewModel.profile
        canAdvance = viewModel.canAdvance
    }

    func displaySetProfile(_ viewModel: OnboardingModels.SetProfile.ViewModel) {
        profile = viewModel.profile
        canAdvance = viewModel.canAdvance
    }

    func displaySetAge(_ viewModel: OnboardingModels.SetAge.ViewModel) {
        profile = viewModel.profile
        canAdvance = viewModel.canAdvance
    }

    func displaySetGender(_ viewModel: OnboardingModels.SetGender.ViewModel) {
        profile = viewModel.profile
        canAdvance = viewModel.canAdvance
    }

    func displayToggleGoal(_ viewModel: OnboardingModels.ToggleGoal.ViewModel) {
        profile = viewModel.profile
        canAdvance = viewModel.canAdvance
    }

    func displayToggleSound(_ viewModel: OnboardingModels.ToggleSound.ViewModel) {
        profile = viewModel.profile
        canAdvance = viewModel.canAdvance
    }

    func displaySetSchedule(_ viewModel: OnboardingModels.SetSchedule.ViewModel) {
        profile = viewModel.profile
        canAdvance = viewModel.canAdvance
    }

    func displaySetLyalyaPreset(_ viewModel: OnboardingModels.SetLyalyaPreset.ViewModel) {
        profile = viewModel.profile
        canAdvance = viewModel.canAdvance
    }

    func displayPermissionsStatus(_ viewModel: OnboardingModels.RequestPermission.ViewModel) {
        permissionsStatus = viewModel.permissionsStatus
        permissionsMicLabel = viewModel.micLabel
        permissionsCameraLabel = viewModel.cameraLabel
        permissionsNotificationsLabel = viewModel.notificationsLabel
        canAdvance = viewModel.canAdvance
    }

    func displaySkipPermissions(_ viewModel: OnboardingModels.SkipPermissions.ViewModel) {
        currentStep = viewModel.currentStep
        totalSteps = viewModel.totalSteps
        progress = viewModel.progress
        progressLabel = viewModel.progressLabel
        canAdvance = viewModel.canAdvance
        mascotText = viewModel.mascotText
    }

    func displaySetReminderTime(_ viewModel: OnboardingModels.SetReminderTime.ViewModel) {
        profile = viewModel.profile
        reminderTimeFormatted = viewModel.timeFormatted
        canAdvance = viewModel.canAdvance
    }

    func displayPrivacyConsent(_ viewModel: OnboardingModels.AcceptPrivacyConsent.ViewModel) {
        profile = viewModel.profile
        canAdvance = viewModel.canAdvance
    }

    func displayPrivacyConsentRequired(_ viewModel: OnboardingModels.PrivacyConsentRequired.ViewModel) {
        privacyConsentError = viewModel.errorMessage
    }

    func displayScreeningChoice(_ viewModel: OnboardingModels.SelectScreeningChoice.ViewModel) {
        profile = viewModel.profile
        screeningChoice = viewModel.wantsScreening
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
