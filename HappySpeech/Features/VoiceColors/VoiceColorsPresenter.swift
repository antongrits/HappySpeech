import Foundation
import OSLog

// MARK: - VoiceColorsPresentationLogic

@MainActor
protocol VoiceColorsPresentationLogic: AnyObject {
    func presentStart(_ viewModel: VoiceColorsStartViewModel)
    func presentSelectIntonation(_ response: VoiceColorsModels.SelectIntonation.Response)
    func presentSelectStressWord(_ response: VoiceColorsModels.SelectStressWord.Response)
    func presentSelectEmotion(_ response: VoiceColorsModels.SelectEmotion.Response)
    func presentRecording(_ isRecording: Bool)
    func presentPlaying(_ isPlaying: Bool)
    func presentLiveSample(_ response: VoiceColorsModels.LiveSample.Response)
    func presentScore(_ response: VoiceColorsModels.Score.Response)
    func presentComplete(_ response: VoiceColorsModels.Complete.Response)
    /// Микрофон не разрешён — показать понятное сообщение вместо тихого 1★.
    func presentMicrophoneDenied()
}

// MARK: - VoiceColorsPresenter
//
// Конвертирует Response → ViewModel: локализация подсказок, нормализация
// амплитуды/высот столбиков, тёплые безоценочные тексты результата.
// Бизнес-логика (анализ контура/RMS/эмоции, прогресс) — в Interactor.

@MainActor
final class VoiceColorsPresenter: VoiceColorsPresentationLogic {

    weak var display: (any VoiceColorsDisplayLogic)?

    private let stressAnalyzer = WordStressAnalyzer()
    private let logger = Logger(subsystem: "ru.happyspeech", category: "VoiceColorsPresenter")

    // MARK: - Start

    func presentStart(_ viewModel: VoiceColorsStartViewModel) {
        logger.info("presentStart mode=\(viewModel.mode.rawValue, privacy: .public)")
        display?.displayStart(viewModel)
    }

    // MARK: - Select

    func presentSelectIntonation(_ response: VoiceColorsModels.SelectIntonation.Response) {
        display?.displaySelectIntonation(response)
    }

    func presentSelectStressWord(_ response: VoiceColorsModels.SelectStressWord.Response) {
        display?.displaySelectStressWord(response)
    }

    func presentSelectEmotion(_ response: VoiceColorsModels.SelectEmotion.Response) {
        display?.displaySelectEmotion(response)
    }

    // MARK: - Recording / playing

    func presentRecording(_ isRecording: Bool) {
        display?.displayRecording(isRecording)
    }

    func presentMicrophoneDenied() {
        logger.info("presentMicrophoneDenied")
        display?.displayMicrophoneDenied(
            message: String(
                localized: "voiceColors.mic.denied",
                defaultValue: "Чтобы услышать твой голос, разреши доступ к микрофону в Настройках телефона."
            )
        )
    }

    func presentPlaying(_ isPlaying: Bool) {
        display?.displayPlaying(isPlaying)
    }

    func presentLiveSample(_ response: VoiceColorsModels.LiveSample.Response) {
        display?.displayLiveSample(.init(
            liveContour: response.liveContour,
            amplitudeNormalised: CGFloat(min(max(response.amplitude, 0), 1))
        ))
    }

    // MARK: - Score

    func presentScore(_ response: VoiceColorsModels.Score.Response) {
        let title = scoreTitle(for: response)
        let message = scoreMessage(for: response)
        let heights = stressAnalyzer
            .normalisedHeights(perWordRMS: response.perWordRMS)
            .map { CGFloat($0) }

        display?.displayScore(.init(
            mode: response.mode,
            title: title,
            feedbackMessage: message,
            isMatch: response.isMatch,
            modelContour: response.modelContour,
            liveContour: response.liveContour,
            perWordHeights: heights,
            loudestWordIndex: response.loudestWordIndex,
            reflectedEmotion: response.detectedEmotion,
            accessibilityLabel: accessibilityLabel(for: response, message: message)
        ))
    }

    // MARK: - Complete

    func presentComplete(_ response: VoiceColorsModels.Complete.Response) {
        let stars = VoiceColorsScoring.stars(for: response.matchRate)
        display?.displayComplete(.init(
            starsEarned: stars,
            completionMessage: completionMessage(stars: stars),
            matchRate: response.matchRate
        ))
    }

    // MARK: - Private: copy

    private func scoreTitle(for response: VoiceColorsModels.Score.Response) -> String {
        switch response.mode {
        case .intonation:
            return response.isMatch
                ? String(localized: "voiceColors.score.intonation.match",
                         defaultValue: "Получилось! Линии почти совпали")
                : String(localized: "voiceColors.score.intonation.try",
                         defaultValue: "Почти! Попробуй догнать дорожку")
        case .stress:
            return response.isMatch
                ? String(localized: "voiceColors.score.stress.match",
                         defaultValue: "Главное слово прозвучало громче")
                : String(localized: "voiceColors.score.stress.try",
                         defaultValue: "Попробуй выделить нужное слово сильнее")
        case .emotion:
            return String(
                format: String(localized: "voiceColors.score.emotion %@",
                               defaultValue: "Ляля услышала: %@"),
                response.detectedEmotion.reflectionName + " " + response.detectedEmotion.emoji
            )
        }
    }

    private func scoreMessage(for response: VoiceColorsModels.Score.Response) -> String {
        switch response.mode {
        case .intonation:
            return response.isMatch
                ? String(localized: "voiceColors.feedback.intonation.match",
                         defaultValue: "Твой голосок повторил мелодию. Здорово!")
                : String(localized: "voiceColors.feedback.intonation.try",
                         defaultValue: "Послушай меня ещё раз и веди голосок по дорожке.")
        case .stress:
            return response.isMatch
                ? String(localized: "voiceColors.feedback.stress.match",
                         defaultValue: "Слышишь — это слово прозвучало ярче всех. Теперь любой поймёт!")
                : String(localized: "voiceColors.feedback.stress.try",
                         defaultValue: "Скажи главное слово погромче и протяжнее, остальные — тихонько.")
        case .emotion:
            return String(
                format: String(localized: "voiceColors.feedback.emotion %@",
                               defaultValue: "Я повторю твоё настроение — %@. Голос умеет звучать по-разному!"),
                response.detectedEmotion.name.lowercased()
            )
        }
    }

    private func completionMessage(stars: Int) -> String {
        switch stars {
        case 3:
            return String(localized: "voiceColors.done.3",
                          defaultValue: "Ты настоящий художник голоса! Краски звучали ярко.")
        case 2:
            return String(localized: "voiceColors.done.2",
                          defaultValue: "Здорово! Голос звучал по-разному — это и есть краски.")
        default:
            return String(localized: "voiceColors.done.1",
                          defaultValue: "Молодец, что попробовал! Голос — как кисточка, рисуй им дальше.")
        }
    }

    private func accessibilityLabel(
        for response: VoiceColorsModels.Score.Response, message: String
    ) -> String {
        switch response.mode {
        case .intonation:
            let percent = Int((response.intonationSimilarity * 100).rounded())
            return String(
                format: String(localized: "voiceColors.a11y.intonation %lld %@",
                               defaultValue: "Сходство мелодии %lld процентов. %@"),
                percent, message
            )
        case .stress:
            return message
        case .emotion:
            return String(
                format: String(localized: "voiceColors.a11y.emotion %@",
                               defaultValue: "Распознано настроение: %@. %@"),
                response.detectedEmotion.reflectionName, message
            )
        }
    }
}
