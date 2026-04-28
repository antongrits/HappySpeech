import Foundation
import OSLog

// MARK: - CustomizationInteractor

/// Бизнес-логика кастомизации Ляли.
/// Читает/пишет Realm через CustomizationStorageWorker,
/// озвучивает голос через CustomizationVoicePreviewWorker,
/// обновляет LyalyaCustomizationStorage (shared state для всего приложения).
@MainActor
final class CustomizationInteractor {

    // MARK: - VIP

    var presenter: CustomizationPresenter?

    // MARK: - Workers

    private let storageWorker: CustomizationStorageWorker
    private let voicePreviewWorker: CustomizationVoicePreviewWorker
    private let storage: LyalyaCustomizationStorage

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

    func loadCustomization(_ request: Customization.LoadRequest) {
        Task {
            let dto = await storageWorker.load()
            let response = Customization.LoadResponse(
                skin: dto.skinEnum,
                color: dto.colorEnum,
                voice: dto.voiceEnum
            )
            presenter?.presentLoadedCustomization(response: response)

            // При загрузке — также синхронизируем LyalyaCustomizationStorage
            storage.apply(dto: dto)
        }
    }

    // MARK: - Selection changes (live preview — не сохраняет)

    func selectSkin(_ request: Customization.SelectSkinRequest) {
        presenter?.presentSkinSelected(skin: request.skin)
    }

    func selectColor(_ request: Customization.SelectColorRequest) {
        presenter?.presentColorSelected(color: request.color)
    }

    func selectVoice(_ request: Customization.SelectVoiceRequest) {
        presenter?.presentVoiceSelected(voice: request.voice)
    }

    // MARK: - Save

    func saveCustomization(_ request: Customization.SaveRequest) {
        presenter?.presentSavingStarted()

        Task {
            let dto = CustomizationDTO(
                skin: request.skin.rawValue,
                colorVariant: request.color.rawValue,
                voice: request.voice.rawValue,
                updatedAt: Date()
            )

            do {
                try await storageWorker.saveLocal(dto: dto)
                // Обновляем shared state — Ляля везде в приложении сразу обновляется
                storage.apply(dto: dto)

                // Cloud sync (async — не блокируем UI)
                let cloudSynced = await storageWorker.syncToCloud(dto: dto)

                let response = Customization.SaveResponse(
                    success: true,
                    cloudSynced: cloudSynced
                )
                presenter?.presentSaveResult(response: response)

                // Если cloud sync — показываем второй toast через 0.5с
                if cloudSynced {
                    try? await Task.sleep(for: .milliseconds(500))
                    presenter?.presentCloudSyncedToast()
                }
            } catch {
                logger.error("saveCustomization failed: \(error)")
                let response = Customization.SaveResponse(
                    success: false,
                    cloudSynced: false,
                    errorMessage: error.localizedDescription
                )
                presenter?.presentSaveResult(response: response)
            }
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
}
