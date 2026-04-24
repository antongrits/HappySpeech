import Foundation
import AVFoundation
import OSLog

// MARK: - BingoBusinessLogic

@MainActor
protocol BingoBusinessLogic: AnyObject {
    func loadGame(_ request: BingoModels.LoadGame.Request)
    func callNextWord()
    func markCell(_ request: BingoModels.MarkCell.Request)
    func completeGame()
    func cancel()
}

// MARK: - BingoInteractor
//
// Бизнес-логика «Бинго»:
//   1) `loadGame` — выбирает 25 слов из каталога по `activity.soundTarget`,
//      перемешивает их, формирует поле и очередь зачитывания, шлёт первое
//      Response в Presenter.
//   2) `callNextWord` — берёт следующее слово, озвучивает через
//      AVSpeechSynthesizer (ru-RU), даёт ребёнку 5 с на ответ, после чего
//      автоматически переходит к следующему.
//   3) `markCell` — помечает клетку, проверяет 12 линий бинго.
//      Если линия собрана — фаза переходит в .bingo, начисляется бонусный
//      score; если все 25 клеток помечены — игра завершена.
//   4) `completeGame` — считает финальный score (hitRate), вызывает Presenter.
//
// AVSpeechSynthesizer хранится как instance-var, чтобы система не освобождала
// его до завершения речи (типичная ловушка с локальной переменной).

@MainActor
final class BingoInteractor: NSObject, BingoBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any BingoPresentationLogic)?
    var router: (any BingoRoutingLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "BingoInteractor")

    // MARK: - TTS

    private let synthesizer = AVSpeechSynthesizer()
    private static let voiceLocale = "ru-RU"
    private static let utteranceRate: Float = 0.45        // чуть медленнее обычного
    private static let utteranceVolume: Float = 1.0
    private static let pitchMultiplier: Float = 1.05
    private static let autoAdvanceDelay: Duration = .seconds(5)

    // MARK: - Game state

    private var cells: [BingoCell] = []
    private var wordQueue: [String] = []
    private var calledIndex: Int = 0      // кол-во уже вызванных слов
    private var totalWords: Int = 0
    private var bingoAchieved: Bool = false
    private var bingoLines: [BingoLine] = []
    private var isGameOver: Bool = false

    private var advanceTask: Task<Void, Never>?

    // MARK: - Word catalog
    //
    // Каталог слов разбит по soundGroup (resolveSoundGroup из ARActivityView).
    // Минимум 30 слов в каждой группе (см. требования M6.5c).

    private let wordCatalog: [String: [String]] = [
        "whistling": [
            "сани", "сова", "коса", "сосна", "зима", "зебра", "зонт", "ваза", "цапля", "цветок",
            "солнце", "стол", "самолёт", "собака", "слон", "заяц", "замок", "звезда",
            "сумка", "сом", "сыр", "снег", "сок", "санки", "роза", "лиса", "глаз", "коза",
            "месяц", "кольцо"
        ],
        "hissing": [
            "шапка", "шуба", "кошка", "машина", "жук", "ёж", "пижама", "лыжи", "чашка", "чайник",
            "ключ", "мяч", "щука", "щётка", "ящик", "овощи", "туча", "дача",
            "шар", "шкаф", "карандаш", "мышка", "лошадь", "жираф", "ножи", "лужа", "часы",
            "мальчик", "плащ", "клещи"
        ],
        "sonants": [
            "рыба", "рак", "ракета", "корова", "забор", "мухомор", "лампа", "лодка", "стол",
            "волк", "белка", "орёл", "лягушка", "крокодил", "тарелка", "молоко",
            "руль", "роза", "топор", "ведро", "перо", "рысь", "мел", "лук", "лимон",
            "клоун", "облако", "пила", "журавль", "дятел"
        ],
        "velar": [
            "кот", "кубик", "рука", "окно", "гусь", "нога", "горка", "губы", "хлеб", "муха",
            "петух", "горох", "кухня", "кактус", "бегемот",
            "ключ", "куст", "крот", "коза", "кран", "гриб", "город", "галка", "глаза",
            "хобот", "хвост", "хомяк", "пастух", "потолок", "колокольчик"
        ]
    ]

    // MARK: - Lifecycle

    deinit {
        advanceTask?.cancel()
    }

    // MARK: - loadGame

    func loadGame(_ request: BingoModels.LoadGame.Request) {
        let group = Self.resolveSoundGroup(for: request.activity.soundTarget)
        let chosenWords = pickWords(forGroup: group, needed: 25)

        // Поле и очередь — две независимые перестановки одного и того же набора.
        let shuffledForGrid = chosenWords.shuffled()
        let shuffledForCalls = chosenWords.shuffled()

        cells = shuffledForGrid.map { word in
            BingoCell(
                id: UUID(),
                word: word,
                soundGroup: group,
                isMarked: false,
                isWinner: false
            )
        }
        wordQueue = shuffledForCalls
        calledIndex = 0
        totalWords = wordQueue.count
        bingoAchieved = false
        bingoLines = []
        isGameOver = false

        logger.info("loadGame group=\(group, privacy: .public) cells=\(self.cells.count, privacy: .public) queue=\(self.totalWords, privacy: .public)")

        presenter?.presentLoadGame(BingoModels.LoadGame.Response(
            cells: cells,
            totalWords: totalWords,
            firstWord: nil
        ))

        // После короткой паузы — первое слово.
        scheduleNextCall(after: .milliseconds(700))
    }

    // MARK: - callNextWord

    func callNextWord() {
        guard !isGameOver else { return }
        guard calledIndex < wordQueue.count else {
            // Все слова прочитаны — авто-завершение.
            logger.info("queue exhausted — completing game")
            completeGame()
            return
        }
        let word = wordQueue[calledIndex]
        calledIndex += 1

        logger.info("callNextWord index=\(self.calledIndex, privacy: .public)/\(self.totalWords, privacy: .public) word=\(word, privacy: .public)")

        presenter?.presentCallWord(BingoModels.CallWord.Response(
            word: word,
            index: calledIndex,
            total: totalWords
        ))

        speak(word: word)

        // Автопереход к следующему слову, если ребёнок не отреагирует.
        scheduleNextCall(after: Self.autoAdvanceDelay)
    }

    // MARK: - markCell

    func markCell(_ request: BingoModels.MarkCell.Request) {
        guard !isGameOver else { return }
        guard let idx = cells.firstIndex(where: { $0.id == request.cellId }) else {
            logger.error("markCell: unknown cellId")
            return
        }
        guard !cells[idx].isMarked else { return }    // повторное нажатие — игнор

        cells[idx].isMarked = true
        logger.info("markCell idx=\(idx, privacy: .public) word=\(self.cells[idx].word, privacy: .public)")

        // Проверяем 12 линий.
        let newLines = checkBingo()
        let bingoJustHappened = !bingoAchieved && !newLines.isEmpty

        if bingoJustHappened {
            bingoAchieved = true
            bingoLines = newLines
            // Подсвечиваем выигрышные клетки.
            let winnerIndices = Set(newLines.flatMap { $0 })
            for winnerIdx in winnerIndices {
                cells[winnerIdx].isWinner = true
            }
            logger.info("BINGO! lines=\(newLines.count, privacy: .public)")
        }

        let allMarked = cells.allSatisfy(\.isMarked)

        presenter?.presentMarkCell(BingoModels.MarkCell.Response(
            cells: cells,
            bingoLines: bingoJustHappened ? newLines : [],
            allMarked: allMarked
        ))

        // Если все клетки помечены — авто-завершение игры.
        if allMarked {
            completeGame()
        }
    }

    // MARK: - completeGame

    func completeGame() {
        guard !isGameOver else { return }
        isGameOver = true
        advanceTask?.cancel()
        advanceTask = nil
        synthesizer.stopSpeaking(at: .immediate)

        let markedCount = cells.filter(\.isMarked).count
        let totalCount = max(cells.count, 1)
        let hitRate = Float(markedCount) / Float(totalCount)
        // Если бинго было — финальный score не ниже 0.7 (поощрение).
        var score = hitRate
        if bingoAchieved {
            score = max(score, 0.7)
        }
        score = min(max(score, 0), 1)

        logger.info("completeGame marked=\(markedCount, privacy: .public)/\(totalCount, privacy: .public) bingo=\(self.bingoAchieved, privacy: .public) score=\(score, privacy: .public)")

        presenter?.presentCompleteGame(BingoModels.CompleteGame.Response(
            score: score,
            bingoAchieved: bingoAchieved,
            markedCells: markedCount,
            totalCells: totalCount
        ))
    }

    // MARK: - cancel

    func cancel() {
        isGameOver = true
        advanceTask?.cancel()
        advanceTask = nil
        synthesizer.stopSpeaking(at: .immediate)
        logger.info("Bingo cancelled")
    }

    // MARK: - Bingo line check

    /// Возвращает ВСЕ линии, в которых сейчас все 5 клеток помечены.
    /// Если бинго ещё не было — массив пустой.
    func checkBingo() -> [BingoLine] {
        BingoLineCatalog.allLines.filter { line in
            line.allSatisfy { idx in
                guard cells.indices.contains(idx) else { return false }
                return cells[idx].isMarked
            }
        }
    }

    // MARK: - Word picking

    /// Выбирает `needed` слов из каталога: сперва из целевой группы, при нехватке —
    /// добирает из остальных. Гарантирует уникальность и корректное число клеток.
    private func pickWords(forGroup group: String, needed: Int) -> [String] {
        var primary = (wordCatalog[group] ?? []).shuffled()
        if primary.count >= needed {
            return Array(primary.prefix(needed))
        }
        // Добираем из других групп.
        let others = wordCatalog
            .filter { $0.key != group }
            .flatMap { $0.value }
            .shuffled()
        for word in others where !primary.contains(word) {
            primary.append(word)
            if primary.count >= needed { break }
        }
        // На крайний случай — повторяем последнее, чтобы поле было полным.
        while primary.count < needed, let last = primary.last {
            primary.append(last)
        }
        return Array(primary.prefix(needed))
    }

    // MARK: - TTS helpers

    private func speak(word: String) {
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.voiceLocale)
        utterance.rate = Self.utteranceRate
        utterance.volume = Self.utteranceVolume
        utterance.pitchMultiplier = Self.pitchMultiplier
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0.1

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        synthesizer.speak(utterance)
    }

    /// Планирует автоматический переход к следующему слову.
    private func scheduleNextCall(after delay: Duration) {
        advanceTask?.cancel()
        advanceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self else { return }
            if Task.isCancelled { return }
            guard !self.isGameOver else { return }
            self.callNextWord()
        }
    }

    // MARK: - Sound group resolution

    /// Определяет группу звуков по целевой букве.
    /// Согласовано с `ARActivityView.resolveSoundGroup`.
    static func resolveSoundGroup(for targetSound: String) -> String {
        let firstLetter = targetSound.uppercased().prefix(1)
        switch firstLetter {
        case "С", "З", "Ц":      return "whistling"
        case "Ш", "Ж", "Ч", "Щ": return "hissing"
        case "Р", "Л":           return "sonants"
        case "К", "Г", "Х":      return "velar"
        default:                  return "whistling"
        }
    }
}
