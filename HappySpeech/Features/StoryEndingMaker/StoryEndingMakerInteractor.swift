import Foundation
import OSLog

// MARK: - StoryEndingMakerInteractor

/// Бизнес-логика игры «Придумай концовку».
///
/// Картинки-концовки берутся из реального словаря под звуки ребёнка
/// (`StoryEndingMakerWorker`). Шаг «запись» использует реальный `AudioService`
/// (ребёнок проговаривает свою концовку) и сохраняет аудио на диск; счётчик
/// сохранённых концовок персистится в `UserDefaults`. Без аудио-сервиса
/// (Preview/тесты) сохранение проходит без записи.
@MainActor
@Observable
final class StoryEndingMakerInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "StoryEndingMaker"
    )

    let childId: String
    var state: StoryEndingMakerModels.ViewState = .initial

    private let worker: (any StoryEndingMakerWorkerProtocol)?
    private let audioService: (any AudioService)?
    private let adaptivePlanner: (any AdaptivePlannerService)?
    private let defaults: UserDefaults

    init(
        childId: String,
        worker: (any StoryEndingMakerWorkerProtocol)? = nil,
        audioService: (any AudioService)? = nil,
        adaptivePlanner: (any AdaptivePlannerService)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.childId = childId
        self.worker = worker
        self.audioService = audioService
        self.adaptivePlanner = adaptivePlanner
        self.defaults = defaults
    }

    func load() async {
        if let worker {
            state.cards = await worker.buildCards(childId: childId)
        }
        state.savedCount = loadSavedCount()
        state.isLoaded = true
        Self.logger.info("loaded \(self.state.cards.count, privacy: .public) cards, saved=\(self.state.savedCount, privacy: .public)")
    }

    func select(_ id: String) {
        state.selectedId = id
        state.phase = .recording
        Self.logger.info("select card \(id, privacy: .public)")
        // Стартуем запись голоса концовки (если доступно).
        startRecordingIfPossible()
    }

    /// Сохраняет концовку: останавливает запись (если шла), инкрементирует
    /// счётчик и фиксирует активность в планировщике.
    func save() {
        guard state.phase == .recording else { return }
        state.phase = .saving
        Task { [weak self] in
            guard let self else { return }
            await self.stopRecordingIfPossible()
            self.state.savedCount += 1
            self.persistSavedCount()
            self.state.phase = .saved
            self.recordActivity()
            Self.logger.info("story ending saved (total=\(self.state.savedCount, privacy: .public))")
        }
    }

    func reset() {
        state.selectedId = nil
        state.phase = .choosing
    }

    // MARK: - Recording

    private func startRecordingIfPossible() {
        guard let audioService else { return }
        Task {
            do {
                try await audioService.startRecording()
            } catch {
                Self.logger.error("startRecording failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func stopRecordingIfPossible() async {
        guard let audioService else { return }
        do {
            _ = try await audioService.stopRecording()
        } catch {
            Self.logger.error("stopRecording failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Persistence

    private var storageKey: String { "storyEnding.savedCount.\(childId)" }

    private func loadSavedCount() -> Int {
        guard !childId.isEmpty else { return 0 }
        return defaults.integer(forKey: storageKey)
    }

    private func persistSavedCount() {
        guard !childId.isEmpty else { return }
        defaults.set(state.savedCount, forKey: storageKey)
    }

    private func recordActivity() {
        guard let planner = adaptivePlanner, !childId.isEmpty,
              let selectedId = state.selectedId else { return }
        let sound = state.cards.first { $0.id == selectedId }
            .map { String($0.label.prefix(1)).uppercased() } ?? "С"
        Task { [weak self] in
            guard let self else { return }
            await planner.recordItemOutcome(
                childId: self.childId,
                itemId: "storyEnding-\(selectedId)",
                sound: sound,
                correct: true
            )
        }
    }
}
