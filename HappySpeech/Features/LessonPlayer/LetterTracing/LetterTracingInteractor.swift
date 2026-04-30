import CoreGraphics
import OSLog
import PencilKit
import UIKit

// MARK: - LetterTracingInteractor

/// Бизнес-логика шаблона «Написание буквы» (LetterTracing, 18-й шаблон).
///
/// Scoring — три компонента:
///   | Компонент         | Вес | Метод                                         |
///   |-------------------|-----|-----------------------------------------------|
///   | Vision recognition| 50% | recognizedLetter == targetLetter → 1.0        |
///   | Stroke coverage   | 30% | пересечение bounding boxes / area буквы       |
///   | Speed bonus       | 20% | < 5с → 1.0, < 10с → 0.5, иначе 0.0           |
///
/// iPad-only guard: `UIDevice.current.userInterfaceIdiom == .pad`.
/// На iPhone routing заблокирован в SessionShellBinder.
@MainActor
final class LetterTracingInteractor: LetterTracingBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any LetterTracingPresentationLogic)?
    var router: (any LetterTracingRoutingLogic)?

    private let recognitionWorker = HandwritingRecognitionWorker()
    private let logger = Logger(subsystem: "ru.happyspeech", category: "LetterTracing")

    // MARK: - Session state

    private var letters: [String] = []
    private var currentIndex: Int = 0
    private var scores: [Double] = []
    private var drawingStartDate: Date?

    // MARK: - Init

    init() {}

    // MARK: - LetterTracingBusinessLogic

    func loadExercise(_ request: LetterTracingModels.LoadExercise.Request) async {
        // Bootstrap on first call.
        if letters.isEmpty {
            letters = Self.letterSequence(for: request.targetLetter, difficulty: request.difficulty)
            currentIndex = 0
            scores = []
            logger.info(
                "Session bootstrap letter='\(request.targetLetter, privacy: .public)' rounds=\(self.letters.count, privacy: .public)"
            )
        }

        guard currentIndex < letters.count else {
            logger.notice("loadExercise called but no more letters in queue")
            return
        }

        let letter = letters[currentIndex]
        drawingStartDate = Date()

        let response = LetterTracingModels.LoadExercise.Response(
            targetLetter: letter,
            promptText: letter,
            roundIndex: currentIndex,
            totalRounds: letters.count
        )
        presenter?.presentLoadExercise(response)
    }

    func submitDrawing(_ request: LetterTracingModels.SubmitDrawing.Request) async {
        let duration = drawingStartDate.map { Date().timeIntervalSince($0) } ?? 0

        // 1. Vision recognition (async, на actor).
        let recognized = await recognitionWorker.recognizeLetter(from: request.drawing)
        let recognizedStr = recognized ?? "nil"
        logger.debug(
            "Recognition result='\(recognizedStr, privacy: .public)' target='\(request.targetLetter, privacy: .public)'"
        )

        // 2. Coverage score.
        let coverage = computeCoverageScore(
            drawing: request.drawing,
            letter: request.targetLetter
        )

        // 3. Speed score.
        let speed = computeSpeedScore(duration: duration)

        // 4. Recognition score.
        let recognitionScore: Double = (recognized == request.targetLetter) ? 1.0 : 0.0

        // 5. Composite.
        let finalScore = (recognitionScore * 0.5) + (coverage * 0.3) + (speed * 0.2)
        let isCorrect = finalScore >= 0.4

        scores.append(finalScore)
        logScore(
            recognition: recognitionScore,
            coverage: coverage,
            speed: speed,
            final: finalScore
        )

        let response = LetterTracingModels.SubmitDrawing.Response(
            recognizedLetter: recognized,
            targetLetter: request.targetLetter,
            recognitionScore: recognitionScore,
            coverageScore: coverage,
            speedScore: speed,
            finalScore: finalScore,
            isCorrect: isCorrect
        )
        presenter?.presentSubmitDrawing(response)

        // Advance to next round after a short UI pause (handled in View via feedback).
        currentIndex += 1
        if currentIndex >= letters.count {
            scheduleSessionComplete()
        }
    }

    func resetCanvas(_ request: LetterTracingModels.ResetCanvas.Request) {
        drawingStartDate = Date()
        presenter?.presentResetCanvas(LetterTracingModels.ResetCanvas.Response())
        logger.debug("Canvas reset, timer restarted")
    }

    // MARK: - Private: Scheduling session complete

    private func scheduleSessionComplete() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Небольшая задержка чтобы UI успел показать feedback последнего раунда.
            try? await Task.sleep(for: .milliseconds(1200))
            let avg = self.scores.isEmpty
                ? 0.0
                : self.scores.reduce(0, +) / Double(self.scores.count)
            let correct = self.scores.filter { $0 >= 0.4 }.count

            let completeResponse = LetterTracingModels.CompleteSession.Response(
                averageScore: avg,
                correctCount: correct,
                totalRounds: self.letters.count
            )
            self.presenter?.presentCompleteSession(completeResponse)
            self.router?.routeToCompleteWith(score: Float(avg))
        }
    }

    // MARK: - Private: Logging

    private func logScore(recognition: Double, coverage: Double, speed: Double, final finalScore: Double) {
        let rStr = String(format: "%.2f", recognition)
        let cStr = String(format: "%.2f", coverage)
        let sStr = String(format: "%.2f", speed)
        let fStr = String(format: "%.2f", finalScore)
        logger.info("Score r=\(rStr, privacy: .public) c=\(cStr, privacy: .public) s=\(sStr, privacy: .public) f=\(fStr, privacy: .public)")
    }

    // MARK: - Private: Scoring helpers

    /// Метрика покрытия: насколько рисунок попадает в предполагаемую
    /// bounding box буквы. Bounding box задаётся эвристически — центр
    /// холста, 70% высоты и 60% ширины — так как реальные координаты шрифта
    /// недоступны без CoreText рендера.
    private func computeCoverageScore(drawing: PKDrawing, letter: String) -> Double {
        let drawingBounds = drawing.bounds
        guard !drawingBounds.isEmpty else { return 0.0 }

        let templateBounds = Self.estimatedLetterBounds(canvasBounds: drawingBounds)
        let intersection = drawingBounds.intersection(templateBounds)

        guard !intersection.isNull, templateBounds.width > 0, templateBounds.height > 0 else {
            return 0.0
        }

        let intersectArea = intersection.width * intersection.height
        let templateArea = templateBounds.width * templateBounds.height
        let raw = Double(intersectArea / templateArea)
        return min(1.0, raw)
    }

    /// Оценивает bounding box буквы относительно рисунка.
    /// Используем центр рисунка ±35% ширины/высоты как ожидаемую зону.
    private static func estimatedLetterBounds(canvasBounds: CGRect) -> CGRect {
        let cx = canvasBounds.midX
        let cy = canvasBounds.midY
        let hw = canvasBounds.width * 0.35
        let hh = canvasBounds.height * 0.40
        return CGRect(x: cx - hw, y: cy - hh, width: hw * 2, height: hh * 2)
    }

    private func computeSpeedScore(duration: TimeInterval) -> Double {
        if duration < 5 { return 1.0 }
        if duration < 10 { return 0.5 }
        return 0.0
    }

    // MARK: - Private: Letter sequence

    /// Строит последовательность букв для упражнения.
    /// Сложность 1: только целевая буква ×3.
    /// Сложность 2+: целевая + пара похожих ×2.
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

    /// Визуально похожие буквы — для усложнённого режима.
    /// Разбито на две функции для снижения cyclomatic complexity.
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

    // MARK: - Static: iPad guard

    /// Возвращает true если устройство — iPad (LetterTracing primary target).
    static func isAvailable() -> Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}
