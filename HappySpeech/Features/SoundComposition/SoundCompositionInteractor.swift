import Foundation
import OSLog

// MARK: - SoundCompositionBusinessLogic

@MainActor
protocol SoundCompositionBusinessLogic: AnyObject {
    func start(_ request: SoundCompositionModels.Start.Request) async
    func playWord()
    func playActiveSound()
    func placeChip(_ request: SoundCompositionModels.PlaceChip.Request)
    func beginPlacing()
    func enterSynthesis()
    func playSynthesis()
    func chooseBonus(_ request: SoundCompositionModels.Bonus.Request)
    func advanceWord() async
    func cancel()
}

// MARK: - SoundCompositionInteractor
//
// Бизнес-логика «Мастерской звукового состава».
//   • start          — собирает сессию слов через `SoundCompositionBuilder`
//                       по возрасту ребёнка; шлёт первое слово.
//   • playWord        — протяжная озвучка слова целиком (LessonVoiceWorker).
//   • playActiveSound — изолированная озвучка текущего звука (фонема).
//   • placeChip       — проверяет цвет фишки против эльконинского типа звука;
//                       верно → ставит фишку, двигает активный звук; неверно →
//                       мягкая подсказка + повтор изолированного звука (без «неправильно»).
//   • enterSynthesis  — слово собрано → шаг 3 (синтез + бонус).
//   • playSynthesis   — последовательная озвучка звуков + слово целиком (слияние).
//   • chooseBonus     — проверяет вариант цепочки замены первого звука.
//   • advanceWord     — следующее слово или завершение сессии.
//
// Скоринг: доля верно собранных слов БЕЗ ошибок цвета. Ошибка цвета снижает
// «чистоту» слова, но errorless — слово всё равно собирается до конца.
// Результат сохраняется в `AdaptivePlannerService` (SM-2 + пословный outcome).

@MainActor
final class SoundCompositionInteractor: SoundCompositionBusinessLogic {

    // MARK: - VIP

    var presenter: (any SoundCompositionPresentationLogic)?

    // MARK: - Deps

    private let childId: String
    private let childAge: Int
    private let builder: SoundCompositionBuilder
    private let voice: LessonVoiceWorker
    private let adaptivePlanner: (any AdaptivePlannerService)?
    /// Тестовый seam: если задано — используется вместо загрузки пака
    /// (детерминированные сессии в юнит-тестах). В проде всегда nil.
    private let seededWords: [SoundCompositionWord]?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SoundCompositionInteractor")

    // MARK: - Tunables

    private static let wordsPerSession = 6

    // MARK: - State

    private var words: [SoundCompositionWord] = []
    private var wordIndex: Int = 0
    private var activeSoundIndex: Int = 0
    /// Слово собрано без единой ошибки цвета.
    private var wordHadError: Bool = false
    private var cleanWordCount: Int = 0
    private var completedWordCount: Int = 0
    private var isFinished: Bool = false

    private var speakTask: Task<Void, Never>?

    // MARK: - Init

    init(
        childId: String,
        childAge: Int,
        builder: SoundCompositionBuilder,
        voice: LessonVoiceWorker = .shared,
        adaptivePlanner: (any AdaptivePlannerService)? = nil,
        seededWords: [SoundCompositionWord]? = nil
    ) {
        self.childId = childId
        self.childAge = max(5, min(childAge, 8))
        self.builder = builder
        self.voice = voice
        self.adaptivePlanner = adaptivePlanner
        self.seededWords = seededWords
    }

    deinit {
        speakTask?.cancel()
    }

    // MARK: - start

    func start(_ request: SoundCompositionModels.Start.Request) async {
        if let seededWords {
            words = seededWords
        } else {
            let all = builder.loadWords()
            words = builder.buildSession(from: all, age: childAge, count: Self.wordsPerSession)
        }
        wordIndex = 0
        activeSoundIndex = 0
        wordHadError = false
        cleanWordCount = 0
        completedWordCount = 0
        isFinished = false
        logger.info("start child=\(self.childId, privacy: .public) words=\(self.words.count, privacy: .public)")
        presenter?.presentStart(SoundCompositionModels.Start.Response(words: words))
    }

    // MARK: - playWord (протяжно, слово целиком)

    func playWord() {
        guard let word = currentWord else { return }
        speak(word.text, soundIndexReset: false)
    }

    // MARK: - playActiveSound (изолированный звук)

    func playActiveSound() {
        guard let word = currentWord,
              word.sounds.indices.contains(activeSoundIndex) else { return }
        let letter = word.sounds[activeSoundIndex].letter
        speak(letter.lowercased(), soundIndexReset: false)
    }

    // MARK: - beginPlacing (шаг 1 → шаг 2)

    func beginPlacing() {
        guard let word = currentWord else { return }
        activeSoundIndex = 0
        wordHadError = false
        // Сразу подсветим первый активный звук и проиграем его изолированно.
        presenter?.presentPlaceChip(
            SoundCompositionModels.PlaceChip.Response(
                isCorrect: true,                 // нейтральный «вход» без оценки
                soundIndex: -1,                  // ничего ещё не поставлено
                correctType: word.sounds[0].type,
                letter: word.sounds[0].letter,
                isWordComplete: false
            ),
            allSounds: word.sounds
        )
        playActiveSound()
    }

    // MARK: - placeChip (проверка цвета фишки)

    func placeChip(_ request: SoundCompositionModels.PlaceChip.Request) {
        guard !isFinished, let word = currentWord,
              word.sounds.indices.contains(activeSoundIndex) else { return }
        let expected = word.sounds[activeSoundIndex].type
        let letter = word.sounds[activeSoundIndex].letter
        let isCorrect = request.chosenType == expected

        if isCorrect {
            let placedIndex = activeSoundIndex
            activeSoundIndex += 1
            let isComplete = activeSoundIndex >= word.sounds.count
            presenter?.presentPlaceChip(
                SoundCompositionModels.PlaceChip.Response(
                    isCorrect: true,
                    soundIndex: placedIndex,
                    correctType: expected,
                    letter: letter,
                    isWordComplete: isComplete
                ),
                allSounds: word.sounds
            )
            logger.info("placeChip OK idx=\(placedIndex, privacy: .public) complete=\(isComplete, privacy: .public)")
        } else {
            wordHadError = true
            // Мягкая подсказка + повтор изолированного звука.
            presenter?.presentPlaceChip(
                SoundCompositionModels.PlaceChip.Response(
                    isCorrect: false,
                    soundIndex: activeSoundIndex,
                    correctType: expected,
                    letter: letter,
                    isWordComplete: false
                ),
                allSounds: word.sounds
            )
            playActiveSound()
            logger.info("placeChip soft-hint idx=\(self.activeSoundIndex, privacy: .public)")
        }
    }

    // MARK: - enterSynthesis (шаг 3)

    func enterSynthesis() {
        guard let word = currentWord else { return }
        completedWordCount += 1
        if !wordHadError { cleanWordCount += 1 }
        let chips = word.sounds.map { PlacedChip(letter: $0.letter, type: $0.type) }
        presenter?.presentSynthesis(SoundCompositionModels.Synthesis.Response(word: word, chips: chips))
    }

    // MARK: - playSynthesis (слияние звуков → слово)

    func playSynthesis() {
        guard let word = currentWord else { return }
        speakTask?.cancel()
        voice.stop()
        presenter?.presentPlaying(true)
        speakTask = Task { @MainActor [weak self] in
            guard let self else { return }
            // Звуки по очереди.
            for sound in word.sounds {
                if Task.isCancelled || self.isFinished { break }
                await self.voice.speak(sound.letter.lowercased(), lessonType: "sound_composition")
            }
            // Слово целиком — синтез.
            if !Task.isCancelled, !self.isFinished {
                await self.voice.speak(word.text, lessonType: "sound_composition")
            }
            guard !Task.isCancelled, !self.isFinished else { return }
            self.presenter?.presentPlaying(false)
            self.speakTask = nil
        }
    }

    // MARK: - chooseBonus (цепочка замены первого звука)

    func chooseBonus(_ request: SoundCompositionModels.Bonus.Request) {
        guard let word = currentWord, let chain = word.chain,
              chain.variants.indices.contains(request.variantIndex) else { return }
        let variant = chain.variants[request.variantIndex]
        // Целевой вариант — первый (его просит Ляля в подсказке).
        let isCorrect = request.variantIndex == 0
        presenter?.presentBonus(SoundCompositionModels.Bonus.Response(
            variantIndex: request.variantIndex,
            isCorrect: isCorrect,
            resultWord: variant.text
        ))
        if isCorrect {
            speak(variant.text, soundIndexReset: false)
        }
    }

    // MARK: - advanceWord

    func advanceWord() async {
        guard !isFinished else { return }
        await recordWordOutcome()
        let next = wordIndex + 1
        if next >= words.count {
            await complete()
            return
        }
        wordIndex = next
        activeSoundIndex = 0
        wordHadError = false
        let word = words[wordIndex]
        presenter?.presentLoadWord(SoundCompositionModels.LoadWord.Response(
            word: word,
            wordIndex: wordIndex,
            totalWords: words.count
        ))
    }

    // MARK: - complete

    private func complete() async {
        guard !isFinished else { return }
        isFinished = true
        voice.stop()
        let total = max(words.count, 1)
        let score = min(max(Float(cleanWordCount) / Float(total), 0), 1)
        logger.info("complete clean=\(self.cleanWordCount, privacy: .public)/\(total, privacy: .public) score=\(score, privacy: .public)")
        await recordSession(score: score)
        presenter?.presentComplete(SoundCompositionModels.Complete.Response(
            wordsCompleted: completedWordCount,
            totalWords: words.count,
            score: score
        ))
    }

    // MARK: - cancel

    func cancel() {
        isFinished = true
        speakTask?.cancel()
        speakTask = nil
        voice.stop()
        logger.info("SoundComposition cancelled")
    }

    // MARK: - Persistence

    private func recordWordOutcome() async {
        guard let word = currentWord, let planner = adaptivePlanner else { return }
        await planner.recordItemOutcome(
            childId: childId,
            itemId: word.id,
            sound: word.sounds.first?.letter ?? "",
            correct: !wordHadError
        )
    }

    private func recordSession(score: Float) async {
        guard let planner = adaptivePlanner else { return }
        let quality = SM2Quality.fromSuccessRate(Double(score))
        do {
            try await planner.recordSessionResult(
                childId: childId,
                soundTarget: "звуковой-анализ",
                qualityScore: quality
            )
        } catch {
            logger.error("recordSessionResult failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Helpers

    private var currentWord: SoundCompositionWord? {
        words.indices.contains(wordIndex) ? words[wordIndex] : nil
    }

    private func speak(_ text: String, soundIndexReset: Bool) {
        guard !text.isEmpty else { return }
        speakTask?.cancel()
        voice.stop()
        presenter?.presentPlaying(true)
        speakTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.voice.speak(text, lessonType: "sound_composition")
            guard !Task.isCancelled, !self.isFinished else { return }
            self.presenter?.presentPlaying(false)
            self.speakTask = nil
        }
    }

    // MARK: - Test seams

    /// Доля «чистых» слов (для тестов и расчётов).
    var cleanFraction: Double {
        words.isEmpty ? 0 : Double(cleanWordCount) / Double(words.count)
    }
}
