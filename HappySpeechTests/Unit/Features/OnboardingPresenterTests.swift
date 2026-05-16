import XCTest
@testable import HappySpeech

// MARK: - OnboardingPresenterTests
//
// Phase 2.6 batch 3 — покрытие OnboardingPresenter (23% → цель ≥90%).

@MainActor
final class OnboardingPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: OnboardingDisplayLogic {
        var loadVM: OnboardingModels.LoadOnboarding.ViewModel?
        var advanceVM: OnboardingModels.AdvanceStep.ViewModel?
        var goBackVM: OnboardingModels.GoBack.ViewModel?
        var setRoleVM: OnboardingModels.SetRole.ViewModel?
        var setProfileVM: OnboardingModels.SetProfile.ViewModel?
        var setAgeVM: OnboardingModels.SetAge.ViewModel?
        var toggleGoalVM: OnboardingModels.ToggleGoal.ViewModel?
        var toggleSoundVM: OnboardingModels.ToggleSound.ViewModel?
        var setScheduleVM: OnboardingModels.SetSchedule.ViewModel?
        var setGenderVM: OnboardingModels.SetGender.ViewModel?
        var setLyalyaVM: OnboardingModels.SetLyalyaPreset.ViewModel?
        var permissionsVM: OnboardingModels.RequestPermission.ViewModel?
        var skipPermissionsVM: OnboardingModels.SkipPermissions.ViewModel?
        var reminderVM: OnboardingModels.SetReminderTime.ViewModel?
        var privacyVM: OnboardingModels.AcceptPrivacyConsent.ViewModel?
        var privacyRequiredVM: OnboardingModels.PrivacyConsentRequired.ViewModel?
        var screeningChoiceVM: OnboardingModels.SelectScreeningChoice.ViewModel?
        var modelDownloadVM: OnboardingModels.StartModelDownload.ViewModel?
        var completeVM: OnboardingModels.CompleteOnboarding.ViewModel?

        func displayLoadOnboarding(_ vm: OnboardingModels.LoadOnboarding.ViewModel) { loadVM = vm }
        func displayAdvanceStep(_ vm: OnboardingModels.AdvanceStep.ViewModel) { advanceVM = vm }
        func displayGoBack(_ vm: OnboardingModels.GoBack.ViewModel) { goBackVM = vm }
        func displaySetRole(_ vm: OnboardingModels.SetRole.ViewModel) { setRoleVM = vm }
        func displaySetProfile(_ vm: OnboardingModels.SetProfile.ViewModel) { setProfileVM = vm }
        func displaySetAge(_ vm: OnboardingModels.SetAge.ViewModel) { setAgeVM = vm }
        func displaySetGender(_ vm: OnboardingModels.SetGender.ViewModel) { setGenderVM = vm }
        func displaySetLyalyaPreset(_ vm: OnboardingModels.SetLyalyaPreset.ViewModel) { setLyalyaVM = vm }
        func displayToggleGoal(_ vm: OnboardingModels.ToggleGoal.ViewModel) { toggleGoalVM = vm }
        func displayToggleSound(_ vm: OnboardingModels.ToggleSound.ViewModel) { toggleSoundVM = vm }
        func displaySetSchedule(_ vm: OnboardingModels.SetSchedule.ViewModel) { setScheduleVM = vm }
        func displayPermissionsStatus(_ vm: OnboardingModels.RequestPermission.ViewModel) { permissionsVM = vm }
        func displaySkipPermissions(_ vm: OnboardingModels.SkipPermissions.ViewModel) { skipPermissionsVM = vm }
        func displaySetReminderTime(_ vm: OnboardingModels.SetReminderTime.ViewModel) { reminderVM = vm }
        func displayPrivacyConsent(_ vm: OnboardingModels.AcceptPrivacyConsent.ViewModel) { privacyVM = vm }
        func displayPrivacyConsentRequired(_ vm: OnboardingModels.PrivacyConsentRequired.ViewModel) { privacyRequiredVM = vm }
        func displayScreeningChoice(_ vm: OnboardingModels.SelectScreeningChoice.ViewModel) { screeningChoiceVM = vm }
        func displayStartModelDownload(_ vm: OnboardingModels.StartModelDownload.ViewModel) { modelDownloadVM = vm }
        func displayCompleteOnboarding(_ vm: OnboardingModels.CompleteOnboarding.ViewModel) { completeVM = vm }
    }

    private func makeSUT() -> (OnboardingPresenter, DisplaySpy) {
        let sut = OnboardingPresenter()
        let spy = DisplaySpy()
        sut.display = spy
        return (sut, spy)
    }

    private func defaultProfile() -> OnboardingProfile { OnboardingProfile() }

    private func defaultStatus() -> OnboardingPermissionsStatus {
        OnboardingPermissionsStatus(microphoneGranted: false, cameraGranted: false, notificationsGranted: false)
    }

    // MARK: - presentLoadOnboarding

    func test_presentLoadOnboarding_welcomeStep_canAdvance() {
        let (sut, spy) = makeSUT()
        sut.presentLoadOnboarding(.init(
            initialStep: .welcome,
            profile: defaultProfile(),
            permissionsStatus: defaultStatus()
        ))
        XCTAssertNotNil(spy.loadVM)
        XCTAssertTrue(spy.loadVM?.canAdvance == true)
        XCTAssertEqual(spy.loadVM?.currentStep, .welcome)
        XCTAssertFalse(spy.loadVM?.mascotText.isEmpty ?? true)
    }

    func test_presentLoadOnboarding_progressLabel_notEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentLoadOnboarding(.init(
            initialStep: .role,
            profile: defaultProfile(),
            permissionsStatus: defaultStatus()
        ))
        XCTAssertFalse(spy.loadVM?.progressLabel.isEmpty ?? true)
        XCTAssertGreaterThan(spy.loadVM?.progress ?? 0, 0)
    }

    // MARK: - presentAdvanceStep

    func test_presentAdvanceStep_childNameEmpty_cannotAdvance() {
        let (sut, spy) = makeSUT()
        var profile = defaultProfile()
        profile.childName = ""
        sut.presentAdvanceStep(.init(
            currentStep: .childName,
            profile: profile,
            permissionsStatus: defaultStatus(),
            isCompleted: false
        ))
        XCTAssertFalse(spy.advanceVM?.canAdvance ?? true)
    }

    func test_presentAdvanceStep_childNameShort_cannotAdvance() {
        let (sut, spy) = makeSUT()
        var profile = defaultProfile()
        profile.childName = "А"
        sut.presentAdvanceStep(.init(
            currentStep: .childName,
            profile: profile,
            permissionsStatus: defaultStatus(),
            isCompleted: false
        ))
        XCTAssertFalse(spy.advanceVM?.canAdvance ?? true)
    }

    func test_presentAdvanceStep_childNameValid_canAdvance() {
        let (sut, spy) = makeSUT()
        var profile = defaultProfile()
        profile.childName = "Маша"
        sut.presentAdvanceStep(.init(
            currentStep: .childName,
            profile: profile,
            permissionsStatus: defaultStatus(),
            isCompleted: false
        ))
        XCTAssertTrue(spy.advanceVM?.canAdvance == true)
    }

    func test_presentAdvanceStep_goalsEmpty_cannotAdvance() {
        let (sut, spy) = makeSUT()
        var profile = defaultProfile()
        profile.goals = []
        sut.presentAdvanceStep(.init(
            currentStep: .goals,
            profile: profile,
            permissionsStatus: defaultStatus(),
            isCompleted: false
        ))
        XCTAssertFalse(spy.advanceVM?.canAdvance ?? true)
    }

    func test_presentAdvanceStep_goalsNotEmpty_canAdvance() {
        let (sut, spy) = makeSUT()
        var profile = defaultProfile()
        profile.goals = ["pronunciation"]
        sut.presentAdvanceStep(.init(
            currentStep: .goals,
            profile: profile,
            permissionsStatus: defaultStatus(),
            isCompleted: false
        ))
        XCTAssertTrue(spy.advanceVM?.canAdvance == true)
    }

    func test_presentAdvanceStep_completion_isCompleted() {
        let (sut, spy) = makeSUT()
        sut.presentAdvanceStep(.init(
            currentStep: .completion,
            profile: defaultProfile(),
            permissionsStatus: defaultStatus(),
            isCompleted: true
        ))
        XCTAssertTrue(spy.advanceVM?.isCompleted == true)
    }

    // MARK: - presentGoBack

    func test_presentGoBack_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentGoBack(.init(
            currentStep: .role,
            profile: defaultProfile(),
            permissionsStatus: defaultStatus()
        ))
        XCTAssertNotNil(spy.goBackVM)
        XCTAssertFalse(spy.goBackVM?.mascotText.isEmpty ?? true)
    }

    // MARK: - presentSetRole

    func test_presentSetRole_canAdvance() {
        let (sut, spy) = makeSUT()
        sut.presentSetRole(.init(profile: defaultProfile()))
        XCTAssertTrue(spy.setRoleVM?.canAdvance == true)
    }

    // MARK: - presentSetProfile

    func test_presentSetProfile_shortName_cannotAdvance() {
        let (sut, spy) = makeSUT()
        var p = defaultProfile()
        p.childName = "А"
        sut.presentSetProfile(.init(profile: p))
        XCTAssertFalse(spy.setProfileVM?.canAdvance ?? true)
    }

    func test_presentSetProfile_validName_canAdvance() {
        let (sut, spy) = makeSUT()
        var p = defaultProfile()
        p.childName = "Петя"
        sut.presentSetProfile(.init(profile: p))
        XCTAssertTrue(spy.setProfileVM?.canAdvance == true)
    }

    // MARK: - presentSetAge

    func test_presentSetAge_validAge_canAdvance() {
        let (sut, spy) = makeSUT()
        var p = defaultProfile()
        p.childAge = 6
        sut.presentSetAge(.init(profile: p))
        XCTAssertTrue(spy.setAgeVM?.canAdvance == true)
    }

    func test_presentSetAge_invalidAge_cannotAdvance() {
        let (sut, spy) = makeSUT()
        var p = defaultProfile()
        p.childAge = 100
        sut.presentSetAge(.init(profile: p))
        XCTAssertFalse(spy.setAgeVM?.canAdvance ?? true)
    }

    // MARK: - presentToggleGoal

    func test_presentToggleGoal_noGoals_cannotAdvance() {
        let (sut, spy) = makeSUT()
        var p = defaultProfile()
        p.goals = []
        sut.presentToggleGoal(.init(profile: p))
        XCTAssertFalse(spy.toggleGoalVM?.canAdvance ?? true)
    }

    func test_presentToggleGoal_hasGoal_canAdvance() {
        let (sut, spy) = makeSUT()
        var p = defaultProfile()
        p.goals = ["fluency"]
        sut.presentToggleGoal(.init(profile: p))
        XCTAssertTrue(spy.toggleGoalVM?.canAdvance == true)
    }

    // MARK: - presentToggleSound

    func test_presentToggleSound_alwaysCanAdvance() {
        let (sut, spy) = makeSUT()
        sut.presentToggleSound(.init(profile: defaultProfile()))
        XCTAssertTrue(spy.toggleSoundVM?.canAdvance == true)
    }

    // MARK: - presentSetSchedule

    func test_presentSetSchedule_validSchedule_canAdvance() {
        let (sut, spy) = makeSUT()
        var p = defaultProfile()
        p.dailyMinutes = 10
        sut.presentSetSchedule(.init(profile: p))
        XCTAssertTrue(spy.setScheduleVM?.canAdvance == true)
    }

    func test_presentSetSchedule_invalidSchedule_cannotAdvance() {
        let (sut, spy) = makeSUT()
        var p = defaultProfile()
        p.dailyMinutes = 99
        sut.presentSetSchedule(.init(profile: p))
        XCTAssertFalse(spy.setScheduleVM?.canAdvance ?? true)
    }

    // MARK: - presentSetGender

    func test_presentSetGender_alwaysCanAdvance() {
        let (sut, spy) = makeSUT()
        sut.presentSetGender(.init(profile: defaultProfile()))
        XCTAssertTrue(spy.setGenderVM?.canAdvance == true)
    }

    // MARK: - presentSetLyalyaPreset

    func test_presentSetLyalyaPreset_alwaysCanAdvance() {
        let (sut, spy) = makeSUT()
        sut.presentSetLyalyaPreset(.init(profile: defaultProfile()))
        XCTAssertTrue(spy.setLyalyaVM?.canAdvance == true)
    }

    // MARK: - presentPermissionsStatus

    func test_presentPermissionsStatus_micGranted_micLabelNotEmpty() {
        let (sut, spy) = makeSUT()
        let status = OnboardingPermissionsStatus(microphoneGranted: true, cameraGranted: false, notificationsGranted: false)
        sut.presentPermissionsStatus(.init(profile: defaultProfile(), permissionsStatus: status))
        XCTAssertFalse(spy.permissionsVM?.micLabel.isEmpty ?? true)
        XCTAssertFalse(spy.permissionsVM?.cameraLabel.isEmpty ?? true)
        XCTAssertFalse(spy.permissionsVM?.notificationsLabel.isEmpty ?? true)
        XCTAssertTrue(spy.permissionsVM?.canAdvance == true)
    }

    // MARK: - presentSkipPermissions

    func test_presentSkipPermissions_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentSkipPermissions(.init(currentStep: .permissions, profile: defaultProfile()))
        XCTAssertNotNil(spy.skipPermissionsVM)
        XCTAssertFalse(spy.skipPermissionsVM?.mascotText.isEmpty ?? true)
    }

    // MARK: - presentStartModelDownload

    func test_presentStartModelDownload_idle_canAdvance() {
        let (sut, spy) = makeSUT()
        sut.presentStartModelDownload(.init(status: .idle))
        XCTAssertTrue(spy.modelDownloadVM?.canAdvance == true)
        XCTAssertFalse(spy.modelDownloadVM?.statusLabel.isEmpty ?? true)
    }

    func test_presentStartModelDownload_downloading_cannotAdvance() {
        let (sut, spy) = makeSUT()
        sut.presentStartModelDownload(.init(status: .downloading(progress: 0.5)))
        XCTAssertFalse(spy.modelDownloadVM?.canAdvance ?? true)
        XCTAssertFalse(spy.modelDownloadVM?.statusLabel.isEmpty ?? true)
    }

    func test_presentStartModelDownload_completed_canAdvance() {
        let (sut, spy) = makeSUT()
        sut.presentStartModelDownload(.init(status: .completed))
        XCTAssertTrue(spy.modelDownloadVM?.canAdvance == true)
    }

    func test_presentStartModelDownload_failed_canAdvance() {
        let (sut, spy) = makeSUT()
        sut.presentStartModelDownload(.init(status: .failed(message: "Сеть недоступна")))
        XCTAssertTrue(spy.modelDownloadVM?.canAdvance == true)
        XCTAssertEqual(spy.modelDownloadVM?.statusLabel, "Сеть недоступна")
    }

    func test_presentStartModelDownload_skipped_canAdvance() {
        let (sut, spy) = makeSUT()
        sut.presentStartModelDownload(.init(status: .skipped))
        XCTAssertTrue(spy.modelDownloadVM?.canAdvance == true)
    }

    // MARK: - presentSetReminderTime

    func test_presentSetReminderTime_formatsTime() {
        let (sut, spy) = makeSUT()
        var p = defaultProfile()
        p.reminderHour = 9
        p.reminderMinute = 30
        sut.presentSetReminderTime(.init(profile: p))
        XCTAssertEqual(spy.reminderVM?.timeFormatted, "09:30")
        XCTAssertTrue(spy.reminderVM?.canAdvance == true)
    }

    // MARK: - presentPrivacyConsent

    func test_presentPrivacyConsent_accepted_canAdvance() {
        let (sut, spy) = makeSUT()
        var p = defaultProfile()
        p.privacyAccepted = true
        sut.presentPrivacyConsent(.init(profile: p))
        XCTAssertTrue(spy.privacyVM?.canAdvance == true)
    }

    func test_presentPrivacyConsent_notAccepted_cannotAdvance() {
        let (sut, spy) = makeSUT()
        var p = defaultProfile()
        p.privacyAccepted = false
        sut.presentPrivacyConsent(.init(profile: p))
        XCTAssertFalse(spy.privacyVM?.canAdvance ?? true)
    }

    // MARK: - presentPrivacyConsentRequired

    func test_presentPrivacyConsentRequired_errorMessageNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentPrivacyConsentRequired(.init())
        XCTAssertFalse(spy.privacyRequiredVM?.errorMessage.isEmpty ?? true)
    }

    // MARK: - presentScreeningChoice

    func test_presentScreeningChoice_wantsScreening() {
        let (sut, spy) = makeSUT()
        sut.presentScreeningChoice(.init(profile: defaultProfile(), wantsScreening: true))
        XCTAssertTrue(spy.screeningChoiceVM?.wantsScreening == true)
        XCTAssertTrue(spy.screeningChoiceVM?.canAdvance == true)
    }

    // MARK: - presentCompleteOnboarding

    func test_presentCompleteOnboarding_passesProfile() {
        let (sut, spy) = makeSUT()
        var p = defaultProfile()
        p.childName = "Ваня"
        sut.presentCompleteOnboarding(.init(profile: p))
        XCTAssertEqual(spy.completeVM?.profile.childName, "Ваня")
    }

    // MARK: - mascotText helpers

    func test_mascotText_allSteps_notEmpty() {
        let (sut, spy) = makeSUT()
        for step in OnboardingStep.allCases {
            sut.presentLoadOnboarding(.init(
                initialStep: step,
                profile: defaultProfile(),
                permissionsStatus: defaultStatus()
            ))
            XCTAssertFalse(spy.loadVM?.mascotText.isEmpty ?? true, "Mascot text must not be empty for step \(step)")
        }
    }
}
