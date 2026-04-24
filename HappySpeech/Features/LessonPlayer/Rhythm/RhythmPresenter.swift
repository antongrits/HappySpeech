import Foundation

// MARK: - RhythmPresentationLogic

@MainActor
protocol RhythmPresentationLogic: AnyObject {
    func presentLoadPattern(_ response: RhythmModels.LoadPattern.Response)
    func presentPlayPattern(_ response: RhythmModels.PlayPattern.Response)
    func presentStartRecord(_ response: RhythmModels.StartRecord.Response)
    func presentUpdateRMS(_ response: RhythmModels.UpdateRMS.Response)
    func presentEvaluateRhythm(_ response: RhythmModels.EvaluateRhythm.Response)
    func presentNextPattern(_ response: RhythmModels.NextPattern.Response)
    func presentComplete(_ response: RhythmModels.Complete.Response)
}

// MARK: - RhythmPresenter
//
// Делает Response → ViewModel и отдаёт в `viewModel` (store на стороне View).
// Здесь живут все пользовательские тексты и правила отображения
// (звёздная шкала, локализованные фразы обратной связи).

@MainActor
final class RhythmPresenter: RhythmPresentationLogic {

    weak var viewModel: (any RhythmDisplayLogic)?

    // MARK: - LoadPattern

    func presentLoadPattern(_ response: RhythmModels.LoadPattern.Response) {
        let p = response.pattern
        let beats = p.beats.map {
            RhythmBeatDisplay(strength: $0, isActive: false, wasHit: false)
        }
        let progress = Double(response.patternIndex) / Double(max(1, response.totalPatterns))
        let vm = RhythmModels.LoadPattern.ViewModel(
            beats: beats,
            syllableWord: p.syllableWord,
            targetWord: p.targetWord,
            displayPattern: p.displayPattern,
            emoji: p.emoji,
            patternIndex: response.patternIndex,
            totalPatterns: response.totalPatterns,
            progressFraction: progress
        )
        viewModel?.displayLoadPattern(vm)
    }

    // MARK: - PlayPattern

    func presentPlayPattern(_ response: RhythmModels.PlayPattern.Response) {
        let vm = RhythmModels.PlayPattern.ViewModel(activeBeatIndex: response.activeBeatIndex)
        viewModel?.displayPlayPattern(vm)
    }

    // MARK: - StartRecord

    func presentStartRecord(_ response: RhythmModels.StartRecord.Response) {
        viewModel?.displayStartRecord(.init())
    }

    // MARK: - UpdateRMS

    func presentUpdateRMS(_ response: RhythmModels.UpdateRMS.Response) {
        let clamped = max(0, min(1, response.rmsLevel))
        let vm = RhythmModels.UpdateRMS.ViewModel(
            rmsLevel: clamped,
            detectedBeats: response.detectedBeats
        )
        viewModel?.displayUpdateRMS(vm)
    }

    // MARK: - EvaluateRhythm

    func presentEvaluateRhythm(_ response: RhythmModels.EvaluateRhythm.Response) {
        let feedbackText: String
        if response.correct {
            feedbackText = String(localized: "Отличный ритм!")
        } else {
            let diff = response.detectedBeats - response.expectedBeats
            if diff > 0 {
                feedbackText = String(localized: "Слишком много слогов. Попробуй ещё раз.")
            } else if diff < 0 {
                feedbackText = String(localized: "Не хватает слогов. Скажи все до конца.")
            } else {
                feedbackText = String(localized: "Почти! Повтори ритм ещё раз.")
            }
        }

        let stars = Self.stars(for: response.score)
        let vm = RhythmModels.EvaluateRhythm.ViewModel(
            feedbackText: feedbackText,
            feedbackCorrect: response.correct,
            starsPreview: stars,
            beatsWasHit: response.beatsWasHit,
            lastScore: response.score
        )
        viewModel?.displayEvaluateRhythm(vm)
    }

    // MARK: - NextPattern

    func presentNextPattern(_ response: RhythmModels.NextPattern.Response) {
        viewModel?.displayNextPattern(.init())
    }

    // MARK: - Complete

    func presentComplete(_ response: RhythmModels.Complete.Response) {
        let stars = Self.stars(for: response.finalScore)
        let completionMessage: String
        switch stars {
        case 3: completionMessage = String(localized: "Превосходный ритм!")
        case 2: completionMessage = String(localized: "Молодец, ритм получается!")
        case 1: completionMessage = String(localized: "Хорошо, ещё немного попрактикуемся.")
        default: completionMessage = String(localized: "Продолжай тренироваться!")
        }
        let scoreLabel = String(
            format: String(localized: "Правильно %d из %d"),
            response.correctPatterns,
            response.totalPatterns
        )
        let vm = RhythmModels.Complete.ViewModel(
            completionMessage: completionMessage,
            scoreLabel: scoreLabel,
            starsEarned: stars,
            finalScore: response.finalScore
        )
        viewModel?.displayComplete(vm)
    }

    // MARK: - Scoring

    /// Шкала звёзд: ≥0.9→3, ≥0.7→2, ≥0.5→1, иначе 0.
    static func stars(for score: Float) -> Int {
        if score >= 0.9 { return 3 }
        if score >= 0.7 { return 2 }
        if score >= 0.5 { return 1 }
        return 0
    }
}
