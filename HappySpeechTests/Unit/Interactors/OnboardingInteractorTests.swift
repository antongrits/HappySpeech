@testable import HappySpeech
import XCTest

// MARK: - Spy Notification Service

private final class SpyOnboardingNotificationService: NotificationService, @unchecked Sendable {
    var permissionResult = true
    var failSchedule = false

    private(set) var requestPermissionCount = 0
    private(set) var scheduleDailyCount = 0
    private(set) var lastScheduledHour: Int?
    private(set) var lastScheduledMinute: Int?

    func scheduleDailyReminder(at hour: Int, minute: Int) async throws {
        scheduleDailyCount += 1
        lastScheduledHour = hour
        lastScheduledMinute = minute
        if failSchedule { throw AppError.unknown("mock schedule fail") }
    }
    func cancelAllReminders() async {}
    func requestPermission() async -> Bool {
        requestPermissionCount += 1
        return permissionResult
    }
    func scheduleDailyKidReminder(childName: String) async {}
    func cancelDailyKidReminder(childName: String) async {}
    func scheduleWeeklyParentSummary(achievementsCount: Int, streakDays: Int) async {}
    func cancelWeeklyParentSummary() async {}
}

// MARK: - Spy Presenter

@MainActor
private final class SpyOnboardingPresenter: OnboardingPresentationLogic {

    var loadCount = 0
    var advanceCount = 0
    var goBackCount = 0
    var setRoleCount = 0
    var setProfileCount = 0
    var setAgeCount = 0
    var setGenderCount = 0
    var toggleGoalCount = 0
    var toggleSoundCount = 0
    var setScheduleCount = 0
    var setLyalyaPresetCount = 0
    var permissionsStatusCount = 0
    var skipPermissionsCount = 0
    var setReminderTimeCount = 0
    var privacyConsentCount = 0
    var privacyConsentRequiredCount = 0
    var screeningChoiceCount = 0
    var modelDownloadCount = 0
    var completeCount = 0

    var lastLoad: OnboardingModels.LoadOnboarding.Response?
    var lastAdvance: OnboardingModels.AdvanceStep.Response?
    var lastGoBack: OnboardingModels.GoBack.Response?
    var lastSetRole: OnboardingModels.SetRole.Response?
    var lastSetProfile: OnboardingModels.SetProfile.Response?
    var lastSetAge: OnboardingModels.SetAge.Response?
    var lastToggleGoal: OnboardingModels.ToggleGoal.Response?
    var lastToggleSound: OnboardingModels.ToggleSound.Response?
    var lastSetSchedule: OnboardingModels.SetSchedule.Response?
    var lastPermissions: OnboardingModels.RequestPermission.Response?
    var lastReminderTime: OnboardingModels.SetReminderTime.Response?
    var lastModelDownload: OnboardingModels.StartModelDownload.Response?
    var lastComplete: OnboardingModels.CompleteOnboarding.Response?

    func presentLoadOnboarding(_ response: OnboardingModels.LoadOnboarding.Response) {
        loadCount += 1
        lastLoad = response
    }
    func presentAdvanceStep(_ response: OnboardingModels.AdvanceStep.Response) {
        advanceCount += 1
        lastAdvance = response
    }
    func presentGoBack(_ response: OnboardingModels.GoBack.Response) {
        goBackCount += 1
        lastGoBack = response
    }
    func presentSetRole(_ response: OnboardingModels.SetRole.Response) {
        setRoleCount += 1
        lastSetRole = response
    }
    func presentSetProfile(_ response: OnboardingModels.SetProfile.Response) {
        setProfileCount += 1
        lastSetProfile = response
    }
    func presentSetAge(_ response: OnboardingModels.SetAge.Response) {
        setAgeCount += 1
        lastSetAge = response
    }
    func presentSetGender(_ response: OnboardingModels.SetGender.Response) {
        setGenderCount += 1
    }
    func presentToggleGoal(_ response: OnboardingModels.ToggleGoal.Response) {
        toggleGoalCount += 1
        lastToggleGoal = response
    }
    func presentToggleSound(_ response: OnboardingModels.ToggleSound.Response) {
        toggleSoundCount += 1
        lastToggleSound = response
    }
    func presentSetSchedule(_ response: OnboardingModels.SetSchedule.Response) {
        setScheduleCount += 1
        lastSetSchedule = response
    }
    func presentSetLyalyaPreset(_ response: OnboardingModels.SetLyalyaPreset.Response) {
        setLyalyaPresetCount += 1
    }
    func presentPermissionsStatus(_ response: OnboardingModels.RequestPermission.Response) {
        permissionsStatusCount += 1
        lastPermissions = response
    }
    func presentSkipPermissions(_ response: OnboardingModels.SkipPermissions.Response) {
        skipPermissionsCount += 1
    }
    func presentSetReminderTime(_ response: OnboardingModels.SetReminderTime.Response) {
        setReminderTimeCount += 1
        lastReminderTime = response
    }
    func presentPrivacyConsent(_ response: OnboardingModels.AcceptPrivacyConsent.Response) {
        privacyConsentCount += 1
    }
    func presentPrivacyConsentRequired(_ response: OnboardingModels.PrivacyConsentRequired.Response) {
        privacyConsentRequiredCount += 1
    }
    func presentScreeningChoice(_ response: OnboardingModels.SelectScreeningChoice.Response) {
        screeningChoiceCount += 1
    }
    func presentStartModelDownload(_ response: OnboardingModels.StartModelDownload.Response) {
        modelDownloadCount += 1
        lastModelDownload = response
    }
    func presentCompleteOnboarding(_ response: OnboardingModels.CompleteOnboarding.Response) {
        completeCount += 1
        lastComplete = response
    }
}

// MARK: - Tests

@MainActor
final class OnboardingInteractorTests: XCTestCase {

    private var notification: SpyOnboardingNotificationService!

    override func setUp() {
        super.setUp()
        OnboardingState.reset()
        UserDefaults.standard.removeObject(forKey: "onboarding.resume.step")
        UserDefaults.standard.removeObject(forKey: "onboarding.resume.profile")
        UserDefaults.standard.removeObject(forKey: "adaptivePlanner.seed")
        notification = SpyOnboardingNotificationService()
    }

    override func tearDown() {
        OnboardingState.reset()
        UserDefaults.standard.removeObject(forKey: "onboarding.resume.step")
        UserDefaults.standard.removeObject(forKey: "onboarding.resume.profile")
        UserDefaults.standard.removeObject(forKey: "adaptivePlanner.seed")
        notification = nil
        super.tearDown()
    }

    private func makeSUT() -> (OnboardingInteractor, SpyOnboardingPresenter) {
        let sut = OnboardingInteractor(notificationService: notification)
        let spy = SpyOnboardingPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    /// Детерминированно ждёт выполнения условия вместо фиксированного sleep.
    /// Interactor диспатчит разрешения/планирование в fire-and-forget Task —
    /// polling по spy-счётчику устраняет гонку с планировщиком.
    private func waitUntil(
        timeout: TimeInterval = 5.0,
        _ condition: @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("waitUntil: условие не выполнено за \(timeout) с")
                return
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    // MARK: - loadOnboarding

    func test_loadOnboarding_freshStartAtWelcome() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        XCTAssertEqual(spy.loadCount, 1)
        XCTAssertEqual(spy.lastLoad?.initialStep, .welcome)
    }

    func test_loadOnboarding_resumesFromSavedStep() {
        UserDefaults.standard.set(OnboardingStep.goals.rawValue, forKey: "onboarding.resume.step")
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        XCTAssertEqual(spy.lastLoad?.initialStep, .goals)
    }

    func test_loadOnboarding_completedOnboardingStartsFresh() {
        // Если онбординг уже завершён ранее — load начинает с welcome заново.
        var profile = OnboardingProfile()
        profile.childName = "Старый"
        OnboardingState.markCompleted(profile: profile)
        UserDefaults.standard.set(OnboardingStep.goals.rawValue, forKey: "onboarding.resume.step")
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        XCTAssertEqual(spy.lastLoad?.initialStep, .welcome)
        XCTAssertTrue(spy.lastLoad?.profile.childName.isEmpty ?? false)
    }

    // MARK: - advanceStep / goBack

    func test_advanceStep_movesForward() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.advanceStep(.init(from: .welcome))
        XCTAssertEqual(spy.advanceCount, 1)
        XCTAssertEqual(spy.lastAdvance?.currentStep, .role)
        XCTAssertEqual(spy.lastAdvance?.isCompleted, false)
    }

    func test_advanceStep_skipsChildStepsForSpecialist() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.setRole(.init(role: .specialist))
        // welcome → role.
        sut.advanceStep(.init(from: .welcome))
        // role → следующий валидный шаг (childName/childAge пропускаются для специалиста).
        sut.advanceStep(.init(from: .role))
        XCTAssertNotEqual(spy.lastAdvance?.currentStep, .childName)
        XCTAssertNotEqual(spy.lastAdvance?.currentStep, .childAge)
    }

    func test_advanceStep_parentSeesChildSteps() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.setRole(.init(role: .parent))
        // welcome → role.
        sut.advanceStep(.init(from: .welcome))
        // role → childName (для родителя детские шаги показываются).
        sut.advanceStep(.init(from: .role))
        XCTAssertEqual(spy.lastAdvance?.currentStep, .childName)
    }

    func test_advanceStep_reachesCompletion() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.setRole(.init(role: .parent))
        for _ in 0..<20 {
            sut.advanceStep(.init(from: spy.lastAdvance?.currentStep ?? .welcome))
            if spy.lastAdvance?.isCompleted == true { break }
        }
        XCTAssertEqual(spy.lastAdvance?.currentStep, .completion)
    }

    func test_goBack_movesBackward() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.setRole(.init(role: .parent))
        sut.advanceStep(.init(from: .welcome))
        sut.advanceStep(.init(from: .role))
        let before = spy.lastAdvance?.currentStep
        sut.goBack(.init())
        XCTAssertEqual(spy.goBackCount, 1)
        XCTAssertNotEqual(spy.lastGoBack?.currentStep, before)
    }

    func test_goBack_atWelcomeStaysAtWelcome() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.goBack(.init())
        XCTAssertEqual(spy.lastGoBack?.currentStep, .welcome)
    }

    // MARK: - Profile setters

    func test_setRole() {
        let (sut, spy) = makeSUT()
        sut.setRole(.init(role: .specialist))
        XCTAssertEqual(spy.lastSetRole?.profile.role, .specialist)
    }

    func test_setProfile_acceptsValidName() {
        let (sut, spy) = makeSUT()
        sut.setProfile(.init(name: "  Маша  ", avatar: "word_fox"))
        XCTAssertEqual(spy.lastSetProfile?.profile.childName, "Маша")
        XCTAssertEqual(spy.lastSetProfile?.profile.childAvatar, "word_fox")
    }

    func test_setProfile_emptyAvatarKeepsDefault() {
        let (sut, spy) = makeSUT()
        sut.setProfile(.init(name: "Маша", avatar: ""))
        XCTAssertEqual(spy.lastSetProfile?.profile.childAvatar, "word_cat")
    }

    func test_setAge_clampsAndSetsRecommendedMinutes() {
        let (sut, spy) = makeSUT()
        sut.setAge(.init(age: 99))
        XCTAssertEqual(spy.lastSetAge?.profile.childAge, 12)
        XCTAssertEqual(spy.lastSetAge?.profile.dailyMinutes, 15)
    }

    func test_setAge_youngChildShortSession() {
        let (sut, spy) = makeSUT()
        sut.setAge(.init(age: 5))
        XCTAssertEqual(spy.lastSetAge?.profile.childAge, 5)
        XCTAssertEqual(spy.lastSetAge?.profile.dailyMinutes, 5)
    }

    func test_setAge_negativeClampedToMinimum() {
        let (sut, spy) = makeSUT()
        sut.setAge(.init(age: -3))
        XCTAssertEqual(spy.lastSetAge?.profile.childAge, 3)
    }

    func test_setGender() {
        let (sut, spy) = makeSUT()
        sut.setGender(.init(gender: .girl))
        XCTAssertEqual(spy.setGenderCount, 1)
    }

    func test_toggleGoal_addsAndKeepsAtLeastOne() {
        let (sut, spy) = makeSUT()
        sut.toggleGoal(.init(goalId: "pronunciation"))
        XCTAssertTrue(spy.lastToggleGoal?.profile.goals.contains("pronunciation") ?? false)
        // Снять последнюю цель нельзя.
        sut.toggleGoal(.init(goalId: "pronunciation"))
        XCTAssertEqual(spy.lastToggleGoal?.profile.goals.count, 1)
    }

    func test_toggleGoal_removesWhenMultiple() {
        let (sut, spy) = makeSUT()
        sut.toggleGoal(.init(goalId: "pronunciation"))
        sut.toggleGoal(.init(goalId: "grammar"))
        sut.toggleGoal(.init(goalId: "pronunciation"))
        XCTAssertFalse(spy.lastToggleGoal?.profile.goals.contains("pronunciation") ?? true)
    }

    func test_toggleSound_addsAndRemoves() {
        let (sut, spy) = makeSUT()
        sut.toggleSound(.init(soundId: "R"))
        XCTAssertTrue(spy.lastToggleSound?.profile.difficultSounds.contains("R") ?? false)
        sut.toggleSound(.init(soundId: "R"))
        XCTAssertFalse(spy.lastToggleSound?.profile.difficultSounds.contains("R") ?? true)
    }

    func test_setSchedule_acceptsValidValue() {
        let (sut, spy) = makeSUT()
        sut.setSchedule(.init(minutes: 15))
        XCTAssertEqual(spy.lastSetSchedule?.profile.dailyMinutes, 15)
    }

    func test_setSchedule_invalidValueFallsBackToRecommended() {
        let (sut, spy) = makeSUT()
        sut.setAge(.init(age: 6))
        sut.setSchedule(.init(minutes: 999))
        // 999 не в availableSchedules → используется рекомендованное (для 6 лет = 10).
        XCTAssertEqual(spy.lastSetSchedule?.profile.dailyMinutes, 10)
    }

    func test_setLyalyaPreset() {
        let (sut, spy) = makeSUT()
        sut.setLyalyaPreset(.init(preset: .ocean))
        XCTAssertEqual(spy.setLyalyaPresetCount, 1)
    }

    // MARK: - Reminder

    func test_setReminderTime_clampsValues() {
        let (sut, spy) = makeSUT()
        sut.setReminderTime(.init(hour: 99, minute: 99))
        XCTAssertEqual(spy.lastReminderTime?.profile.reminderHour, 23)
        XCTAssertEqual(spy.lastReminderTime?.profile.reminderMinute, 59)
        XCTAssertEqual(spy.lastReminderTime?.profile.reminderEnabled, true)
    }

    func test_toggleReminderDay_addsAndKeepsAtLeastOne() {
        let (sut, spy) = makeSUT()
        // Профиль по умолчанию имеет дни 1-5. Убираем все кроме одного.
        for day in [1, 2, 3, 4] {
            sut.toggleReminderDay(.init(weekday: day))
        }
        XCTAssertGreaterThanOrEqual(spy.lastReminderTime?.profile.reminderDays.count ?? 0, 1)
    }

    func test_toggleReminderDay_addsNewDay() {
        let (sut, spy) = makeSUT()
        sut.toggleReminderDay(.init(weekday: 6))
        XCTAssertTrue(spy.lastReminderTime?.profile.reminderDays.contains(6) ?? false)
    }

    // MARK: - Privacy consent

    func test_acceptPrivacyConsent() {
        let (sut, spy) = makeSUT()
        sut.acceptPrivacyConsent(.init(accepted: true))
        XCTAssertEqual(spy.privacyConsentCount, 1)
    }

    // MARK: - Screening choice

    func test_selectScreeningChoice_advances() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.selectScreeningChoice(.init(wantsScreening: true))
        XCTAssertEqual(spy.screeningChoiceCount, 1)
        XCTAssertGreaterThanOrEqual(spy.advanceCount, 1)
    }

    func test_selectScreeningChoice_skipAlsoAdvances() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.selectScreeningChoice(.init(wantsScreening: false))
        XCTAssertGreaterThanOrEqual(spy.advanceCount, 1)
    }

    // MARK: - skipPermissions

    func test_skipPermissions_advances() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.skipPermissions(.init())
        XCTAssertGreaterThanOrEqual(spy.advanceCount, 1)
    }

    // MARK: - requestNotificationPermission

    func test_requestNotificationPermission_grantedEnablesReminder() async throws {
        let (sut, spy) = makeSUT()
        notification.permissionResult = true
        sut.requestNotificationPermission(.init())
        try await waitUntil { spy.permissionsStatusCount > 0 }
        XCTAssertEqual(notification.requestPermissionCount, 1)
        XCTAssertEqual(spy.lastPermissions?.permissionsStatus.notificationsGranted, true)
        XCTAssertEqual(spy.lastPermissions?.profile.reminderEnabled, true)
    }

    func test_requestNotificationPermission_deniedDoesNotEnableReminder() async throws {
        let (sut, spy) = makeSUT()
        notification.permissionResult = false
        sut.requestNotificationPermission(.init())
        try await waitUntil { spy.permissionsStatusCount > 0 }
        XCTAssertEqual(spy.lastPermissions?.permissionsStatus.notificationsGranted, false)
    }

    // MARK: - Model readiness
    //
    // v29: ML-модели (Whisper ASR, Qwen LLM, Core ML scorers) поставляются
    // внутри бандла приложения — загрузок во время онбординга нет.
    // startModelDownload/skipModelDownload синхронно подтверждают готовность
    // (status == .completed) без асинхронной симуляции прогресса.

    func test_startModelDownload_emitsCompletedStatus() {
        let (sut, spy) = makeSUT()
        sut.startModelDownload(.init())
        XCTAssertEqual(spy.modelDownloadCount, 1)
        XCTAssertEqual(spy.lastModelDownload?.status, .completed,
                       "Модели в бандле → шаг сразу .completed")
    }

    func test_skipModelDownload_emitsCompletedStatus() {
        let (sut, spy) = makeSUT()
        sut.skipModelDownload(.init())
        XCTAssertEqual(spy.lastModelDownload?.status, .completed)
    }

    func test_startModelDownload_isSynchronousAndIdempotent() {
        let (sut, spy) = makeSUT()
        sut.startModelDownload(.init())
        sut.startModelDownload(.init())
        // Шаг синхронный и идемпотентный: каждый вызов эмитит .completed.
        XCTAssertEqual(spy.modelDownloadCount, 2)
        XCTAssertEqual(spy.lastModelDownload?.status, .completed)
    }

    // MARK: - completeOnboarding

    func test_completeOnboarding_blockedWithoutPrivacyConsent() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.completeOnboarding(.init())
        XCTAssertEqual(spy.privacyConsentRequiredCount, 1)
        XCTAssertEqual(spy.completeCount, 0)
    }

    func test_completeOnboarding_succeedsWithConsent() {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        sut.acceptPrivacyConsent(.init(accepted: true))
        sut.completeOnboarding(.init())
        XCTAssertEqual(spy.completeCount, 1)
        XCTAssertTrue(OnboardingState.isCompleted)
    }

    func test_completeOnboarding_seedsAdaptivePlanner() {
        let (sut, _) = makeSUT()
        sut.loadOnboarding(.init())
        sut.toggleSound(.init(soundId: "R"))
        sut.acceptPrivacyConsent(.init(accepted: true))
        sut.completeOnboarding(.init())
        let seed = AdaptivePlannerSeed.load()
        XCTAssertNotNil(seed)
        XCTAssertEqual(seed?.soundPriorities["R"], .high)
    }

    func test_completeOnboarding_enablesGrammarModeWhenGoalSet() {
        let (sut, _) = makeSUT()
        sut.loadOnboarding(.init())
        sut.toggleGoal(.init(goalId: "grammar"))
        sut.acceptPrivacyConsent(.init(accepted: true))
        sut.completeOnboarding(.init())
        XCTAssertEqual(AdaptivePlannerSeed.load()?.enableGrammarMode, true)
    }

    func test_completeOnboarding_enablesFluencyModeWhenGoalSet() {
        let (sut, _) = makeSUT()
        sut.loadOnboarding(.init())
        sut.toggleGoal(.init(goalId: "fluency"))
        sut.acceptPrivacyConsent(.init(accepted: true))
        sut.completeOnboarding(.init())
        XCTAssertEqual(AdaptivePlannerSeed.load()?.enableFluencyMode, true)
    }

    func test_completeOnboarding_schedulesReminderWhenEnabledAndGranted() async throws {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        // Включаем уведомления (reminderEnabled + notificationsGranted).
        notification.permissionResult = true
        sut.requestNotificationPermission(.init())
        try await waitUntil { spy.permissionsStatusCount > 0 }
        sut.setReminderTime(.init(hour: 18, minute: 30))
        sut.acceptPrivacyConsent(.init(accepted: true))
        sut.completeOnboarding(.init())
        try await waitUntil { self.notification.scheduleDailyCount == 1 }
        XCTAssertEqual(notification.scheduleDailyCount, 1)
        XCTAssertEqual(notification.lastScheduledHour, 18)
        XCTAssertEqual(notification.lastScheduledMinute, 30)
    }

    func test_completeOnboarding_scheduleReminderFailureIsTolerated() async throws {
        let (sut, spy) = makeSUT()
        sut.loadOnboarding(.init())
        notification.permissionResult = true
        notification.failSchedule = true
        sut.requestNotificationPermission(.init())
        try await waitUntil { spy.permissionsStatusCount > 0 }
        sut.setReminderTime(.init(hour: 9, minute: 0))
        sut.acceptPrivacyConsent(.init(accepted: true))
        sut.completeOnboarding(.init())
        try await waitUntil { spy.completeCount == 1 }
        // Сбой планирования напоминания не блокирует завершение онбординга.
        XCTAssertEqual(spy.completeCount, 1)
    }

    // MARK: - AdaptivePlannerSeed persistence

    func test_adaptivePlannerSeed_saveAndLoad() {
        var seed = AdaptivePlannerSeed()
        seed.soundPriorities["Sh"] = .medium
        seed.enableFluencyMode = true
        seed.childAge = 7
        AdaptivePlannerSeed.save(seed)
        let loaded = AdaptivePlannerSeed.load()
        XCTAssertEqual(loaded?.soundPriorities["Sh"], .medium)
        XCTAssertEqual(loaded?.enableFluencyMode, true)
        XCTAssertEqual(loaded?.childAge, 7)
    }

    func test_adaptivePlannerSeed_loadReturnsNilWhenAbsent() {
        UserDefaults.standard.removeObject(forKey: "adaptivePlanner.seed")
        XCTAssertNil(AdaptivePlannerSeed.load())
    }

    // MARK: - OnboardingProfile encode/decode

    func test_onboardingState_encodeDecodeRoundTrip() throws {
        var profile = OnboardingProfile()
        profile.childName = "Тимофей"
        profile.childAge = 7
        profile.goals = ["pronunciation", "grammar"]
        profile.difficultSounds = ["R", "L"]
        let data = try OnboardingState.encode(profile: profile)
        let decoded = try OnboardingState.decode(data: data)
        XCTAssertEqual(decoded.childName, "Тимофей")
        XCTAssertEqual(decoded.childAge, 7)
        XCTAssertEqual(decoded.goals, ["pronunciation", "grammar"])
        XCTAssertEqual(decoded.difficultSounds, ["R", "L"])
    }

    // MARK: - OnboardingPermissionsStatus

    func test_permissionsStatus_allGranted() {
        var status = OnboardingPermissionsStatus()
        XCTAssertFalse(status.allGranted)
        status.microphoneGranted = true
        status.cameraGranted = true
        status.notificationsGranted = true
        XCTAssertTrue(status.allGranted)
    }

    func test_permissionsStatus_minimumGranted() {
        var status = OnboardingPermissionsStatus()
        XCTAssertFalse(status.minimumGranted)
        status.microphoneGranted = true
        XCTAssertTrue(status.minimumGranted)
    }
}
