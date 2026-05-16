@testable import HappySpeech
import XCTest

// MARK: - CustomizationPresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие CustomizationPresenter (64% → цель ≥90%).

@MainActor
final class CustomizationPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: CustomizationDisplayLogic {
        var loadedVM: CustomizationViewModel?
        var saveResultVM: CustomizationViewModel?
        var selectionChangedVM: CustomizationViewModel?
        var playingVoice: LyalyaVoice?
        var lockedItemVM: CustomizationViewModel?

        func displayLoadedCustomization(viewModel: CustomizationViewModel) { loadedVM = viewModel }
        func displaySaveResult(viewModel: CustomizationViewModel) { saveResultVM = viewModel }
        func displaySelectionChanged(viewModel: CustomizationViewModel) { selectionChangedVM = viewModel }
        func displayVoicePreviewState(playingVoice: LyalyaVoice?) { self.playingVoice = playingVoice }
        func displayLockedItemAttempt(viewModel: CustomizationViewModel) { lockedItemVM = viewModel }
    }

    private func makeSUT() -> (CustomizationPresenter, DisplaySpy) {
        let presenter = CustomizationPresenter()
        let spy = DisplaySpy()
        presenter.display = spy
        return (presenter, spy)
    }

    private func makeLoadResponse(
        skin: LyalyaSkin = .classic,
        color: LyalyaColorVariant = .warm,
        voice: LyalyaVoice = .classic,
        outfit: LyalyaOutfit = .everyday,
        background: LyalyaBackground = .bedroom
    ) -> Customization.LoadResponse {
        Customization.LoadResponse(
            skin: skin,
            color: color,
            voice: voice,
            outfit: outfit,
            background: background
        )
    }

    // MARK: - presentLoadedCustomization

    func test_presentLoadedCustomization_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentLoadedCustomization(response: makeLoadResponse(), outfitItems: [], accessoryItems: [], backgroundItems: [])
        XCTAssertNotNil(spy.loadedVM)
    }

    func test_presentLoadedCustomization_skinPassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentLoadedCustomization(response: makeLoadResponse(skin: .princess), outfitItems: [], accessoryItems: [], backgroundItems: [])
        XCTAssertEqual(spy.loadedVM?.selectedSkin, .princess)
    }

    func test_presentLoadedCustomization_isUnchangedTrue() {
        let (sut, spy) = makeSUT()
        sut.presentLoadedCustomization(response: makeLoadResponse(), outfitItems: [], accessoryItems: [], backgroundItems: [])
        XCTAssertTrue(spy.loadedVM?.isUnchanged ?? false)
    }

    func test_presentLoadedCustomization_backgroundPassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentLoadedCustomization(response: makeLoadResponse(background: .forest), outfitItems: [], accessoryItems: [], backgroundItems: [])
        XCTAssertEqual(spy.loadedVM?.selectedBackground, .forest)
    }

    // MARK: - presentSkinSelected

    func test_presentSkinSelected_skinUpdated() {
        let (sut, spy) = makeSUT()
        sut.presentLoadedCustomization(response: makeLoadResponse(skin: .classic), outfitItems: [], accessoryItems: [], backgroundItems: [])
        sut.presentSkinSelected(skin: .scientist)
        XCTAssertEqual(spy.selectionChangedVM?.selectedSkin, .scientist)
    }

    func test_presentSkinSelected_isUnchangedFalse() {
        let (sut, spy) = makeSUT()
        sut.presentLoadedCustomization(response: makeLoadResponse(skin: .classic), outfitItems: [], accessoryItems: [], backgroundItems: [])
        sut.presentSkinSelected(skin: .athlete)
        XCTAssertFalse(spy.selectionChangedVM?.isUnchanged ?? true)
    }

    // MARK: - presentColorSelected

    func test_presentColorSelected_colorUpdated() {
        let (sut, spy) = makeSUT()
        sut.presentLoadedCustomization(response: makeLoadResponse(color: .warm), outfitItems: [], accessoryItems: [], backgroundItems: [])
        sut.presentColorSelected(color: .cool, lyalyaPrompt: "Красиво!")
        XCTAssertEqual(spy.selectionChangedVM?.selectedColor, .cool)
    }

    func test_presentColorSelected_lyalyaPromptSet() {
        let (sut, spy) = makeSUT()
        sut.presentLoadedCustomization(response: makeLoadResponse(), outfitItems: [], accessoryItems: [], backgroundItems: [])
        sut.presentColorSelected(color: .cool, lyalyaPrompt: "Ура!")
        XCTAssertEqual(spy.selectionChangedVM?.lyalyaPrompt, "Ура!")
    }

    // MARK: - presentVoiceSelected

    func test_presentVoiceSelected_voiceUpdated() {
        let (sut, spy) = makeSUT()
        sut.presentLoadedCustomization(response: makeLoadResponse(voice: .classic), outfitItems: [], accessoryItems: [], backgroundItems: [])
        sut.presentVoiceSelected(voice: .soft, lyalyaPrompt: nil)
        XCTAssertEqual(spy.selectionChangedVM?.selectedVoice, .soft)
    }

    // MARK: - presentHairColorSelected

    func test_presentHairColorSelected_hairColorUpdated() {
        let (sut, spy) = makeSUT()
        sut.presentLoadedCustomization(response: makeLoadResponse(), outfitItems: [], accessoryItems: [], backgroundItems: [])
        sut.presentHairColorSelected(color: .pink)
        XCTAssertEqual(spy.selectionChangedVM?.selectedHairColor, .pink)
    }

    // MARK: - presentEyeColorSelected

    func test_presentEyeColorSelected_eyeColorUpdated() {
        let (sut, spy) = makeSUT()
        sut.presentLoadedCustomization(response: makeLoadResponse(), outfitItems: [], accessoryItems: [], backgroundItems: [])
        sut.presentEyeColorSelected(color: .green)
        XCTAssertEqual(spy.selectionChangedVM?.selectedEyeColor, .green)
    }

    // MARK: - presentSkinToneSelected

    func test_presentSkinToneSelected_skinToneUpdated() {
        let (sut, spy) = makeSUT()
        sut.presentLoadedCustomization(response: makeLoadResponse(), outfitItems: [], accessoryItems: [], backgroundItems: [])
        sut.presentSkinToneSelected(tone: .dark)
        XCTAssertEqual(spy.selectionChangedVM?.selectedSkinTone, .dark)
    }

    // MARK: - presentOutfitSelected

    func test_presentOutfitSelected_outfitUpdated() {
        let (sut, spy) = makeSUT()
        sut.presentLoadedCustomization(response: makeLoadResponse(outfit: .everyday), outfitItems: [], accessoryItems: [], backgroundItems: [])
        sut.presentOutfitSelected(outfit: .beach, outfitItems: [], lyalyaPrompt: "Пляж!")
        XCTAssertEqual(spy.selectionChangedVM?.selectedOutfit, .beach)
    }

    // MARK: - presentAccessoryToggled

    func test_presentAccessoryToggled_updatesAccessories() {
        let (sut, spy) = makeSUT()
        sut.presentLoadedCustomization(response: makeLoadResponse(), outfitItems: [], accessoryItems: [], backgroundItems: [])
        let accessoryItem = AccessoryItemViewModel(id: "bow", accessory: .bow, localizedName: "Бант", iconName: "bow_icon", unlockStatus: .available, isEnabled: true)
        sut.presentAccessoryToggled(accessory: .bow, accessoryItems: [accessoryItem])
        XCTAssertTrue(spy.selectionChangedVM?.enabledAccessories.contains(.bow) ?? false)
    }

    // MARK: - presentBackgroundSelected

    func test_presentBackgroundSelected_backgroundUpdated() {
        let (sut, spy) = makeSUT()
        sut.presentLoadedCustomization(response: makeLoadResponse(background: .bedroom), outfitItems: [], accessoryItems: [], backgroundItems: [])
        sut.presentBackgroundSelected(background: .forest, backgroundItems: [])
        XCTAssertEqual(spy.selectionChangedVM?.selectedBackground, .forest)
    }

    // MARK: - presentLockedItemAttempt

    func test_presentLockedItemAttempt_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentLockedItemAttempt(hint: "Нужно 5 занятий подряд")
        XCTAssertNotNil(spy.lockedItemVM)
    }

    func test_presentLockedItemAttempt_toastMessageSet() {
        let (sut, spy) = makeSUT()
        sut.presentLockedItemAttempt(hint: "Нужно 5 занятий подряд")
        XCTAssertEqual(spy.lockedItemVM?.toastMessage, "Нужно 5 занятий подряд")
    }

    func test_presentLockedItemAttempt_toastIsErrorFalse() {
        let (sut, spy) = makeSUT()
        sut.presentLockedItemAttempt(hint: "Подсказка")
        XCTAssertFalse(spy.lockedItemVM?.toastIsError ?? true)
    }

    // MARK: - presentSavingStarted

    func test_presentSavingStarted_isSavingTrue() {
        let (sut, spy) = makeSUT()
        sut.presentSavingStarted()
        XCTAssertTrue(spy.selectionChangedVM?.isSaving ?? false)
    }

    // MARK: - presentSaveResult: success

    func test_presentSaveResult_success_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentSaveResult(
            response: .init(success: true, cloudSynced: false),
            outfitItems: [], accessoryItems: [], backgroundItems: [], lyalyaPrompt: nil
        )
        XCTAssertNotNil(spy.saveResultVM)
    }

    func test_presentSaveResult_success_isSavingFalse() {
        let (sut, spy) = makeSUT()
        sut.presentSaveResult(
            response: .init(success: true, cloudSynced: false),
            outfitItems: [], accessoryItems: [], backgroundItems: [], lyalyaPrompt: nil
        )
        XCTAssertFalse(spy.saveResultVM?.isSaving ?? true)
    }

    func test_presentSaveResult_success_isUnchangedTrue() {
        let (sut, spy) = makeSUT()
        sut.presentSaveResult(
            response: .init(success: true, cloudSynced: false),
            outfitItems: [], accessoryItems: [], backgroundItems: [], lyalyaPrompt: nil
        )
        XCTAssertTrue(spy.saveResultVM?.isUnchanged ?? false)
    }

    func test_presentSaveResult_success_toastMessageNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentSaveResult(
            response: .init(success: true, cloudSynced: true),
            outfitItems: [], accessoryItems: [], backgroundItems: [], lyalyaPrompt: nil
        )
        XCTAssertFalse(spy.saveResultVM?.toastMessage?.isEmpty ?? true)
    }

    func test_presentSaveResult_success_showCelebrationTrue() {
        let (sut, spy) = makeSUT()
        sut.presentSaveResult(
            response: .init(success: true, cloudSynced: false),
            outfitItems: [], accessoryItems: [], backgroundItems: [], lyalyaPrompt: nil
        )
        XCTAssertTrue(spy.saveResultVM?.showCelebration ?? false)
    }

    // MARK: - presentSaveResult: failure

    func test_presentSaveResult_failure_isSavingFalse() {
        let (sut, spy) = makeSUT()
        sut.presentSaveResult(
            response: .init(success: false, cloudSynced: false, errorMessage: "Ошибка"),
            outfitItems: [], accessoryItems: [], backgroundItems: [], lyalyaPrompt: nil
        )
        XCTAssertFalse(spy.saveResultVM?.isSaving ?? true)
    }

    func test_presentSaveResult_failure_toastIsErrorTrue() {
        let (sut, spy) = makeSUT()
        sut.presentSaveResult(
            response: .init(success: false, cloudSynced: false, errorMessage: "Ошибка"),
            outfitItems: [], accessoryItems: [], backgroundItems: [], lyalyaPrompt: nil
        )
        XCTAssertTrue(spy.saveResultVM?.toastIsError ?? false)
    }

    func test_presentSaveResult_failure_errorToastNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentSaveResult(
            response: .init(success: false, cloudSynced: false, errorMessage: nil),
            outfitItems: [], accessoryItems: [], backgroundItems: [], lyalyaPrompt: nil
        )
        XCTAssertFalse(spy.saveResultVM?.toastMessage?.isEmpty ?? true)
    }

    // MARK: - presentCloudSyncedToast

    func test_presentCloudSyncedToast_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentCloudSyncedToast()
        XCTAssertNotNil(spy.saveResultVM)
    }

    func test_presentCloudSyncedToast_toastMessageNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentCloudSyncedToast()
        XCTAssertFalse(spy.saveResultVM?.toastMessage?.isEmpty ?? true)
    }

    func test_presentCloudSyncedToast_toastIsErrorFalse() {
        let (sut, spy) = makeSUT()
        sut.presentCloudSyncedToast()
        XCTAssertFalse(spy.saveResultVM?.toastIsError ?? true)
    }

    // MARK: - presentVoicePreviewStarted / Stopped

    func test_presentVoicePreviewStarted_playingVoiceSet() {
        let (sut, spy) = makeSUT()
        sut.presentVoicePreviewStarted(voice: .soft)
        XCTAssertEqual(spy.playingVoice, .soft)
    }

    func test_presentVoicePreviewStopped_playingVoiceNil() {
        let (sut, spy) = makeSUT()
        sut.presentVoicePreviewStarted(voice: .cheerful)
        sut.presentVoicePreviewStopped()
        XCTAssertNil(spy.playingVoice)
    }
}
