import Foundation
import OSLog

// MARK: - CustomizationInteractor

/// Бизнес-логика кастомизации Ляли.
///
/// Ответственности:
/// - Загрузка текущей кастомизации из Realm (через CustomizationStorageWorker).
/// - Проверка unlock-статуса нарядов и аксессуаров по streak/достижениям ребёнка.
/// - Live-preview: обработка выбора outfit / цвет / голос / аксессуары / фон без сохранения.
/// - Debounce auto-save: 1 секунда после последнего изменения → автоматическое сохранение.
/// - Принудительное сохранение по кнопке «Готово!».
/// - Воспроизведение preview-голоса через CustomizationVoicePreviewWorker.
/// - Lyalya voice prompts при изменении отдельных категорий.
/// - Публикация AchievementEvent.skinChanged / allSkinsExplored при первом изменении скина.
/// - Сброс к дефолтным настройкам с подтверждением.
///
/// Kid circuit — все операции on-device, никаких HFInference вызовов (COPPA).
@MainActor
final class CustomizationInteractor {

    // MARK: - VIP

    var presenter: CustomizationPresenter?

    // MARK: - Workers

    private let storageWorker: CustomizationStorageWorker
    private let voicePreviewWorker: CustomizationVoicePreviewWorker

    // MARK: - Shared state

    private let storage: LyalyaCustomizationStorage

    // MARK: - Private selection state (current in-flight values, not yet saved)

    private var currentSkin: LyalyaSkin = .classic
    private var currentColor: LyalyaColorVariant = .warm
    private var currentVoice: LyalyaVoice = .classic
    private var currentOutfit: LyalyaOutfit = .everyday
    private var currentHairColor: LyalyaHairColor = .golden
    private var currentEyeColor: LyalyaEyeColor = .blue
    private var currentSkinTone: LyalyaSkinTone = .light
    private var currentAccessories: Set<LyalyaAccessory> = []
    private var currentBackground: LyalyaBackground = .bedroom

    // MARK: - Original saved state (для отслеживания изменений)

    private var originalSkin: LyalyaSkin = .classic
    private var originalColor: LyalyaColorVariant = .warm
    private var originalVoice: LyalyaVoice = .classic
    private var originalOutfit: LyalyaOutfit = .everyday
    private var originalHairColor: LyalyaHairColor = .golden
    private var originalEyeColor: LyalyaEyeColor = .blue
    private var originalSkinTone: LyalyaSkinTone = .light
    private var originalAccessories: Set<LyalyaAccessory> = []
    private var originalBackground: LyalyaBackground = .bedroom

    // MARK: - Unlock context

    private var childStreakDays: Int = 0
    private var unlockedAchievements: Set<String> = []

    // MARK: - Debounce auto-save

    private var autoSaveTask: Task<Void, Never>?
    private static let autoSaveDelay: Duration = .milliseconds(1000)

    // MARK: - Lyalya prompts

    /// Набор реплик Ляли для разных категорий изменений.
    private static let outfitPrompts: [String] = [
        String(localized: "customization.prompt.outfit.1"),
        String(localized: "customization.prompt.outfit.2"),
        String(localized: "customization.prompt.outfit.3")
    ]

    private static let colorPrompts: [String] = [
        String(localized: "customization.prompt.color.1"),
        String(localized: "customization.prompt.color.2")
    ]

    private static let voicePrompts: [String] = [
        String(localized: "customization.prompt.voice.1"),
        String(localized: "customization.prompt.voice.2")
    ]

    private static let savePrompts: [String] = [
        String(localized: "customization.prompt.save.1"),
        String(localized: "customization.prompt.save.2")
    ]

    // MARK: - Skin change tracking (для AchievementEvent)

    private var triedSkins: Set<String> = []

    // MARK: - Logger

    private let logger = Logger(subsystem: "ru.happyspeech", category: "CustomizationInteractor")

    // MARK: - Init

    init(
        realmActor: RealmActor,
        authService: any AuthService,
        storage: LyalyaCustomizationStorage = LyalyaCustomizationStorage.shared
    ) {
        self.storageWorker = CustomizationStorageWorker(
            realmActor: realmActor,
            authService: authService
        )
        self.voicePreviewWorker = CustomizationVoicePreviewWorker()
        self.storage = storage

        self.voicePreviewWorker.onPlaybackFinished = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.presenter?.presentVoicePreviewStopped()
            }
        }
    }

    // MARK: - Load

    /// Загружает кастомизацию, вычисляет unlock-статусы, собирает полный ViewModel.
    func loadCustomization(_ request: Customization.LoadRequest) {
        childStreakDays = request.childStreakDays
        unlockedAchievements = request.unlockedAchievements

        Task {
            let dto = await storageWorker.load()

            // Восстанавливаем текущий и оригинальный state из Realm
            applyDTOToCurrentState(dto)
            applyDTOToOriginalState(dto)

            // Добавляем текущий скин в набор исследованных
            triedSkins.insert(currentSkin.rawValue)

            let outfitItems = buildOutfitItems()
            let accessoryItems = buildAccessoryItems()
            let backgroundItems = buildBackgroundItems()

            let response = Customization.LoadResponse(
                skin: currentSkin,
                color: currentColor,
                voice: currentVoice,
                outfit: currentOutfit,
                hairColor: currentHairColor,
                eyeColor: currentEyeColor,
                skinTone: currentSkinTone,
                enabledAccessories: currentAccessories,
                background: currentBackground,
                childStreakDays: childStreakDays,
                unlockedAchievements: unlockedAchievements
            )

            presenter?.presentLoadedCustomization(
                response: response,
                outfitItems: outfitItems,
                accessoryItems: accessoryItems,
                backgroundItems: backgroundItems
            )

            // Синхронизируем LyalyaCustomizationStorage
            storage.apply(dto: dto)

            logger.info("CustomizationInteractor: loaded skin=\(dto.skin) streak=\(request.childStreakDays)")
        }
    }

    // MARK: - Outfit selection

    /// Выбор наряда. Проверяет unlock-статус — заблокированный наряд не применяется.
    func selectOutfit(_ request: Customization.SelectOutfitRequest) {
        let status = outfitUnlockStatus(request.outfit)
        switch status {
        case .locked(let hint):
            presenter?.presentLockedItemAttempt(hint: hint)
            logger.info("CustomizationInteractor: outfit \(request.outfit.rawValue) locked")
            return
        case .available, .unlocked:
            currentOutfit = request.outfit
            scheduleAutoSave()
            let prompt = Self.outfitPrompts.randomElement()
            presenter?.presentOutfitSelected(
                outfit: request.outfit,
                outfitItems: buildOutfitItems(),
                lyalyaPrompt: prompt
            )
            logger.info("CustomizationInteractor: outfit selected=\(request.outfit.rawValue)")
        }
    }

    // MARK: - Skin selection

    func selectSkin(_ request: Customization.SelectSkinRequest) {
        currentSkin = request.skin
        triedSkins.insert(request.skin.rawValue)
        scheduleAutoSave()

        // Проверяем достижения за изучение скинов
        postSkinAchievementEventIfNeeded()

        presenter?.presentSkinSelected(skin: request.skin)
    }

    // MARK: - Color selection

    func selectColor(_ request: Customization.SelectColorRequest) {
        currentColor = request.color
        scheduleAutoSave()
        let prompt = Self.colorPrompts.randomElement()
        presenter?.presentColorSelected(color: request.color, lyalyaPrompt: prompt)
    }

    // MARK: - Voice selection

    func selectVoice(_ request: Customization.SelectVoiceRequest) {
        currentVoice = request.voice
        scheduleAutoSave()
        let prompt = Self.voicePrompts.randomElement()
        presenter?.presentVoiceSelected(voice: request.voice, lyalyaPrompt: prompt)
    }

    // MARK: - Hair color selection

    func selectHairColor(_ request: Customization.SelectHairColorRequest) {
        currentHairColor = request.color
        scheduleAutoSave()
        presenter?.presentHairColorSelected(color: request.color)
    }

    // MARK: - Eye color selection

    func selectEyeColor(_ request: Customization.SelectEyeColorRequest) {
        currentEyeColor = request.color
        scheduleAutoSave()
        presenter?.presentEyeColorSelected(color: request.color)
    }

    // MARK: - Skin tone selection

    func selectSkinTone(_ request: Customization.SelectSkinToneRequest) {
        currentSkinTone = request.tone
        scheduleAutoSave()
        presenter?.presentSkinToneSelected(tone: request.tone)
    }

    // MARK: - Accessory toggle

    /// Toggle аксессуара. Заблокированные аксессуары показывают hint.
    func toggleAccessory(_ request: Customization.ToggleAccessoryRequest) {
        let status = accessoryUnlockStatus(request.accessory)
        switch status {
        case .locked(let hint):
            presenter?.presentLockedItemAttempt(hint: hint)
            logger.info("CustomizationInteractor: accessory \(request.accessory.rawValue) locked")
            return
        case .available, .unlocked:
            if currentAccessories.contains(request.accessory) {
                currentAccessories.remove(request.accessory)
            } else {
                currentAccessories.insert(request.accessory)
            }
            scheduleAutoSave()
            presenter?.presentAccessoryToggled(
                accessory: request.accessory,
                accessoryItems: buildAccessoryItems()
            )
        }
    }

    // MARK: - Background selection

    func selectBackground(_ request: Customization.SelectBackgroundRequest) {
        currentBackground = request.background
        scheduleAutoSave()
        presenter?.presentBackgroundSelected(
            background: request.background,
            backgroundItems: buildBackgroundItems()
        )
    }

    // MARK: - Save

    /// Принудительное сохранение по нажатию «Готово!».
    func saveCustomization(_ request: Customization.SaveRequest) {
        // Отменяем pending auto-save, раз сохраняем явно
        autoSaveTask?.cancel()
        autoSaveTask = nil

        // Обновляем current state из request (View может передавать актуальные значения)
        currentSkin = request.skin
        currentColor = request.color
        currentVoice = request.voice
        currentOutfit = request.outfit
        currentHairColor = request.hairColor
        currentEyeColor = request.eyeColor
        currentSkinTone = request.skinTone
        currentAccessories = request.enabledAccessories
        currentBackground = request.background

        presenter?.presentSavingStarted()

        Task {
            await performSave()
        }
    }

    // MARK: - Reset to default

    /// Сброс кастомизации к дефолтным значениям.
    func resetToDefault(_ request: Customization.ResetRequest) {
        autoSaveTask?.cancel()
        autoSaveTask = nil

        currentSkin = .classic
        currentColor = .warm
        currentVoice = .classic
        currentOutfit = .everyday
        currentHairColor = .golden
        currentEyeColor = .blue
        currentSkinTone = .light
        currentAccessories = []
        currentBackground = .bedroom

        presenter?.presentSavingStarted()

        Task {
            await performSave()
            logger.info("CustomizationInteractor: reset to default completed")
        }
    }

    // MARK: - Voice Preview

    func previewVoice(_ request: Customization.PreviewVoiceRequest) {
        if voicePreviewWorker.currentVoice == request.voice {
            voicePreviewWorker.stop()
            presenter?.presentVoicePreviewStopped()
        } else {
            voicePreviewWorker.play(voice: request.voice)
            presenter?.presentVoicePreviewStarted(voice: request.voice)
        }
    }

    func stopVoicePreview() {
        voicePreviewWorker.stop()
        presenter?.presentVoicePreviewStopped()
    }

    // MARK: - Dismiss

    /// Вызывается при уходе с экрана — останавливаем preview, сбрасываем pending auto-save.
    func viewWillDisappear() {
        voicePreviewWorker.stop()
        // Не отменяем auto-save — даём ему дозавершиться
        logger.info("CustomizationInteractor: viewWillDisappear")
    }

    // MARK: - Private: auto-save debounce

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: Self.autoSaveDelay)
                guard !Task.isCancelled else { return }
                await self.performSave()
                logger.info("CustomizationInteractor: auto-save completed")
            } catch {
                // Task отменён — нормальное поведение
            }
        }
    }

    // MARK: - Private: save implementation

    private func performSave() async {
        let dto = buildCurrentDTO()

        do {
            try await storageWorker.saveLocal(dto: dto)
            storage.apply(dto: dto)

            // Обновляем original state → кнопка "Готово!" снова неактивна
            applyDTOToOriginalState(dto)

            let cloudSynced = await storageWorker.syncToCloud(dto: dto)

            let response = Customization.SaveResponse(
                success: true,
                cloudSynced: cloudSynced
            )
            let prompt = Self.savePrompts.randomElement()
            presenter?.presentSaveResult(
                response: response,
                outfitItems: buildOutfitItems(),
                accessoryItems: buildAccessoryItems(),
                backgroundItems: buildBackgroundItems(),
                lyalyaPrompt: prompt
            )

            if cloudSynced {
                try? await Task.sleep(for: .milliseconds(500))
                presenter?.presentCloudSyncedToast()
            }

            logger.info("CustomizationInteractor: saved skin=\(dto.skin) outfit=\(dto.colorVariant)")
        } catch {
            logger.error("CustomizationInteractor: save failed: \(error)")
            let response = Customization.SaveResponse(
                success: false,
                cloudSynced: false,
                errorMessage: error.localizedDescription
            )
            presenter?.presentSaveResult(
                response: response,
                outfitItems: buildOutfitItems(),
                accessoryItems: buildAccessoryItems(),
                backgroundItems: buildBackgroundItems(),
                lyalyaPrompt: nil
            )
        }
    }

    // MARK: - Private: unlock status

    private func outfitUnlockStatus(_ outfit: LyalyaOutfit) -> UnlockStatus {
        guard outfit.requiredStreak > 0 else { return .available }
        if childStreakDays >= outfit.requiredStreak {
            return .unlocked
        }
        return .locked(hint: outfit.unlockHint)
    }

    private func accessoryUnlockStatus(_ accessory: LyalyaAccessory) -> UnlockStatus {
        guard let required = accessory.requiredAchievement else { return .available }
        if unlockedAchievements.contains(required.rawValue) {
            return .unlocked
        }
        let hint = String(
            format: String(localized: "customization.accessory.unlock_hint"),
            required.localizedTitle
        )
        return .locked(hint: hint)
    }

    // MARK: - Private: build item ViewModels

    private func buildOutfitItems() -> [OutfitItemViewModel] {
        LyalyaOutfit.allCases.map { outfit in
            OutfitItemViewModel(
                id: outfit.rawValue,
                outfit: outfit,
                localizedName: outfit.localizedName,
                illustrationName: outfit.illustrationName,
                starCost: outfit.starCost,
                unlockStatus: outfitUnlockStatus(outfit),
                isSelected: currentOutfit == outfit
            )
        }
    }

    private func buildAccessoryItems() -> [AccessoryItemViewModel] {
        LyalyaAccessory.allCases.map { accessory in
            AccessoryItemViewModel(
                id: accessory.rawValue,
                accessory: accessory,
                localizedName: accessory.localizedName,
                iconName: accessory.iconName,
                unlockStatus: accessoryUnlockStatus(accessory),
                isEnabled: currentAccessories.contains(accessory)
            )
        }
    }

    private func buildBackgroundItems() -> [BackgroundItemViewModel] {
        LyalyaBackground.allCases.map { bg in
            BackgroundItemViewModel(
                id: bg.rawValue,
                background: bg,
                localizedName: bg.localizedName,
                illustrationName: bg.illustrationName,
                isSelected: currentBackground == bg
            )
        }
    }

    // MARK: - Private: DTO helpers

    private func buildCurrentDTO() -> CustomizationDTO {
        CustomizationDTO(
            skin: currentSkin.rawValue,
            colorVariant: currentColor.rawValue,
            voice: currentVoice.rawValue,
            updatedAt: Date()
        )
    }

    private func applyDTOToCurrentState(_ dto: CustomizationDTO) {
        currentSkin = dto.skinEnum
        currentColor = dto.colorEnum
        currentVoice = dto.voiceEnum
    }

    private func applyDTOToOriginalState(_ dto: CustomizationDTO) {
        originalSkin = dto.skinEnum
        originalColor = dto.colorEnum
        originalVoice = dto.voiceEnum
        originalOutfit = currentOutfit
        originalHairColor = currentHairColor
        originalEyeColor = currentEyeColor
        originalSkinTone = currentSkinTone
        originalAccessories = currentAccessories
        originalBackground = currentBackground
    }

    // MARK: - Private: achievement notifications

    private func postSkinAchievementEventIfNeeded() {
        // Уведомляем систему достижений только если это новый скин
        let allSkinsRawValues = Set(LyalyaSkin.allCases.map { $0.rawValue })
        let allTried = allSkinsRawValues.isSubset(of: triedSkins)

        NotificationCenter.default.post(
            name: .achievementEventOccurred,
            object: nil,
            userInfo: ["event": AchievementEvent.skinChanged]
        )

        if allTried {
            NotificationCenter.default.post(
                name: .achievementEventOccurred,
                object: nil,
                userInfo: ["event": AchievementEvent.allSkinsExplored]
            )
            logger.info("CustomizationInteractor: allSkinsExplored achievement triggered")
        }
    }

    // MARK: - Computed: has unsaved changes

    private var hasUnsavedChanges: Bool {
        currentSkin != originalSkin
            || currentColor != originalColor
            || currentVoice != originalVoice
            || currentOutfit != originalOutfit
            || currentHairColor != originalHairColor
            || currentEyeColor != originalEyeColor
            || currentSkinTone != originalSkinTone
            || currentAccessories != originalAccessories
            || currentBackground != originalBackground
    }
}
