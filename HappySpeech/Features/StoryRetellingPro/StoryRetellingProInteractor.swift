import Foundation
import OSLog

// MARK: - StoryRetellingProInteractor (Clean Swift: Interactor)
//
// Реальная активность пересказа: загрузка завершённости из Realm, запись
// пересказа, ASR-распознавание, скоринг покрытия фактов, персист. Без
// репозиториев (Preview) остаётся на нейтральном `.initial` (всё «не пройдено»).

@MainActor
@Observable
final class StoryRetellingProInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "StoryRetellingPro"
    )

    let childId: String
    var state: StoryRetellingProModels.ViewState

    private let worker: (any StoryRetellingProWorkerProtocol)?
    private var recordingStartedAt: Date?

    init(
        childId: String,
        worker: (any StoryRetellingProWorkerProtocol)? = nil
    ) {
        self.childId = childId
        self.worker = worker
        self.state = .initial
    }

    // MARK: - Load

    /// Восстанавливает реальную завершённость каждой сказки из Realm.
    func load() async {
        guard let worker, !childId.isEmpty else {
            state.isLoading = false
            return
        }
        let coverageByStory = await worker.loadCompletion(
            childId: childId,
            stories: state.stories
        )
        state.stories = state.stories.map { story in
            var updated = story
            let best = coverageByStory[story.id] ?? 0
            updated.bestCoverage = best
            updated.isCompleted = best >= StoryRetellingProModels.ViewState.passThreshold
            return updated
        }
        state.isLoading = false
        Self.logger.info("Loaded real completion for \(self.state.stories.count) stories")
    }

    // MARK: - Selection

    func select(_ id: String) {
        state.selectedStoryId = id
        state.phase = .browsing
        Self.logger.info("select story \(id, privacy: .public)")
    }

    // MARK: - Recording / scoring

    func startRecording() async {
        guard let worker, state.selectedStoryId != nil else { return }
        do {
            try await worker.startRecording()
            recordingStartedAt = Date()
            state.phase = .recording
        } catch {
            Self.logger.error("start recording failed: \(error.localizedDescription, privacy: .public)")
            state.phase = .browsing
        }
    }

    func stopAndScore() async {
        guard let worker,
              let storyId = state.selectedStoryId,
              let story = state.stories.first(where: { $0.id == storyId }) else { return }
        state.phase = .scoring
        let started = recordingStartedAt ?? Date()
        let (scoring, _) = await worker.stopRecordAndScore(
            story: story,
            childId: childId,
            startedAt: started
        )
        // Обновить завершённость из реального результата.
        state.stories = state.stories.map { item in
            guard item.id == storyId else { return item }
            var updated = item
            updated.bestCoverage = max(item.bestCoverage, scoring.coverage)
            updated.isCompleted = updated.bestCoverage >= StoryRetellingProModels.ViewState.passThreshold
            return updated
        }
        state.phase = .result(
            coverage: scoring.coverage,
            matched: scoring.matched,
            missed: scoring.missed
        )
        Self.logger.info("retelling result coverage=\(Int(scoring.coverage * 100), privacy: .public)%")
    }

    func backToBrowsing() {
        state.phase = .browsing
    }
}
