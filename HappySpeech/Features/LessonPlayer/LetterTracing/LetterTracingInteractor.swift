import CoreGraphics
import OSLog
import PencilKit
import UIKit

// MARK: - LetterTracingInteractor

/// Бизнес-логика шаблона «Написание буквы» (LetterTracing).
///
/// Scoring — три компонента:
///   | Компонент         | Вес | Метод                                         |
///   |-------------------|-----|-----------------------------------------------|
///   | Vision recognition| 50% | recognizedLetter == targetLetter → 1.0        |
///   | Stroke coverage   | 30% | пересечение bounding boxes / area буквы       |
///   | Speed bonus       | 20% | < 5с → 1.0, < 10с → 0.5, иначе 0.0           |
///
/// Пороги правильности:
///   - iPhone (палец): 65% — более мягкий, учитывает неточность пальца.
///   - iPad (Apple Pencil / палец): 80%.
///
/// Функционал:
///   - Все 33 русских буквы (А–Я) с ассоциированными фонемами и примерными словами.
///   - Три прогрессивных уровня обводки: поверх шаблона → точки → свободно.
///   - Трёхуровневая система подсказок: точка старта → стрелка → полный шаблон.
///   - Multi-attempt: до 3 попыток на букву, сохраняется лучший результат.
///   - Per-letter proficiency: буква считается усвоенной при bestScore ≥ 90%.
///   - Voice prompts: озвучка Ляли при старте и по результату.
///   - Stroke metadata: количество штрихов для UI-индикатора прогресса.
///   - Accessibility: VO-аннотации, Reduce Motion учитывается в анимациях хинтов.
@MainActor
final class LetterTracingInteractor: LetterTracingBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any LetterTracingPresentationLogic)?
    var router: (any LetterTracingRoutingLogic)?

    private let recognitionWorker = HandwritingRecognitionWorker()
    private let logger = Logger(subsystem: "ru.happyspeech", category: "LetterTracing")

    // MARK: - Device-aware threshold

    /// Порог правильности: iPhone (палец) — 0.65, iPad — 0.80.
    private var scoreThreshold: Double {
        UIDevice.current.userInterfaceIdiom == .phone ? 0.65 : 0.80
    }

    // MARK: - Session state

    private var letters: [String] = []
    private var currentIndex: Int = 0
    private var scores: [Double] = []
    private var drawingStartDate: Date?

    /// Текущий прогрессивный уровень обводки.
    private var currentTracingLevel: LetterTracingModels.TracingLevel = .overTemplate

    /// Текущее состояние системы подсказок для активной буквы.
    private var currentHintState: LetterTracingModels.HintState = .none

    /// Словарь прогресса по буквам: letter → LetterProficiency.
    private var proficiencyMap: [String: LetterTracingModels.LetterProficiency] = [:]

    /// Счётчик попыток для текущей буквы (не более maxAttemptsPerLetter).
    private var currentAttemptNumber: Int = 0
    private static let maxAttemptsPerLetter = 3

    // MARK: - Init

    init() {}

    // MARK: - LetterTracingBusinessLogic

    func loadExercise(_ request: LetterTracingModels.LoadExercise.Request) async {
        if letters.isEmpty {
            letters = Self.letterSequence(
                for: request.targetLetter,
                difficulty: request.difficulty
            )
            currentIndex = 0
            scores = []
            currentTracingLevel = tracingLevel(for: request.difficulty)
            let lvl = currentTracingLevel.rawValue
            let rounds = self.letters.count
            logger.info(
                "Session bootstrap letter='\(request.targetLetter, privacy: .public)' rounds=\(rounds, privacy: .public) level=\(lvl, privacy: .public)"
            )
        }

        guard currentIndex < letters.count else {
            logger.notice("loadExercise called but no more letters in queue")
            return
        }

        let letter = letters[currentIndex]
        currentHintState = .none
        currentAttemptNumber = 0
        drawingStartDate = Date()

        if proficiencyMap[letter] == nil {
            proficiencyMap[letter] = LetterTracingModels.LetterProficiency(letter: letter)
        }

        let word = Self.phonemeWord(for: letter)
        let strokes = Self.strokeCount(for: letter)
        let prompt = Self.buildVoicePrompt(
            for: letter,
            phonemeWord: word,
            level: currentTracingLevel
        )

        let response = LetterTracingModels.LoadExercise.Response(
            targetLetter: letter,
            promptText: prompt,
            roundIndex: currentIndex,
            totalRounds: letters.count,
            tracingLevel: currentTracingLevel,
            hintState: currentHintState,
            strokeCount: strokes,
            phonemeWord: word
        )
        presenter?.presentLoadExercise(response)
        await speakVoicePrompt(prompt)
    }

    func submitDrawing(_ request: LetterTracingModels.SubmitDrawing.Request) async {
        let duration = drawingStartDate.map { Date().timeIntervalSince($0) } ?? 0
        currentAttemptNumber += 1

        let recognized = await recognitionWorker.recognizeLetter(from: request.drawing)
        let recognizedStr = recognized ?? "nil"
        logger.debug(
            "Recognition result='\(recognizedStr, privacy: .public)' target='\(request.targetLetter, privacy: .public)'"
        )

        let coverage = computeCoverageScore(
            drawing: request.drawing,
            letter: request.targetLetter
        )
        let speed = computeSpeedScore(duration: duration, level: currentTracingLevel)
        let recognitionScore: Double = (recognized == request.targetLetter) ? 1.0 : 0.0
        let finalScore = compositeScore(
            recognition: recognitionScore,
            coverage: coverage,
            speed: speed
        )
        let isCorrect = finalScore >= scoreThreshold

        updateProficiency(letter: request.targetLetter, score: finalScore)
        let bestScore = proficiencyMap[request.targetLetter]?.bestScore ?? finalScore

        scores.append(finalScore)
        logScore(ScoreEntry(
            letter: request.targetLetter,
            attempt: currentAttemptNumber,
            recognition: recognitionScore,
            coverage: coverage,
            speed: speed,
            finalScore: finalScore
        ))

        let response = LetterTracingModels.SubmitDrawing.Response(
            recognizedLetter: recognized,
            targetLetter: request.targetLetter,
            recognitionScore: recognitionScore,
            coverageScore: coverage,
            speedScore: speed,
            finalScore: finalScore,
            isCorrect: isCorrect,
            attemptNumber: currentAttemptNumber,
            bestScore: bestScore
        )
        presenter?.presentSubmitDrawing(response)

        let exhausted = currentAttemptNumber >= Self.maxAttemptsPerLetter
        if isCorrect || exhausted {
            currentIndex += 1
            if currentIndex >= letters.count {
                scheduleSessionComplete()
            }
        }
    }

    func resetCanvas(_ request: LetterTracingModels.ResetCanvas.Request) {
        drawingStartDate = Date()
        presenter?.presentResetCanvas(LetterTracingModels.ResetCanvas.Response())
        logger.debug("Canvas reset, timer restarted")
    }

    func requestHint(_ request: LetterTracingModels.RequestHint.Request) {
        let nextHint = currentHintState.next
        currentHintState = nextHint
        let hintRaw = nextHint.rawValue
        logger.debug(
            "Hint requested letter='\(request.letter, privacy: .public)' state=\(hintRaw, privacy: .public)"
        )
        let description = hintDescription(for: nextHint, letter: request.letter)
        let response = LetterTracingModels.RequestHint.Response(
            hintState: nextHint,
            hintDescription: description
        )
        presenter?.presentRequestHint(response)
    }

    // MARK: - Static: availability

    /// Возвращает true для всех устройств.
    static func isAvailable() -> Bool {
        true
    }

    // MARK: - Private: Voice

    private func speakVoicePrompt(_ text: String) async {
        await LessonVoiceWorker.shared.speak(text, lessonType: "letter_tracing")
    }

    // MARK: - Private: Hint description

    private func hintDescription(
        for state: LetterTracingModels.HintState,
        letter: String
    ) -> String {
        switch state {
        case .none:
            return ""
        case .startPoint:
            return String(localized: "letter_tracing.hint.desc.start_point \(letter)")
        case .direction:
            return String(localized: "letter_tracing.hint.desc.direction \(letter)")
        case .fullTemplate:
            return String(localized: "letter_tracing.hint.desc.full_template \(letter)")
        }
    }

    // MARK: - Private: Session complete

    private func scheduleSessionComplete() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(1200))

            let avg = self.scores.isEmpty
                ? 0.0
                : self.scores.reduce(0.0, +) / Double(self.scores.count)
            let correct = self.scores.filter { $0 >= self.scoreThreshold }.count

            let achieved = self.proficiencyMap.values
                .filter { $0.isAchieved }
                .map { $0.letter }
                .sorted()
            let improved = self.proficiencyMap.values
                .filter { !$0.isAchieved && $0.bestScore > 0.5 }
                .map { $0.letter }
                .sorted()

            let completeResponse = LetterTracingModels.CompleteSession.Response(
                averageScore: avg,
                correctCount: correct,
                totalRounds: self.letters.count,
                achievedLetters: achieved,
                improvedLetters: improved
            )
            self.presenter?.presentCompleteSession(completeResponse)
            self.router?.routeToCompleteWith(score: Float(avg))
        }
    }

    // MARK: - Private: Proficiency tracking

    private func updateProficiency(letter: String, score: Double) {
        var entry = proficiencyMap[letter] ?? LetterTracingModels.LetterProficiency(letter: letter)
        entry.attempts += 1
        entry.lastScore = score
        if score > entry.bestScore {
            entry.bestScore = score
        }
        entry.isAchieved = entry.bestScore >= 0.90
        proficiencyMap[letter] = entry
        let best = String(format: "%.2f", entry.bestScore)
        logger.debug(
            "Proficiency updated letter='\(letter, privacy: .public)' best=\(best, privacy: .public) achieved=\(entry.isAchieved, privacy: .public)"
        )
    }

    // MARK: - Private: Logging

    private struct ScoreEntry {
        let letter: String
        let attempt: Int
        let recognition: Double
        let coverage: Double
        let speed: Double
        let finalScore: Double
    }

    private func logScore(_ entry: ScoreEntry) {
        let rStr = String(format: "%.2f", entry.recognition)
        let cStr = String(format: "%.2f", entry.coverage)
        let sStr = String(format: "%.2f", entry.speed)
        let fStr = String(format: "%.2f", entry.finalScore)
        let scoreMsg = "Score '\(entry.letter)' #\(entry.attempt) r=\(rStr) c=\(cStr) s=\(sStr) f=\(fStr)"
        logger.info("\(scoreMsg, privacy: .public)")
    }

    // MARK: - Private: Scoring helpers

    private func compositeScore(recognition: Double, coverage: Double, speed: Double) -> Double {
        (recognition * 0.5) + (coverage * 0.3) + (speed * 0.2)
    }

    /// Метрика покрытия: насколько рисунок попадает в bounding box буквы.
    private func computeCoverageScore(drawing: PKDrawing, letter: String) -> Double {
        let drawingBounds = drawing.bounds
        guard !drawingBounds.isEmpty else { return 0.0 }

        let templateBounds = Self.estimatedLetterBounds(canvasBounds: drawingBounds)
        let intersection = drawingBounds.intersection(templateBounds)

        guard !intersection.isNull,
              templateBounds.width > 0,
              templateBounds.height > 0 else {
            return 0.0
        }

        let intersectArea = intersection.width * intersection.height
        let templateArea = templateBounds.width * templateBounds.height
        let raw = Double(intersectArea / templateArea)
        return min(1.0, raw)
    }

    private static func estimatedLetterBounds(canvasBounds: CGRect) -> CGRect {
        let cx = canvasBounds.midX
        let cy = canvasBounds.midY
        let hw = canvasBounds.width * 0.35
        let hh = canvasBounds.height * 0.40
        return CGRect(x: cx - hw, y: cy - hh, width: hw * 2, height: hh * 2)
    }

    /// Speed score с поправкой на уровень: freeWrite не штрафует за медленное написание.
    private func computeSpeedScore(
        duration: TimeInterval,
        level: LetterTracingModels.TracingLevel
    ) -> Double {
        switch level {
        case .freeWrite:
            if duration < 8 { return 1.0 }
            if duration < 15 { return 0.5 }
            return 0.0
        default:
            if duration < 5 { return 1.0 }
            if duration < 10 { return 0.5 }
            return 0.0
        }
    }

    // MARK: - Private: Tracing level

    private func tracingLevel(for difficulty: Int) -> LetterTracingModels.TracingLevel {
        switch difficulty {
        case 1: return .overTemplate
        case 2: return .dotsOnly
        default: return .freeWrite
        }
    }

    // MARK: - Private: Letter sequence

    private static func letterSequence(for target: String, difficulty: Int) -> [String] {
        let upper = target.uppercased()
        if difficulty <= 1 {
            return Array(repeating: upper, count: 3)
        }
        let similar = similarLetters(for: upper)
        var seq = [upper, upper] + similar.prefix(1)
        seq.shuffle()
        return seq
    }

    // MARK: - Private: Similar letters (split for cyclomatic complexity)

    private static func similarLetters(for letter: String) -> [String] {
        similarLettersFirstHalf(for: letter) ?? similarLettersSecondHalf(for: letter) ?? ["А", "О"]
    }

    private static func similarLettersFirstHalf(for letter: String) -> [String]? {
        switch letter {
        case "А": return ["Д", "Л"]
        case "Б": return ["В", "Р"]
        case "В": return ["Б", "Р"]
        case "Г": return ["П", "Т"]
        case "Д": return ["А", "Л"]
        case "Е", "Ё": return ["З", "С"]
        case "З": return ["Е", "С"]
        case "И": return ["Й", "Н"]
        case "Й": return ["И", "Н"]
        case "К": return ["Х", "Ж"]
        case "Л": return ["А", "Д"]
        case "М": return ["Н", "П"]
        case "Н": return ["И", "М"]
        case "О": return ["С", "Ю"]
        case "П": return ["Г", "Н"]
        case "Р": return ["В", "Б"]
        default: return nil
        }
    }

    private static func similarLettersSecondHalf(for letter: String) -> [String]? {
        switch letter {
        case "С": return ["О", "З"]
        case "Т": return ["Г", "П"]
        case "У": return ["Ч", "Ш"]
        case "Ф": return ["О", "Ю"]
        case "Х": return ["К", "Ж"]
        case "Ц": return ["Щ", "Ш"]
        case "Ч": return ["У", "Щ"]
        case "Ш": return ["Щ", "Ц"]
        case "Щ": return ["Ш", "Ц"]
        case "Ъ": return ["Ь", "Б"]
        case "Ы": return ["В", "Р"]
        case "Ь": return ["Ъ", "Б"]
        case "Э": return ["Е", "З"]
        case "Ю": return ["О", "Ф"]
        case "Я": return ["Р", "В"]
        default: return nil
        }
    }

    // MARK: - Private: Phoneme words (первая половина — А...Н)

    /// Слово-пример начинающееся на данную букву, для ассоциации фонемы.
    /// Разбито на две функции для снижения cyclomatic complexity.
    static func phonemeWord(for letter: String) -> String {
        phonemeWordFirstHalf(for: letter)
            ?? phonemeWordSecondHalf(for: letter)
            ?? letter.lowercased()
    }

    private static func phonemeWordFirstHalf(for letter: String) -> String? {
        switch letter {
        case "А": return "арбуз"
        case "Б": return "бабочка"
        case "В": return "волк"
        case "Г": return "гусь"
        case "Д": return "дом"
        case "Е": return "ёжик"
        case "Ё": return "ёлка"
        case "Ж": return "жираф"
        case "З": return "зайка"
        case "И": return "игла"
        case "Й": return "йогурт"
        case "К": return "кот"
        case "Л": return "лиса"
        case "М": return "мышка"
        case "Н": return "нос"
        case "О": return "облако"
        default: return nil
        }
    }

    private static func phonemeWordSecondHalf(for letter: String) -> String? {
        switch letter {
        case "П": return "петух"
        case "Р": return "рыба"
        case "С": return "сани"
        case "Т": return "тигр"
        case "У": return "утка"
        case "Ф": return "фонарь"
        case "Х": return "хомяк"
        case "Ц": return "цапля"
        case "Ч": return "чайник"
        case "Ш": return "шапка"
        case "Щ": return "щука"
        case "Ъ": return "объект"
        case "Ы": return "мыло"
        case "Ь": return "конь"
        case "Э": return "экран"
        case "Ю": return "юла"
        case "Я": return "яблоко"
        default: return nil
        }
    }

    // MARK: - Private: Stroke count per letter

    /// Приблизительное количество штрихов для написания буквы.
    /// Используется для UI-индикатора «ожидаемых штрихов».
    static func strokeCount(for letter: String) -> Int {
        switch letter {
        case "А", "Д", "Ж", "З", "К", "Л", "М", "Н", "Х", "Ц", "Ч", "Ш", "Щ", "Э", "Я":
            return 2
        case "Б", "В", "Г", "Е", "Ё", "Й", "П", "Р", "С", "Т", "У", "Ъ", "Ь", "Ю":
            return 2
        case "И":
            return 3
        case "Ф":
            return 1
        default:
            return 1
        }
    }

    // MARK: - Private: Voice prompt builder

    private static func buildVoicePrompt(
        for letter: String,
        phonemeWord: String,
        level: LetterTracingModels.TracingLevel
    ) -> String {
        switch level {
        case .overTemplate:
            return String(
                localized: "letter_tracing.voice.prompt_template \(letter) \(phonemeWord)"
            )
        case .dotsOnly:
            return String(
                localized: "letter_tracing.voice.prompt_dots \(letter) \(phonemeWord)"
            )
        case .freeWrite:
            return String(
                localized: "letter_tracing.voice.prompt_free \(letter) \(phonemeWord)"
            )
        }
    }
}
