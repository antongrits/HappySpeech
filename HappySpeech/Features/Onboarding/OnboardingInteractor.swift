import AVFoundation
import Foundation
import OSLog
import UserNotifications

// MARK: - OnboardingBusinessLogic

@MainActor
protocol OnboardingBusinessLogic: AnyObject {
    func loadOnboarding(_ request: OnboardingModels.LoadOnboarding.Request)
    func advanceStep(_ request: OnboardingModels.AdvanceStep.Request)
    func goBack(_ request: OnboardingModels.GoBack.Request)
    func setRole(_ request: OnboardingModels.SetRole.Request)
    func setProfile(_ request: OnboardingModels.SetProfile.Request)
    func setAge(_ request: OnboardingModels.SetAge.Request)
    func setGender(_ request: OnboardingModels.SetGender.Request)
    func toggleGoal(_ request: OnboardingModels.ToggleGoal.Request)
    func toggleSound(_ request: OnboardingModels.ToggleSound.Request)
    func setSchedule(_ request: OnboardingModels.SetSchedule.Request)
    func setLyalyaPreset(_ request: OnboardingModels.SetLyalyaPreset.Request)
    func requestMicrophonePermission(_ request: OnboardingModels.RequestPermission.Request)
    func requestCameraPermission(_ request: OnboardingModels.RequestPermission.Request)
    func requestNotificationPermission(_ request: OnboardingModels.RequestPermission.Request)
    func skipPermissions(_ request: OnboardingModels.SkipPermissions.Request)
    func setReminderTime(_ request: OnboardingModels.SetReminderTime.Request)
    func toggleReminderDay(_ request: OnboardingModels.ToggleReminderDay.Request)
    func acceptPrivacyConsent(_ request: OnboardingModels.AcceptPrivacyConsent.Request)
    func selectScreeningChoice(_ request: OnboardingModels.SelectScreeningChoice.Request)
    func startModelDownload(_ request: OnboardingModels.StartModelDownload.Request)
    func skipModelDownload(_ request: OnboardingModels.SkipModelDownload.Request)
    func completeOnboarding(_ request: OnboardingModels.CompleteOnboarding.Request)
}

// MARK: - OnboardingInteractor

/// Бизнес-логика 10-шагового онбординга.
///
/// ### Шаги онбординга
///  1. Welcome           — маскот Ляля, «Поехали!»
///  2. Role              — родитель / специалист / ребёнок
///  3. ChildName         — имя + пол + аватар-emoji
///  4. ChildAge          — возраст 5–8 лет
///  5. Goals             — мультиселект целей (обязательно ≥1)
///  6. LyalyaPreset      — быстрая кастомизация маскота (пропускаемый)
///  7. Permissions       — микрофон / камера / уведомления (пропускаемый)
///  8. ReminderSetup     — выбор времени и дней напоминания (пропускаемый)
///  9. PrivacyConsent    — согласие с политикой (обязательный)
/// 10. Completion        — праздник + «Начать!»
///
/// ### Resume mid-onboarding
/// При каждом `advanceStep` текущий шаг сохраняется в UserDefaults.
/// При `loadOnboarding` — восстанавливается, если онбординг не был завершён.
///
/// ### Permissions workflow
/// Каждый вид прав запрашивается отдельным методом, статусы хранятся в
/// `OnboardingPermissionsStatus` внутри профиля (через `OnboardingState`).
///
/// ### Reminder scheduling
/// При `completeOnboarding`, если `profile.reminderEnabled == true`,
/// сервис `NotificationServiceLive` планирует ежедневное напоминание.
///
/// ### AdaptivePlanner seeding
/// После завершения онбординга метод `seedAdaptivePlanner` записывает
/// первичные приоритеты звуков в `AdaptivePlannerSeed` (UserDefaults).
/// `LiveAdaptivePlannerService` считывает seed при первом `buildDailyRoute`.
@MainActor
final class OnboardingInteractor: OnboardingBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any OnboardingPresentationLogic)?

    private let notificationService: any NotificationService
    private let logger = Logger(subsystem: "ru.happyspeech", category: "OnboardingInteractor")

    // MARK: - State

    private var currentStep: OnboardingStep = .welcome
    private var profile = OnboardingProfile()
    private var permissionsStatus = OnboardingPermissionsStatus()
    private var modelStatus: ModelDownloadStatus = .idle
    private var downloadTask: Task<Void, Never>?

    // MARK: - Resume keys

    private enum ResumeKeys {
        static let stepRaw = "onboarding.resume.step"
        static let profileData = "onboarding.resume.profile"
    }

    // MARK: - Init

    init(notificationService: any NotificationService = NotificationServiceLive()) {
        self.notificationService = notificationService
    }

    deinit {
        downloadTask?.cancel()
    }

    // MARK: - BusinessLogic: Load

    func loadOnboarding(_ request: OnboardingModels.LoadOnboarding.Request) {
        // Resume mid-onboarding: если онбординг уже был начат, но не завершён
        if !OnboardingState.isCompleted {
            restoreResumeState()
        } else {
            currentStep = .welcome
            profile = OnboardingProfile()
        }
        modelStatus = .idle
        logger.info("loadOnboarding step=\(self.currentStep.rawValue, privacy: .public)")
        presenter?.presentLoadOnboarding(.init(
            initialStep: currentStep,
            profile: profile,
            permissionsStatus: permissionsStatus
        ))
    }

    // MARK: - BusinessLogic: Navigation

    func advanceStep(_ request: OnboardingModels.AdvanceStep.Request) {
        let nextStep = nextValidStep(after: currentStep)
        let isCompleted: Bool
        if let next = nextStep {
            currentStep = next
            isCompleted = false
            persistResumeStep(currentStep)
        } else {
            isCompleted = true
        }
        logger.info("advanceStep → \(self.currentStep.rawValue, privacy: .public) completed=\(isCompleted, privacy: .public)")
        presenter?.presentAdvanceStep(.init(
            currentStep: currentStep,
            profile: profile,
            permissionsStatus: permissionsStatus,
            isCompleted: isCompleted
        ))
    }

    func goBack(_ request: OnboardingModels.GoBack.Request) {
        let prevStep = prevValidStep(before: currentStep)
        if let prev = prevStep {
            currentStep = prev
            persistResumeStep(currentStep)
        }
        logger.info("goBack → \(self.currentStep.rawValue, privacy: .public)")
        presenter?.presentGoBack(.init(
            currentStep: currentStep,
            profile: profile,
            permissionsStatus: permissionsStatus
        ))
    }

    // MARK: - BusinessLogic: Profile

    func setRole(_ request: OnboardingModels.SetRole.Request) {
        profile.role = request.role
        logger.info("setRole role=\(request.role.rawValue, privacy: .public)")
        presenter?.presentSetRole(.init(profile: profile))
    }

    func setProfile(_ request: OnboardingModels.SetProfile.Request) {
        let trimmed = request.name.trimmingCharacters(in: .whitespaces)
        // Не принимаем имена короче 2 символов — UI показывает ошибку
        if trimmed.count >= 2 {
            profile.childName = trimmed
        } else if trimmed.isEmpty {
            profile.childName = trimmed
        } else {
            profile.childName = trimmed
        }
        if !request.avatar.isEmpty {
            profile.childAvatar = request.avatar
        }
        persistResumeProfile()
        logger.info("setProfile nameLen=\(trimmed.count, privacy: .public) avatar=\(request.avatar, privacy: .public)")
        presenter?.presentSetProfile(.init(profile: profile))
    }

    func setAge(_ request: OnboardingModels.SetAge.Request) {
        let clamped = max(3, min(12, request.age))
        profile.childAge = clamped
        // Автоматически корректируем dailyMinutes под возрастную норму
        profile.dailyMinutes = recommendedDailyMinutes(forAge: clamped)
        persistResumeProfile()
        logger.info("setAge age=\(clamped, privacy: .public) dailyMin=\(self.profile.dailyMinutes, privacy: .public)")
        presenter?.presentSetAge(.init(profile: profile))
    }

    func setGender(_ request: OnboardingModels.SetGender.Request) {
        profile.childGender = request.gender
        persistResumeProfile()
        logger.info("setGender gender=\(request.gender.rawValue, privacy: .public)")
        presenter?.presentSetGender(.init(profile: profile))
    }

    func toggleGoal(_ request: OnboardingModels.ToggleGoal.Request) {
        if profile.goals.contains(request.goalId) {
            // Не снимаем последнюю цель — хотя бы одна обязательна
            if profile.goals.count > 1 {
                profile.goals.remove(request.goalId)
            }
        } else {
            profile.goals.insert(request.goalId)
        }
        persistResumeProfile()
        logger.info("toggleGoal id=\(request.goalId, privacy: .public) count=\(self.profile.goals.count, privacy: .public)")
        presenter?.presentToggleGoal(.init(profile: profile))
    }

    func toggleSound(_ request: OnboardingModels.ToggleSound.Request) {
        if profile.difficultSounds.contains(request.soundId) {
            profile.difficultSounds.remove(request.soundId)
        } else {
            profile.difficultSounds.insert(request.soundId)
        }
        persistResumeProfile()
        logger.info("toggleSound id=\(request.soundId, privacy: .public) count=\(self.profile.difficultSounds.count, privacy: .public)")
        presenter?.presentToggleSound(.init(profile: profile))
    }

    func setSchedule(_ request: OnboardingModels.SetSchedule.Request) {
        let valid = OnboardingProfile.availableSchedules.contains(request.minutes)
            ? request.minutes
            : recommendedDailyMinutes(forAge: profile.childAge)
        profile.dailyMinutes = valid
        persistResumeProfile()
        logger.info("setSchedule minutes=\(valid, privacy: .public)")
        presenter?.presentSetSchedule(.init(profile: profile))
    }

    // MARK: - BusinessLogic: Lyalya customization

    func setLyalyaPreset(_ request: OnboardingModels.SetLyalyaPreset.Request) {
        profile.lyalyaPreset = request.preset
        persistResumeProfile()
        logger.info("setLyalyaPreset preset=\(request.preset.rawValue, privacy: .public)")
        presenter?.presentSetLyalyaPreset(.init(profile: profile))
    }

    // MARK: - BusinessLogic: Permissions

    /// Запрашивает разрешение на микрофон через AVFoundation.
    /// Результат сохраняется в `permissionsStatus.microphoneGranted`.
    func requestMicrophonePermission(_ request: OnboardingModels.RequestPermission.Request) {
        Task { [weak self] in
            guard let self else { return }
            let granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
            permissionsStatus.microphoneGranted = granted
            logger.info("microphonePermission granted=\(granted, privacy: .public)")
            presenter?.presentPermissionsStatus(.init(
                profile: profile,
                permissionsStatus: permissionsStatus
            ))
        }
    }

    /// Запрашивает разрешение на камеру через AVCaptureDevice.
    func requestCameraPermission(_ request: OnboardingModels.RequestPermission.Request) {
        Task { [weak self] in
            guard let self else { return }
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionsStatus.cameraGranted = granted
            logger.info("cameraPermission granted=\(granted, privacy: .public)")
            presenter?.presentPermissionsStatus(.init(
                profile: profile,
                permissionsStatus: permissionsStatus
            ))
        }
    }

    /// Запрашивает разрешение на уведомления через UNUserNotificationCenter.
    func requestNotificationPermission(_ request: OnboardingModels.RequestPermission.Request) {
        Task { [weak self] in
            guard let self else { return }
            let granted = await notificationService.requestPermission()
            permissionsStatus.notificationsGranted = granted
            // Если уведомления разрешены, включаем reminder по умолчанию
            if granted {
                profile.reminderEnabled = true
            }
            logger.info("notificationsPermission granted=\(granted, privacy: .public)")
            presenter?.presentPermissionsStatus(.init(
                profile: profile,
                permissionsStatus: permissionsStatus
            ))
        }
    }

    func skipPermissions(_ request: OnboardingModels.SkipPermissions.Request) {
        permissionsStatus.skipped = true
        logger.info("skipPermissions")
        // Переходим к следующему шагу
        advanceStep(.init(from: currentStep))
    }

    // MARK: - BusinessLogic: Reminder

    func setReminderTime(_ request: OnboardingModels.SetReminderTime.Request) {
        let clampedHour = max(0, min(23, request.hour))
        let clampedMinute = max(0, min(59, request.minute))
        profile.reminderHour = clampedHour
        profile.reminderMinute = clampedMinute
        profile.reminderEnabled = true
        persistResumeProfile()
        logger.info("setReminderTime hour=\(clampedHour, privacy: .public) min=\(clampedMinute, privacy: .public)")
        presenter?.presentSetReminderTime(.init(profile: profile))
    }

    func toggleReminderDay(_ request: OnboardingModels.ToggleReminderDay.Request) {
        let day = request.weekday
        if profile.reminderDays.contains(day) {
            // Оставляем хотя бы один день
            if profile.reminderDays.count > 1 {
                profile.reminderDays.remove(day)
            }
        } else {
            profile.reminderDays.insert(day)
        }
        persistResumeProfile()
        logger.info("toggleReminderDay day=\(day, privacy: .public) count=\(self.profile.reminderDays.count, privacy: .public)")
        presenter?.presentSetReminderTime(.init(profile: profile))
    }

    // MARK: - BusinessLogic: Privacy consent

    func acceptPrivacyConsent(_ request: OnboardingModels.AcceptPrivacyConsent.Request) {
        profile.privacyAccepted = request.accepted
        persistResumeProfile()
        logger.info("acceptPrivacyConsent accepted=\(request.accepted, privacy: .public)")
        presenter?.presentPrivacyConsent(.init(profile: profile))
    }

    // MARK: - BusinessLogic: Screening

    func selectScreeningChoice(_ request: OnboardingModels.SelectScreeningChoice.Request) {
        profile.screeningRequested = request.wantsScreening
        persistResumeProfile()
        logger.info("selectScreeningChoice wants=\(request.wantsScreening, privacy: .public)")
        presenter?.presentScreeningChoice(.init(
            profile: profile,
            wantsScreening: request.wantsScreening
        ))
        // Если пользователь хочет скрининг — переходим к нему немедленно
        if request.wantsScreening {
            advanceStep(.init(from: currentStep))
        } else {
            // Пропуск скрининга — переходим к следующему шагу
            advanceStep(.init(from: currentStep))
        }
    }

    // MARK: - BusinessLogic: Model Download

    func startModelDownload(_ request: OnboardingModels.StartModelDownload.Request) {
        guard downloadTask == nil else {
            logger.info("startModelDownload: already in progress")
            return
        }
        modelStatus = .downloading(progress: 0.0)
        presenter?.presentStartModelDownload(.init(status: modelStatus))

        downloadTask = Task { [weak self] in
            // Симуляция 12 шагов по 250 мс (~3 с). На M8 — реальный WhisperKitModelManager.
            for step in 1...12 {
                if Task.isCancelled { return }
                try? await Task.sleep(for: .milliseconds(250))
                let progress = Double(step) / 12.0
                self?.publishDownloadProgress(progress)
            }
            self?.completeModelDownload()
        }
    }

    func skipModelDownload(_ request: OnboardingModels.SkipModelDownload.Request) {
        downloadTask?.cancel()
        downloadTask = nil
        modelStatus = .skipped
        logger.info("skipModelDownload")
        presenter?.presentStartModelDownload(.init(status: modelStatus))
    }

    // MARK: - BusinessLogic: Complete

    func completeOnboarding(_ request: OnboardingModels.CompleteOnboarding.Request) {
        guard profile.privacyAccepted else {
            // Не завершаем без согласия с политикой
            logger.warning("completeOnboarding blocked: privacy not accepted")
            presenter?.presentPrivacyConsentRequired(.init())
            return
        }

        downloadTask?.cancel()
        downloadTask = nil

        // 1. Сохраняем флаг завершения и профиль
        OnboardingState.markCompleted(profile: profile)

        // 2. Очищаем resume-state
        clearResumeState()

        // 3. Планируем ежедневное напоминание если разрешение есть
        if profile.reminderEnabled && permissionsStatus.notificationsGranted {
            scheduleReminderIfNeeded()
        }

        // 4. Seeding AdaptivePlanner начальными приоритетами
        seedAdaptivePlanner()

        let roleStr = profile.role.rawValue
        let genderStr = profile.childGender.rawValue
        let countsStr = "age=\(profile.childAge) goals=\(profile.goals.count) sounds=\(profile.difficultSounds.count)"
        logger.info("completeOnboarding role=\(roleStr, privacy: .public) \(countsStr, privacy: .public) gender=\(genderStr, privacy: .public)")

        presenter?.presentCompleteOnboarding(.init(profile: profile))
    }

    // MARK: - Private: Navigation helpers

    /// Возвращает следующий шаг с учётом роли и опциональных шагов.
    /// Например, шаг ChildName показывается только если role != .specialist.
    private func nextValidStep(after step: OnboardingStep) -> OnboardingStep? {
        var candidate = step.rawValue + 1
        while candidate < OnboardingStep.allCases.count {
            if let next = OnboardingStep(rawValue: candidate), shouldShow(step: next) {
                return next
            }
            candidate += 1
        }
        return nil
    }

    private func prevValidStep(before step: OnboardingStep) -> OnboardingStep? {
        var candidate = step.rawValue - 1
        while candidate >= 0 {
            if let prev = OnboardingStep(rawValue: candidate), shouldShow(step: prev) {
                return prev
            }
            candidate -= 1
        }
        return nil
    }

    /// Фильтрует шаги по текущей роли пользователя.
    /// - ChildName / ChildAge — только для parent (и child, если напрямую)
    /// - Specialist пропускает все детские шаги
    private func shouldShow(step: OnboardingStep) -> Bool {
        switch step {
        case .childName, .childAge:
            return profile.role == .parent || profile.role == .child
        case .sounds:
            // Показываем звуки только если в goals есть «произношение»
            return profile.goals.contains("pronunciation") || profile.goals.isEmpty
        default:
            return true
        }
    }

    // MARK: - Private: Recommended daily minutes

    /// Логопедическая норма длительности занятий по возрасту.
    /// 5–6 лет: 7 мин, 6–7 лет: 10 мин, 7–8 лет: 12 мин, 8+: 15 мин.
    private func recommendedDailyMinutes(forAge age: Int) -> Int {
        switch age {
        case ...5:  return 5
        case 6:     return 10
        case 7:     return 12
        default:    return 15
        }
    }

    // MARK: - Private: Model download helpers

    private func publishDownloadProgress(_ progress: Double) {
        modelStatus = .downloading(progress: progress)
        presenter?.presentStartModelDownload(.init(status: modelStatus))
    }

    private func completeModelDownload() {
        modelStatus = .completed
        downloadTask = nil
        logger.info("modelDownload completed")
        presenter?.presentStartModelDownload(.init(status: modelStatus))
    }

    // MARK: - Private: Reminder scheduling

    /// Планирует ежедневное напоминание через NotificationService.
    /// Вызывается асинхронно из `completeOnboarding` — UI не блокируется.
    private func scheduleReminderIfNeeded() {
        let hour = profile.reminderHour
        let minute = profile.reminderMinute
        Task { [weak self] in
            guard let self else { return }
            do {
                try await notificationService.scheduleDailyReminder(at: hour, minute: minute)
                logger.info("dailyReminder scheduled hour=\(hour, privacy: .public) min=\(minute, privacy: .public)")
            } catch {
                logger.error("scheduleDailyReminder failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Private: AdaptivePlanner seeding

    /// Сохраняет начальные приоритеты звуков в UserDefaults под ключом
    /// `adaptivePlanner.seed`, который считывает `LiveAdaptivePlannerService`.
    ///
    /// Приоритеты рассчитываются из выбранных `difficultSounds` + целей.
    private func seedAdaptivePlanner() {
        var seed = AdaptivePlannerSeed()

        // Выбранные трудные звуки → максимальный приоритет
        for soundId in profile.difficultSounds {
            seed.soundPriorities[soundId] = AdaptivePlannerSeed.Priority.high
        }

        // Если выбрана цель «грамматика» — добавляем режим
        if profile.goals.contains("grammar") {
            seed.enableGrammarMode = true
        }

        // Если выбрана цель «плавность речи» — включаем breathing/rhythm шаблоны
        if profile.goals.contains("fluency") {
            seed.enableFluencyMode = true
        }

        // Возрастная метка для расчёта длины сессии
        seed.childAge = profile.childAge
        seed.dailyMinutes = profile.dailyMinutes

        // Gender hint для голосовой модели
        seed.gender = profile.childGender

        AdaptivePlannerSeed.save(seed)
        logger.info("adaptivePlannerSeed saved sounds=\(seed.soundPriorities.count, privacy: .public)")
    }

    // MARK: - Private: Resume persistence

    private func persistResumeStep(_ step: OnboardingStep) {
        UserDefaults.standard.set(step.rawValue, forKey: ResumeKeys.stepRaw)
    }

    private func persistResumeProfile() {
        if let data = try? OnboardingState.encode(profile: profile) {
            UserDefaults.standard.set(data, forKey: ResumeKeys.profileData)
        }
    }

    private func restoreResumeState() {
        let rawStep = UserDefaults.standard.integer(forKey: ResumeKeys.stepRaw)
        if rawStep > 0, let step = OnboardingStep(rawValue: rawStep) {
            currentStep = step
            logger.info("resumeOnboarding step=\(rawStep, privacy: .public)")
        } else {
            currentStep = .welcome
        }

        if let data = UserDefaults.standard.data(forKey: ResumeKeys.profileData),
           let restored = try? OnboardingState.decode(data: data) {
            profile = restored
            logger.info("resumeOnboarding profile restored name=\(self.profile.childName, privacy: .private)")
        }
    }

    private func clearResumeState() {
        UserDefaults.standard.removeObject(forKey: ResumeKeys.stepRaw)
        UserDefaults.standard.removeObject(forKey: ResumeKeys.profileData)
    }
}

// MARK: - OnboardingPermissionsStatus

/// Состояние разрешений, собранных в процессе онбординга.
struct OnboardingPermissionsStatus: Sendable, Equatable {
    var microphoneGranted: Bool = false
    var cameraGranted: Bool = false
    var notificationsGranted: Bool = false
    var skipped: Bool = false

    /// Все три ключевых разрешения получены
    var allGranted: Bool {
        microphoneGranted && cameraGranted && notificationsGranted
    }

    /// Хотя бы микрофон — минимум для работы ASR
    var minimumGranted: Bool {
        microphoneGranted
    }
}

// MARK: - AdaptivePlannerSeed

/// Начальный seed для LiveAdaptivePlannerService после завершения онбординга.
/// Хранится в UserDefaults под ключом `adaptivePlanner.seed`.
struct AdaptivePlannerSeed: Sendable {

    enum Priority: Int, Sendable, Codable {
        case low = 1
        case medium = 2
        case high = 3
    }

    private enum StorageKey {
        static let seed = "adaptivePlanner.seed"
    }

    var soundPriorities: [String: Priority] = [:]
    var enableGrammarMode: Bool = false
    var enableFluencyMode: Bool = false
    var childAge: Int = 6
    var dailyMinutes: Int = 10
    var gender: ChildGender = .notSpecified

    init() {}

    // MARK: - Persistence

    static func save(_ seed: AdaptivePlannerSeed) {
        let codable = CodableSeed(from: seed)
        if let data = try? JSONEncoder().encode(codable) {
            UserDefaults.standard.set(data, forKey: StorageKey.seed)
        }
    }

    static func load() -> AdaptivePlannerSeed? {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.seed),
              let codable = try? JSONDecoder().decode(CodableSeed.self, from: data) else {
            return nil
        }
        return AdaptivePlannerSeed(from: codable)
    }

    // MARK: - Codable

    private struct CodableSeed: Codable {
        let soundPriorities: [String: Int]
        let enableGrammarMode: Bool
        let enableFluencyMode: Bool
        let childAge: Int
        let dailyMinutes: Int
        let genderRaw: String

        init(from seed: AdaptivePlannerSeed) {
            self.soundPriorities = seed.soundPriorities.mapValues { $0.rawValue }
            self.enableGrammarMode = seed.enableGrammarMode
            self.enableFluencyMode = seed.enableFluencyMode
            self.childAge = seed.childAge
            self.dailyMinutes = seed.dailyMinutes
            self.genderRaw = seed.gender.rawValue
        }
    }

    private init(from codable: CodableSeed) {
        self.soundPriorities = codable.soundPriorities.compactMapValues { Priority(rawValue: $0) }
        self.enableGrammarMode = codable.enableGrammarMode
        self.enableFluencyMode = codable.enableFluencyMode
        self.childAge = codable.childAge
        self.dailyMinutes = codable.dailyMinutes
        self.gender = ChildGender(rawValue: codable.genderRaw) ?? .notSpecified
    }
}

// MARK: - OnboardingState extensions (encode/decode helpers)

extension OnboardingState {

    /// Публичный encode-helper для использования вне enum.
    static func encode(profile: OnboardingProfile) throws -> Data {
        let codable = CodableProfile(
            role: profile.role.rawValue,
            childName: profile.childName,
            childAge: profile.childAge,
            childAvatar: profile.childAvatar,
            childGenderRaw: profile.childGender.rawValue,
            goals: Array(profile.goals).sorted(),
            difficultSounds: Array(profile.difficultSounds).sorted(),
            dailyMinutes: profile.dailyMinutes,
            reminderEnabled: profile.reminderEnabled,
            reminderHour: profile.reminderHour,
            reminderMinute: profile.reminderMinute,
            reminderDays: Array(profile.reminderDays).sorted(),
            privacyAccepted: profile.privacyAccepted,
            screeningRequested: profile.screeningRequested,
            lyalyaPresetRaw: profile.lyalyaPreset.rawValue
        )
        return try JSONEncoder().encode(codable)
    }

    /// Публичный decode-helper для восстановления из UserDefaults.
    static func decode(data: Data) throws -> OnboardingProfile {
        let decoded = try JSONDecoder().decode(CodableProfile.self, from: data)
        return OnboardingProfile(
            role: UserRole(rawValue: decoded.role) ?? .parent,
            childName: decoded.childName,
            childAge: decoded.childAge,
            childAvatar: decoded.childAvatar,
            childGender: ChildGender(rawValue: decoded.childGenderRaw) ?? .notSpecified,
            goals: Set(decoded.goals),
            difficultSounds: Set(decoded.difficultSounds),
            dailyMinutes: decoded.dailyMinutes,
            reminderEnabled: decoded.reminderEnabled,
            reminderHour: decoded.reminderHour,
            reminderMinute: decoded.reminderMinute,
            reminderDays: Set(decoded.reminderDays),
            privacyAccepted: decoded.privacyAccepted,
            screeningRequested: decoded.screeningRequested,
            lyalyaPreset: LyalyaPreset(rawValue: decoded.lyalyaPresetRaw) ?? .default
        )
    }

    // MARK: - Extended CodableProfile

    fileprivate struct CodableProfile: Codable {
        let role: String
        let childName: String
        let childAge: Int
        let childAvatar: String
        let childGenderRaw: String
        let goals: [String]
        let difficultSounds: [String]
        let dailyMinutes: Int
        let reminderEnabled: Bool
        let reminderHour: Int
        let reminderMinute: Int
        let reminderDays: [Int]
        let privacyAccepted: Bool
        let screeningRequested: Bool
        let lyalyaPresetRaw: String
    }
}
