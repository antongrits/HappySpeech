import Foundation
import OSLog

// MARK: - TongueTwisterArenaInteractor

/// Бизнес-логика игры «Арена скороговорок».
///
/// Содержит реальный цикл записи: `toggleRecord` стартует/останавливает запись
/// через `AudioService`, распознаёт результат через `ASRService` и оценивает
/// произношение по перекрытию слов с целевой скороговоркой. Лучший результат
/// (звёзды) персистится в `UserDefaults` и фиксируется в планировщике повторов.
/// Без сервисов (Preview/тесты) запись недоступна — экран показывает контент.
@MainActor
@Observable
final class TongueTwisterArenaInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "TongueTwisterArena"
    )

    let childId: String
    var state: TongueTwisterArenaModels.ViewState = .initial

    private let audioService: (any AudioService)?
    private let asrService: (any ASRService)?
    private let adaptivePlanner: (any AdaptivePlannerService)?
    private let childRepository: (any ChildRepository)?
    private let defaults: UserDefaults

    private var childAge = 6

    init(
        childId: String,
        audioService: (any AudioService)? = nil,
        asrService: (any ASRService)? = nil,
        adaptivePlanner: (any AdaptivePlannerService)? = nil,
        childRepository: (any ChildRepository)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.childId = childId
        self.audioService = audioService
        self.asrService = asrService
        self.adaptivePlanner = adaptivePlanner
        self.childRepository = childRepository
        self.defaults = defaults
    }

    // MARK: - Load

    func load() async {
        var targets: [String] = []
        if let childRepository, !childId.isEmpty {
            do {
                let child = try await childRepository.fetch(id: childId)
                targets = child.targetSounds
                childAge = child.age
            } catch {
                Self.logger.error("child fetch failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        state.twisters = TongueTwisterContent.twisters(forTargetSounds: targets)
        state.bestStars = loadBestStars()
    }

    // MARK: - Selection

    func select(_ twister: TongueTwisterArenaModels.Twister) {
        state.selected = twister
        state.phase = .idle
        Self.logger.info("select twister \(twister.id, privacy: .public)")
    }

    func back() {
        state.selected = nil
        state.phase = .idle
    }

    // MARK: - Recording

    /// Признак доступности записи (есть аудио и ASR сервисы).
    var canRecord: Bool {
        audioService != nil && asrService != nil
    }

    func toggleRecord() {
        guard let twister = state.selected else { return }
        switch state.phase {
        case .recording:
            Task { [weak self] in await self?.finishRecording(twister: twister) }
        case .scoring:
            return
        default:
            startRecording()
        }
    }

    private func startRecording() {
        guard let audioService else { return }
        state.phase = .recording
        Task { [weak self] in
            guard let self else { return }
            do {
                try await audioService.startRecording()
            } catch {
                Self.logger.error("startRecording failed: \(error.localizedDescription, privacy: .public)")
                self.state.phase = .idle
            }
        }
    }

    private func finishRecording(twister: TongueTwisterArenaModels.Twister) async {
        guard let audioService, let asrService else {
            state.phase = .idle
            return
        }
        state.phase = .scoring
        do {
            let url = try await audioService.stopRecording()
            let result = try await asrService.transcribe(
                url: url,
                expectedWord: twister.text,
                childAge: childAge
            )
            let similarity = Self.similarity(transcript: result.transcript, target: twister.text)
            let stars = Self.stars(for: similarity)
            applyResult(twister: twister, stars: stars, similarity: similarity)
        } catch {
            Self.logger.error("finishRecording failed: \(error.localizedDescription, privacy: .public)")
            state.phase = .idle
        }
    }

    private func applyResult(
        twister: TongueTwisterArenaModels.Twister,
        stars: Int,
        similarity: Double
    ) {
        state.phase = .result(stars: stars, similarity: similarity)
        let previousBest = state.bestStars(for: twister.id)
        if stars > previousBest {
            state.bestStars[twister.id] = stars
            persistBestStars()
        }
        recordOutcome(twister: twister, correct: stars >= 2)
    }

    // MARK: - Scoring (pure)

    /// Доля слов целевой скороговорки, встретившихся в транскрипте (0…1).
    static func similarity(transcript: String, target: String) -> Double {
        let targetWords = tokens(target)
        guard !targetWords.isEmpty else { return 0 }
        let said = Set(tokens(transcript))
        let hit = targetWords.filter { said.contains($0) }.count
        return Double(hit) / Double(targetWords.count)
    }

    private static func tokens(_ s: String) -> [String] {
        s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }
    }

    static func stars(for similarity: Double) -> Int {
        switch similarity {
        case ..<0.4: return 1
        case 0.4..<0.75: return 2
        default: return 3
        }
    }

    // MARK: - Persistence

    private var storageKey: String { "tongueTwister.bestStars.\(childId)" }

    private func loadBestStars() -> [String: Int] {
        guard !childId.isEmpty,
              let raw = defaults.dictionary(forKey: storageKey) as? [String: Int] else {
            return [:]
        }
        return raw
    }

    private func persistBestStars() {
        guard !childId.isEmpty else { return }
        defaults.set(state.bestStars, forKey: storageKey)
    }

    private func recordOutcome(twister: TongueTwisterArenaModels.Twister, correct: Bool) {
        guard let planner = adaptivePlanner, !childId.isEmpty else { return }
        let sound = String(twister.targetSound.prefix(1)).uppercased()
        Task { [weak self] in
            guard let self else { return }
            await planner.recordItemOutcome(
                childId: self.childId,
                itemId: twister.id,
                sound: sound,
                correct: correct
            )
        }
    }
}
