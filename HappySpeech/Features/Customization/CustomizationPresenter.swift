import Foundation
import OSLog

// MARK: - CustomizationPresenter

/// Формирует ViewModel из Response и передаёт в Display.
/// Запускается на MainActor — Display (View) обновляется синхронно на главном потоке.
@MainActor
final class CustomizationPresenter {

    // MARK: - Dependencies

    weak var display: CustomizationDisplayLogic?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "CustomizationPresenter")

    // MARK: - Internal selection state
    // Презентер хранит текущий выбор между load/save чтобы корректно
    // собирать промежуточные viewModel при изменении отдельных полей.

    private var currentSkin: LyalyaSkin = .classic
    private var currentColor: LyalyaColorVariant = .warm
    private var currentVoice: LyalyaVoice = .classic
    private var originalSkin: LyalyaSkin = .classic
    private var originalColor: LyalyaColorVariant = .warm
    private var originalVoice: LyalyaVoice = .classic

    // MARK: - Present Load

    func presentLoadedCustomization(response: Customization.LoadResponse) {
        currentSkin = response.skin
        currentColor = response.color
        currentVoice = response.voice
        originalSkin = response.skin
        originalColor = response.color
        originalVoice = response.voice

        let viewModel = CustomizationViewModel(
            selectedSkin: response.skin,
            selectedColor: response.color,
            selectedVoice: response.voice,
            isSaving: false,
            isUnchanged: true
        )
        display?.displayLoadedCustomization(viewModel: viewModel)
        logger.info("Customization loaded: skin=\(response.skin.rawValue), color=\(response.color.rawValue), voice=\(response.voice.rawValue)")
    }

    // MARK: - Present Selection Change

    func presentSkinSelected(skin: LyalyaSkin) {
        currentSkin = skin
        let viewModel = makeCurrentViewModel()
        display?.displaySelectionChanged(viewModel: viewModel)
    }

    func presentColorSelected(color: LyalyaColorVariant) {
        currentColor = color
        let viewModel = makeCurrentViewModel()
        display?.displaySelectionChanged(viewModel: viewModel)
    }

    func presentVoiceSelected(voice: LyalyaVoice) {
        currentVoice = voice
        let viewModel = makeCurrentViewModel()
        display?.displaySelectionChanged(viewModel: viewModel)
    }

    // MARK: - Present Saving state

    func presentSavingStarted() {
        var vm = makeCurrentViewModel()
        vm.isSaving = true
        display?.displaySelectionChanged(viewModel: vm)
    }

    // MARK: - Present Save Result

    func presentSaveResult(response: Customization.SaveResponse) {
        if response.success {
            originalSkin = currentSkin
            originalColor = currentColor
            originalVoice = currentVoice

            var vm = makeCurrentViewModel()
            vm.isSaving = false
            vm.isUnchanged = true
            vm.toastMessage = String(localized: "customization.feedback.saved")
            vm.toastIsError = false
            vm.showCelebration = true
            display?.displaySaveResult(viewModel: vm)

            if response.cloudSynced {
                logger.info("Customization saved and cloud synced")
            } else {
                logger.info("Customization saved locally (offline)")
            }
        } else {
            var vm = makeCurrentViewModel()
            vm.isSaving = false
            vm.toastMessage = response.errorMessage ?? String(localized: "customization.feedback.error_save")
            vm.toastIsError = true
            display?.displaySaveResult(viewModel: vm)
            logger.error("Customization save failed: \(response.errorMessage ?? "unknown")")
        }
    }

    // MARK: - Present Cloud sync toast (delayed)

    func presentCloudSyncedToast() {
        var vm = makeCurrentViewModel()
        vm.isSaving = false
        vm.isUnchanged = true
        vm.toastMessage = String(localized: "customization.feedback.cloud_synced")
        vm.toastIsError = false
        display?.displaySaveResult(viewModel: vm)
    }

    // MARK: - Present Voice Preview

    func presentVoicePreviewStarted(voice: LyalyaVoice) {
        display?.displayVoicePreviewState(playingVoice: voice)
    }

    func presentVoicePreviewStopped() {
        display?.displayVoicePreviewState(playingVoice: nil)
    }

    // MARK: - Private helpers

    private func makeCurrentViewModel() -> CustomizationViewModel {
        let unchanged = (currentSkin == originalSkin
                         && currentColor == originalColor
                         && currentVoice == originalVoice)
        return CustomizationViewModel(
            selectedSkin: currentSkin,
            selectedColor: currentColor,
            selectedVoice: currentVoice,
            isSaving: false,
            isUnchanged: unchanged
        )
    }
}
