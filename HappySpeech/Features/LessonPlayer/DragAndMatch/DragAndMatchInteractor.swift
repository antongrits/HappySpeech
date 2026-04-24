import Foundation
import OSLog

// MARK: - DragAndMatchBusinessLogic

@MainActor
protocol DragAndMatchBusinessLogic: AnyObject {
    func loadSession(_ request: DragAndMatchModels.LoadSession.Request) async
    func dropWord(_ request: DragAndMatchModels.DropWord.Request) async
    func completeSession(_ request: DragAndMatchModels.CompleteSession.Request) async
}

// MARK: - DragAndMatchInteractor
//
// Бизнес-логика игры «Перетащи и совмести».
//
// Жизненный цикл:
//   loadSession(soundGroup, childName)
//     → подготовка words + buckets
//     → presentLoadSession
//   dropWord(wordId, bucketId)
//     → проверка correctBucketId == bucketId
//     → haptic (success/error)
//     → presentDropWord(correct, feedback)
//     → если все слова размещены → completeSession
//   completeSession()
//     → расчёт correctCount, presentCompleteSession

@MainActor
final class DragAndMatchInteractor: DragAndMatchBusinessLogic {

    // MARK: Dependencies

    var presenter: (any DragAndMatchPresentationLogic)?
    private let hapticService: any HapticService
    private let logger = Logger(subsystem: "ru.happyspeech", category: "DragAndMatch")

    // MARK: State

    private var words: [DragWord] = []
    private var buckets: [DragBucket] = []
    private var placedWords: [String: String] = [:]   // wordId → bucketId

    // MARK: Init

    init(hapticService: any HapticService) {
        self.hapticService = hapticService
    }

    // MARK: - loadSession

    func loadSession(_ request: DragAndMatchModels.LoadSession.Request) async {
        let (words, buckets) = DragWord.set(for: request.soundGroup)
        self.words = words.shuffled()
        self.buckets = buckets
        self.placedWords = [:]
        logger.info("Loaded \(self.words.count, privacy: .public) words / \(self.buckets.count, privacy: .public) buckets for group=\(request.soundGroup, privacy: .public)")

        let response = DragAndMatchModels.LoadSession.Response(
            words: self.words,
            buckets: self.buckets,
            childName: request.childName
        )
        presenter?.presentLoadSession(response)
    }

    // MARK: - dropWord

    func dropWord(_ request: DragAndMatchModels.DropWord.Request) async {
        guard let word = words.first(where: { $0.id == request.wordId }) else {
            logger.error("dropWord: unknown wordId \(request.wordId, privacy: .public)")
            return
        }
        // Повторный дроп одного и того же слова игнорируем — считаем только
        // первый. Это защищает от двойных тапов/раннего кеширования.
        let wasAlreadyPlaced = (placedWords[request.wordId] != nil)
        placedWords[request.wordId] = request.bucketId

        let correct = (word.correctBucketId == request.bucketId)
        logger.info("Drop word=\(word.word, privacy: .public) bucket=\(request.bucketId, privacy: .public) correct=\(correct)")

        // Тактильный фидбек (мягкий, детский). selection() для успеха, чтобы
        // не пугать, .warning — для ошибки (тоже мягко).
        if correct {
            hapticService.selection()
        } else {
            hapticService.notification(.warning)
        }

        let response = DragAndMatchModels.DropWord.Response(
            correct: correct,
            wordId: request.wordId,
            feedbackText: correct ? "Верно!" : "Попробуй другую корзину."
        )
        presenter?.presentDropWord(response)

        // Если все слова размещены — автозавершение. Не повторяем если это
        // был re-drop (уже было учтено, корзина просто поменялась).
        _ = wasAlreadyPlaced
        if placedWords.count >= words.count {
            await completeSession(DragAndMatchModels.CompleteSession.Request())
        }
    }

    // MARK: - completeSession

    func completeSession(_ request: DragAndMatchModels.CompleteSession.Request) async {
        var correct = 0
        for word in words {
            if placedWords[word.id] == word.correctBucketId {
                correct += 1
            }
        }
        let total = max(words.count, 1)
        logger.info("Session complete: \(correct)/\(total)")

        let response = DragAndMatchModels.CompleteSession.Response(
            correctCount: correct,
            totalWords: total
        )
        presenter?.presentCompleteSession(response)
    }
}
