@testable import HappySpeech
import XCTest

// MARK: - OnboardingInteractorTests
//
// M10.1 — 10 тестов для OnboardingInteractor.
// Покрывает: loadOnboarding, advanceStep, goBack, setRole, setProfile,
// setAge, toggleGoal, setSchedule, completeOnboarding, edge cases.

@MainActor
final class OnboardingInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: OnboardingPresentationLogic {
        var loadOnboardingCalled = false
        var advanceStepCalled = false
        var goBackCalled = false
        var setRoleCalled = false
        var setProfileCalled = false
        var setAgeCalled = false
        var toggleGoalCalled = false
        var toggleSoundCalled = false
        var setScheduleCalled = false
        var skipPermissionsCalled = false
        var startModelDownloadCalled = false
        var completeOnboardingCalled = false

        var lastLoadOnboarding: OnboardingModels.LoadOnboarding.Response?
        var lastAdvanceStep: OnboardingModels.AdvanceStep.Response?
        var lastGoBack: OnboardingModels.GoBack.Response?
        var lastSetRole: OnboardingModels.SetRole.Response?
        var lastSetProfile: OnboardingModels.SetProfile.Response?
        var lastSetAge: OnboardingModels.SetAge.Response?
        var lastToggleGoal: OnboardingModels.ToggleGoal.Response?
        var lastSetSchedule: OnboardingModels.SetSchedule.Response?
        var lastComplete: OnboardingModels.CompleteOnboarding.Response?

        func presentLoadOnboarding(_ response: OnboardingModels.LoadOnboarding.Response) {
            loadOnboardingCalled = true
            lastLoadOnboarding = response
        }
        func presentAdvanceStep(_ response: OnboardingModels.AdvanceStep.Response) {
            advanceStepCalled = true
            lastAdvanceStep = response
        }
        func presentGoBack(_ response: OnboardingModels.GoBack.Response) {
            goBackCalled = true
            lastGoBack = response
        }
        func presentSetRole(_ response: OnboardingModels.SetRole.Response) {
            setRoleCalled = true
            lastSetRole = response
        }
        func presentSetProfile(_ response: OnboardingModels.SetProfile.Response) {
            setProfileCalled = true
            lastSetProfile = response
        }
        func presentSetAge(_ response: OnboardingModels.SetAge.Response) {
            setAgeCalled = true
            lastSetAge = response
        }
        func presentToggleGoal(_ response: OnboardingModels.ToggleGoal.Response) {
            toggleGoalCalled = true
            lastToggleGoal = response
        }
        func presentToggleSound(_ response: OnboardingModels.ToggleSound.Response) {
            toggleSoundCalled = true
        }
        func presentSetSchedule(_ response: OnboardingModels.SetSchedule.Response) {
            setScheduleCalled = true
            lastSetSchedule = response
        }
        func presentSkipPermissions(_ response: OnboardingModels.SkipPermissions.Response) {
            skipPermissionsCalled = true
        }
        func presentStartModelDownload(_ response: OnboardingModels.StartModelDownload.Response) {
            startModelDownloadCalled = true
        }
        func presentCompleteOnboarding(_ response: OnboardingModels.CompleteOnboarding.Response) {
            completeOnboardingCalled = true
            lastComplete = response
        }
        func presentSetGender(_ response: OnboardingModels.SetGender.Response) {}
        func presentPermissionsStatus(_ response: OnboardingModels.RequestPermission.Response) {}
        func presentSetReminderTime(_ response: OnboardingModels.SetReminderTime.Response) {}
        func presentPrivacyConsent(_ response: OnboardingModels.AcceptPrivacyConsent.Response) {}
        func presentPrivacyConsentRequired(_ response: OnboardingModels.PrivacyConsentRequired.Response) {}
        func presentScreeningChoice(_ response: OnboardingModels.SelectScreeningChoice.Response) {}
        func presentSetLyalyaPreset(_ response: OnboardingModels.SetLyalyaPreset.Response) {}
    }

    private func makeSUT() -> (OnboardingInteractor, SpyPresenter) {
        let sut = OnboardingInteractor()
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadOnboarding вызывает presentLoadOnboarding

    func test_loadOnboarding_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        XCTAssertTrue(spy.loadOnboardingCalled)
        XCTAssertNotNil(spy.lastLoadOnboarding)
    }

    // MARK: - 2. advanceStep переходит к следующему шагу

    func test_advanceStep_progressesStep() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.advanceStep(.init(from: .welcome))
        XCTAssertTrue(spy.advanceStepCalled)
        let currentStep = spy.lastAdvanceStep?.currentStep
        XCTAssertNotNil(currentStep)
    }

    // MARK: - 3. goBack возвращается на предыдущий шаг

    func test_goBack_afterAdvance_returnsToWelcome() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.advanceStep(.init(from: .welcome))
        sut.goBack(.init())
        XCTAssertTrue(spy.goBackCalled)
        // После advance+back мы должны вернуться к welcome (rawValue=0)
        XCTAssertEqual(spy.lastGoBack?.currentStep.rawValue, 0)
    }

    // MARK: - 4. setRole обновляет profile.role

    func test_setRole_updatesRole() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.setRole(.init(role: .parent))
        XCTAssertTrue(spy.setRoleCalled)
        XCTAssertEqual(spy.lastSetRole?.profile.role, .parent)
    }

    // MARK: - 5. setProfile обновляет childName

    func test_setProfile_updatesName() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.setProfile(.init(name: "Петя", avatar: "bear"))
        XCTAssertTrue(spy.setProfileCalled)
        XCTAssertEqual(spy.lastSetProfile?.profile.childName, "Петя")
    }

    // MARK: - 6. setAge клампирует возраст в [3, 12]

    func test_setAge_clamps() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.setAge(.init(age: 99))
        XCTAssertTrue(spy.setAgeCalled)
        XCTAssertLessThanOrEqual(spy.lastSetAge?.profile.childAge ?? 99, 12)

        sut.setAge(.init(age: 1))
        XCTAssertGreaterThanOrEqual(spy.lastSetAge?.profile.childAge ?? 1, 3)
    }

    // MARK: - 7. toggleGoal добавляет/убирает цель

    func test_toggleGoal_addsAndRemoves() async throws {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.toggleGoal(.init(goalId: "correct_sounds"))
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(spy.toggleGoalCalled)
        XCTAssertTrue(spy.lastToggleGoal?.profile.goals.contains("correct_sounds") ?? false)
        // Повторный вызов убирает
        sut.toggleGoal(.init(goalId: "correct_sounds"))
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(spy.lastToggleGoal?.profile.goals.contains("correct_sounds") ?? true)
    }

    // MARK: - 8. setSchedule принимает только допустимые значения

    func test_setSchedule_validMinutes() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.setSchedule(.init(minutes: 10))
        XCTAssertTrue(spy.setScheduleCalled)
        let validSet = Set(OnboardingProfile.availableSchedules)
        XCTAssertTrue(validSet.contains(spy.lastSetSchedule?.profile.dailyMinutes ?? -1))
    }

    // MARK: - 9. setSchedule с недопустимым значением → дефолт 10

    func test_setSchedule_invalidMinutes_defaultsTo10() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.setSchedule(.init(minutes: 999))
        XCTAssertEqual(spy.lastSetSchedule?.profile.dailyMinutes, 10)
    }

    // MARK: - 10. completeOnboarding вызывает presentCompleteOnboarding

    func test_completeOnboarding_callsPresenter() async throws {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.completeOnboarding(.init())
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(spy.completeOnboardingCalled)
        XCTAssertNotNil(spy.lastComplete)
    }
}
