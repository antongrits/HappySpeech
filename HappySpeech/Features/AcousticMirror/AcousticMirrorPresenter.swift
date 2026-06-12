import Foundation

// MARK: - AcousticMirrorPresentationLogic

@MainActor
protocol AcousticMirrorPresentationLogic: AnyObject {
    func presentStart(_ response: AcousticMirrorModels.Start.Response)
    func presentRecording()
    func presentAnalyzing()
    func presentAttempt(_ response: AcousticMirrorModels.Attempt.Response)
    func presentComplete(_ response: AcousticMirrorModels.Complete.Response)
    func presentFailure(permissionDenied: Bool)
}

// MARK: - AcousticMirrorDisplayLogic

@MainActor
protocol AcousticMirrorDisplayLogic: AnyObject {
    func displayStart(_ viewModel: AcousticMirrorModels.Start.ViewModel)
    func displayPhase(_ phase: AcousticMirrorModels.Phase)
    func displayAttempt(_ viewModel: AcousticMirrorModels.Attempt.ViewModel)
    func displayComplete(_ viewModel: AcousticMirrorModels.Complete.ViewModel)
    func displayFailure(_ viewModel: AcousticMirrorModels.Failure.ViewModel)
}

// MARK: - AcousticMirrorPresenter

/// Формирует детские формулировки результата из акустического вердикта.
/// Тексты — поддерживающие, без «неправильно» (errorless-подход).
@MainActor
final class AcousticMirrorPresenter: AcousticMirrorPresentationLogic {

    weak var display: (any AcousticMirrorDisplayLogic)?

    // MARK: - Present

    func presentStart(_ response: AcousticMirrorModels.Start.Response) {
        let pole = SibilantPole.pole(forTargetSound: response.targetSound) ?? .whistling
        let hint = pole == .whistling
            ? String(localized: "acousticMirror.pole.whistling")
            : String(localized: "acousticMirror.pole.hissing")
        let instruction = String(
            format: String(localized: "acousticMirror.instruction"),
            response.targetSound, response.targetSound, response.targetSound
        )
        display?.displayStart(
            AcousticMirrorModels.Start.ViewModel(
                targetSound: response.targetSound,
                targetHint: hint,
                totalRounds: response.totalRounds,
                instruction: instruction
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

    func presentAttempt(_ response: AcousticMirrorModels.Attempt.Response) {
        let evaluation = response.evaluation
        let viewModel = AcousticMirrorModels.Attempt.ViewModel(
            continuumPosition: evaluation.continuumPosition,
            hasMeasurement: evaluation.verdict != .noFrication,
            title: Self.title(for: evaluation),
            hint: Self.hint(for: evaluation),
            stars: evaluation.stars,
            roundNumber: response.roundNumber,
            totalRounds: response.totalRounds,
            mascotCelebrates: evaluation.stars >= 2
        )
        display?.displayAttempt(viewModel)
        display?.displayPhase(response.isSessionComplete ? .completed : .result)
    }

    func presentComplete(_ response: AcousticMirrorModels.Complete.Response) {
        // Нормировка: 0…3 звезды сессии от доли набранных.
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
            ? String(localized: "acousticMirror.complete.great")
            : String(localized: "acousticMirror.complete.keepGoing")
        let subtitle = String(
            format: String(localized: "acousticMirror.complete.subtitle"),
            response.targetSound
        )
        display?.displayComplete(
            AcousticMirrorModels.Complete.ViewModel(
                title: title,
                subtitle: subtitle,
                sessionStars: sessionStars
            )
        )
    }

    func presentFailure(permissionDenied: Bool) {
        let message = permissionDenied
            ? String(localized: "acousticMirror.error.micPermission")
            : String(localized: "acousticMirror.error.generic")
        display?.displayFailure(
            AcousticMirrorModels.Failure.ViewModel(
                message: message,
                isPermissionIssue: permissionDenied
            )
        )
        display?.displayPhase(.ready)
    }

    // MARK: - Wording

    static func title(for evaluation: SibilantEvaluation) -> String {
        switch evaluation.verdict {
        case .onTarget:
            return String(localized: "acousticMirror.result.onTarget")
        case .nearTarget:
            return String(localized: "acousticMirror.result.nearTarget")
        case .middle:
            return String(localized: "acousticMirror.result.middle")
        case .oppositePole:
            return evaluation.targetPole == .whistling
                ? String(localized: "acousticMirror.result.sweptToHissing")
                : String(localized: "acousticMirror.result.sweptToWhistling")
        case .noFrication:
            return String(localized: "acousticMirror.result.noSound")
        }
    }

    static func hint(for evaluation: SibilantEvaluation) -> String? {
        if evaluation.verdict == .noFrication {
            return String(localized: "acousticMirror.hint.sustain")
        }
        // Первый по приоритету качественный флаг → подсказка-действие.
        if evaluation.flags.contains(.weakAirstream) {
            return String(localized: "acousticMirror.hint.airstream")
        }
        if evaluation.flags.contains(.diffuseSpectrum) {
            return String(localized: "acousticMirror.hint.focus")
        }
        if evaluation.flags.contains(.shortSustain) {
            return String(localized: "acousticMirror.hint.longer")
        }
        switch evaluation.verdict {
        case .middle, .oppositePole:
            return evaluation.targetPole == .whistling
                ? String(localized: "acousticMirror.hint.towardWhistling")
                : String(localized: "acousticMirror.hint.towardHissing")
        default:
            return nil
        }
    }
}
