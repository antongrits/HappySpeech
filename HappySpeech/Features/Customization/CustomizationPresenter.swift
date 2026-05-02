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
    private var currentOutfit: LyalyaOutfit = .everyday
    private var currentHairColor: LyalyaHairColor = .golden
    private var currentEyeColor: LyalyaEyeColor = .blue
    private var currentSkinTone: LyalyaSkinTone = .light
    private var currentAccessories: Set<LyalyaAccessory> = []
    private var currentBackground: LyalyaBackground = .bedroom

    private var originalSkin: LyalyaSkin = .classic
    private var originalColor: LyalyaColorVariant = .warm
    private var originalVoice: LyalyaVoice = .classic
    private var originalOutfit: LyalyaOutfit = .everyday
    private var originalHairColor: LyalyaHairColor = .golden
    private var originalEyeColor: LyalyaEyeColor = .blue
    private var originalSkinTone: LyalyaSkinTone = .light
    private var originalAccessories: Set<LyalyaAccessory> = []
    private var originalBackground: LyalyaBackground = .bedroom

    private var currentOutfitItems: [OutfitItemViewModel] = []
    private var currentAccessoryItems: [AccessoryItemViewModel] = []
    private var currentBackgroundItems: [BackgroundItemViewModel] = []

    // MARK: - Present Load

    func presentLoadedCustomization(
        response: Customization.LoadResponse,
        outfitItems: [OutfitItemViewModel],
        accessoryItems: [AccessoryItemViewModel],
        backgroundItems: [BackgroundItemViewModel]
    ) {
        currentSkin = response.skin
        currentColor = response.color
        currentVoice = response.voice
        currentOutfit = response.outfit
        currentHairColor = response.hairColor
        currentEyeColor = response.eyeColor
        currentSkinTone = response.skinTone
        currentAccessories = response.enabledAccessories
        currentBackground = response.background

        originalSkin = response.skin
        originalColor = response.color
        originalVoice = response.voice
        originalOutfit = response.outfit
        originalHairColor = response.hairColor
        originalEyeColor = response.eyeColor
        originalSkinTone = response.skinTone
        originalAccessories = response.enabledAccessories
        originalBackground = response.background

        currentOutfitItems = outfitItems
        currentAccessoryItems = accessoryItems
        currentBackgroundItems = backgroundItems

        let viewModel = makeCurrentViewModel()
        display?.displayLoadedCustomization(viewModel: viewModel)

        logger.info(
            "Customization loaded: skin=\(response.skin.rawValue) outfit=\(response.outfit.rawValue) bg=\(response.background.rawValue)"
        )
    }

    // MARK: - Present Outfit

    func presentOutfitSelected(
        outfit: LyalyaOutfit,
        outfitItems: [OutfitItemViewModel],
        lyalyaPrompt: String?
    ) {
        currentOutfit = outfit
        currentOutfitItems = outfitItems
        var vm = makeCurrentViewModel()
        vm.lyalyaPrompt = lyalyaPrompt
        display?.displaySelectionChanged(viewModel: vm)
    }

    // MARK: - Present Skin

    func presentSkinSelected(skin: LyalyaSkin) {
        currentSkin = skin
        let viewModel = makeCurrentViewModel()
        display?.displaySelectionChanged(viewModel: viewModel)
    }

    // MARK: - Present Color

    func presentColorSelected(color: LyalyaColorVariant, lyalyaPrompt: String?) {
        currentColor = color
        var vm = makeCurrentViewModel()
        vm.lyalyaPrompt = lyalyaPrompt
        display?.displaySelectionChanged(viewModel: vm)
    }

    // MARK: - Present Voice

    func presentVoiceSelected(voice: LyalyaVoice, lyalyaPrompt: String?) {
        currentVoice = voice
        var vm = makeCurrentViewModel()
        vm.lyalyaPrompt = lyalyaPrompt
        display?.displaySelectionChanged(viewModel: vm)
    }

    // MARK: - Present Hair Color

    func presentHairColorSelected(color: LyalyaHairColor) {
        currentHairColor = color
        let vm = makeCurrentViewModel()
        display?.displaySelectionChanged(viewModel: vm)
    }

    // MARK: - Present Eye Color

    func presentEyeColorSelected(color: LyalyaEyeColor) {
        currentEyeColor = color
        let vm = makeCurrentViewModel()
        display?.displaySelectionChanged(viewModel: vm)
    }

    // MARK: - Present Skin Tone

    func presentSkinToneSelected(tone: LyalyaSkinTone) {
        currentSkinTone = tone
        let vm = makeCurrentViewModel()
        display?.displaySelectionChanged(viewModel: vm)
    }

    // MARK: - Present Accessory Toggle

    func presentAccessoryToggled(
        accessory: LyalyaAccessory,
        accessoryItems: [AccessoryItemViewModel]
    ) {
        currentAccessoryItems = accessoryItems
        // Синхронизируем currentAccessories из items
        currentAccessories = Set(accessoryItems.filter { $0.isEnabled }.compactMap { $0.accessory })
        let vm = makeCurrentViewModel()
        display?.displaySelectionChanged(viewModel: vm)
    }

    // MARK: - Present Background

    func presentBackgroundSelected(
        background: LyalyaBackground,
        backgroundItems: [BackgroundItemViewModel]
    ) {
        currentBackground = background
        currentBackgroundItems = backgroundItems
        let vm = makeCurrentViewModel()
        display?.displaySelectionChanged(viewModel: vm)
    }

    // MARK: - Present Locked Item

    func presentLockedItemAttempt(hint: String) {
        var vm = makeCurrentViewModel()
        vm.toastMessage = hint
        vm.toastIsError = false
        display?.displayLockedItemAttempt(viewModel: vm)
    }

    // MARK: - Present Saving state

    func presentSavingStarted() {
        var vm = makeCurrentViewModel()
        vm.isSaving = true
        display?.displaySelectionChanged(viewModel: vm)
    }

    // MARK: - Present Save Result

    func presentSaveResult(
        response: Customization.SaveResponse,
        outfitItems: [OutfitItemViewModel],
        accessoryItems: [AccessoryItemViewModel],
        backgroundItems: [BackgroundItemViewModel],
        lyalyaPrompt: String?
    ) {
        currentOutfitItems = outfitItems
        currentAccessoryItems = accessoryItems
        currentBackgroundItems = backgroundItems

        if response.success {
            // После успешного сохранения original = current
            originalSkin = currentSkin
            originalColor = currentColor
            originalVoice = currentVoice
            originalOutfit = currentOutfit
            originalHairColor = currentHairColor
            originalEyeColor = currentEyeColor
            originalSkinTone = currentSkinTone
            originalAccessories = currentAccessories
            originalBackground = currentBackground

            var vm = makeCurrentViewModel()
            vm.isSaving = false
            vm.isUnchanged = true
            vm.toastMessage = String(localized: "customization.feedback.saved")
            vm.toastIsError = false
            vm.showCelebration = true
            vm.lyalyaPrompt = lyalyaPrompt
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
            && currentVoice == originalVoice
            && currentOutfit == originalOutfit
            && currentHairColor == originalHairColor
            && currentEyeColor == originalEyeColor
            && currentSkinTone == originalSkinTone
            && currentAccessories == originalAccessories
            && currentBackground == originalBackground)

        return CustomizationViewModel(
            selectedSkin: currentSkin,
            selectedColor: currentColor,
            selectedVoice: currentVoice,
            selectedOutfit: currentOutfit,
            selectedHairColor: currentHairColor,
            selectedEyeColor: currentEyeColor,
            selectedSkinTone: currentSkinTone,
            enabledAccessories: currentAccessories,
            selectedBackground: currentBackground,
            outfitItems: currentOutfitItems,
            accessoryItems: currentAccessoryItems,
            backgroundItems: currentBackgroundItems,
            isSaving: false,
            isUnchanged: unchanged
        )
    }
}
