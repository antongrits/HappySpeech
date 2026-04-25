import Foundation
import OSLog

// MARK: - OnboardingBusinessLogic

@MainActor
protocol OnboardingBusinessLogic: AnyObject {
    func loadOnboarding(_ request: OnboardingModels.LoadOnboarding.Request)
    func advanceStep(_ request: OnboardingModels.AdvanceStep.Request)
    func goBack(_ request: OnboardingModels.GoBack.Request)
    func setRole(_ request: OnboardingModels.SetRole.Request)
    func setProfile(_ request: OnboardingModels.SetProfile.Request)
    func toggleGoal(_ request: OnboardingModels.ToggleGoal.Request)
    func skipPermissions(_ request: OnboardingModels.SkipPermissions.Request)
    func startModelDownload(_ request: OnboardingModels.StartModelDownload.Request)
    func completeOnboarding(_ request: OnboardingModels.CompleteOnboarding.Request)
}

// MARK: - OnboardingInteractor

/// Бизнес-логика онбординга. На M7.2 хранит профиль в памяти; на M8 будет
/// сохранять в `ChildRepository` и передавать `WhisperKitModelManager` для
/// фоновой загрузки модели.
@MainActor
final class OnboardingInteractor: OnboardingBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any OnboardingPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Onboarding")

    // MARK: - State

    private var currentStep: OnboardingStep = .welcome
    private var profile = OnboardingProfile()
    private var modelStatus: ModelDownloadStatus = .idle
    private var downloadTask: Task<Void, Never>?

    // MARK: - Init

    init() {}

    deinit {
        downloadTask?.cancel()
    }

    // MARK: - BusinessLogic

    func loadOnboarding(_ request: OnboardingModels.LoadOnboarding.Request) {
        currentStep = .welcome
        profile = OnboardingProfile()
        modelStatus = .idle
        logger.info("loadOnboarding")
        presenter?.presentLoadOnboarding(.init(
            initialStep: currentStep,
            profile: profile
        ))
    }

    func advanceStep(_ request: OnboardingModels.AdvanceStep.Request) {
        let nextRaw = currentStep.rawValue + 1
        let isCompleted = nextRaw >= OnboardingStep.allCases.count

        if !isCompleted, let next = OnboardingStep(rawValue: nextRaw) {
            currentStep = next
        }
        logger.info("advanceStep to=\(self.currentStep.rawValue, privacy: .public) completed=\(isCompleted, privacy: .public)")

        presenter?.presentAdvanceStep(.init(
            currentStep: currentStep,
            profile: profile,
            isCompleted: isCompleted
        ))
    }

    func goBack(_ request: OnboardingModels.GoBack.Request) {
        let prevRaw = max(0, currentStep.rawValue - 1)
        if let prev = OnboardingStep(rawValue: prevRaw) {
            currentStep = prev
        }
        logger.info("goBack to=\(self.currentStep.rawValue, privacy: .public)")
        presenter?.presentGoBack(.init(
            currentStep: currentStep,
            profile: profile
        ))
    }

    func setRole(_ request: OnboardingModels.SetRole.Request) {
        profile.role = request.role
        logger.info("setRole role=\(request.role.rawValue, privacy: .public)")
        presenter?.presentSetRole(.init(profile: profile))
    }

    func setProfile(_ request: OnboardingModels.SetProfile.Request) {
        let trimmedName = request.name.trimmingCharacters(in: .whitespaces)
        profile.childName = trimmedName
        profile.childAge = max(3, min(12, request.age))
        if !request.avatar.isEmpty {
            profile.childAvatar = request.avatar
        }
        logger.info("setProfile age=\(self.profile.childAge, privacy: .public)")
        presenter?.presentSetProfile(.init(profile: profile))
    }

    func toggleGoal(_ request: OnboardingModels.ToggleGoal.Request) {
        if profile.goals.contains(request.goalId) {
            profile.goals.remove(request.goalId)
        } else {
            profile.goals.insert(request.goalId)
        }
        logger.info("toggleGoal id=\(request.goalId, privacy: .public) selected=\(self.profile.goals.count, privacy: .public)")
        presenter?.presentToggleGoal(.init(profile: profile))
    }

    func skipPermissions(_ request: OnboardingModels.SkipPermissions.Request) {
        // Continue to model download step.
        if currentStep == .permissions, let next = OnboardingStep(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        }
        logger.info("skipPermissions → step=\(self.currentStep.rawValue, privacy: .public)")
        presenter?.presentSkipPermissions(.init(
            currentStep: currentStep,
            profile: profile
        ))
    }

    func startModelDownload(_ request: OnboardingModels.StartModelDownload.Request) {
        guard downloadTask == nil else {
            logger.info("startModelDownload: already in progress")
            return
        }
        modelStatus = .downloading(progress: 0.0)
        presenter?.presentStartModelDownload(.init(status: modelStatus))

        downloadTask = Task { [weak self] in
            // Симуляция загрузки: 12 шагов по 250 ms (~3 сек).
            for step in 1...12 {
                if Task.isCancelled { return }
                try? await Task.sleep(for: .milliseconds(250))
                let progress = Double(step) / 12.0
                await self?.publishProgress(progress)
            }
            await self?.completeModelDownload()
        }
    }

    func completeOnboarding(_ request: OnboardingModels.CompleteOnboarding.Request) {
        downloadTask?.cancel()
        downloadTask = nil
        logger.info("completeOnboarding role=\(self.profile.role.rawValue, privacy: .public) name=\(self.profile.childName, privacy: .private(mask: .hash))")
        presenter?.presentCompleteOnboarding(.init(profile: profile))
    }

    // MARK: - Private

    private func publishProgress(_ progress: Double) {
        modelStatus = .downloading(progress: progress)
        presenter?.presentStartModelDownload(.init(status: modelStatus))
    }

    private func completeModelDownload() {
        modelStatus = .completed
        downloadTask = nil
        logger.info("model download completed")
        presenter?.presentStartModelDownload(.init(status: modelStatus))
    }
}
