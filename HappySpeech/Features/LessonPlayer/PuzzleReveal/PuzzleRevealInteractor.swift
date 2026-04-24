import Foundation
import OSLog

// MARK: - PuzzleRevealBusinessLogic

@MainActor
protocol PuzzleRevealBusinessLogic: AnyObject {
    func loadPuzzle(_ request: PuzzleRevealModels.LoadPuzzle.Request)
    func startRecord(_ request: PuzzleRevealModels.StartRecord.Request)
    func stopRecord(_ request: PuzzleRevealModels.StopRecord.Request)
    func nextPuzzle(_ request: PuzzleRevealModels.NextPuzzle.Request)
    func complete(_ request: PuzzleRevealModels.Complete.Request)
    func cancel()
}

// MARK: - PuzzleRevealInteractor
//
// Бизнес-логика «Сложи пазл»:
//   1) `loadPuzzle` — достаёт PuzzleItem для текущего `puzzleIndex` из каталога
//      по soundGroup, формирует 9 свежих плиток и отправляет Response.
//   2) `startRecord` — запускает AudioService.startRecording() (если ASR есть)
//      и переводит фазу в .recording.
//   3) `stopRecord` — останавливает запись, считает score:
//       • с ASR: через ASRService.transcribe и overlap с target word;
//       • fallback: Float.random(0.65...0.95) — детская мотивационная шкала.
//      Дальше вызывает revealTile.
//   4) `revealTile(score:)` — открывает очередную (следующую закрытую) плитку,
//      обновляет счётчик attemptNumber, а когда все 9 открыты — переводит
//      фазу в .puzzleComplete.
//   5) `nextPuzzle` — инкрементит puzzleIndex, либо (если дошли до 5) вызывает
//      complete.
//   6) `complete` — считает averageScore по всем открытым плиткам всех пазлов,
//      выдаёт 1–3 звёзды.

@MainActor
final class PuzzleRevealInteractor: PuzzleRevealBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any PuzzleRevealPresentationLogic)?
    var router: (any PuzzleRevealRoutingLogic)?

    private let container: AppContainer
    private let logger = Logger(subsystem: "ru.happyspeech", category: "PuzzleRevealInteractor")

    // MARK: - Config

    static let tileCount: Int = 9
    static let totalPuzzles: Int = 5
    private static let revealDelay: Duration = .milliseconds(800)

    // MARK: - Session state

    private var activity: SessionActivity?
    private var soundGroup: String = ""
    private var puzzles: [PuzzleItem] = []
    private var currentPuzzleIndex: Int = 0
    private var currentTiles: [PuzzleTile] = []
    private var attemptNumber: Int = 0                    // 1..9 — следующая плитка
    private var allRevealScores: [Float] = []             // накопленные scores за всю сессию
    private var isASRAvailable: Bool = false
    private var isRecording: Bool = false
    private var asrTask: Task<Void, Never>?
    private var advanceTask: Task<Void, Never>?

    // MARK: - Init

    init(container: AppContainer) {
        self.container = container
    }

    // MARK: - Puzzle catalog
    //
    // 4 группы × 5 пазлов. Emoji подбираются так, чтобы визуал был понятен
    // ребёнку 5–8 лет, но не обязательно буквально совпадал со словом —
    // это подсказка, а не тест.

    private let puzzleCatalog: [String: [PuzzleItem]] = [
        "whistling": [
            PuzzleItem(word: "самолёт", emoji: "✈️",  soundGroup: "whistling",
                       hintText: String(localized: "Произнеси слово с буквой «С»")),
            PuzzleItem(word: "зебра",   emoji: "🦓", soundGroup: "whistling",
                       hintText: String(localized: "Произнеси слово с буквой «З»")),
            PuzzleItem(word: "цапля",   emoji: "🦢", soundGroup: "whistling",
                       hintText: String(localized: "Произнеси слово с буквой «Ц»")),
            PuzzleItem(word: "слон",    emoji: "🐘", soundGroup: "whistling",
                       hintText: String(localized: "Произнеси слово с буквой «С»")),
            PuzzleItem(word: "заяц",    emoji: "🐇", soundGroup: "whistling",
                       hintText: String(localized: "Произнеси слово с буквой «З»"))
        ],
        "hissing": [
            PuzzleItem(word: "шапка",   emoji: "🧢", soundGroup: "hissing",
                       hintText: String(localized: "Произнеси слово с буквой «Ш»")),
            PuzzleItem(word: "жираф",   emoji: "🦒", soundGroup: "hissing",
                       hintText: String(localized: "Произнеси слово с буквой «Ж»")),
            PuzzleItem(word: "чайник",  emoji: "🫖", soundGroup: "hissing",
                       hintText: String(localized: "Произнеси слово с буквой «Ч»")),
            PuzzleItem(word: "щука",    emoji: "🐟", soundGroup: "hissing",
                       hintText: String(localized: "Произнеси слово с буквой «Щ»")),
            PuzzleItem(word: "кошка",   emoji: "🐱", soundGroup: "hissing",
                       hintText: String(localized: "Произнеси слово с буквой «Ш»"))
        ],
        "sonants": [
            PuzzleItem(word: "ракета",  emoji: "🚀", soundGroup: "sonants",
                       hintText: String(localized: "Произнеси слово с буквой «Р»")),
            PuzzleItem(word: "лягушка", emoji: "🐸", soundGroup: "sonants",
                       hintText: String(localized: "Произнеси слово с буквой «Л»")),
            PuzzleItem(word: "рыба",    emoji: "🐠", soundGroup: "sonants",
                       hintText: String(localized: "Произнеси слово с буквой «Р»")),
            PuzzleItem(word: "лампа",   emoji: "💡", soundGroup: "sonants",
                       hintText: String(localized: "Произнеси слово с буквой «Л»")),
            PuzzleItem(word: "орёл",    emoji: "🦅", soundGroup: "sonants",
                       hintText: String(localized: "Произнеси слово с буквой «Р»"))
        ],
        "velar": [
            PuzzleItem(word: "кот",     emoji: "🐈", soundGroup: "velar",
                       hintText: String(localized: "Произнеси слово с буквой «К»")),
            PuzzleItem(word: "гусь",    emoji: "🦢", soundGroup: "velar",
                       hintText: String(localized: "Произнеси слово с буквой «Г»")),
            PuzzleItem(word: "хомяк",   emoji: "🐹", soundGroup: "velar",
                       hintText: String(localized: "Произнеси слово с буквой «Х»")),
            PuzzleItem(word: "кубик",   emoji: "🎲", soundGroup: "velar",
                       hintText: String(localized: "Произнеси слово с буквой «К»")),
            PuzzleItem(word: "горилла", emoji: "🦍", soundGroup: "velar",
                       hintText: String(localized: "Произнеси слово с буквой «Г»"))
        ]
    ]

    // MARK: - Lifecycle

    func cancel() {
        asrTask?.cancel()
        advanceTask?.cancel()
        asrTask = nil
        advanceTask = nil
    }

    // MARK: - loadPuzzle

    func loadPuzzle(_ request: PuzzleRevealModels.LoadPuzzle.Request) {
        self.activity = request.activity
        self.soundGroup = Self.resolveSoundGroup(for: request.activity.soundTarget)
        self.puzzles = puzzleCatalog[soundGroup] ?? puzzleCatalog["whistling"] ?? []
        self.currentPuzzleIndex = min(max(0, request.puzzleIndex), max(0, puzzles.count - 1))

        // Резервный puzzle, если вдруг каталог пуст (быть не должно).
        let item = puzzles.indices.contains(currentPuzzleIndex)
            ? puzzles[currentPuzzleIndex]
            : PuzzleItem(word: "мама", emoji: "❤️", soundGroup: soundGroup,
                         hintText: String(localized: "Произнеси слово"))

        currentTiles = (0..<Self.tileCount).map { idx in
            PuzzleTile(index: idx, isRevealed: false, revealScore: 0)
        }
        attemptNumber = 1
        isRecording = false
        isASRAvailable = container.asrService.isReady

        logger.info("loadPuzzle group=\(self.soundGroup, privacy: .public) index=\(self.currentPuzzleIndex, privacy: .public) word=\(item.word, privacy: .public) asrReady=\(self.isASRAvailable, privacy: .public)")

        presenter?.presentLoadPuzzle(.init(
            tiles: currentTiles,
            word: item.word,
            emoji: item.emoji,
            hintText: item.hintText,
            puzzleIndex: currentPuzzleIndex,
            totalPuzzles: Self.totalPuzzles,
            attemptNumber: attemptNumber,
            isASRAvailable: isASRAvailable
        ))
    }

    // MARK: - startRecord

    func startRecord(_ request: PuzzleRevealModels.StartRecord.Request) {
        guard !isRecording else { return }
        isRecording = true
        presenter?.presentStartRecord(.init())

        guard isASRAvailable else {
            // Без ASR — phase=.recording держится до нажатия «Я произнёс!»,
            // реальной записи нет. Выход — в stopRecord с fallback-score.
            return
        }

        let audioService = container.audioService
        asrTask?.cancel()
        asrTask = Task { @MainActor [weak self] in
            guard let self else { return }
            if !audioService.isPermissionGranted {
                let granted = await audioService.requestPermission()
                if !granted {
                    self.isASRAvailable = false
                    return
                }
            }
            do {
                try await audioService.startRecording()
            } catch {
                self.logger.error("startRecording failed: \(error.localizedDescription, privacy: .public)")
                self.isASRAvailable = false
            }
        }
    }

    // MARK: - stopRecord

    func stopRecord(_ request: PuzzleRevealModels.StopRecord.Request) {
        guard isRecording else { return }
        isRecording = false
        presenter?.presentStopRecord(.init())

        let targetWord = currentWord()

        guard isASRAvailable else {
            // Fallback — ребёнок всегда получает «хороший» score.
            let score = Float.random(in: 0.65...0.95)
            logger.info("stopRecord fallback score=\(score, privacy: .public)")
            revealNextTile(score: score)
            return
        }

        let audioService = container.audioService
        let asrService = container.asrService

        asrTask?.cancel()
        asrTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let url = try await audioService.stopRecording()
                let result = try await asrService.transcribe(url: url)
                let score = Self.score(transcript: result.transcript,
                                       target: targetWord,
                                       confidence: Float(result.confidence))
                self.logger.info("stopRecord asr transcript='\(result.transcript, privacy: .public)' target='\(targetWord, privacy: .public)' score=\(score, privacy: .public)")
                self.revealNextTile(score: score)
            } catch {
                self.logger.error("stopRecord asr failed: \(error.localizedDescription, privacy: .public)")
                let score = Float.random(in: 0.65...0.95)
                self.revealNextTile(score: score)
            }
        }
    }

    // MARK: - revealTile (internal)

    private func revealNextTile(score: Float) {
        // Индекс следующей закрытой плитки (линейно слева направо, сверху вниз).
        guard let targetIndex = currentTiles.firstIndex(where: { !$0.isRevealed }) else {
            return
        }
        currentTiles[targetIndex].isRevealed = true
        currentTiles[targetIndex].revealScore = score
        allRevealScores.append(score)

        let allRevealed = currentTiles.allSatisfy { $0.isRevealed }
        let response = PuzzleRevealModels.RevealTile.Response(
            tileIndex: currentTiles[targetIndex].index,
            score: score,
            tiles: currentTiles,
            allRevealed: allRevealed,
            attemptNumber: attemptNumber
        )
        presenter?.presentRevealTile(response)

        if allRevealed {
            // Плавный переход к следующему пазлу / финалу через небольшую задержку.
            advanceTask?.cancel()
            advanceTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: Self.revealDelay)
                guard let self else { return }
                self.nextPuzzle(.init())
            }
        } else {
            attemptNumber = min(Self.tileCount, attemptNumber + 1)
        }
    }

    // MARK: - nextPuzzle

    func nextPuzzle(_ request: PuzzleRevealModels.NextPuzzle.Request) {
        let nextIndex = currentPuzzleIndex + 1
        let hasNext = nextIndex < Self.totalPuzzles && nextIndex < puzzles.count

        presenter?.presentNextPuzzle(.init(hasNext: hasNext))

        if hasNext, let activity {
            loadPuzzle(.init(activity: activity, puzzleIndex: nextIndex))
        } else {
            complete(.init())
        }
    }

    // MARK: - complete

    func complete(_ request: PuzzleRevealModels.Complete.Request) {
        let total = allRevealScores.reduce(Float(0), +)
        let avg = allRevealScores.isEmpty ? 0 : total / Float(allRevealScores.count)
        let stars = Self.stars(for: avg)

        logger.info("complete avg=\(avg, privacy: .public) stars=\(stars, privacy: .public) attempts=\(self.allRevealScores.count, privacy: .public)")

        presenter?.presentComplete(.init(
            averageScore: avg,
            starsEarned: stars
        ))
    }

    // MARK: - Helpers

    private func currentWord() -> String {
        guard puzzles.indices.contains(currentPuzzleIndex) else { return "" }
        return puzzles[currentPuzzleIndex].word
    }

    /// Простой scoring: точное совпадение — 1.0; совпадение первых двух букв — 0.7;
    /// любая непустая транскрипция — 0.5; пустая — 0.3 с подмешанным confidence.
    private static func score(transcript: String, target: String, confidence: Float) -> Float {
        let t = transcript
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let target = target.lowercased()
        guard !target.isEmpty else { return min(max(confidence, 0), 1) }

        if t == target { return 1.0 }
        if t.hasPrefix(target.prefix(2)) { return 0.7 }
        if !t.isEmpty { return max(0.5, confidence * 0.8) }
        return max(0.3, confidence * 0.5)
    }

    private static func stars(for score: Float) -> Int {
        switch score {
        case ..<0.5: return 1
        case 0.5..<0.8: return 2
        default: return 3
        }
    }

    /// Согласовано с `ARActivityView.resolveSoundGroup(for:)`.
    static func resolveSoundGroup(for targetSound: String) -> String {
        let upper = targetSound.uppercased()
        let firstLetter = upper.prefix(1)
        switch firstLetter {
        case "С", "З", "Ц":
            return "whistling"
        case "Ш", "Ж", "Ч", "Щ":
            return "hissing"
        case "Р", "Л":
            return "sonants"
        case "К", "Г", "Х":
            return "velar"
        default:
            return "whistling"
        }
    }
}
