import Foundation
import OSLog

// MARK: - VoiceStrongmanPresentationLogic

@MainActor
protocol VoiceStrongmanPresentationLogic: AnyObject {
    func presentStart(_ viewModel: VoiceStrongmanStartViewModel)
    func presentRecording(_ isRecording: Bool)
    func presentPlaying(_ isPlaying: Bool)
    func presentLiveSample(_ response: VoiceStrongmanModels.LiveSample.Response)
    func presentScore(_ response: VoiceStrongmanModels.Score.Response)
    func presentComplete(_ response: VoiceStrongmanModels.Complete.Response)
    /// Микрофон не разрешён — показать понятное сообщение вместо тихого 1★.
    func presentMicrophoneDenied()
}

// MARK: - VoiceStrongmanPresenter
//
// Конвертирует Response → ViewModel: локализация подсказок, нормализация
// громкости/высоты, тёплые безоценочные тексты результата. Бизнес-логика
// (анализ RMS/контура, прогресс) — в Interactor.

@MainActor
final class VoiceStrongmanPresenter: VoiceStrongmanPresentationLogic {

    weak var display: (any VoiceStrongmanDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "VoiceStrongmanPresenter")

    // MARK: - Start

    func presentStart(_ viewModel: VoiceStrongmanStartViewModel) {
        logger.info("presentStart mode=\(viewModel.mode.rawValue, privacy: .public)")
        display?.displayStart(viewModel)
    }

    // MARK: - Recording / playing

    func presentRecording(_ isRecording: Bool) {
        display?.displayRecording(isRecording)
    }

    func presentMicrophoneDenied() {
        logger.info("presentMicrophoneDenied")
        display?.displayMicrophoneDenied(
            message: String(
                localized: "voiceStrongman.mic.denied",
                defaultValue: "Чтобы услышать твой голос, разреши доступ к микрофону в Настройках телефона."
            )
        )
    }

    func presentPlaying(_ isPlaying: Bool) {
        display?.displayPlaying(isPlaying)
    }

    func presentLiveSample(_ response: VoiceStrongmanModels.LiveSample.Response) {
        display?.displayLiveSample(.init(
            loudnessNormalised: CGFloat(min(max(response.loudness, 0), 1)),
            pitchNormalised: CGFloat(min(max(response.pitchNorm, 0), 1)),
            inTarget: response.inTarget,
            liveContour: response.liveContour
        ))
    }

    // MARK: - Score

    func presentScore(_ response: VoiceStrongmanModels.Score.Response) {
        let title = scoreTitle(for: response)
        let message = scoreMessage(for: response)
        display?.displayScore(.init(
            mode: response.mode,
            title: title,
            feedbackMessage: message,
            isMatch: response.isMatch,
            loudnessNormalised: CGFloat(min(max(response.loudnessAverage, 0), 1)),
            loudnessInBand: response.loudnessInBand,
            ladderReached: CGFloat(min(max(response.ladderReached, 0), 1)),
            liveContour: response.liveContour,
            directionMatched: response.directionMatched,
            accessibilityLabel: accessibilityLabel(for: response, message: message)
        ))
    }

    // MARK: - Complete

    func presentComplete(_ response: VoiceStrongmanModels.Complete.Response) {
        let stars = VoiceStrongmanScoring.stars(for: response.matchRate)
        display?.displayComplete(.init(
            starsEarned: stars,
            completionMessage: completionMessage(stars: stars),
            matchRate: response.matchRate
        ))
    }

    // MARK: - Private: copy

    private func scoreTitle(for response: VoiceStrongmanModels.Score.Response) -> String {
        switch response.mode {
        case .loudness:
            return response.isMatch
                ? String(localized: "voiceStrongman.score.loudness.match",
                         defaultValue: "Попал в цель! Удобная громкость")
                : String(localized: "voiceStrongman.score.loudness.try",
                         defaultValue: "Почти! Попади в золотую полоску")
        case .pitch:
            return response.isMatch
                ? String(localized: "voiceStrongman.score.pitch.match",
                         defaultValue: "Голос прошёл всю лесенку!")
                : String(localized: "voiceStrongman.score.pitch.try",
                         defaultValue: "Почти! Веди голосок дальше по ступенькам")
        }
    }

    private func scoreMessage(for response: VoiceStrongmanModels.Score.Response) -> String {
        switch response.mode {
        case .loudness:
            return response.isMatch
                ? String(localized: "voiceStrongman.feedback.loudness.match",
                         defaultValue: "Голос звучал ровно — громко, но не криком. Здорово!")
                : String(localized: "voiceStrongman.feedback.loudness.try",
                         defaultValue: "Сделай голос чуть ровнее, чтобы шарик попал в золотую полоску.")
        case .pitch:
            return response.isMatch
                ? String(localized: "voiceStrongman.feedback.pitch.match",
                         defaultValue: "Ты плавно повёл голос по ступенькам — цыплёнок добрался!")
                : String(localized: "voiceStrongman.feedback.pitch.try",
                         defaultValue: "Тяни гласный плавно и веди голос всё дальше — без перепрыгиваний.")
        }
    }

    private func completionMessage(stars: Int) -> String {
        switch stars {
        case 3:
            return String(localized: "voiceStrongman.done.3",
                          defaultValue: "Настоящий силач голоса! Ты управляешь силой и высотой.")
        case 2:
            return String(localized: "voiceStrongman.done.2",
                          defaultValue: "Здорово! Голос звучал по-разному — то тихо, то высоко.")
        default:
            return String(localized: "voiceStrongman.done.1",
                          defaultValue: "Молодец, что попробовал! Голос — как силомер, тренируй его дальше.")
        }
    }

    private func accessibilityLabel(
        for response: VoiceStrongmanModels.Score.Response, message: String
    ) -> String {
        switch response.mode {
        case .loudness:
            let percent = Int((response.loudnessAverage * 100).rounded())
            return String(
                format: String(localized: "voiceStrongman.a11y.loudness %lld %@",
                               defaultValue: "Громкость %lld процентов. %@"),
                percent, message
            )
        case .pitch:
            let percent = Int((response.ladderReached * 100).rounded())
            return String(
                format: String(localized: "voiceStrongman.a11y.pitch %lld %@",
                               defaultValue: "Пройдено лесенки %lld процентов. %@"),
                percent, message
            )
        }
    }
}
