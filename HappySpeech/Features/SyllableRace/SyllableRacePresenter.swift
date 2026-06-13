import Foundation

// MARK: - SyllableRacePresentationLogic

@MainActor
protocol SyllableRacePresentationLogic: AnyObject {
    func presentStart(_ response: SyllableRaceModels.Start.Response)
    func presentRecording()
    func presentAnalyzing()
    func presentAttempt(_ response: SyllableRaceModels.Attempt.Response)
    func presentComplete(_ response: SyllableRaceModels.Complete.Response)
    func presentFailure(permissionDenied: Bool)
}

// MARK: - SyllableRaceDisplayLogic

@MainActor
protocol SyllableRaceDisplayLogic: AnyObject {
    func displayStart(_ viewModel: SyllableRaceModels.Start.ViewModel)
    func displayPhase(_ phase: SyllableRaceModels.Phase)
    func displayAttempt(_ viewModel: SyllableRaceModels.Attempt.ViewModel)
    func displayComplete(_ viewModel: SyllableRaceModels.Complete.ViewModel)
    func displayFailure(_ viewModel: SyllableRaceModels.Failure.ViewModel)
}

// MARK: - SyllableRacePresenter

/// Формирует детские формулировки результата из вердикта диадохокинеза.
/// Тексты — поддерживающие, без «неправильно» (errorless-подход).
@MainActor
final class SyllableRacePresenter: SyllableRacePresentationLogic {

    weak var display: (any SyllableRaceDisplayLogic)?

    // MARK: - Present

    func presentStart(_ response: SyllableRaceModels.Start.Response) {
        let instruction = String(
            format: String(localized: "syllableRace.instruction"),
            response.sequence.displayString
        )
        display?.displayStart(
            SyllableRaceModels.Start.ViewModel(
                sequenceDisplay: response.sequence.displayString,
                syllables: response.sequence.syllables,
                instruction: instruction,
                roundNumber: response.roundNumber,
                totalRounds: response.totalRounds
            )
        )
        display?.displayPhase(.ready)
    }

    func presentRecording() {
        display?.displayPhase(.recording)
    }

    func presentAnalyzing() {
        display?.displayPhase(.analyzing)
    }

    func presentAttempt(_ response: SyllableRaceModels.Attempt.Response) {
        let evaluation = response.evaluation
        let hasMeasurement = evaluation.verdict != .notDetected
        let viewModel = SyllableRaceModels.Attempt.ViewModel(
            rocketHeight: Self.rocketHeight(for: evaluation),
            hasMeasurement: hasMeasurement,
            title: Self.title(for: evaluation),
            rateLabel: Self.rateLabel(for: evaluation),
            steadinessLabel: Self.steadinessLabel(for: evaluation),
            hint: Self.hint(for: evaluation),
            stars: evaluation.stars,
            roundNumber: response.roundNumber,
            totalRounds: response.totalRounds,
            mascotCelebrates: evaluation.stars >= 2
        )
        display?.displayAttempt(viewModel)
        display?.displayPhase(response.isSessionComplete ? .completed : .result)
    }

    func presentComplete(_ response: SyllableRaceModels.Complete.Response) {
        let share = response.maxStars > 0
            ? Double(response.totalStars) / Double(response.maxStars)
            : 0
        let sessionStars: Int
        switch share {
        case 0.78...: sessionStars = 3
        case 0.5 ..< 0.78: sessionStars = 2
        case 0.2 ..< 0.5: sessionStars = 1
        default: sessionStars = 0
        }

        let title = sessionStars >= 2
            ? String(localized: "syllableRace.complete.great")
            : String(localized: "syllableRace.complete.keepGoing")
        let subtitle = String(
            format: String(localized: "syllableRace.complete.subtitle"),
            Self.formattedRate(response.bestRate)
        )
        display?.displayComplete(
            SyllableRaceModels.Complete.ViewModel(
                title: title,
                subtitle: subtitle,
                sessionStars: sessionStars
            )
        )
    }

    func presentFailure(permissionDenied: Bool) {
        let message = permissionDenied
            ? String(localized: "syllableRace.error.micPermission")
            : String(localized: "syllableRace.error.generic")
        display?.displayFailure(
            SyllableRaceModels.Failure.ViewModel(
                message: message,
                isPermissionIssue: permissionDenied
            )
        )
        display?.displayPhase(.ready)
    }

    // MARK: - Mapping helpers

    /// Высота ракеты 0…1: комбинация «сколько звёзд» (грубо) и ровности (точно).
    /// 3 звезды → ~0.92, 2 → ~0.66, 1 → ~0.38, 0 → 0; ровность приподнимает в зоне.
    static func rocketHeight(for evaluation: DDKEvaluation) -> Double {
        guard evaluation.verdict != .notDetected else { return 0 }
        let base: Double
        switch evaluation.stars {
        case 3: base = 0.92
        case 2: base = 0.66
        case 1: base = 0.38
        default: base = 0.12
        }
        // Ровность ритма даёт небольшой бонус/штраф (±0.06).
        let steadyAdjust = ((evaluation.steadiness ?? 0.5) - 0.5) * 0.12
        return min(1, max(0, base + steadyAdjust))
    }

    static func title(for evaluation: DDKEvaluation) -> String {
        switch evaluation.verdict {
        case .fastSteady:
            return String(localized: "syllableRace.result.fastSteady")
        case .steady:
            return String(localized: "syllableRace.result.steady")
        case .uneven:
            return String(localized: "syllableRace.result.uneven")
        case .slow:
            return String(localized: "syllableRace.result.slow")
        case .notDetected:
            return String(localized: "syllableRace.result.notDetected")
        }
    }

    static func rateLabel(for evaluation: DDKEvaluation) -> String {
        guard evaluation.verdict != .notDetected else {
            return String(localized: "syllableRace.rate.unknown")
        }
        return String(
            format: String(localized: "syllableRace.rate.value"),
            formattedRate(evaluation.syllablesPerSecond)
        )
    }

    static func steadinessLabel(for evaluation: DDKEvaluation) -> String? {
        guard let steadiness = evaluation.steadiness, evaluation.verdict != .notDetected else {
            return nil
        }
        if steadiness >= 0.75 {
            return String(localized: "syllableRace.rhythm.steady")
        } else if steadiness >= 0.45 {
            return String(localized: "syllableRace.rhythm.ok")
        }
        return String(localized: "syllableRace.rhythm.uneven")
    }

    static func hint(for evaluation: DDKEvaluation) -> String? {
        if evaluation.verdict == .notDetected {
            return String(localized: "syllableRace.hint.louder")
        }
        // Приоритет качественных флагов → подсказка-действие.
        if evaluation.flags.contains(.weakVoice) {
            return String(localized: "syllableRace.hint.louder")
        }
        if evaluation.flags.contains(.incompleteSequence) {
            return String(localized: "syllableRace.hint.allTheWay")
        }
        if evaluation.flags.contains(.unevenRhythm) {
            return String(localized: "syllableRace.hint.steady")
        }
        if evaluation.flags.contains(.extraSyllables) {
            return String(localized: "syllableRace.hint.clear")
        }
        if evaluation.verdict == .slow {
            return String(localized: "syllableRace.hint.faster")
        }
        return nil
    }

    /// Форматирует темп: «4.6» (одна десятичная, запятая в русской локали через NumberFormatter не нужна — String(localized) шаблон сам подставит).
    static func formattedRate(_ rate: Double) -> String {
        String(format: "%.1f", rate)
    }
}
