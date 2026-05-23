@testable import HappySpeech
import XCTest

/// Unit tests for I-05 — OnboardingVariant A/B gating.
/// Covers fromTutorialVariant factory, analyticsLabel, enabledIn(variant:) and
/// OnboardingInteractor integration (variant=.b should skip 5 of 10 steps).
final class OnboardingVariantTests: XCTestCase {

    // MARK: - fromTutorialVariant

    func test_fromTutorialVariant_A() {
        XCTAssertEqual(OnboardingVariant.fromTutorialVariant("A"), .a)
        XCTAssertEqual(OnboardingVariant.fromTutorialVariant("a"), .a)
    }

    func test_fromTutorialVariant_B() {
        XCTAssertEqual(OnboardingVariant.fromTutorialVariant("B"), .b)
        XCTAssertEqual(OnboardingVariant.fromTutorialVariant("b"), .b)
    }

    func test_fromTutorialVariant_unknownDefaultsToA() {
        XCTAssertEqual(OnboardingVariant.fromTutorialVariant(""), .a)
        XCTAssertEqual(OnboardingVariant.fromTutorialVariant("C"), .a)
        XCTAssertEqual(OnboardingVariant.fromTutorialVariant("control"), .a)
    }

    // MARK: - analyticsLabel

    func test_analyticsLabel_uppercase() {
        XCTAssertEqual(OnboardingVariant.a.analyticsLabel, "A")
        XCTAssertEqual(OnboardingVariant.b.analyticsLabel, "B")
    }

    // MARK: - OnboardingStep.enabledIn

    func test_variantA_enablesAllSteps() {
        for step in OnboardingStep.allCases {
            XCTAssertTrue(step.enabledIn(variant: .a), "step \(step) must be enabled in variant A")
        }
    }

    func test_variantB_enablesOnlyFiveSteps() {
        let enabledInB = OnboardingStep.allCases.filter { $0.enabledIn(variant: .b) }
        XCTAssertEqual(enabledInB, [.welcome, .childName, .sounds, .permissions, .completion])
    }

    func test_variantB_disabledSteps() {
        XCTAssertFalse(OnboardingStep.role.enabledIn(variant: .b))
        XCTAssertFalse(OnboardingStep.childAge.enabledIn(variant: .b))
        XCTAssertFalse(OnboardingStep.goals.enabledIn(variant: .b))
        XCTAssertFalse(OnboardingStep.schedule.enabledIn(variant: .b))
        XCTAssertFalse(OnboardingStep.modelDownload.enabledIn(variant: .b))
    }

    // MARK: - CaseIterable

    func test_variantCaseIterable() {
        XCTAssertEqual(OnboardingVariant.allCases, [.a, .b])
    }

    // MARK: - Interactor wiring with variant

    @MainActor
    func test_interactorWithVariantB_skipsDisabledStepsOnAdvance() async throws {
        OnboardingState.reset()
        UserDefaults.standard.removeObject(forKey: "onboarding.resume.step")
        let spy = SpyVariantPresenter()
        let sut = OnboardingInteractor(variant: .b)
        sut.presenter = spy
        sut.loadOnboarding(.init())
        // welcome → next valid in variant B is childName (skipping role)
        sut.advanceStep(.init(from: .welcome))
        XCTAssertEqual(spy.lastStep, .childName,
                       "variant B should skip .role and land on .childName")
    }

    @MainActor
    func test_interactorWithVariantA_doesNotSkip() async throws {
        OnboardingState.reset()
        UserDefaults.standard.removeObject(forKey: "onboarding.resume.step")
        let spy = SpyVariantPresenter()
        let sut = OnboardingInteractor(variant: .a)
        sut.presenter = spy
        sut.loadOnboarding(.init())
        sut.advanceStep(.init(from: .welcome))
        XCTAssertEqual(spy.lastStep, .role,
                       "variant A should NOT skip .role — it goes welcome → role")
    }
}

// MARK: - Spy

@MainActor
private final class SpyVariantPresenter: OnboardingPresentationLogic {
    var lastStep: OnboardingStep?

    nonisolated init() {}

    func presentLoadOnboarding(_ response: OnboardingModels.LoadOnboarding.Response) {
        lastStep = response.initialStep
    }

    func presentAdvanceStep(_ response: OnboardingModels.AdvanceStep.Response) {
        lastStep = response.currentStep
    }

    func presentGoBack(_ response: OnboardingModels.GoBack.Response) {
        lastStep = response.currentStep
    }

    func presentSetRole(_ response: OnboardingModels.SetRole.Response) {}
    func presentSetProfile(_ response: OnboardingModels.SetProfile.Response) {}
    func presentSetAge(_ response: OnboardingModels.SetAge.Response) {}
    func presentSetGender(_ response: OnboardingModels.SetGender.Response) {}
    func presentToggleGoal(_ response: OnboardingModels.ToggleGoal.Response) {}
    func presentToggleSound(_ response: OnboardingModels.ToggleSound.Response) {}
    func presentSetSchedule(_ response: OnboardingModels.SetSchedule.Response) {}
    func presentSetLyalyaPreset(_ response: OnboardingModels.SetLyalyaPreset.Response) {}
    func presentPermissionsStatus(_ response: OnboardingModels.RequestPermission.Response) {}
    func presentSkipPermissions(_ response: OnboardingModels.SkipPermissions.Response) {}
    func presentSetReminderTime(_ response: OnboardingModels.SetReminderTime.Response) {}
    func presentPrivacyConsent(_ response: OnboardingModels.AcceptPrivacyConsent.Response) {}
    func presentPrivacyConsentRequired(_ response: OnboardingModels.PrivacyConsentRequired.Response) {}
    func presentScreeningChoice(_ response: OnboardingModels.SelectScreeningChoice.Response) {}
    func presentStartModelDownload(_ response: OnboardingModels.StartModelDownload.Response) {}
    func presentCompleteOnboarding(_ response: OnboardingModels.CompleteOnboarding.Response) {}
}
